---@module 'fileops.bindings'
---Orchestrates fileops's bindings: usrcmds, keymaps, autocmds.
---
---The which-key group labels are no longer wired here: they are two fields in
---the keymap spec, applied by lib.nvim's registry.
local M = {}

---Wire up every binding for the resolved config.
---@param cfg FileOps.Config
function M.setup(cfg)
  if cfg.commands ~= false then
    require("fileops.bindings.usrcmds").register()
  end

  -- One call, unconditionally: the `cycle` / `delete` master switches are
  -- applied inside, by turning their family's keys into `false`. Binding
  -- nothing is not the same as declaring nothing -- :checkhealth and the
  -- generated docs ask what EXISTS, and that stays true either way.
  require("fileops.bindings.keymaps").setup(cfg)

  require("fileops.bindings.autocmds").attach_auto_mkdir(cfg.auto_mkdir)
  require("fileops.bindings.autocmds").attach_on_hold(cfg.on_hold)
  require("fileops.bindings.autocmds").attach_conflict_marks(cfg.conflict_marks)
end

return M
