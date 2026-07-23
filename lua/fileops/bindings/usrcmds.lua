---@module 'fileops.bindings.usrcmds'
---Registers the single :File[!] unified user command, built via
---lib.nvim.usercmd.composer.
local M = {}

local composer = require("lib.nvim.usercmd.composer")
local notify = require("fileops.util.notify")
local file   = require("fileops.ops.file")
local cycle  = require("fileops.ops.cycle")
local bulk   = require("fileops.ops.bulk")
local config = require("fileops.config")

-- ─── Subcommand catalogue ─────────────────────────────────────────────────────

local SUBCMDS = {
  "new", "write", "saveas", "writeto", "mkdir", "touch",
  "rename", "move", "duplicate", "copy", "delete",
  "next", "prev", "first", "last", "open", "path", "info",
  "bulk rename", "cd", "help",
}

local HELP_TEXT = table.concat({
  ":File[!] {subcommand} [args…]",
  "",
  "  new {path}              set buffer name (no write)",
  "  write {path}            set buffer name + write (! overwrites)",
  "  saveas {path}           :saveas-equivalent (! overwrites)",
  "  writeto {path}          write a copy, name stays (! overwrites)",
  "  mkdir                   create parent dirs for current buffer",
  "  touch {path}            create an empty file if missing",
  "  rename [%] {dest}       rename + update buffer (reloads)",
  "  move [%] {dest}         move + update buffer (no reload)",
  "  duplicate [%] {dest}    copy + open the copy (! overwrites)",
  "  copy [%] {dest}         copy without opening (! overwrites)",
  "  delete [%]              delete + close buffer (! force-closes)",
  "  next/prev [target] [glob]  navigate directory listing, optionally filtered",
  "  first/last [target]     jump to first/last file in directory",
  "  open [target]           reopen current file in split/vsplit/tab/…",
  "  path [mode]             copy path to clipboard (abs/rel/name/dir)",
  "  info                    show size/mtime/permissions for current file",
  "  bulk rename {pat} {rep} batch-rename files in dir via Lua pattern (preview + confirm)",
  "  cd [scope]              cd to buffer's dir + refresh explorer",
  "  help                    show this message",
  "",
  "See :h fileops-command or docs/commands.md for full details.",
}, "\n")

local CD_SCOPES = { "window", "tab", "global" }

local CD_SCOPE_MAP = {
  ["window"] = "lcd",
  ["tab"]    = "tcd",
  ["global"] = "cd",
}

local CYCLE_TARGETS = {
  "%", "replace", "stay", "current", "new", "split", "vsplit", "tab", "bg", "background",
}

local PATH_MODES = { "abs", "rel", "name", "dir" }

local CYCLE_TARGET_MAP = {
  ["%"]          = "replace",
  ["replace"]    = "replace",
  ["stay"]       = "current",
  ["current"]    = "current",
  ["new"]        = "split",
  ["split"]      = "split",
  ["vsplit"]     = "vsplit",
  ["tab"]        = "tab",
  ["bg"]         = "background",
  ["background"] = "background",
}

-- ─── Completion ───────────────────────────────────────────────────────────────
-- rename/duplicate's first slot ("%" or a direct dest path) needs a custom
-- type; every other path completion below is FILEOPS_PATH (bufdir-relative);
-- non-path args map onto enums (CD_SCOPES/CYCLE_TARGETS/PATH_MODES).

