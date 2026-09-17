-- TESTS/health_menu_spec.lua — the two modules a user only ever reaches
-- indirectly: `health.lua` (`:checkhealth fileops`) and
-- `integrations/menu.lua` (context-menu entries a host composes into its own
-- menu).
--
-- `vim.health` is swapped for a recorder so the report can be read back
-- instead of rendered, and `ui.contextmenu` is stubbed with the same
-- self-gating shape ui.nvim implements — ui.nvim is neither on this suite's
-- runtimepath nor a CI checkout, and the point here is which entries fileops
-- contributes and what they run, not how ui.nvim draws them.

return function(H)
  local eq, ok = H.eq, H.ok
  local fn = vim.fn

  -- ── health ───────────────────────────────────────────────────────────────
  do
    local report = {}
    local function record(kind)
      return function(msg, advice)
        report[#report + 1] = { kind = kind, msg = tostring(msg), advice = advice }
      end
    end

    local real_health = vim.health
    vim.health = {
      start = record("start"),
      ok = record("ok"),
      warn = record("warn"),
      error = record("error"),
      info = record("info"),
    }
    -- composer's check module binds its `vim.health` functions once, at load
    -- time (it shims the pre-0.10 `report_*` spellings), so it has to be
    -- re-required while the recorder is installed — otherwise the tail of the
    -- report goes to the real `vim.health`, outside any `:checkhealth` run.
    local check_mod = "lib.nvim.bindings.usercmd.composer.check"
    local real_check = package.loaded[check_mod]
    package.loaded[check_mod] = nil

    local health_ok, health_err = pcall(function()
      require("fileops.health").check()
    end)
    vim.health = real_health
    package.loaded[check_mod] = real_check

    ok(health_ok, ":checkhealth fileops runs to completion: " .. tostring(health_err))

    local function find(kind, needle)
      for _, entry in ipairs(report) do
        if entry.kind == kind and entry.msg:find(needle, 1, true) then
          return entry
        end
      end
      return nil
    end

    eq(report[1].kind, "start", "the report opens a section")
    eq(report[1].msg, "fileops", "…named after the plugin")

    ok(find("ok", "Neovim >= 0.9"), "the Neovim version is reported")
    ok(find("ok", "libuv available"), "libuv is reported")
    ok(find("ok", "vim.ui.select"), "vim.ui.select is reported")
    ok(find("ok", "vim.fs.dir"), "vim.fs.dir is reported")
    ok(find("ok", "lib.nvim detected"), "lib.nvim is reported as present (it is a hard dependency)")
    ok(find("ok", "lib.nvim.notify in use"), "the notifier in use is reported")
    ok(find("ok", "plugin loaded"), "the loaded guard set by setup() is reported")

    -- Every optional dependency reports as `ok` whether or not it is
    -- installed — "not installed (not required)" is a finding, not a problem,
    -- and a warning there would train the user to ignore the report.
    for _, optional in ipairs({ "nvim-treesitter", "which-key", "gitsigns" }) do
      ok(
        find("ok", optional) ~= nil,
        optional .. " is reported at ok level either way, present or not"
      )
    end

    local errors = {}
    for _, entry in ipairs(report) do
      if entry.kind == "error" then
        errors[#errors + 1] = entry.msg
      end
    end
    eq(#errors, 0, "a complete install reports no errors: " .. table.concat(errors, " | "))

    -- git drives on_hold and git_aware, so its absence is a warning with
    -- advice rather than a silent "ok".
    local git_entry = find("ok", "git executable found") or find("warn", "git executable not found")
    ok(git_entry ~= nil, "the git executable is reported either way")
    if git_entry.kind == "warn" then
      ok(type(git_entry.advice) == "table", "…with advice when it is missing")
    end

    -- The last thing the check does is hand the :File verb to composer's own
    -- route check, which reports through the same vim.health calls.
    ok(#report > 10, "the composer route check contributes to the same report")
  end

  -- ── menu ─────────────────────────────────────────────────────────────────
  do
    -- Mirrors ui.contextmenu's own contract: `entry` gates itself and returns
    -- nil when unavailable, `group` drops the nils and separates surviving
    -- groups, `submenu` returns nil for an empty item list.
    local restore = H.stub("ui.contextmenu", {
      entry = function(available, label, cb)
        if not available then
          return nil
        end
        return { name = label, cmd = cb }
      end,
      group = function(out, ...)
        local compact = {}
        for i = 1, select("#", ...) do
          local item = select(i, ...)
          if item ~= nil then
            compact[#compact + 1] = item
          end
        end
        if #compact == 0 then
          return false
        end
        if #out > 0 then
          out[#out + 1] = { name = "separator" }
        end
        for _, item in ipairs(compact) do
          out[#out + 1] = item
        end
        return true
      end,
      submenu = function(label, items)
        if type(items) ~= "table" or #items == 0 then
          return nil
        end
        return { name = label, items = items }
      end,
    })

    package.loaded["fileops.integrations.menu"] = nil
    local menu = require("fileops.integrations.menu")

    local function labels(items)
      local out = {}
      for _, item in ipairs(items) do
        if item.name ~= "separator" then
          out[#out + 1] = item.name
        end
      end
      return out
    end

    local dir = H.tmpdir()
    H.write_file(dir .. "menu_target.txt", "x")
    local named_buf = H.edit(dir .. "menu_target.txt")

    local items = menu.items()
    local names = table.concat(labels(items), "|")
    for _, want in ipairs({ "Rename", "Duplicate", "Delete", "Copy path", "file info", "Next file" }) do
      ok(names:find(want, 1, true) ~= nil, "a named buffer offers " .. want .. ": " .. names)
    end
    eq(#labels(items), 7, "a named buffer offers every entry")
    ok(#items > #labels(items), "…with separators between the groups")

    -- On a buffer with no file there is nothing to rename, duplicate or
    -- delete; only the directory-navigation entries survive.
    vim.cmd("enew")
    local bare = labels(menu.items())
    eq(#bare, 2, "a nameless buffer keeps only the two navigation entries")
    ok(bare[1]:find("Next file in directory", 1, true) ~= nil, "…next: " .. bare[1])
    ok(bare[2]:find("Previous file in directory", 1, true) ~= nil, "…and previous: " .. bare[2])

    -- An explicit bufnr wins over the current buffer, so a host can build the
    -- menu for the buffer under the mouse.
    eq(#labels(menu.items(named_buf)), 7, "an explicit bufnr is used instead of the current buffer")

    -- Each entry runs the matching `:File` subcommand rather than
    -- re-deriving the op's options — that is what keeps the menu from
    -- drifting out of sync with the command's own config handling.
    local prompted = nil
    local restore_kit = H.stub("ui.kit", {
      input = function(o)
        prompted = o.title
      end,
    })
    H.edit(dir .. "menu_target.txt")
    for _, item in ipairs(menu.items()) do
      if item.name and item.name:find("Rename", 1, true) then
        item.cmd()
      end
    end
    restore_kit()
    eq(prompted, "File rename: ", "the rename entry runs :File rename, prompt and all")

    -- The submenu wrapper is the same items behind one fly-out label.
    local sub = menu.submenu()
    ok(sub ~= nil, "submenu() returns an entry for a buffer that has entries")
    eq(sub.name, "  File", "…with the default label")
    eq(#sub.items, #menu.items(), "…wrapping exactly the same items")
    eq(menu.submenu("Custom").name, "Custom", "…and the label is overridable")

    restore()
    package.loaded["fileops.integrations.menu"] = nil
  end
end
