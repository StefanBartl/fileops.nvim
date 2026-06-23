---@module 'fileops_nvim.util.notify'
---Lightweight prefixed notification helpers. No lib.nvim dependency.
local M = {}

local PREFIX = "[fileops] "

function M.info(msg)
  vim.notify(PREFIX .. msg, vim.log.levels.INFO)
end

function M.warn(msg)
  vim.notify(PREFIX .. msg, vim.log.levels.WARN)
end

function M.error(msg)
  vim.notify(PREFIX .. msg, vim.log.levels.ERROR)
end

function M.debug(msg)
  vim.notify(PREFIX .. msg, vim.log.levels.DEBUG)
end

return M
