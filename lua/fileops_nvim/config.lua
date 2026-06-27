---@module 'fileops_nvim.config'
local M = {}

---@type FileOps.Config
M.DEFAULTS = {
  cycle = {
    open_target         = "replace",
    keep_focus          = true,
    include_hidden      = false,
    wrap                = true,
    follow_symlinks     = true,
    root                = "buffer_dir",
    confirm_on_modified = true,
    case_insensitive    = true,
  },
  cd = {
    scope             = "window",  -- "window" (lcd) | "tab" (tcd) | "global" (cd)
    refresh_explorers = true,      -- refresh neo-tree/nvim-tree/netrw after cd
  },
  keymaps = {
    cycle  = true,
    delete = true,
  },
  commands = true,
}

---@type FileOps.Config
local _active = vim.deepcopy(M.DEFAULTS)

---Merge user opts over defaults and store result.
---@param user_opts FileOps.Config|nil
---@return FileOps.Config
function M.setup(user_opts)
  if user_opts then
    _active = vim.tbl_deep_extend("force", vim.deepcopy(M.DEFAULTS), user_opts)
  else
    _active = vim.deepcopy(M.DEFAULTS)
  end
  return _active
end

---Return the active config (read-only view).
---@return FileOps.Config
function M.get()
  return _active
end

return M
