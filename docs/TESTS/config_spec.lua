-- docs/TESTS/config_spec.lua — config merge (DEFAULTS + user options).

return function(H)
  local eq, ok = H.eq, H.ok
  local config = require("fileops.config")

  -- defaults
  config.setup({})
  local d = config.get()
  eq(d.cycle.open_target, "replace", "default cycle.open_target")
  eq(d.cd.scope, "window", "default cd.scope")
  eq(d.delete.mode, "permanent", "default delete.mode")
  eq(d.delete.on_before_delete, nil, "default delete.on_before_delete")
  eq(d.keymaps.cycle, true, "default keymaps.cycle")
  eq(d.keymaps.lhs.next_replace, "<leader>nf", "default keymaps.lhs.next_replace")
  ok(type(d.keymaps.lhs) == "table", "keymaps.lhs is a table")
  eq(d.auto_mkdir.enable, true, "default auto_mkdir.enable")
  eq(d.auto_mkdir.skip_remote, true, "default auto_mkdir.skip_remote")
  eq(d.on_hold.enable, false, "default on_hold.enable (opt-in)")
  eq(d.on_hold.throttle_ms, 1200, "default on_hold.throttle_ms")
  eq(d.conflict_marks.enable, true, "default conflict_marks.enable")
  eq(d.conflict_marks.hl_a, "DiffDelete", "default conflict_marks.hl_a")

  -- opting in / toggling off
  config.setup({ on_hold = { enable = true }, conflict_marks = { enable = false } })
  local t = config.get()
  eq(t.on_hold.enable, true, "on_hold can be explicitly enabled")
  eq(t.conflict_marks.enable, false, "conflict_marks can be disabled")

  -- shallow override
  config.setup({ commands = false, cd = { scope = "global" } })
  local o = config.get()
  eq(o.commands, false, "override commands")
  eq(o.cd.scope, "global", "override nested cd.scope")
  -- untouched sibling keeps its default
  eq(o.cd.refresh_explorers, true, "untouched sibling key keeps default")

  -- delete.mode override + on_before_delete hook is passed through as-is
  local hook = function() return true end
  config.setup({ delete = { mode = "trash", on_before_delete = hook } })
  local dd = config.get()
  eq(dd.delete.mode, "trash", "override delete.mode")
  eq(dd.delete.on_before_delete, hook, "override delete.on_before_delete")

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
