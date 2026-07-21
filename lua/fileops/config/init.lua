---@module 'fileops.config'
---Runtime config store: merge user options over DEFAULTS, expose get().
local M = {}

---@type FileOps.Config
M.DEFAULTS = require("fileops.config.DEFAULTS")

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
