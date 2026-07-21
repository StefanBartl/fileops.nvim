---@module 'fileops_nvim.ops.cycle'
---Core logic for cycling through files in a directory (next/previous).
---Pure functions where possible; no global state.
---
---Public functions return `ok, msg`: `msg` is a human-readable string to
---relay regardless of outcome, and the caller (the UI/binding layer) decides
---whether/how to notify it. The one exception is the "unsaved changes"
---confirm dialog inside `open_path`, which is itself an interactive UI flow
---(vim.ui.select) with no synchronous caller to report back to.
local M = {}

local notify = require("fileops_nvim.util.notify")
local open_background = require("lib.nvim.buffer.open_background")
local api, fn = vim.api, vim.fn
local uv      = vim.uv or vim.loop

-- ─── Path helpers ────────────────────────────────────────────────────────────

---Resolve a canonical, absolute path.
---@param p string
---@param follow boolean  Resolve symlinks when true.
---@return string
local function canon(p, follow)
  if follow and uv.fs_realpath then
    local rp = uv.fs_realpath(p)
    if type(rp) == "string" and rp ~= "" then return rp end
  end
  return fn.fnamemodify(p, ":p")
end

-- ─── Directory listing ───────────────────────────────────────────────────────

---Return the root directory to scan according to config.
---@param opts FileOps.CycleConfig
---@return string|nil dir
---@return string|nil err
function M.get_root_dir(opts)
  if opts.root == "cwd" or opts.root == "cwd_recursive" then
    local cwd = fn.getcwd()
    return (type(cwd) == "string" and cwd ~= "") and cwd or nil,
           (type(cwd) ~= "string" or cwd == "") and "getcwd() failed" or nil
  end

  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then
    return nil, "current buffer has no file name"
  end
  local dir = fn.fnamemodify(name, ":p:h")
  return (dir ~= "") and dir or nil, (dir == "") and "cannot resolve buffer directory" or nil
end

---Whether `name` matches a glob `pattern` (converted via `glob2regpat`).
---No pattern means everything matches.
---@param name string
---@param pattern string|nil
---@return boolean
local function matches_pattern(name, pattern)
  if not pattern or pattern == "" then return true end
  return fn.match(name, fn.glob2regpat(pattern)) ~= -1
end

---Classify a `vim.fs.dir` entry, falling back to `fs_stat` when the
---iterator itself couldn't determine the type (e.g. some network mounts).
---@param full string  Absolute-ish path to the entry.
---@param t string|nil  Type reported by `vim.fs.dir` ("file"|"directory"|nil).
---@return boolean is_file
---@return boolean is_dir
local function classify_entry(full, t)
  if t == "file" then return true, false end
  if t == "directory" then return false, true end
  local st = uv.fs_stat and uv.fs_stat(fn.fnamemodify(full, ":p"))
  if not st then return false, false end
  return st.type == "file", st.type == "directory"
end

