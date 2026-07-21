-- docs/TESTS/cycle_spec.lua — ops/cycle.lua directory listing + navigate.

return function(H)
  local eq, ok = H.eq, H.ok
  local cycle = require("fileops_nvim.ops.cycle")

  local dir = H.tmpdir()
  H.write_file(dir .. "a.lua", "-- a")
  H.write_file(dir .. "b.lua", "-- b")
  H.write_file(dir .. "c.lua", "-- c")
  H.write_file(dir .. ".hidden.lua", "-- hidden")

  ---@type FileOps.CycleConfig
  local opts = {
    open_target         = "current",
    keep_focus          = true,
    include_hidden      = false,
    wrap                = true,
    follow_symlinks     = true,
    root                = "buffer_dir",
    confirm_on_modified = false,
    case_insensitive    = true,
  }

  H.edit(dir .. "a.lua")

  -- get_root_dir resolves the buffer's directory
  local root, err = cycle.get_root_dir(opts)
  ok(root ~= nil, "get_root_dir resolves a directory: " .. tostring(err))
  ---@cast root string

  -- next: a -> b
  ok(cycle.navigate(root, "next", opts, 1), "navigate next from a.lua succeeds")
  eq(vim.fn.expand("%:t"), "b.lua", "next moves a.lua -> b.lua")

  -- next: b -> c
  ok(cycle.navigate(root, "next", opts, 1), "navigate next from b.lua succeeds")
  eq(vim.fn.expand("%:t"), "c.lua", "next moves b.lua -> c.lua")

  -- next wraps: c -> a (hidden file excluded from the 3-file cycle)
  ok(cycle.navigate(root, "next", opts, 1), "navigate next from c.lua succeeds")
  eq(vim.fn.expand("%:t"), "a.lua", "next wraps c.lua -> a.lua")

  -- prev: a -> c (wrap backward)
  ok(cycle.navigate(root, "prev", opts, 1), "navigate prev from a.lua succeeds")
  eq(vim.fn.expand("%:t"), "c.lua", "prev wraps a.lua -> c.lua")

  -- include_hidden = true picks up the dot-file
  local opts_hidden = vim.tbl_extend("force", opts, { include_hidden = true })
  H.edit(dir .. "c.lua")
  ok(cycle.navigate(root, "next", opts_hidden, 1), "navigate next with include_hidden succeeds")
  eq(vim.fn.expand("%:t"), ".hidden.lua", "hidden file included when include_hidden = true")

  -- jump_edge: first/last jump directly, regardless of current position
  H.edit(dir .. "b.lua")
  ok(cycle.jump_edge(root, "first", opts), "jump_edge first succeeds")
  eq(vim.fn.expand("%:t"), "a.lua", "jump_edge first lands on a.lua")

  ok(cycle.jump_edge(root, "last", opts), "jump_edge last succeeds")
  eq(vim.fn.expand("%:t"), "c.lua", "jump_edge last lands on c.lua")

  -- open_current: reopens the same file it started on (no navigation)
  H.edit(dir .. "b.lua")
  ok(cycle.open_current(opts), "open_current succeeds")
  eq(vim.fn.expand("%:t"), "b.lua", "open_current stays on b.lua")

  -- pattern: glob filter narrows the cycle set
  H.write_file(dir .. "notes.md", "-- notes")
  local opts_md = vim.tbl_extend("force", opts, { pattern = "*.md", wrap = false })
  H.edit(dir .. "notes.md")
  local root_md = cycle.get_root_dir(opts_md)
  ---@cast root_md string
  local nav_ok, nav_msg = cycle.navigate(root_md, "next", opts_md, 1)
  ok(not nav_ok, "pattern *.md: only match in the dir, no wrap, no next: " .. tostring(nav_msg))

  H.edit(dir .. "a.lua")
  local opts_lua = vim.tbl_extend("force", opts, { pattern = "*.lua" })
  ok(cycle.navigate(root, "next", opts_lua, 1), "pattern *.lua: navigate next succeeds")
  eq(vim.fn.expand("%:t"), "b.lua", "pattern *.lua: notes.md excluded from the cycle")
end
