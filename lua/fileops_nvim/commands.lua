---@module 'fileops_nvim.commands'
---Registers all user commands for fileops_nvim.
local M = {}

local notify = require("fileops_nvim.util.notify")
local file   = require("fileops_nvim.ops.file")
local cycle  = require("fileops_nvim.ops.cycle")
local config = require("fileops_nvim.config")

-- ─── Cycle helpers ────────────────────────────────────────────────────────────

local VALID_TARGETS = {
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

---@param args string[]
---@return integer
local function parse_count(args)
  for _, a in ipairs(args) do
    local n = tonumber(a)
    if n and n >= 1 then return math.floor(n) end
  end
  return 1
end

---@param arg string|nil
---@return FileOps.OpenTarget|nil
local function parse_target(arg)
  if not arg or arg == "" then return nil end
  return VALID_TARGETS[arg:lower()]
end

local function completions()
  return { "%", "replace", "stay", "current", "new", "split", "vsplit", "tab", "bg", "background" }
end

local function cycle_cmd(direction, count_arg, args_raw, bang)
  local cfg   = config.get()
  local copts = vim.deepcopy(cfg.cycle or {})

  local parts = type(args_raw) == "string" and vim.split(args_raw, "%s+", { trimempty = true }) or {}

  local target = parse_target(parts[1])
  if target then copts.open_target = target end

  local cnt = (count_arg and count_arg > 0) and count_arg or parse_count(parts)

  if bang then copts.confirm_on_modified = false end

  local dir, err = cycle.get_root_dir(copts)
  if not dir then
    notify.warn(err or "cannot determine root directory")
    return
  end

  cycle.navigate(dir, direction, copts, cnt)
end

-- ─── Register ────────────────────────────────────────────────────────────────

function M.register()
  -- NextFile[!] [target]
  vim.api.nvim_create_user_command("NextFile", function(a)
    cycle_cmd("next", a.count > 0 and a.count or nil, a.args, a.bang)
  end, {
    nargs = "?",
    bang  = true,
    count = 0,
    complete = completions,
    desc  = "Open the next file in the current directory",
  })

  -- PreviousFile[!] [target]
  vim.api.nvim_create_user_command("PreviousFile", function(a)
    cycle_cmd("prev", a.count > 0 and a.count or nil, a.args, a.bang)
  end, {
    nargs = "?",
    bang  = true,
    count = 0,
    complete = completions,
    desc  = "Open the previous file in the current directory",
  })

  -- NewFile {path}
  vim.api.nvim_create_user_command("NewFile", function(a)
    if a.args == "" then notify.warn("usage: NewFile {path}"); return end
    file.edit_new(a.args, {})
  end, {
    nargs = 1,
    complete = "file",
    desc  = "Set buffer name to a new path (creates parent dirs)",
  })

  -- NewFileWrite {path}
  vim.api.nvim_create_user_command("NewFileWrite", function(a)
    if a.args == "" then notify.warn("usage: NewFileWrite {path}"); return end
    file.edit_new(a.args, { write = true })
  end, {
    nargs = 1,
    complete = "file",
    desc  = "Set buffer name and write immediately (creates parent dirs)",
  })

  -- SaveAsR[!] {path}
  vim.api.nvim_create_user_command("SaveAsR", function(a)
    if a.args == "" then notify.warn("usage: SaveAsR[!] {path}"); return end
    file.save_as(a.args, { bang = a.bang })
  end, {
    nargs = 1,
    bang  = true,
    complete = "file",
    desc  = "Save buffer under a new path (creates parent dirs)",
  })

  -- WriteToR[!] {path}
  vim.api.nvim_create_user_command("WriteToR", function(a)
    if a.args == "" then notify.warn("usage: WriteToR[!] {path}"); return end
    file.write_to(a.args, { bang = a.bang })
  end, {
    nargs = 1,
    bang  = true,
    complete = "file",
    desc  = "Write a copy of the buffer without changing its name",
  })

  -- MkParent
  vim.api.nvim_create_user_command("MkParent", function(_)
    file.mk_parent()
  end, {
    nargs = 0,
    desc  = "Create parent directories for the current buffer's file",
  })

  -- RenameFile[!] {newpath}
  vim.api.nvim_create_user_command("RenameFile", function(a)
    if a.args == "" then notify.warn("usage: RenameFile[!] {newpath}"); return end
    file.rename(a.args, { bang = a.bang })
  end, {
    nargs = 1,
    bang  = true,
    complete = "file",
    desc  = "Rename (move) the current file on disk and update the buffer",
  })

  -- DuplicateFile[!] {newpath}
  vim.api.nvim_create_user_command("DuplicateFile", function(a)
    if a.args == "" then notify.warn("usage: DuplicateFile[!] {newpath}"); return end
    file.duplicate(a.args, { bang = a.bang })
  end, {
    nargs = 1,
    bang  = true,
    complete = "file",
    desc  = "Copy the current file to a new path and open the copy",
  })

  -- DeleteCurrentFile
  vim.api.nvim_create_user_command("DeleteCurrentFile", function(_)
    file.delete_current({})
  end, {
    nargs = 0,
    desc  = "Delete the current file from disk and close the buffer",
  })
end

return M
