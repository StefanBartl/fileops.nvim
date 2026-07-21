---@module 'fileops.features.on_hold'
---Ambient, mode-aware line-diff preview on CursorHold/CursorHoldI.
---Prefers gitsigns' `preview_hunk_inline()` when available; otherwise falls
---back to rendering the previous committed content of the current line as
---EOL/right-aligned virtual text (via `git blame`/`git show`, argv-only —
---no shell). Per-window throttling and a generation counter guard against
---stale scheduled runs after a mode change.

local api, fn = vim.api, vim.fn
local uv = vim.uv or vim.loop
local autocmd = require("lib.nvim.autocmd")

local M = {}

---@type integer  Namespace for the fallback EOL/right-aligned virtual text
local NS = api.nvim_create_namespace("fileops_on_hold_preview")

---Clear this feature's virtual text in a buffer.
---@param buf integer
---@return nil
local function clear_line_diff(buf)
  if api.nvim_buf_is_valid(buf) then
    api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  end
end

---@param name string
---@return integer
local function augroup(name)
  -- Created directly via nvim_create_augroup(..., { clear = true }) rather
  -- than lib.nvim.autocmd.group(): that helper caches groups by name and
  -- skips the clear on subsequent calls, which would stack duplicate
  -- autocmds if setup() ever re-runs.
  return api.nvim_create_augroup("fileops_on_hold_" .. name, { clear = true })
end

---@param s string
---@param max_len integer
---@return string
local function truncate(s, max_len)
  if type(s) ~= "string" then
    return ""
  end
  local n = math.max(0, tonumber(max_len or 0) or 0)
  if #s <= n then
    return s
  end
  if n <= 2 then
    return s:sub(1, n)
  end
  return s:sub(1, n - 2) .. " …"
end

