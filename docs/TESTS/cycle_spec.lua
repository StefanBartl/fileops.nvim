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
end
