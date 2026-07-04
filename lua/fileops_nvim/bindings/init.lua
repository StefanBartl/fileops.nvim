---@module 'fileops_nvim.bindings'
---Orchestrates fileops_nvim's bindings: usrcmds, keymaps, which-key.
local M = {}

---Wire up every binding for the resolved config.
---@param cfg FileOps.Config
function M.setup(cfg)
  if cfg.commands ~= false then
    require("fileops_nvim.bindings.usrcmds").register()
  end

  local km = cfg.keymaps or {}

  if km.cycle ~= false then
    require("fileops_nvim.bindings.keymaps").attach_cycle()
  end

  if km.delete ~= false then
    require("fileops_nvim.bindings.keymaps").attach_delete()
  end

  require("fileops_nvim.bindings.which_key").setup()
end

return M
