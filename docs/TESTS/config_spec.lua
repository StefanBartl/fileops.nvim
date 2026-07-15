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
  eq(d.auto_mkdir.enable, true, "default auto_mkdir.enable")
  eq(d.auto_mkdir.skip_remote, true, "default auto_mkdir.skip_remote")
  eq(d.on_hold.enable, true, "default on_hold.enable")
  eq(d.on_hold.throttle_ms, 1200, "default on_hold.throttle_ms")
  eq(d.conflict_marks.enable, true, "default conflict_marks.enable")
  eq(d.conflict_marks.hl_a, "DiffDelete", "default conflict_marks.hl_a")

  -- toggling off
  config.setup({ on_hold = { enable = false }, conflict_marks = { enable = false } })
  local t = config.get()
  eq(t.on_hold.enable, false, "on_hold can be disabled")
  eq(t.conflict_marks.enable, false, "conflict_marks can be disabled")

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