---Complete `arg_lead` relative to the current buffer's directory instead of
---cwd (`getcompletion`'s default base), so `:File rename <Tab>` browses
---files next to the buffer being edited rather than wherever Neovim's cwd
---happens to be. Absolute-looking input (`~`, `/`, or a Windows drive
---letter) is left alone. Candidates come back as full absolute paths — that
---keeps them unambiguous regardless of cwd once the command actually runs.
---@param arg_lead string
---@return string[]
local function complete_from_bufdir(arg_lead)
  if arg_lead:match("^~") or arg_lead:match("^/") or arg_lead:match("^%a:[\\/]") then
    return vim.fn.getcompletion(arg_lead, "file")
  end

  local bufdir = vim.fn.expand("%:p:h")
  if bufdir == "" or vim.fn.isdirectory(bufdir) ~= 1 then
    return vim.fn.getcompletion(arg_lead, "file")
  end

  return vim.fn.getcompletion(bufdir .. "/" .. arg_lead, "file")
end

composer.register_type("FILEOPS_DEST_FIRST", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
    local fc = complete_from_bufdir(arg_lead)
    if ("%"):sub(1, #arg_lead) == arg_lead then
      table.insert(fc, 1, "%")
    end
    return fc
  end,
})

composer.register_type("FILEOPS_PATH", {
  validate = function(raw) return true, require("lib.nvim.cross.fs.expand_path")(raw), nil end,
  complete = complete_from_bufdir,
})

-- `next`/`prev` accept an optional glob filter (e.g. `:File next *.lua`) in
-- the same slot a target keyword would go — so this slot can't be a strict
-- enum. Validation always passes; completion still offers the known target
-- keywords as a prefix match.
composer.register_type("FILEOPS_CYCLE_ARG", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
    if arg_lead == "" then return vim.deepcopy(CYCLE_TARGETS) end
    local out = {}
    for _, t in ipairs(CYCLE_TARGETS) do
      if t:sub(1, #arg_lead) == arg_lead then out[#out + 1] = t end
    end
    return out
  end,
})

-- ─── Dispatch ─────────────────────────────────────────────────────────────────

local report = notify.report

---Split next/prev's two optional args into a resolved target + glob
---pattern. Since the first slot may be either a target keyword or a glob
---filter (`:File next *.lua`), a recognized target keyword there shifts the
---pattern to the second slot; anything else is treated as the pattern
---itself (and a second arg, if present, is ignored).
---@param a1 string|nil
---@param a2 string|nil
---@return string|nil target
---@return string|nil pattern
local function resolve_cycle_args(a1, a2)
  local target = a1 and CYCLE_TARGET_MAP[a1:lower()]
  if target then return target, a2 end
  return nil, a1
end

---Run the file-cycle navigate with opts from config + per-call overrides.
---@param direction FileOps.Direction
---@param a1 string|nil  Target keyword or glob pattern (see `resolve_cycle_args`).
---@param a2 string|nil  Glob pattern, when `a1` was a target keyword.
---@param count integer
---@param bang boolean
local function do_cycle(direction, a1, a2, count, bang)
  local cfg   = config.get()
  local copts = vim.deepcopy(cfg.cycle or {})

  local target, pattern = resolve_cycle_args(a1, a2)
  if target then copts.open_target = target end
  if pattern and pattern ~= "" then copts.pattern = pattern end

  if bang then copts.confirm_on_modified = false end

  local dir, err = cycle.get_root_dir(copts)
  if not dir then
    notify.warn(err or "cannot determine root directory")
    return
  end

  report(cycle.navigate(dir, direction, copts, count))
end

---Jump straight to the first/last file in the directory, with opts from
---config + per-call overrides (same target/bang handling as `do_cycle`).
---@param edge "first"|"last"
---@param target_arg string|nil
---@param bang boolean
local function do_jump(edge, target_arg, bang)
  local cfg   = config.get()
  local copts = vim.deepcopy(cfg.cycle or {})

  local target = target_arg and CYCLE_TARGET_MAP[target_arg:lower()]
  if target then copts.open_target = target end

  if bang then copts.confirm_on_modified = false end

  local dir, err = cycle.get_root_dir(copts)
  if not dir then
    notify.warn(err or "cannot determine root directory")
    return
  end

  report(cycle.jump_edge(dir, edge, copts))
end

---Resolve destination from fargs, handling optional "%" scope prefix.
---Returns the destination path, or nil if missing.
---@param fargs string[]  Args after the subcommand.
---@return string|nil dest
local function resolve_dest(fargs)
  if #fargs == 0 then return nil end
  if fargs[1] == "%" then
    return fargs[2]  -- :File rename % dest
  end
  return fargs[1]    -- :File rename dest  (% implied)
end

---Prompt for a missing path argument via vim.ui.input instead of erroring.
---Calls `cb(input)` once a non-empty value is entered; a cancelled/empty
---prompt is a silent no-op (matches vim.ui.input's own convention).
---@param prompt_label string
---@param cb fun(input: string)
local function prompt_dest(prompt_label, cb)
  vim.ui.input({ prompt = prompt_label }, function(input)
    if not input or input == "" then return end
    cb(input)
  end)
end

---Whether tree-explorer refresh is enabled per `config.explorer.refresh_on_change`.
---@return boolean
local function refresh_flag()
  local cfg = config.get()
  return not (cfg.explorer and cfg.explorer.refresh_on_change == false)
end

---git_aware.* opts for rename/move/duplicate/copy/delete, from config.
---@return { git_aware: boolean, git_warn_only: boolean, git_cmd: string }
local function git_flags()
  local cfg = config.get()
  local gcfg = cfg.git_aware or {}
  return {
    git_aware = gcfg.enable == true,
    git_warn_only = gcfg.warn_only ~= false,
    git_cmd = gcfg.git_cmd or "git",
  }
end

---Build a bulk-rename plan for the buffer's directory, preview it, and
---(on confirmation via `vim.ui.select`) execute it. `!` allows overwriting
---existing destinations.
---@param pattern string|nil
---@param replacement string|nil
---@param bang boolean
local function do_bulk_rename(pattern, replacement, bang)
  if not pattern then
    notify.warn("usage: File[!] bulk rename {pattern} {replacement}")
    return
  end
  replacement = replacement or ""

  local dir, dir_err = cycle.get_root_dir({ root = "buffer_dir" })
  if not dir then
    notify.warn(dir_err or "cannot determine directory")
    return
  end

  local plan, plan_err = bulk.plan(dir, pattern, replacement)
  if plan_err then
    notify.error("bulk rename: " .. plan_err)
    return
  end
  if #plan == 0 then
    notify.info(("bulk rename: no files in %s matched %q"):format(dir, pattern))
    return
  end

  local preview = { ("bulk rename: %d file(s) in %s"):format(#plan, dir) }
  for _, item in ipairs(plan) do
    preview[#preview + 1] = ("  %s → %s"):format(
      vim.fn.fnamemodify(item.old, ":t"), vim.fn.fnamemodify(item.new, ":t"))
  end
  notify.info(table.concat(preview, "\n"))

  local confirm_choice = ("Rename %d file(s)"):format(#plan)
  vim.ui.select({ confirm_choice, "Cancel" }, {
    prompt = "[fileops] Confirm bulk rename?",
  }, function(choice)
    if choice ~= confirm_choice then return end
    local renamed, err = bulk.execute(plan, { bang = bang, refresh_explorers = refresh_flag() })
    if err then
      notify.error(("bulk rename: %d/%d renamed, first failure: %s"):format(renamed, #plan, err))
    else
      notify.info(("bulk rename: %d file(s) renamed"):format(renamed))
    end
  end)
end

---Dispatch a parsed command to the appropriate operation.
---@param subcmd string
---@param fargs string[]  Arguments after the subcommand.
---@param bang boolean
---@param count integer   v:count1 equivalent from :N File
local function dispatch(subcmd, fargs, bang, count)
  local refresh = refresh_flag()
  local gitopts = git_flags()

  if subcmd == "new" then
    if fargs[1] then
      report(file.edit_new(fargs[1], { refresh_explorers = refresh }))
    else
      prompt_dest("File new: ", function(dest)
        report(file.edit_new(dest, { refresh_explorers = refresh }))
      end)
    end

  elseif subcmd == "write" then
    if fargs[1] then
      report(file.edit_new(fargs[1], { write = true, bang = bang, refresh_explorers = refresh }))
    else
      prompt_dest("File write: ", function(dest)
        report(file.edit_new(dest, { write = true, bang = bang, refresh_explorers = refresh }))
      end)
    end

  elseif subcmd == "saveas" then
    if fargs[1] then
      report(file.save_as(fargs[1], { bang = bang, refresh_explorers = refresh }))
    else
      prompt_dest("File saveas: ", function(dest)
        report(file.save_as(dest, { bang = bang, refresh_explorers = refresh }))
      end)
    end

  elseif subcmd == "writeto" then
    if fargs[1] then
      report(file.write_to(fargs[1], { bang = bang, refresh_explorers = refresh }))
    else
      prompt_dest("File writeto: ", function(dest)
        report(file.write_to(dest, { bang = bang, refresh_explorers = refresh }))
      end)
    end

  elseif subcmd == "mkdir" then
    report(file.mk_parent({ refresh_explorers = refresh }))

  elseif subcmd == "touch" then
    if fargs[1] then
      report(file.touch(fargs[1], { refresh_explorers = refresh }))
    else
      prompt_dest("File touch: ", function(dest)
        report(file.touch(dest, { refresh_explorers = refresh }))
      end)
    end

  elseif subcmd == "rename" then
    local dest = resolve_dest(fargs)
    local ropts = vim.tbl_extend("force", { bang = bang, refresh_explorers = refresh }, gitopts)
    if dest then
      report(file.rename(dest, ropts))
    else
      prompt_dest("File rename: ", function(d)
        report(file.rename(d, ropts))
      end)
    end

  elseif subcmd == "move" then
    local dest = resolve_dest(fargs)
    local mopts = vim.tbl_extend("force", { bang = bang, refresh_explorers = refresh }, gitopts)
    if dest then
      report(file.move(dest, mopts))
    else
      prompt_dest("File move: ", function(d)
        report(file.move(d, mopts))
      end)
    end

  elseif subcmd == "duplicate" then
    local dest = resolve_dest(fargs)
    local dopts = vim.tbl_extend("force", { bang = bang, refresh_explorers = refresh }, gitopts)
    if dest then
      report(file.duplicate(dest, dopts))
    else
      prompt_dest("File duplicate: ", function(d)
        report(file.duplicate(d, dopts))
      end)
    end

  elseif subcmd == "copy" then
    local dest = resolve_dest(fargs)
    local copts = vim.tbl_extend("force", { bang = bang, refresh_explorers = refresh }, gitopts)
    if dest then
      report(file.copy(dest, copts))
    else
      prompt_dest("File copy: ", function(d)
        report(file.copy(d, copts))
      end)
    end

  elseif subcmd == "delete" then
    local cfg = config.get()
    local dcfg = cfg.delete or {}
    report(file.delete_current(vim.tbl_extend("force", {
      force = bang,
      mode = dcfg.mode,
      on_before_delete = dcfg.on_before_delete,
      refresh_explorers = refresh,
    }, gitopts)))

  elseif subcmd == "cd" then
    local cfg   = config.get()
    local arg   = fargs[1] and CD_SCOPE_MAP[fargs[1]:lower()]
    local scope = arg or (cfg.cd and CD_SCOPE_MAP[cfg.cd.scope]) or "lcd"
    local cd_refresh = not (cfg.cd and cfg.cd.refresh_explorers == false)
    report(file.cd_here({ scope = scope, refresh = cd_refresh }))

  elseif subcmd == "next" then
    do_cycle("next", fargs[1], fargs[2], count, bang)

  elseif subcmd == "prev" then
    do_cycle("prev", fargs[1], fargs[2], count, bang)

  elseif subcmd == "first" then
    do_jump("first", fargs[1], bang)

  elseif subcmd == "last" then
    do_jump("last", fargs[1], bang)

  elseif subcmd == "open" then
    local cfg   = config.get()
    local copts = vim.deepcopy(cfg.cycle or {})

    local target = fargs[1] and CYCLE_TARGET_MAP[fargs[1]:lower()]
    if target then copts.open_target = target end

    if bang then copts.confirm_on_modified = false end

    report(cycle.open_current(copts))

  elseif subcmd == "path" then
    report(file.copy_path(fargs[1]))

  elseif subcmd == "info" then
    report(file.info())

  elseif subcmd == "bulk_rename" then
    do_bulk_rename(fargs[1], fargs[2], bang)

  elseif subcmd == "help" then
    notify.info(HELP_TEXT)

  else
    notify.warn(("unknown subcommand %q — try: %s"):format(subcmd, table.concat(SUBCMDS, ", ")))
  end
end

-- ─── Register ────────────────────────────────────────────────────────────────

---Reconstruct a flat fargs array (matching dispatch's expected shape) from
--- composer's bound positionals + any leftover tokens.
---@param ctx table composer Ctx
---@return string[]
local function fargs_of(ctx)
  local out = {}
  for _, v in ipairs(ctx.pos) do out[#out + 1] = tostring(v) end
  for _, v in ipairs(ctx.rest) do out[#out + 1] = v end
  return out
end

---@param subcmd string
---@param args? table[]
---@return table
local function route(subcmd, args)
  return {
    path = { subcmd },
    args = args,
    run = function(ctx)
      local count = (ctx.range.count and ctx.range.count > 0) and ctx.range.count or 1
      dispatch(subcmd, fargs_of(ctx), ctx.bang, count)
    end,
  }
end

function M.register()
  composer.verb("File", {
    desc = "Unified file operations (new/write/saveas/writeto/mkdir/touch/rename/move/duplicate/copy/delete/next/prev/first/last/open/path/info/bulk rename/cd/help)",
    bang = true,
    count = 0,
    routes = {
      route("new", { { name = "path", type = "FILEOPS_PATH", optional = true } }),
      route("write", { { name = "path", type = "FILEOPS_PATH", optional = true } }),
      route("saveas", { { name = "path", type = "FILEOPS_PATH", optional = true } }),
      route("writeto", { { name = "path", type = "FILEOPS_PATH", optional = true } }),
      route("mkdir"),
      route("touch", { { name = "path", type = "FILEOPS_PATH", optional = true } }),
      route("rename", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "FILEOPS_PATH", optional = true },
      }),
      route("move", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "FILEOPS_PATH", optional = true },
      }),
      route("duplicate", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "FILEOPS_PATH", optional = true },
      }),
      route("copy", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "FILEOPS_PATH", optional = true },
      }),
      route("delete"),
      route("cd", { { name = "scope", type = "STRING", optional = true, enum = CD_SCOPES } }),
      route("next", {
        { name = "a1", type = "FILEOPS_CYCLE_ARG", optional = true },
        { name = "a2", type = "STRING", optional = true },
      }),
      route("prev", {
        { name = "a1", type = "FILEOPS_CYCLE_ARG", optional = true },
        { name = "a2", type = "STRING", optional = true },
      }),
      route("first", { { name = "target", type = "STRING", optional = true, enum = CYCLE_TARGETS } }),
      route("last", { { name = "target", type = "STRING", optional = true, enum = CYCLE_TARGETS } }),
      route("open", { { name = "target", type = "STRING", optional = true, enum = CYCLE_TARGETS } }),
      route("path", { { name = "mode", type = "STRING", optional = true, enum = PATH_MODES } }),
      route("info"),
      {
        path = { "bulk", "rename" },
        args = {
          { name = "pattern", type = "STRING" },
          { name = "replacement", type = "STRING", optional = true },
        },
        run = function(ctx)
          dispatch("bulk_rename", fargs_of(ctx), ctx.bang, 1)
        end,
      },
      route("help"),
    },
  })
end

return M
