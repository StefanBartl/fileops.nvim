-- docs/TESTS/platform_spec.lua — util/platform.lua libuv file ops.

return function(H)
  local eq, ok = H.eq, H.ok
  local platform = require("fileops_nvim.util.platform")

  local dir = H.tmpdir()

  -- mkdir_p
  local nested = dir .. "a/b/c"
  ok(platform.mkdir_p(nested), "mkdir_p creates nested dirs")
  eq(vim.fn.isdirectory(nested), 1, "nested dir exists on disk")

  -- copy_file
  local src = dir .. "src.txt"
  local dst = dir .. "dst.txt"
  H.write_file(src, "hello world")
  local copy_ok = platform.copy_file(src, dst)
  ok(copy_ok, "copy_file succeeds")
  eq(vim.fn.filereadable(dst), 1, "copy destination exists")

  -- rename_file
  local moved = dir .. "moved.txt"
  local rename_ok = platform.rename_file(dst, moved)
  ok(rename_ok, "rename_file succeeds")
  eq(vim.fn.filereadable(dst), 0, "old path gone after rename")
  eq(vim.fn.filereadable(moved), 1, "new path exists after rename")

  -- delete_file
  local delete_ok = platform.delete_file(moved)
  ok(delete_ok, "delete_file succeeds")
  eq(vim.fn.filereadable(moved), 0, "file gone after delete")

  -- delete_file on a missing path fails gracefully (no error thrown)
  local missing_ok, missing_err = platform.delete_file(dir .. "does-not-exist.txt")
  eq(missing_ok, false, "delete_file on missing path returns false")
  ok(missing_err ~= nil, "delete_file on missing path returns an error message")
end
