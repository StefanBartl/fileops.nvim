---@module 'fileops_nvim.bindings.usrcmds'
---Registers the single :File[!] unified user command.
local M = {}

local notify = require("fileops_nvim.util.notify")
local file   = require("fileops_nvim.ops.file")
local cycle  = require("fileops_nvim.ops.cycle")
local config = require("fileops_nvim.config")

-- ─── Subcommand catalogue ─────────────────────────────────────────────────────

local SUBCMDS = {
  "new", "write", "saveas", "writeto", "mkdir",
  "rename", "duplicate", "delete",
  "next", "prev", "cd",
}

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

---@param ArgLead string
---@param CmdLine string
---@return string[]
local function complete(ArgLead, CmdLine, _)
  local tokens = vim.split(CmdLine:match("^%s*(.-)%s*$"), "%s+", { trimempty = true })
  local trailing = CmdLine:match("%s$") ~= nil

  -- Number of args fully committed before ArgLead
  -- tokens[1] = command name, everything after = args
  local committed = #tokens - (trailing and 0 or 1) - 1

  -- Position 0 → completing subcommand
  if committed == 0 then
    return vim.tbl_filter(function(s)
      return s:sub(1, #ArgLead) == ArgLead
    end, SUBCMDS)
  end

  local subcmd = tokens[2]

  if subcmd == "next" or subcmd == "prev" then
    -- 1st arg: open target
    if committed == 1 then
      return vim.tbl_filter(function(s)
        return s:sub(1, #ArgLead) == ArgLead
      end, CYCLE_TARGETS)
    end
    return {}
  end

  if subcmd == "delete" then
    if committed == 1 then return { "%" } end
    return {}
  end

  if subcmd == "cd" then
    if committed == 1 then
      return vim.tbl_filter(function(s)
        return s:sub(1, #ArgLead) == ArgLead
      end, CD_SCOPES)
    end
    return {}
  end

  if subcmd == "rename" or subcmd == "duplicate" then
    if committed == 1 then
      -- First arg: "%" (current) or direct dest path
      local fc = vim.fn.getcompletion(ArgLead, "file")
      if ("%"):sub(1, #ArgLead) == ArgLead then
        table.insert(fc, 1, "%")
      end
      return fc
    end
    -- Second arg onwards: file path
    return vim.fn.getcompletion(ArgLead, "file")
  end

  -- new / write / saveas / writeto / mkdir → file path completion
  return vim.fn.getcompletion(ArgLead, "file")
end

-- ─── Dispatch ─────────────────────────────────────────────────────────────────

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

  cycle.navigate(dir, direction, copts, count)
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
    file.edit_new(fargs[1], {})

  elseif subcmd == "write" then
    if not fargs[1] then notify.warn("usage: File[!] write {path}"); return end
    file.edit_new(fargs[1], { write = true, bang = bang })

  elseif subcmd == "saveas" then
    if not fargs[1] then notify.warn("usage: File[!] saveas {path}"); return end
    file.save_as(fargs[1], { bang = bang })

  elseif subcmd == "writeto" then
    if not fargs[1] then notify.warn("usage: File[!] writeto {path}"); return end
    file.write_to(fargs[1], { bang = bang })

  elseif subcmd == "mkdir" then
    file.mk_parent()

  elseif subcmd == "rename" then
    local dest = resolve_dest(fargs)
    if not dest then notify.warn("usage: File[!] rename [%] {dest}"); return end
    file.rename(dest, { bang = bang })

  elseif subcmd == "duplicate" then
    local dest = resolve_dest(fargs)
    if not dest then notify.warn("usage: File[!] duplicate [%] {dest}"); return end
    file.duplicate(dest, { bang = bang })

  elseif subcmd == "delete" then
    file.delete_current({ force = bang })

  elseif subcmd == "cd" then
    local cfg   = config.get()
    local arg   = fargs[1] and CD_SCOPE_MAP[fargs[1]:lower()]
    local scope = arg or (cfg.cd and CD_SCOPE_MAP[cfg.cd.scope]) or "lcd"
    local refresh = not (cfg.cd and cfg.cd.refresh_explorers == false)
    file.cd_here({ scope = scope, refresh = refresh })

  elseif subcmd == "next" then
    do_cycle("next", fargs[1], count, bang)

  elseif subcmd == "prev" then
    do_cycle("prev", fargs[1], count, bang)

  else
    notify.warn(("unknown subcommand %q — try: %s"):format(subcmd, table.concat(SUBCMDS, ", ")))
  end
end

-- ─── Register ────────────────────────────────────────────────────────────────

function M.register()
  vim.api.nvim_create_user_command("File", function(a)
    local fargs = a.fargs  -- properly-parsed argument list (handles quoted paths)
    if #fargs == 0 then
      notify.warn("usage: File[!] {subcommand} [args…] — subcommands: " .. table.concat(SUBCMDS, ", "))
      return
    end

    local subcmd = table.remove(fargs, 1):lower()
    local count  = (a.count and a.count > 0) and a.count or 1
    dispatch(subcmd, fargs, a.bang, count)
  end, {
    nargs    = "+",
    bang     = true,
    count    = 0,
    complete = complete,
    desc     = "Unified file operations (new/write/saveas/writeto/mkdir/rename/duplicate/delete/next/prev/cd)",
  })
end

return M
