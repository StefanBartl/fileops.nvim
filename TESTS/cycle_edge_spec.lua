-- TESTS/cycle_edge_spec.lua — ops/cycle.lua beyond the happy path already
-- covered by cycle_spec.lua: every `open_target`, the unsaved-changes confirm
-- dialog, the `root` variants, the failure returns, and the Windows path
-- comparison `navigate` depends on.
--
-- `ui.kit` (ui.nvim) is not on this suite's runtimepath — and is not checked
-- out by CI either, which only fetches lib.nvim — so the confirm dialog is
-- driven through a `package.loaded["ui.kit"]` stub. The module resolves it
-- lazily inside `open_path`, so the stub is what it finds.

return function(H)
  local eq, ok = H.eq, H.ok
  local cycle = require("fileops.ops.cycle")
  local fn = vim.fn

  ---@type FileOps.CycleConfig
  local base = {
    open_target = "current",
    keep_focus = true,
    include_hidden = false,
    wrap = true,
    follow_symlinks = true,
    root = "buffer_dir",
    confirm_on_modified = false,
    case_insensitive = true,
  }

  local function opts_with(extra)
    return vim.tbl_extend("force", base, extra or {})
  end

  local dir = H.tmpdir()
  H.write_file(dir .. "a.lua", "-- a")
  H.write_file(dir .. "b.lua", "-- b")
  H.write_file(dir .. "c.lua", "-- c")

  -- ── get_root_dir ─────────────────────────────────────────────────────────
  do
    H.edit(dir .. "a.lua")
    local bufdir = cycle.get_root_dir(opts_with({}))
    eq(bufdir, fn.fnamemodify(dir .. "a.lua", ":p:h"), "root=buffer_dir resolves the file's folder")

    local prev_cwd = fn.getcwd()
    local cwd_dir = H.tmpdir()
    vim.cmd("cd " .. fn.fnameescape(cwd_dir))
    local from_cwd = cycle.get_root_dir(opts_with({ root = "cwd" }))
    eq(
      vim.fs.normalize(tostring(from_cwd)),
      vim.fs.normalize(fn.getcwd()),
      "root=cwd resolves Neovim's cwd, not the buffer's folder"
    )
    local from_cwd_rec = cycle.get_root_dir(opts_with({ root = "cwd_recursive" }))
    eq(from_cwd_rec, from_cwd, "root=cwd_recursive resolves the same root as root=cwd")
    vim.cmd("cd " .. fn.fnameescape(prev_cwd))

    vim.cmd("enew")
    local none, err = cycle.get_root_dir(opts_with({}))
    eq(none, nil, "root=buffer_dir on a nameless buffer resolves nothing")
    eq(err, "current buffer has no file name", "…and says why")
  end

  -- ── open_path: every target ──────────────────────────────────────────────
  do
    H.edit(dir .. "a.lua")

    local eok, emsg = cycle.open_path("", opts_with({}))
    ok(not eok, "open_path refuses an empty path")
    eq(emsg, "empty path", "…and names it")

    local uok, umsg = cycle.open_path(dir .. "b.lua", opts_with({ open_target = "nonsense" }))
    ok(not uok, "open_path refuses an unknown open_target")
    ok(
      tostring(umsg):find("unknown open_target", 1, true) ~= nil,
      "…and names the bad target: " .. tostring(umsg)
    )

    -- current: edits in place, leaves the previous buffer listed.
    H.edit(dir .. "a.lua")
    local a_buf = vim.api.nvim_get_current_buf()
    ok(cycle.open_path(dir .. "b.lua", opts_with({ open_target = "current" })), "target=current")
    eq(fn.expand("%:t"), "b.lua", "current: the new file is showing")
    ok(vim.api.nvim_buf_is_valid(a_buf), "current: the previous buffer survives")

    -- replace: same window, but the buffer we came from is wiped, so cycling
    -- through a directory does not pile up buffers.
    H.edit(dir .. "a.lua")
    local doomed = vim.api.nvim_get_current_buf()
    ok(cycle.open_path(dir .. "c.lua", opts_with({ open_target = "replace" })), "target=replace")
    eq(fn.expand("%:t"), "c.lua", "replace: the new file is showing")
    ok(not vim.api.nvim_buf_is_valid(doomed), "replace: the previous buffer was wiped")

    -- split / vsplit, with and without keep_focus.
    vim.cmd("only")
    H.edit(dir .. "a.lua")
    local origin_win = vim.api.nvim_get_current_win()
    ok(cycle.open_path(dir .. "b.lua", opts_with({ open_target = "split" })), "target=split")
    eq(#vim.api.nvim_list_wins(), 2, "split: a second window was opened")
    -- keep_focus hands focus back on the next tick, so this only settles once
    -- the scheduled callback has run.
    vim.wait(200, function()
      return vim.api.nvim_get_current_win() == origin_win
    end)
    eq(vim.api.nvim_get_current_win(), origin_win, "split with keep_focus returns focus")

    vim.cmd("only")
    H.edit(dir .. "a.lua")
    local stay_win = vim.api.nvim_get_current_win()
    ok(
      cycle.open_path(dir .. "b.lua", opts_with({ open_target = "vsplit", keep_focus = false })),
      "target=vsplit"
    )
    eq(#vim.api.nvim_list_wins(), 2, "vsplit: a second window was opened")
    vim.wait(100)
    ok(
      vim.api.nvim_get_current_win() ~= stay_win,
      "vsplit without keep_focus leaves focus in the new window"
    )
    eq(fn.expand("%:t"), "b.lua", "vsplit: the new window shows the opened file")
    vim.cmd("only")

    -- tab
    local tabs_before = #vim.api.nvim_list_tabpages()
    H.edit(dir .. "a.lua")
    ok(cycle.open_path(dir .. "c.lua", opts_with({ open_target = "tab" })), "target=tab")
    eq(#vim.api.nvim_list_tabpages(), tabs_before + 1, "tab: a new tab page was opened")
    eq(fn.expand("%:t"), "c.lua", "tab: the new tab shows the opened file")
    vim.cmd("tabonly")
    vim.cmd("only")

    -- background: listed, loaded, but neither shown nor focused.
    H.edit(dir .. "a.lua")
    local before_win = vim.api.nvim_get_current_win()
    local bg_target = dir .. "b.lua"
    ok(cycle.open_path(bg_target, opts_with({ open_target = "background" })), "target=background")
    eq(fn.expand("%:t"), "a.lua", "background: the current window did not move")
    eq(vim.api.nvim_get_current_win(), before_win, "background: focus did not move")
    local bg_buf = fn.bufnr(fn.fnamemodify(bg_target, ":p"))
    ok(bg_buf ~= -1 and vim.bo[bg_buf].buflisted, "background: the file is on the buffer list")

    -- …and a background open of something unreadable reports the failure
    -- instead of pretending it worked.
    local mok, mmsg =
      cycle.open_path(dir .. "not_here.lua", opts_with({ open_target = "background" }))
    ok(not mok, "background: an unreadable file is a failure")
    ok(
      tostring(mmsg):find("background open failed", 1, true) ~= nil,
      "background: the failure is named: " .. tostring(mmsg)
    )
  end

  -- ── the unsaved-changes confirm dialog ───────────────────────────────────
  -- Only `replace` asks: it is the target that would discard the buffer.
  do
    local function with_answer(answer, body)
      local seen_question = nil
      local restore = H.stub("ui.kit", {
        confirm = function(o)
          seen_question = o.question
          if answer then
            o.on_answer(answer)
          end
        end,
      })
      body()
      restore()
      return seen_question
    end

    local cdir = H.tmpdir()
    H.write_file(cdir .. "one.txt", "one")
    H.write_file(cdir .. "two.txt", "two")

    -- Cancel: the buffer stays, unsaved content and all.
    H.edit(cdir .. "one.txt")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "edited" })
    local q = with_answer("Cancel", function()
      local cok, cmsg = cycle.open_path(
        cdir .. "two.txt",
        opts_with({ open_target = "replace", confirm_on_modified = true })
      )
      ok(cok, "the confirm path returns ok (the dialog owns the outcome from here)")
      eq(cmsg, nil, "…with no message to relay")
    end)
    ok(
      tostring(q):find("unsaved changes", 1, true) ~= nil,
      "the dialog names the problem: " .. tostring(q)
    )
    eq(fn.expand("%:t"), "one.txt", "Cancel: the modified buffer is still showing")
    ok(vim.bo.modified, "Cancel: the unsaved content is still unsaved")

    -- Discard: navigation happens, the file on disk keeps its old content.
    with_answer("Discard changes and open", function()
      cycle.open_path(
        cdir .. "two.txt",
        opts_with({ open_target = "replace", confirm_on_modified = true })
      )
    end)
    eq(fn.expand("%:t"), "two.txt", "Discard: navigation went through")
    eq(fn.readfile(cdir .. "one.txt")[1], "one", "Discard: the edit was never written")

    -- Save and open: navigation happens AND the edit lands on disk.
    H.edit(cdir .. "one.txt")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "saved edit" })
    with_answer("Save and open", function()
      cycle.open_path(
        cdir .. "two.txt",
        opts_with({ open_target = "replace", confirm_on_modified = true })
      )
    end)
    eq(fn.expand("%:t"), "two.txt", "Save and open: navigation went through")
    eq(fn.readfile(cdir .. "one.txt")[1], "saved edit", "Save and open: the edit was written first")

    -- An unmodified buffer never asks, even with confirm_on_modified on.
    local asked = false
    local restore = H.stub("ui.kit", {
      confirm = function()
        asked = true
      end,
    })
    H.edit(cdir .. "one.txt")
    cycle.open_path(
      cdir .. "two.txt",
      opts_with({ open_target = "replace", confirm_on_modified = true })
    )
    restore()
    ok(not asked, "an unmodified buffer is never asked about unsaved changes")
    eq(fn.expand("%:t"), "two.txt", "…and navigation happened directly")

    -- Nor does any non-replace target, which does not discard anything.
    asked = false
    restore = H.stub("ui.kit", {
      confirm = function()
        asked = true
      end,
    })
    H.edit(cdir .. "one.txt")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "dirty again" })
    cycle.open_path(
      cdir .. "two.txt",
      opts_with({ open_target = "current", confirm_on_modified = true })
    )
    restore()
    ok(not asked, "target=current does not ask: it discards nothing")
    vim.cmd("bwipeout! " .. fn.bufnr(fn.fnamemodify(cdir .. "one.txt", ":p")))
  end

  -- ── navigate / jump_edge failure returns ─────────────────────────────────
  do
    local empty = H.tmpdir()
    H.edit(dir .. "a.lua")
    local nok, nmsg = cycle.navigate(empty, "next", opts_with({}), 1)
    ok(not nok, "navigate in an empty directory fails")
    eq(nmsg, "no files in directory", "…and says so")

    local jok, jmsg = cycle.jump_edge(empty, "first", opts_with({}))
    ok(not jok, "jump_edge in an empty directory fails")
    eq(jmsg, "no files in directory", "…and says so")

    vim.cmd("enew")
    local bok, bmsg = cycle.navigate(dir, "next", opts_with({}), 1)
    ok(not bok, "navigate from a nameless buffer fails")
    eq(bmsg, "current buffer has no file name", "…and says so")

    local ook, omsg = cycle.open_current(opts_with({}))
    ok(not ook, "open_current on a nameless buffer fails")
    eq(omsg, "current buffer has no file name", "…and says so")
  end

  -- ── counts and wrap boundaries ───────────────────────────────────────────
  do
    H.edit(dir .. "a.lua")
    ok(cycle.navigate(dir, "next", opts_with({}), 2), "navigate accepts a count")
    eq(fn.expand("%:t"), "c.lua", "count=2 skips b.lua")

    -- A count that overshoots wraps around rather than clamping.
    H.edit(dir .. "a.lua")
    ok(cycle.navigate(dir, "next", opts_with({}), 4), "a count larger than the listing still moves")
    eq(fn.expand("%:t"), "b.lua", "count=4 over 3 files wraps to the second one")

    -- An invalid count is clamped to one step, not treated as zero.
    H.edit(dir .. "a.lua")
    ok(cycle.navigate(dir, "next", opts_with({}), 0), "count=0 is clamped")
    eq(fn.expand("%:t"), "b.lua", "count=0 behaves like count=1")
    H.edit(dir .. "a.lua")
    ok(cycle.navigate(dir, "next", opts_with({}), nil), "a nil count is clamped")
    eq(fn.expand("%:t"), "b.lua", "nil count behaves like count=1")

    -- wrap=false stops at both ends, and says which boundary it hit.
    H.edit(dir .. "c.lua")
    local wok, wmsg = cycle.navigate(dir, "next", opts_with({ wrap = false }), 1)
    ok(not wok, "wrap=false: no next past the last file")
    ok(
      tostring(wmsg):find("boundary reached", 1, true) ~= nil,
      "…named as a boundary: " .. tostring(wmsg)
    )
    eq(fn.expand("%:t"), "c.lua", "wrap=false: the buffer did not move")

    H.edit(dir .. "a.lua")
    local pok, pmsg = cycle.navigate(dir, "prev", opts_with({ wrap = false }), 1)
    ok(not pok, "wrap=false: no prev before the first file")
    ok(tostring(pmsg):find("boundary reached", 1, true) ~= nil, "…named as a boundary")
    eq(fn.expand("%:t"), "a.lua", "wrap=false: the buffer did not move")
  end

  -- ── a current file that the filter excludes ──────────────────────────────
  -- Navigating a `*.md` set from a `.lua` buffer must still work: the current
  -- file is spliced into the sorted listing so there is a position to step
  -- from, without appearing as a navigation target of its own.
  do
    local mixed = H.tmpdir()
    H.write_file(mixed .. "notes_a.md", "a")
    H.write_file(mixed .. "notes_b.md", "b")
    H.write_file(mixed .. "code.lua", "-- code")

    H.edit(mixed .. "code.lua")
    local mopts = opts_with({ pattern = "*.md" })
    ok(cycle.navigate(mixed, "next", mopts, 1), "navigate from a file outside the filtered set")
    eq(fn.expand("%:t"), "notes_a.md", "…lands on the first matching file after it")

    ok(cycle.navigate(mixed, "next", mopts, 1), "…and keeps walking the filtered set")
    eq(fn.expand("%:t"), "notes_b.md", "…to the second match")
  end

  -- ── path comparison: follow_symlinks = false ─────────────────────────────
  -- `list_files` joins every entry as `dir .. "/" .. name`, while
  -- `nvim_buf_get_name` spells the same file the way the platform does. With
  -- `follow_symlinks = true` (the default) `uv.fs_realpath` normalizes both
  -- sides, so they match. With it off, `canon` falls back to
  -- `fnamemodify(":p")` — which on Windows leaves that `/` exactly where it
  -- was, while the buffer name uses `\`.
  do
    local sdir = H.tmpdir()
    H.write_file(sdir .. "one.txt", "1")
    H.write_file(sdir .. "two.txt", "2")
    H.write_file(sdir .. "three.txt", "3")
    local sopts = opts_with({ follow_symlinks = false, pattern = "*.txt" })

    H.edit(sdir .. "one.txt")
    local root = cycle.get_root_dir(sopts)
    ---@cast root string
    ok(cycle.navigate(root, "next", sopts, 1), "navigate with follow_symlinks=false returns ok")

    if H.is_windows() then
      -- BUG: on Windows this does not move. `index_of` cannot find the current
      -- file (mixed separators), so `navigate` appends it to the listing as a
      -- fourth entry; `\` sorts after `/`, so the appended copy lands last and
      -- `next` wraps straight back onto the same file. `:File next`/`:File
      -- prev` are therefore a silent no-op for anyone who sets
      -- `cycle.follow_symlinks = false`. Pinned rather than fixed: the fix is
      -- to normalize separators in `canon`, which changes the path shape every
      -- caller of `list_files` sees.
      eq(
        fn.expand("%:t"),
        "one.txt",
        "BUG: follow_symlinks=false on Windows — next stays on the current file"
      )
    else
      eq(fn.expand("%:t"), "three.txt", "follow_symlinks=false still walks the listing on POSIX")
    end

    -- The default (realpath) path is unaffected, which is why this has stayed
    -- invisible: both sides are normalized before they are compared.
    local topts = opts_with({ follow_symlinks = true, pattern = "*.txt" })
    H.edit(sdir .. "one.txt")
    ok(cycle.navigate(root, "next", topts, 1), "follow_symlinks=true navigates")
    eq(fn.expand("%:t"), "three.txt", "follow_symlinks=true: alphabetical next after one.txt")
  end
end