---@param first string|nil
---@return string|nil
local function parse_blame_sha(first)
  if type(first) ~= "string" or first == "" then
    return nil
  end
  local sha = first:match("^([0-9a-f]+)")
  if not sha then
    return nil
  end
  return (#sha >= 7 and #sha <= 40) and sha or nil
end

---@param win integer
---@return integer
local function get_lnum(win)
  return api.nvim_win_get_cursor(win)[1]
end

---Normalize Neovim's mode string to one of "n"|"v"|"i".
---@return "n"|"v"|"i"|nil
local function normalize_mode()
  local m = fn.mode(1)
  if m == "i" then
    return "i"
  end
  if m == "n" or m == "no" then
    return "n"
  end
  if m == "v" or m == "V" or m == "\022" then
    return "v"
  end
  return nil
end

---@param modes string|string[]|nil
---@return boolean
local function mode_allowed(modes)
  if modes == nil then
    return normalize_mode() ~= "i"
  end
  local want = {}
  if type(modes) == "string" then
    for c in modes:gmatch(".") do
      want[c] = true
    end
  else
    for _, c in ipairs(modes) do
      want[c] = true
    end
  end
  local cur = normalize_mode()
  return cur ~= nil and want[cur] == true
end

---@param stdout string|nil
---@return string[]
local function to_lines(stdout)
  if type(stdout) ~= "string" or stdout == "" then
    return {}
  end
  return vim.split((stdout:gsub("\n$", "")), "\n", { plain = true })
end

---@param git_cmd string
---@return boolean
local function in_git_repo(git_cmd)
  local res = vim.system({ git_cmd, "rev-parse", "--is-inside-work-tree" }, { text = true }):wait()
  return res.code == 0
end

---@param git_cmd string
---@param file string
---@return boolean
local function is_tracked(git_cmd, file)
  local res = vim.system({ git_cmd, "ls-files", "--error-unmatch", "--", file }, { text = true }):wait()
  return res.code == 0
end

---@param ignore_buftypes string[]|nil
---@return boolean
local function normal_buf_allowed(ignore_buftypes)
  local bt = vim.bo.buftype or ""
  if ignore_buftypes and vim.tbl_contains(ignore_buftypes, bt) then
    return false
  end
  return bt == "" or bt == "acwrite"
end

---@param git_cmd string
---@param file string
---@param lnum integer
---@return string|nil
local function get_previous_line(git_cmd, file, lnum)
  local blame_res = vim
    .system({ git_cmd, "blame", "-L", lnum .. "," .. lnum, "--porcelain", "--", file }, { text = true })
    :wait()
  if blame_res.code ~= 0 then
    return nil
  end
  local blame = to_lines(blame_res.stdout)
  if #blame == 0 then
    return nil
  end
  local sha = parse_blame_sha(blame[1])
  if not sha then
    return nil
  end
  local blob_res = vim.system({ git_cmd, "show", sha .. ":" .. file }, { text = true }):wait()
  if blob_res.code ~= 0 then
    return nil
  end
  local blob = to_lines(blob_res.stdout)
  if #blob == 0 or lnum > #blob then
    return nil
  end
  return blob[lnum]
end

---@param modes string|string[]|nil
---@param events_override string[]|nil
---@return string[]
local function effective_events(modes, events_override)
  if type(events_override) == "table" and #events_override > 0 then
    return events_override
  end
  local has_n, has_v, has_i = false, false, false
  if modes == nil then
    has_n, has_v = true, true
  elseif type(modes) == "string" then
    has_n = modes:find("n", 1, true) ~= nil
    has_v = modes:find("v", 1, true) ~= nil
    has_i = modes:find("i", 1, true) ~= nil
  else
    for _, c in ipairs(modes) do
      if c == "n" then
        has_n = true
      elseif c == "v" then
        has_v = true
      elseif c == "i" then
        has_i = true
      end
    end
  end
  local ev = {}
  if has_n or has_v then
    ev[#ev + 1] = "CursorHold"
  end
  if has_i then
    ev[#ev + 1] = "CursorHoldI"
  end
  if #ev == 0 then
    ev = { "CursorHold" }
  end
  return ev
end

---Register the CursorHold/CursorHoldI line-diff preview autocmds if enabled.
---@param cfg FileOps.OnHoldConfig
---@return nil
function M.setup(cfg)
  cfg = cfg or {}
  if cfg.enable == false then
    return
  end

  local prefer_inline = (cfg.prefer_inline ~= false)
  local restore_view = (cfg.restore_view ~= false)
  local throttle_ms = tonumber(cfg.throttle_ms or 800) or 800

  -- Per-window throttle and generation (to invalidate delayed runs on mode changes)
  local last_fire_ms_by_win = {}
  local gen_by_win = {}

  local function bump_gen(win)
    gen_by_win[win] = (gen_by_win[win] or 0) + 1
    return gen_by_win[win]
  end

  -- Lower updatetime so CursorHold fires promptly for this feature.
  vim.o.updatetime = 100

  local events = effective_events(cfg.modes, cfg.events_override)

  autocmd.create(events, function()
    if not mode_allowed(cfg.modes) then
      return
    end

    local win = api.nvim_get_current_win()
    local now_ms = math.floor((uv.hrtime() or 0) / 1e6)
    local last_ms = last_fire_ms_by_win[win] or 0
    if (now_ms - last_ms) < throttle_ms then
      return
    end
    last_fire_ms_by_win[win] = now_ms

    local buf = api.nvim_get_current_buf()
    if not normal_buf_allowed(cfg.ignore_buftypes) then
      return
    end
    if cfg.require_clean_buffer and vim.bo[buf].modified then
      return
    end

    local git = cfg.git_cmd or "git"
    if not in_git_repo(git) then
      return
    end

    local file = api.nvim_buf_get_name(buf)
    if file == "" then
      return
    end
    if cfg.only_tracked and not is_tracked(git, file) then
      return
    end

    local my_gen = bump_gen(win)

    local function run()
      if not mode_allowed(cfg.modes) then
        return
      end
      if gen_by_win[win] ~= my_gen then
        return
      end
      -- run() may execute after a vim.defer_fn delay (cfg.delay > 0), by
      -- which point the buffer/window captured above could have been closed —
      -- re-validate before touching them.
      if not api.nvim_buf_is_valid(buf) or not api.nvim_win_is_valid(win) then
        return
      end

      clear_line_diff(buf)

      if prefer_inline then
        local ok_gs, gs = pcall(require, "gitsigns")
        if ok_gs and gs.preview_hunk_inline then
          local view = fn.winsaveview()
          local cur = api.nvim_win_get_cursor(win)
          local ok_inline = pcall(gs.preview_hunk_inline)
          if ok_inline then
            if restore_view then
              vim.schedule(function()
                if not api.nvim_win_is_valid(win) then
                  return
                end
                pcall(fn.winrestview, view)
                pcall(api.nvim_win_set_cursor, win, cur)
              end)
            end
            -- Buffer-local (opts.buffer): lib.nvim.autocmd.create doesn't
            -- forward a `buffer` option, so this one stays on the raw API.
            api.nvim_create_autocmd({ "CursorMoved", "BufHidden", "InsertEnter" }, {
              group = augroup("cleanup"),
              buffer = buf,
              once = true,
              callback = function()
                clear_line_diff(buf)
              end,
              desc = "[fileops] Clear inline diff preview on next move",
            })
            return
          end
        end
      end

      local lnum = get_lnum(win)
      local prev = get_previous_line(git, file, lnum)
      if not prev or prev == "" then
        return
      end

      local virt = truncate(prev, tonumber(cfg.max_len or 160) or 160)
      local pos = (cfg.right_align and "right_align") or "eol"
      local pref = (cfg.prefix ~= nil) and tostring(cfg.prefix) or "previous: "

      api.nvim_buf_set_extmark(buf, NS, lnum - 1, 0, {
        virt_text = { { pref .. virt, cfg.hl_prev or "Comment" } },
        virt_text_pos = pos,
        priority = tonumber(cfg.virt_priority or 1000) or 1000,
      })

      -- Buffer-local (opts.buffer): lib.nvim.autocmd.create doesn't
      -- forward a `buffer` option, so this one stays on the raw API.
      api.nvim_create_autocmd({ "CursorMoved", "BufHidden", "InsertEnter" }, {
        group = augroup("cleanup"),
        buffer = buf,
        once = true,
        callback = function()
          clear_line_diff(buf)
        end,
        desc = "[fileops] Clear previous-line preview on next move",
      })
    end

    local extra = tonumber(cfg.delay or 0) or 0
    if extra > 0 then
      vim.defer_fn(run, extra)
    else
      run()
    end
  end, {
    group = augroup("preview"),
    desc = "[fileops] Show line diff/previous content on CursorHold/CursorHoldI (mode-aware, throttled)",
  })

  autocmd.create("ModeChanged", function()
    local win = api.nvim_get_current_win()
    local buf = api.nvim_get_current_buf()
    if not mode_allowed(cfg.modes) then
      clear_line_diff(buf)
      bump_gen(win)
    end
  end, {
    group = augroup("modeclear"),
    desc = "[fileops] Clear/abort line diff preview when leaving allowed modes",
  })
end

return M
