---@module 'fileops_nvim.bindings.usrcmds'
---Registers the single :File[!] unified user command, built via
---lib.nvim.usercmd.composer.
local M = {}

local composer = require("lib.nvim.usercmd.composer")
local notify = require("fileops_nvim.util.notify")
local file   = require("fileops_nvim.ops.file")
local cycle  = require("fileops_nvim.ops.cycle")
local config = require("fileops_nvim.config")

-- ─── Subcommand catalogue ─────────────────────────────────────────────────────

local SUBCMDS = {
  "new", "write", "saveas", "writeto", "mkdir", "touch",
  "rename", "move", "duplicate", "copy", "delete",
  "next", "prev", "cd", "help",
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
  "  next/prev [target]      navigate directory listing",
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
-- type; every other completion below maps onto a composer built-in (PATH,
-- or enum on CD_SCOPES/CYCLE_TARGETS).

composer.register_type("FILEOPS_DEST_FIRST", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
    local fc = vim.fn.getcompletion(arg_lead, "file")
    if ("%"):sub(1, #arg_lead) == arg_lead then
      table.insert(fc, 1, "%")
    end
    return fc
  end,
})

-- ─── Dispatch ─────────────────────────────────────────────────────────────────

local report = notify.report

---Run the file-cycle navigate with opts from config + per-call overrides.
---@param direction FileOps.Direction
---@param target_arg string|nil
---@param count integer
---@param bang boolean
local function do_cycle(direction, target_arg, count, bang)
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

  report(cycle.navigate(dir, direction, copts, count))
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

---Dispatch a parsed command to the appropriate operation.
---@param subcmd string
---@param fargs string[]  Arguments after the subcommand.
---@param bang boolean
---@param count integer   v:count1 equivalent from :N File
local function dispatch(subcmd, fargs, bang, count)
  if subcmd == "new" then
    if not fargs[1] then notify.warn("usage: File new {path}"); return end
    report(file.edit_new(fargs[1], {}))

  elseif subcmd == "write" then
    if not fargs[1] then notify.warn("usage: File[!] write {path}"); return end
    report(file.edit_new(fargs[1], { write = true, bang = bang }))

  elseif subcmd == "saveas" then
    if not fargs[1] then notify.warn("usage: File[!] saveas {path}"); return end
    report(file.save_as(fargs[1], { bang = bang }))

  elseif subcmd == "writeto" then
    if not fargs[1] then notify.warn("usage: File[!] writeto {path}"); return end
    report(file.write_to(fargs[1], { bang = bang }))

  elseif subcmd == "mkdir" then
    report(file.mk_parent())

  elseif subcmd == "touch" then
    if not fargs[1] then notify.warn("usage: File touch {path}"); return end
    report(file.touch(fargs[1]))

  elseif subcmd == "rename" then
    local dest = resolve_dest(fargs)
    if not dest then notify.warn("usage: File[!] rename [%] {dest}"); return end
    report(file.rename(dest, { bang = bang }))

  elseif subcmd == "move" then
    local dest = resolve_dest(fargs)
    if not dest then notify.warn("usage: File[!] move [%] {dest}"); return end
    report(file.move(dest, { bang = bang }))

  elseif subcmd == "duplicate" then
    local dest = resolve_dest(fargs)
    if not dest then notify.warn("usage: File[!] duplicate [%] {dest}"); return end
    report(file.duplicate(dest, { bang = bang }))

  elseif subcmd == "copy" then
    local dest = resolve_dest(fargs)
    if not dest then notify.warn("usage: File[!] copy [%] {dest}"); return end
    report(file.copy(dest, { bang = bang }))

  elseif subcmd == "delete" then
    report(file.delete_current({ force = bang }))

  elseif subcmd == "cd" then
    local cfg   = config.get()
    local arg   = fargs[1] and CD_SCOPE_MAP[fargs[1]:lower()]
    local scope = arg or (cfg.cd and CD_SCOPE_MAP[cfg.cd.scope]) or "lcd"
    local refresh = not (cfg.cd and cfg.cd.refresh_explorers == false)
    report(file.cd_here({ scope = scope, refresh = refresh }))

  elseif subcmd == "next" then
    do_cycle("next", fargs[1], count, bang)

  elseif subcmd == "prev" then
    do_cycle("prev", fargs[1], count, bang)

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
    desc = "Unified file operations (new/write/saveas/writeto/mkdir/touch/rename/move/duplicate/copy/delete/next/prev/cd/help)",
    bang = true,
    count = 0,
    routes = {
      route("new", { { name = "path", type = "PATH" } }),
      route("write", { { name = "path", type = "PATH" } }),
      route("saveas", { { name = "path", type = "PATH" } }),
      route("writeto", { { name = "path", type = "PATH" } }),
      route("mkdir"),
      route("touch", { { name = "path", type = "PATH" } }),
      route("rename", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "PATH", optional = true },
      }),
      route("move", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "PATH", optional = true },
      }),
      route("duplicate", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "PATH", optional = true },
      }),
      route("copy", {
        { name = "a1", type = "FILEOPS_DEST_FIRST", optional = true },
        { name = "a2", type = "PATH", optional = true },
      }),
      route("delete"),
      route("cd", { { name = "scope", type = "STRING", optional = true, enum = CD_SCOPES } }),
      route("next", { { name = "target", type = "STRING", optional = true, enum = CYCLE_TARGETS } }),
      route("prev", { { name = "target", type = "STRING", optional = true, enum = CYCLE_TARGETS } }),
      route("help"),
    },
  })
end

return M
