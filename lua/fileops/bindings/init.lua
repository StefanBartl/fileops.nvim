---@module 'fileops.bindings'
---Orchestrates fileops's bindings: usrcmds, keymaps, which-key.
local M = {}

---Wire up every binding for the resolved config.
---@param cfg FileOps.Config
function M.setup(cfg)
  if cfg.commands ~= false then
    require("fileops.bindings.usrcmds").register()
  end

  local km = cfg.keymaps or {}

  if km.cycle ~= false then
    require("fileops.bindings.keymaps").attach_cycle()
  end

  if km.delete ~= false then
    require("fileops.bindings.keymaps").attach_delete()
  end

  require("fileops.bindings.autocmds").attach_auto_mkdir(cfg.auto_mkdir)
  require("fileops.bindings.autocmds").attach_on_hold(cfg.on_hold)
  require("fileops.bindings.autocmds").attach_conflict_marks(cfg.conflict_marks)

  require("fileops.bindings.which_key").setup()
end

return M
