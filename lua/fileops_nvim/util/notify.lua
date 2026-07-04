---@module 'fileops_nvim.util.notify'
---"[fileops] " prefixed vim.notify wrapper; upgrades to lib.nvim's notifier
---when lib.nvim is installed. Soft dependency only: falls back to plain
---vim.notify when lib.nvim is absent — fileops.nvim stays fully standalone.
local PREFIX = "[fileops] "
local M = {}

local function resolve()
  local ok, lib_notify = pcall(require, "lib.nvim.notify")
  if ok and type(lib_notify) == "table" and type(lib_notify.create) == "function" then
    local create_ok, notifier = pcall(lib_notify.create, PREFIX)
    if create_ok and type(notifier) == "table" then return notifier end
  end
  return nil
end

local lib = resolve()

function M.info(msg)
  if lib then lib.info(msg) else vim.notify(PREFIX .. msg, vim.log.levels.INFO) end
end

function M.warn(msg)
  if lib then lib.warn(msg) else vim.notify(PREFIX .. msg, vim.log.levels.WARN) end
end

function M.error(msg)
  if lib then lib.error(msg) else vim.notify(PREFIX .. msg, vim.log.levels.ERROR) end
end

function M.debug(msg)
  if lib then lib.debug(msg) else vim.notify(PREFIX .. msg, vim.log.levels.DEBUG) end
end

---Whether lib.nvim's notifier is in use (for :checkhealth reporting).
---@return boolean
function M.using_lib()
  return lib ~= nil
end

return M