---Recursively collect matching files under `dir` into `acc`. Symlinked
---directories are never descended into, so a symlink cycle can't cause an
---infinite walk.
---@param dir string
---@param opts FileOps.CycleConfig
---@param acc string[]
local function collect_recursive(dir, opts, acc)
  local ok, iter = pcall(vim.fs.dir, dir)
  if not ok then return end
  for name, t in iter do
    local hidden = name:sub(1, 1) == "."
    if opts.include_hidden or not hidden then
      local full = dir .. "/" .. name
      local is_file, is_dir = classify_entry(full, t)
      if is_file and matches_pattern(name, opts.pattern) then
        acc[#acc + 1] = canon(full, opts.follow_symlinks)
      elseif is_dir then
        local lst = uv.fs_lstat and uv.fs_lstat(full)
        local is_symlink = lst and lst.type == "link"
        if not is_symlink then
          collect_recursive(full, opts, acc)
        end
      end
    end
  end
end

---List regular, filtered files in `dir` sorted alphabetically. Recurses
---into subdirectories when `opts.root` is `"buffer_dir_recursive"` or
---`"cwd_recursive"`.
---@param dir string
---@param opts FileOps.CycleConfig
---@return string[]  Absolute, canonicalized paths.
local function list_files(dir, opts)
  local acc = {}
  local ci = opts.case_insensitive

  if opts.root == "buffer_dir_recursive" or opts.root == "cwd_recursive" then
    collect_recursive(dir, opts, acc)
  else
    local ok, err_or_iter = pcall(vim.fs.dir, dir)
    if not ok then
      -- dir does not exist or is not readable; return empty list
      return acc
    end
    for name, t in err_or_iter do
      local is_file = classify_entry(dir .. "/" .. name, t)
      local hidden = name:sub(1, 1) == "."
      if is_file and (opts.include_hidden or not hidden) and matches_pattern(name, opts.pattern) then
        acc[#acc + 1] = canon(dir .. "/" .. name, opts.follow_symlinks)
      end
    end
  end

  table.sort(acc, function(a, b)
    return ci and (a:lower() < b:lower()) or (a < b)
  end)
  return acc
end

---Find the index of `current` within `files`.
---@param files string[]
---@param current string
---@param ci boolean  Case-insensitive comparison.
---@return integer|nil
local function index_of(files, current, ci)
  local key = ci and current:lower() or current
  for i = 1, #files do
    local v = ci and files[i]:lower() or files[i]
    if v == key then return i end
  end
  return nil
end

---Clamp and validate a count to [1, ∞).
---@param count integer|nil
---@return integer
local function validate_count(count)
  if type(count) ~= "number" or count < 1 then return 1 end
  return math.floor(count)
end

-- ─── Open helpers ─────────────────────────────────────────────────────────────

---Open `path` in the current window according to `opts.open_target`.
---All Neovim API handles are validated before use.
---@param path string
---@param opts FileOps.CycleConfig
---@return boolean ok
---@return string|nil msg
function M.open_path(path, opts)
  if type(path) ~= "string" or path == "" then return false, "empty path" end

  local win = api.nvim_get_current_win()
  if not (win and api.nvim_win_is_valid(win)) then return false, "no valid window" end

  local bufnr = api.nvim_get_current_buf()
  if not (bufnr and api.nvim_buf_is_valid(bufnr)) then return false, "no valid buffer" end

  local target = opts.open_target or "replace"
  local esc    = fn.fnameescape(path)

  -- Prompt for modified buffer when replacing. This branch is an interactive
  -- confirm dialog (vim.ui.select) with no synchronous caller to report back
  -- to, so it notifies directly rather than returning through the callback.
  if target == "replace" and opts.confirm_on_modified and vim.bo[bufnr].modified then
    vim.ui.select(
      { "Save and open", "Discard changes and open", "Cancel" },
      { prompt = "[fileops] Buffer has unsaved changes:" },
      function(choice)
        if not choice or choice == "Cancel" then return end
        if choice == "Save and open" then
          if not pcall(vim.cmd, "write") then
            notify.error("save failed, aborting navigation")
            return
          end
        end
        local cmd = (choice == "Discard changes and open") and "edit! " or "edit "
        pcall(vim.cmd, cmd .. esc)
      end
    )
    return true, nil
  end

  if target == "replace" then
    local old = bufnr
    local ok, err = pcall(vim.cmd, "edit " .. esc)
    if not ok then
      return false, "open failed: " .. tostring(err)
    end
    local new = api.nvim_get_current_buf()
    if old ~= new and api.nvim_buf_is_valid(old) then
      pcall(api.nvim_buf_delete, old, { force = false })
    end
    return true, nil

  elseif target == "current" then
    local ok, err = pcall(vim.cmd, "edit " .. esc)
    if not ok then return false, "open failed: " .. tostring(err) end
    return true, nil

  elseif target == "split" or target == "vsplit" then
    local cmd = (target == "split") and "split " or "vsplit "
    local cur = win
    local ok, err = pcall(vim.cmd, cmd .. esc)
    if not ok then return false, target .. " failed: " .. tostring(err) end
    if opts.keep_focus and api.nvim_win_is_valid(cur) then
      vim.schedule(function()
        if api.nvim_win_is_valid(cur) then
          pcall(api.nvim_set_current_win, cur)
        end
      end)
    end
    return true, nil

  elseif target == "tab" then
    local ok, err = pcall(vim.cmd, "tabedit " .. esc)
    if not ok then return false, "tabedit failed: " .. tostring(err) end
    return true, nil

  elseif target == "background" then
    local ok, err = open_background(path)
    if not ok then
      return false, "background open failed: " .. tostring(err)
    end
    return true, nil

  else
    return false, "unknown open_target: " .. tostring(target)
  end
end

-- ─── Navigate ────────────────────────────────────────────────────────────────

---Navigate `count` steps in `mode` and open the result.
---@param dir string  Root directory (from get_root_dir).
---@param mode FileOps.Direction
---@param opts FileOps.CycleConfig
---@param count integer|nil
---@return boolean ok
---@return string|nil msg
function M.navigate(dir, mode, opts, count)
  count = validate_count(count)

  local files = list_files(dir, opts)
  if #files == 0 then
    return false, "no files in directory"
  end

  local cur = api.nvim_buf_get_name(0)
  if not cur or cur == "" then
    return false, "current buffer has no file name"
  end

  local ci  = opts.case_insensitive or false
  local key = canon(cur, opts.follow_symlinks)
  local idx = index_of(files, key, ci)

  if not idx then
    -- Current file is not in the filtered list; insert it temporarily
    local entry = key
    files[#files + 1] = entry
    table.sort(files, function(a, b)
      return ci and (a:lower() < b:lower()) or (a < b)
    end)
    idx = index_of(files, entry, ci)
  end

  if not idx then
    return false, "cannot locate current file in directory listing"
  end

  local n = #files
  local target_idx

  if mode == "next" then
    target_idx = opts.wrap and ((idx - 1 + count) % n) + 1
                           or (idx + count <= n and idx + count or nil)
  else
    target_idx = opts.wrap and ((idx - 1 - count) % n) + 1
                           or (idx - count >= 1 and idx - count or nil)
  end

  if not target_idx then
    return false, ("boundary reached (wrap=false, count=%d)"):format(count)
  end

  return M.open_path(files[target_idx], opts)
end

---Jump straight to the first or last file in the directory listing.
---@param dir string  Root directory (from get_root_dir).
---@param edge "first"|"last"
---@param opts FileOps.CycleConfig
---@return boolean ok
---@return string|nil msg
function M.jump_edge(dir, edge, opts)
  local files = list_files(dir, opts)
  if #files == 0 then
    return false, "no files in directory"
  end

  local target_idx = (edge == "last") and #files or 1
  return M.open_path(files[target_idx], opts)
end

---Reopen the current buffer's own path in a different window target
---(split/vsplit/tab/background/…), without changing which file is shown.
---@param opts FileOps.CycleConfig
---@return boolean ok
---@return string|nil msg
function M.open_current(opts)
  local name = api.nvim_buf_get_name(0)
  if not name or name == "" then
    return false, "current buffer has no file name"
  end
  return M.open_path(name, opts)
end

return M
