---@module 'fileops.util.notify'
---"[fileops] " prefixed vim.notify wrapper; upgrades to lib.nvim's notifier
---when lib.nvim is installed. Soft dependency only: falls back to plain
---vim.notify when lib.nvim is absent — fileops.nvim stays fully standalone.
local PREFIX = "[fileops] "
local M = {}

---@internal
---@return table|nil notifier  lib.nvim's notifier instance, or nil when lib.nvim is absent.
local function resolve()
  local ok, lib_notify = pcall(require, "lib.nvim.notify")
  if ok and type(lib_notify) == "table" and type(lib_notify.create) == "function" then
    local create_ok, notifier = pcall(lib_notify.create, PREFIX)
    if create_ok and type(notifier) == "table" then return notifier end
  end
  return nil
end

local lib = resolve()

---Show an info-level notification.
---@param msg string
function M.info(msg)
  if lib then lib.info(msg) else vim.notify(PREFIX .. msg, vim.log.levels.INFO) end
end

---Show a warning-level notification.
---@param msg string
function M.warn(msg)
  if lib then lib.warn(msg) else vim.notify(PREFIX .. msg, vim.log.levels.WARN) end
end

---Show an error-level notification.
---@param msg string
function M.error(msg)
  if lib then lib.error(msg) else vim.notify(PREFIX .. msg, vim.log.levels.ERROR) end
end

---Show a debug-level notification.
---@param msg string
function M.debug(msg)
  if lib then lib.debug(msg) else vim.notify(PREFIX .. msg, vim.log.levels.DEBUG) end
end

---Whether lib.nvim's notifier is in use (for :checkhealth reporting).
---@return boolean
function M.using_lib()
  return lib ~= nil
end

---Relay a low-level op's `ok, msg` result. Low-level modules (ops.file,
---ops.cycle, …) never call notify themselves; they return `ok, msg` and
---leave the decision of whether/how to surface it to the caller. This is
---the one place that makes that decision, so it stays consistent across
---every binding (usercmds, keymaps, the public Lua API).
---@param ok boolean
---@param msg string|nil
---@return boolean ok  passthrough, so callers can chain
function M.report(ok, msg)
  if msg then
    if ok then M.info(msg) else M.error(msg) end
  end
  return ok
end

return M
