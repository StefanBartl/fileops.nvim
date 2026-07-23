---@module 'fileops.util.git'
---Minimal, synchronous git helpers for the `git_aware` feature. Argv-only
---(no shell), and every call runs with `cwd` set to the target file's own
---directory so it works regardless of Neovim's global cwd.
local M = {}

local fn = vim.fn

---Whether `path` is tracked by git. `false` on any error (not a repo, git
---missing, etc.) — callers should treat "unknown" the same as "not tracked".
---@param path string  Absolute path.
---@param git_cmd? string  Defaults to "git".
---@return boolean tracked
function M.is_tracked(path, git_cmd)
  git_cmd = git_cmd or "git"
  local dir = fn.fnamemodify(path, ":p:h")
  local name = fn.fnamemodify(path, ":t")
  local ok, res = pcall(function()
    return vim.system({ git_cmd, "ls-files", "--error-unmatch", "--", name }, { text = true, cwd = dir }):wait()
  end)
  return ok and res.code == 0
end

---Rename/move a tracked file via `git mv -f`.
---@param old string  Absolute source path.
---@param new string  Absolute destination path.
---@param git_cmd? string
---@return boolean ok
---@return string|nil err
function M.mv(old, new, git_cmd)
  git_cmd = git_cmd or "git"
  local dir = fn.fnamemodify(old, ":p:h")
  local ok, res = pcall(function()
    return vim.system({ git_cmd, "mv", "-f", "--", old, new }, { text = true, cwd = dir }):wait()
  end)
  if not ok then return false, tostring(res) end
  if res.code ~= 0 then
    return false, (res.stderr ~= "" and res.stderr) or "git mv failed"
  end
  return true, nil
end

---Delete a tracked file via `git rm -f` (removes from the index and the
---working tree in one step).
---@param path string  Absolute path.
---@param git_cmd? string
---@return boolean ok
---@return string|nil err
function M.rm(path, git_cmd)
  git_cmd = git_cmd or "git"
  local dir = fn.fnamemodify(path, ":p:h")
  local ok, res = pcall(function()
    return vim.system({ git_cmd, "rm", "-f", "--", path }, { text = true, cwd = dir }):wait()
  end)
  if not ok then return false, tostring(res) end
  if res.code ~= 0 then
    return false, (res.stderr ~= "" and res.stderr) or "git rm failed"
  end
  return true, nil
end

return M
