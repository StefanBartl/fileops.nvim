---@module 'fileops_nvim.bindings.autocmds'
---Autocommand registration for fileops_nvim. Called only from bindings.setup().
local M = {}

local file = require("fileops_nvim.ops.file")

local GROUP = "fileops_nvim_auto_mkdir"

---Register the BufWritePre auto-mkdir autocmd if `cfg.enable`.
---Creates the parent directory of the file about to be written, reusing the
---same `file.ensure_parent` logic behind `:File mkdir`.
---@param cfg FileOps.AutoMkdirConfig
function M.attach_auto_mkdir(cfg)
  cfg = cfg or {}
  if cfg.enable == false then
    return
  end

  local pattern = cfg.detect_remote_pattern or "^%w%w+:[\\/][\\/]"
  local grp = vim.api.nvim_create_augroup(GROUP, { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = grp,
    callback = function(event)
      if cfg.skip_remote ~= false and event.match:match(pattern) then
        return
      end
      file.ensure_parent(event.match)
    end,
    desc = "[fileops] Create parent directories before writing a file",
  })
end

---Register the ambient CursorHold/CursorHoldI line-diff preview autocmds if `cfg.enable`.
---@param cfg FileOps.OnHoldConfig
function M.attach_on_hold(cfg)
  require("fileops_nvim.features.on_hold").setup(cfg)
end

---Register the BufWinEnter/BufWinLeave conflict-marker highlight autocmds if `cfg.enable`.
---@param cfg FileOps.ConflictMarksConfig
function M.attach_conflict_marks(cfg)
  require("fileops_nvim.features.conflict_marks").setup(cfg)
end

return M
