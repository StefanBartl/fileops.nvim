-- TESTS/keymaps_spec.lua — bindings/keymaps.lua: the named-action preset it
-- hands to lib.nvim's keymap registry, the two family switches, the per-key
-- overrides, and what each action's `rhs` actually does when invoked.
--
-- The registry answers with the list of declared actions (bound or not), so
-- the preset can be checked without reading `:map` output — and an action with
-- no key still shows up, which is exactly the distinction this module's header
-- makes between "switched off" and "does not exist".

return function(H)
  local eq, ok = H.eq, H.ok
  local fn = vim.fn
  local keymaps = require("fileops.bindings.keymaps")
  local config = require("fileops.config")

  ---@param entries table[]
  ---@return table<string, table>
  local function by_name(entries)
    local out = {}
    for _, e in ipairs(entries) do
      out[e.name] = e
    end
    return out
  end

  -- ── the default preset ───────────────────────────────────────────────────
  do
    local cfg = config.setup({})
    local entries = keymaps.setup(cfg)
    local actions = by_name(entries)

    for _, name in ipairs({
      "next_replace",
      "prev_replace",
      "next_current",
      "prev_current",
      "next_background",
      "prev_background",
      "next_vsplit",
      "prev_vsplit",
      "next_filtered",
      "prev_filtered",
      "delete",
      "delete_force",
      "path",
      "cd",
      "info",
      "lockinfo",
      "bulk_rename",
    }) do
      ok(actions[name] ~= nil, "the preset declares the action " .. name)
      ok(type(actions[name].rhs) == "function", name .. " has a callable rhs")
      ok(
        type(actions[name].desc) == "string" and actions[name].desc:find("fileops", 1, true) == 1,
        name .. "'s description is prefixed with the plugin name: " .. tostring(actions[name].desc)
      )
    end

    eq(entries[1].name, "next_replace", "the declared order is preserved (docs read top to bottom)")
    eq(actions.next_replace.lhs, "<leader>nf", "a configured key is bound to its action")
    eq(actions.delete.lhs, "<leader>dcf", "…for every family")
    eq(actions.next_filtered.lhs, nil, "an action with no configured key is declared but unbound")
    eq(actions.bulk_rename.lhs, nil, "…and stays declared, so :checkhealth can report it")
    eq(actions.next_replace.mode, "n", "the preset binds in normal mode")

    -- The mapping really reached Neovim, not just the registry.
    local lhs = vim.keycode and vim.keycode("<leader>nf") or nil
    if lhs then
      local found = false
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.lhs == lhs then
          found = true
        end
      end
      ok(found, "the bound lhs is a real normal-mode mapping")
    end
  end

  -- ── family switches ──────────────────────────────────────────────────────
  do
    local cfg = config.setup({ keymaps = { cycle = false } })
    local actions = by_name(keymaps.setup(cfg))
    eq(actions.next_replace.lhs, nil, "keymaps.cycle = false unbinds the whole cycle family")
    eq(actions.prev_vsplit.lhs, nil, "…every member of it")
    eq(actions.delete.lhs, "<leader>dcf", "…and leaves the other families alone")
    ok(actions.next_replace ~= nil, "a switched-off family is still declared, not erased")

    -- The switch must not be written back into the live config: it would then
    -- be indistinguishable from a per-key opt-out on the next read.
    eq(
      config.get().keymaps.lhs.next_replace,
      "<leader>nf",
      "the family switch leaves the user's lhs table untouched"
    )

    cfg = config.setup({ keymaps = { delete = false } })
    actions = by_name(keymaps.setup(cfg))
    eq(actions.delete.lhs, nil, "keymaps.delete = false unbinds the delete family")
    eq(actions.delete_force.lhs, nil, "…including the forced form")
    eq(actions.next_replace.lhs, "<leader>nf", "…and leaves the cycle family alone")
  end

  -- ── per-key overrides ────────────────────────────────────────────────────
  do
    local cfg = config.setup({
      keymaps = {
        lhs = { next_replace = false, delete = "<leader>XX", bulk_rename = "<leader>fR" },
      },
    })
    local actions = by_name(keymaps.setup(cfg))
    eq(actions.next_replace.lhs, nil, "a single key set to false drops just that mapping")
    eq(actions.prev_replace.lhs, "<leader>pf", "…and its siblings keep theirs")
    eq(actions.delete.lhs, "<leader>XX", "a remapped key is bound where the user asked")
    eq(actions.bulk_rename.lhs, "<leader>fR", "an opt-in key with no default can be claimed")
  end

  -- ── what the actions do ──────────────────────────────────────────────────
  do
    local cfg = config.setup({})
    local actions = by_name(keymaps.setup(cfg))
    local dir = H.tmpdir()
    H.write_file(dir .. "a.lua", "-- a")
    H.write_file(dir .. "b.lua", "-- b")
    H.write_file(dir .. "c.lua", "-- c")

    -- cycle
    H.edit(dir .. "a.lua")
    actions.next_replace.rhs()
    eq(fn.expand("%:t"), "b.lua", "next_replace walks to the next file")
    actions.prev_replace.rhs()
    eq(fn.expand("%:t"), "a.lua", "prev_replace walks back")

    actions.next_background.rhs()
    eq(fn.expand("%:t"), "a.lua", "next_background does not move the current window")
    ok(
      fn.bufnr(fn.fnamemodify(dir .. "b.lua", ":p")) ~= -1,
      "…but the next file is on the buffer list"
    )

    vim.cmd("only")
    H.edit(dir .. "a.lua")
    actions.next_vsplit.rhs()
    eq(#vim.api.nvim_list_wins(), 2, "next_vsplit opens the next file in a vertical split")
    vim.wait(100)
    vim.cmd("only")

    -- A nameless buffer has no directory: the action warns instead of erroring.
    vim.cmd("enew")
    local warned = H.notifications(function()
      actions.next_replace.rhs()
    end)
    ok(H.notified(warned, "no file name"), "a cycle action on a nameless buffer explains itself")

    -- path / info / cd
    H.edit(dir .. "a.lua")
    actions.path.rhs()
    eq(
      fn.getreg('"'),
      fn.fnamemodify(dir .. "a.lua", ":p"),
      "the path action copies the absolute path"
    )

    local info = H.notifications(function()
      actions.info.rhs()
    end)
    ok(H.notified(info, "size:"), "the info action reports the file's stats")

    local prev_cwd = fn.getcwd()
    actions.cd.rhs()
    eq(
      vim.fs.normalize(fn.getcwd()),
      vim.fs.normalize(fn.fnamemodify(dir, ":p:h")),
      "the cd action changes directory to the buffer's folder"
    )
    vim.cmd("cd " .. fn.fnameescape(prev_cwd))

    -- lockinfo goes through the public entry point, which supplies the
    -- notify-based callback `ops.file.diagnose_lock` requires — calling the op
    -- bare (as an earlier version did) raised instead of reporting.
    local restore_lock = H.stub("lib.nvim.cross.fs.lock", {
      report = function(_, cb)
        cb({ "no holder found" })
      end,
    })
    local lock_out = H.notifications(function()
      actions.lockinfo.rhs()
    end)
    restore_lock()
    ok(H.notified(lock_out, "no holder found"), "the lockinfo action reports through notify")

    -- next_filtered prompts for a glob and remembers it for the next call.
    local prompts = {}
    local restore_kit = H.stub("ui.kit", {
      input = function(o)
        prompts[#prompts + 1] = { title = o.title, default = o.default }
        o.on_submit("*.lua")
      end,
    })
    H.write_file(dir .. "notes.md", "-- notes")
    H.edit(dir .. "notes.md")
    actions.next_filtered.rhs()
    eq(fn.expand("%:t"), "a.lua", "next_filtered navigates within the entered glob")
    eq(prompts[1].default, nil, "the first glob prompt starts empty")
    actions.prev_filtered.rhs()
    eq(prompts[2].default, "*.lua", "the next glob prompt is pre-filled with the last one used")

    -- An empty answer cancels rather than navigating with an empty pattern.
    restore_kit()
    restore_kit = H.stub("ui.kit", {
      input = function(o)
        o.on_submit("   ")
      end,
    })
    H.edit(dir .. "a.lua")
    actions.next_filtered.rhs()
    eq(fn.expand("%:t"), "a.lua", "a blank glob answer cancels the navigation")
    restore_kit()

    -- bulk_rename chains two prompts (pattern, then replacement) and reports
    -- the count — the keymap has no other way to say what happened.
    local bdir = H.tmpdir()
    H.write_file(bdir .. "note_1.txt", "1")
    H.write_file(bdir .. "note_2.txt", "2")
    H.edit(bdir .. "note_1.txt")
    local titles = {}
    local replies = { "^note_", "memo_" }
    restore_kit = H.stub("ui.kit", {
      input = function(o)
        titles[#titles + 1] = o.title
        o.on_submit(table.remove(replies, 1))
      end,
    })
    local bulk_out = H.notifications(function()
      actions.bulk_rename.rhs()
    end)
    restore_kit()
    eq(#titles, 2, "bulk_rename asks for a pattern and a replacement")
    ok(titles[2]:find("^note_", 1, true) ~= nil, "…quoting the pattern in the second prompt")
    eq(fn.filereadable(bdir .. "memo_1.txt"), 1, "bulk_rename renamed the matching files")
    ok(H.notified(bulk_out, "2 file(s) renamed"), "…and reported how many")

    -- An empty pattern cancels before anything is planned.
    restore_kit = H.stub("ui.kit", {
      input = function(o)
        o.on_submit("")
      end,
    })
    actions.bulk_rename.rhs()
    restore_kit()
    eq(fn.filereadable(bdir .. "memo_1.txt"), 1, "a cancelled bulk_rename renames nothing")
  end

  -- ── delete: what the key actually deletes ────────────────────────────────
  do
    local cfg = config.setup({})
    local actions = by_name(keymaps.setup(cfg))
    eq(config.get().delete.mode, "trash", "setup: the configured delete mode is 'trash'")

    local dir = H.tmpdir()
    local victim = dir .. "keymap_victim.txt"
    H.write_file(victim, "bye")
    H.edit(victim)

    local trashed = false
    local restore_trash = H.stub("lib.nvim.fs.trash", {
      trash_blocking = function(path)
        trashed = true
        fn.delete(path)
        return true, nil
      end,
    })
    actions.delete.rhs()
    restore_trash()

    eq(fn.filereadable(victim), 0, "the delete key removes the file")
    -- Regression: the keymap used to call `delete_fn({})` and pass no config at
    -- all, so it kept unlinking permanently after the default flipped to
    -- "trash" — the documented safety net did not apply to the default key,
    -- and an `on_before_delete` hook never ran either.
    ok(trashed, "the delete key honours delete.mode = 'trash'")

    -- The same for the veto hook: it runs, and `false` stops the deletion.
    local hook_ran = false
    config.setup({
      delete = {
        mode = "permanent",
        on_before_delete = function()
          hook_ran = true
          return false
        end,
      },
    })
    actions = by_name(keymaps.setup(config.get()))
    local second = dir .. "hooked.txt"
    H.write_file(second, "bye")
    H.edit(second)
    actions.delete.rhs()
    ok(hook_ran, "the delete key consults delete.on_before_delete")
    eq(fn.filereadable(second), 1, "…and a vetoing hook keeps the file")

    -- The forced form is the `!` as a key: it deletes a modified buffer's file
    -- where the plain key refuses.
    config.setup({ delete = { mode = "permanent" } })
    actions = by_name(keymaps.setup(config.get()))
    local dirty = dir .. "dirty.txt"
    H.write_file(dirty, "saved")
    H.edit(dirty)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
    local refused = H.notifications(function()
      actions.delete.rhs()
    end)
    ok(H.notified(refused, "unsaved changes"), "the plain delete key refuses a modified buffer")
    eq(fn.filereadable(dirty), 1, "…and the file survives")
    actions.delete_force.rhs()
    eq(fn.filereadable(dirty), 0, "the delete_force key deletes it anyway")
  end

  -- ── the filetree.nvim cascade seam ───────────────────────────────────────
  -- The interactive delete keys are the common path, so they must ask the
  -- same cascade-delete-assets question `:File delete` asks.
  do
    local cfg = config.setup({ delete = { mode = "permanent" } })
    local actions = by_name(keymaps.setup(cfg))
    local dir = H.tmpdir()
    local victim = dir .. "linking.md"
    local asset = dir .. "assets/shot.png"
    H.write_file(victim, "# doc\n![shot](assets/shot.png)")
    H.write_file(asset, "png")
    H.edit(victim)

    local restore_refs = H.stub("filetree.refs", {
      outgoing_assets_mode = function()
        return "auto"
      end,
      outgoing_assets = function(_path, _opts, cb)
        cb({ { resolved = asset, is_asset = true, still_referenced = false } })
      end,
    })
    actions.delete.rhs()
    restore_refs()

    eq(fn.filereadable(victim), 0, "the delete key deleted the file")
    eq(fn.filereadable(asset), 0, "…and cascade-deleted the orphaned asset it linked to")
  end

  config.setup({})
end
