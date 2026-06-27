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

  if cfg.commands ~= false then
    require("fileops_nvim.commands").register()
  end

  local km_cfg = cfg.keymaps or {}

  if km_cfg.cycle ~= false then
    require("fileops_nvim.keymaps").attach_cycle()
  end

  if km_cfg.delete ~= false then
    require("fileops_nvim.keymaps").attach_delete()
  end

  vim.g.loaded_fileops_nvim = 1
end

-- ─── Public Lua API ──────────────────────────────────────────────────────────

---Navigate to the next file in the current directory.
---@param opts? FileOps.CycleConfig
---@param count? integer
function M.next(opts, count)
  local cfg   = require("fileops_nvim.config").get()
  local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), opts or {})
  local cycle = require("fileops_nvim.ops.cycle")
  local dir, err = cycle.get_root_dir(copts)
  if not dir then require("fileops_nvim.util.notify").warn(err or "no root dir"); return end
  cycle.navigate(dir, "next", copts, count)
end

---Navigate to the previous file in the current directory.
---@param opts? FileOps.CycleConfig
---@param count? integer
function M.prev(opts, count)
  local cfg   = require("fileops_nvim.config").get()
  local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), opts or {})
  local cycle = require("fileops_nvim.ops.cycle")
  local dir, err = cycle.get_root_dir(copts)
  if not dir then require("fileops_nvim.util.notify").warn(err or "no root dir"); return end
  cycle.navigate(dir, "prev", copts, count)
end

---Create a new file (set buffer name + optionally write).
---@param path string
---@param opts? { write?: boolean, bang?: boolean }
function M.new_file(path, opts)
  require("fileops_nvim.ops.file").edit_new(path, opts)
end

---Rename the current file on disk.
---@param new_path string
---@param opts? { bang?: boolean }
function M.rename(new_path, opts)
  require("fileops_nvim.ops.file").rename(new_path, opts)
end

---Duplicate the current file to a new path.
---@param new_path string
---@param opts? { bang?: boolean, open?: boolean }
function M.duplicate(new_path, opts)
  require("fileops_nvim.ops.file").duplicate(new_path, opts)
end

---Delete the current file from disk and close the buffer.
---@param opts? { force?: boolean }
function M.delete_current(opts)
  require("fileops_nvim.ops.file").delete_current(opts)
end

---Change the working directory to the current buffer's directory and refresh
---any open file explorer (neo-tree/nvim-tree/netrw).
---@param opts? { scope?: "lcd"|"cd"|"tcd", refresh?: boolean }
function M.cd_here(opts)
  require("fileops_nvim.ops.file").cd_here(opts)
end

return M
