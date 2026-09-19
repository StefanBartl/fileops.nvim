-- TESTS/config_spec.lua — config merge (DEFAULTS + user options).

return function(H)
  local eq, ok = H.eq, H.ok
  local config = require("fileops.config")

  -- defaults
  config.setup({})
  local d = config.get()
  eq(d.cycle.open_target, "replace", "default cycle.open_target")
  eq(d.cd.scope, "window", "default cd.scope")
  eq(d.delete.mode, "trash", "default delete.mode")
  eq(d.delete.on_before_delete, nil, "default delete.on_before_delete")
  eq(d.keymaps.cycle, true, "default keymaps.cycle")
  eq(d.keymaps.lhs.next_replace, "<leader>nf", "default keymaps.lhs.next_replace")
  ok(type(d.keymaps.lhs) == "table", "keymaps.lhs is a table")

  -- The keys added 2026-08-24 are deliberately unset: their actions were
  -- command-only, and making a keymap *possible* is a different thing from
  -- claiming a key for it. If a default ever appears here it should be a
  -- decision, not a slip.
  for _, key in ipairs({
    "next_filtered",
    "prev_filtered",
    "delete_force",
    "path",
    "cd",
    "info",
    "lockinfo",
    "bulk_rename",
  }) do
    eq(d.keymaps.lhs[key], nil, ("keymaps.lhs.%s has no default"):format(key))
  end
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
  local hook = function()
    return true
  end
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

  -- ERR-50: an unknown top-level key, and an unknown key nested one level
  -- deep, are both dropped before the merge instead of surviving as dead
  -- fields next to the real option -- and reported via issues().
  local function has_issue(needle)
    for _, i in ipairs(config.issues()) do
      if i:find(needle, 1, true) then
        return true
      end
    end
    return false
  end

  config.setup({ delete = { mode2 = "trash" }, cycle = { open_taget = "split" } })
  local u = config.get()
  eq(u.delete.mode, "trash", "the unknown delete.mode2 didn't reach the merge")
  eq(u.cycle.open_target, "replace", "the unknown cycle.open_taget didn't reach the merge")
  eq(u.delete.mode2, nil, "delete.mode2 was not written into the active config")
  ok(has_issue("mode2"), "issues() names the unknown delete.mode2 key")
  ok(has_issue("did you mean"), "…with a did-you-mean hint for a close typo")

  -- ERR-22: an invalid delete.mode degrades to the default instead of to its
  -- opposite, and is reported the same way.
  config.setup({ delete = { mode = "Trash" } })
  eq(config.get().delete.mode, "trash", "an invalid delete.mode falls back to the default")
  ok(has_issue("delete.mode"), "issues() names the rejected delete.mode value")

  -- clean setup() reports no issues
  config.setup({})
  eq(#config.issues(), 0, "a clean setup() call reports no issues")

  -- ERR-53: a sub-table reference a consumer captured (the shape
  -- bindings.autocmds hands to on_hold/auto_mkdir/conflict_marks) survives a
  -- second setup() call -- the merge mutates it in place instead of
  -- replacing it, so the reference doesn't go stale.
  local held_on_hold = config.get().on_hold
  config.setup({ on_hold = { enable = true, throttle_ms = 500 } })
  ok(held_on_hold == config.get().on_hold, "on_hold keeps its table identity across setup()")
  eq(held_on_hold.enable, true, "…and the held reference sees the new value")
  eq(held_on_hold.throttle_ms, 500, "…for every field that changed")

  -- reset
  config.setup({})
end
