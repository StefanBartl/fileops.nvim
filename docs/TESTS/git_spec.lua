-- docs/TESTS/git_spec.lua — util/git.lua: is_tracked/mv/rm against a real repo.

return function(H)
  local eq, ok = H.eq, H.ok
  local git = require("fileops_nvim.util.git")

  local dir = H.tmpdir()

  local function run(...)
    return vim.system({ ... }, { text = true, cwd = dir }):wait()
  end

  local init_res = run("git", "init", "-q")
  if init_res.code ~= 0 then
    -- No git available in this environment; skip rather than fail the suite.
    print("skip  git_spec.lua: git not usable (" .. tostring(init_res.stderr) .. ")")
    return
  end
  run("git", "config", "user.email", "test@example.com")
  run("git", "config", "user.name", "Test")

  local tracked_path = dir .. "tracked.txt"
  H.write_file(tracked_path, "hello")
  run("git", "add", "tracked.txt")
  run("git", "commit", "-q", "-m", "add tracked.txt")

  local untracked_path = dir .. "untracked.txt"
  H.write_file(untracked_path, "hello")

  -- is_tracked
  ok(git.is_tracked(tracked_path), "is_tracked: true for a committed file")
  ok(not git.is_tracked(untracked_path), "is_tracked: false for a never-added file")
  ok(not git.is_tracked(dir .. "does_not_exist.txt"), "is_tracked: false for a missing file")

  -- mv: renames on disk AND keeps the new name tracked
  local dest_path = dir .. "renamed.txt"
  local mv_ok, mv_err = git.mv(tracked_path, dest_path)
  ok(mv_ok, "mv succeeds: " .. tostring(mv_err))
  eq(vim.fn.filereadable(tracked_path), 0, "mv: old path no longer exists")
  eq(vim.fn.filereadable(dest_path), 1, "mv: new path exists")
  ok(git.is_tracked(dest_path), "mv: new path is still tracked")

  -- rm: removes from disk and the index
  local rm_ok, rm_err = git.rm(dest_path)
  ok(rm_ok, "rm succeeds: " .. tostring(rm_err))
  eq(vim.fn.filereadable(dest_path), 0, "rm: file removed from disk")
  local status = run("git", "status", "--porcelain")
  eq(status.stdout:match("renamed%.txt"), nil, "rm: no longer shows up in git status (fully removed)")
end
