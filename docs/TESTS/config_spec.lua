-- docs/TESTS/config_spec.lua — config merge (DEFAULTS + user options).

return function(H)
  local eq, ok = H.eq, H.ok
  local config = require("fileops_nvim.config")

  -- defaults
  config.setup({})
  local d = config.get()
  eq(d.cycle.open_target, "replace", "default cycle.open_target")
  eq(d.cd.scope, "window", "default cd.scope")
  eq(d.keymaps.cycle, true, "default keymaps.cycle")
  eq(d.keymaps.lhs.next_replace, "<leader>nf", "default keymaps.lhs.next_replace")
  ok(type(d.keymaps.lhs) == "table", "keymaps.lhs is a table")

  -- shallow override
  config.setup({ commands = false, cd = { scope = "global" } })
  local o = config.get()
  eq(o.commands, false, "override commands")
  eq(o.cd.scope, "global", "override nested cd.scope")
  -- untouched sibling keeps its default
  eq(o.cd.refresh_explorers, true, "untouched sibling key keeps default")

  -- nested keymaps.lhs deep-merge: only the touched key changes
  config.setup({ keymaps = { lhs = { next_replace = false, delete = "<leader>XX" } } })
  local k = config.get()
  eq(k.keymaps.lhs.next_replace, false, "explicit disable applied")
  eq(k.keymaps.lhs.delete, "<leader>XX", "explicit remap applied")
  eq(k.keymaps.lhs.prev_replace, "<leader>pf", "untouched lhs key keeps default")
  eq(k.keymaps.cycle, true, "master switch untouched by lhs override")

  -- reset
  config.setup({})
end
