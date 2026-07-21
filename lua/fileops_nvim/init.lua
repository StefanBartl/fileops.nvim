---@module 'fileops_nvim'
---Entry point for fileops_nvim. Call M.setup() once in your Neovim config.
local M = {}

local _setup_done = false

---Configure and activate fileops_nvim.
---@param user_opts FileOps.Config|nil
function M.setup(user_opts)
  if _setup_done then return end
  _setup_done = true

  local cfg = require("fileops_nvim.config").setup(user_opts)
  require("fileops_nvim.bindings").setup(cfg)

  vim.g.loaded_fileops_nvim = 1
end

-- ─── Public Lua API ──────────────────────────────────────────────────────────

---Navigate to the next file in the current directory.
---@param opts? FileOps.CycleConfig
---@param count? integer
---@return boolean ok
function M.next(opts, count)
  local cfg   = require("fileops_nvim.config").get()
  local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), opts or {})
  local cycle = require("fileops_nvim.ops.cycle")
  local notify = require("fileops_nvim.util.notify")
  local dir, err = cycle.get_root_dir(copts)
  if not dir then notify.warn(err or "no root dir"); return false end
  return notify.report(cycle.navigate(dir, "next", copts, count))
end

---Navigate to the previous file in the current directory.
---@param opts? FileOps.CycleConfig
---@param count? integer
---@return boolean ok
function M.prev(opts, count)
  local cfg   = require("fileops_nvim.config").get()
  local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), opts or {})
  local cycle = require("fileops_nvim.ops.cycle")
  local notify = require("fileops_nvim.util.notify")
  local dir, err = cycle.get_root_dir(copts)
  if not dir then notify.warn(err or "no root dir"); return false end
  return notify.report(cycle.navigate(dir, "prev", copts, count))
end

---Jump straight to the first file in the current directory listing.
---@param opts? FileOps.CycleConfig
---@return boolean ok
function M.first(opts)
  local cfg   = require("fileops_nvim.config").get()
  local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), opts or {})
  local cycle = require("fileops_nvim.ops.cycle")
  local notify = require("fileops_nvim.util.notify")
  local dir, err = cycle.get_root_dir(copts)
  if not dir then notify.warn(err or "no root dir"); return false end
  return notify.report(cycle.jump_edge(dir, "first", copts))
end

---Jump straight to the last file in the current directory listing.
---@param opts? FileOps.CycleConfig
---@return boolean ok
function M.last(opts)
  local cfg   = require("fileops_nvim.config").get()
  local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), opts or {})
  local cycle = require("fileops_nvim.ops.cycle")
  local notify = require("fileops_nvim.util.notify")
  local dir, err = cycle.get_root_dir(copts)
  if not dir then notify.warn(err or "no root dir"); return false end
  return notify.report(cycle.jump_edge(dir, "last", copts))
end

---Reopen the current buffer's own path in a different window target
---(split/vsplit/tab/background/…), without changing which file is shown.
---@param opts? FileOps.CycleConfig
---@return boolean ok
function M.open(opts)
  local cfg   = require("fileops_nvim.config").get()
  local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), opts or {})
  local cycle = require("fileops_nvim.ops.cycle")
  local notify = require("fileops_nvim.util.notify")
  return notify.report(cycle.open_current(copts))
end

---Create a new file (set buffer name + optionally write).
---@param path string
---@param opts? { write?: boolean, bang?: boolean }
---@return boolean ok
function M.new_file(path, opts)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").edit_new(path, opts)
  )
end

---Create an empty file at `path` if it doesn't already exist. Does not
---require or touch a buffer.
---@param path string
---@return boolean ok
function M.touch(path)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").touch(path)
  )
end

---Rename the current file on disk.
---@param new_path string
---@param opts? { bang?: boolean }
---@return boolean ok
function M.rename(new_path, opts)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").rename(new_path, opts)
  )
end

---Move the current file on disk (possibly to a different directory) without
---reloading the buffer from disk.
---@param new_path string
---@param opts? { bang?: boolean }
---@return boolean ok
function M.move(new_path, opts)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").move(new_path, opts)
  )
end

---Duplicate the current file to a new path.
---@param new_path string
---@param opts? { bang?: boolean, open?: boolean }
---@return boolean ok
function M.duplicate(new_path, opts)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").duplicate(new_path, opts)
  )
end

---Copy the current buffer's file to a new path without opening the copy.
---@param new_path string
---@param opts? { bang?: boolean }
---@return boolean ok
function M.copy(new_path, opts)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").copy(new_path, opts)
  )
end

---Delete the current file from disk and close the buffer.
---@param opts? { force?: boolean, mode?: "trash"|"permanent", on_before_delete?: fun(path: string): boolean|nil }
---@return boolean ok
function M.delete_current(opts)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").delete_current(opts)
  )
end

---Change the working directory to the current buffer's directory and refresh
---any open file explorer (neo-tree/nvim-tree/netrw).
---@param opts? { scope?: "lcd"|"cd"|"tcd", refresh?: boolean }
---@return boolean ok
function M.cd_here(opts)
  return require("fileops_nvim.util.notify").report(
    require("fileops_nvim.ops.file").cd_here(opts)
  )
end

return M
