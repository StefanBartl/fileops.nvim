---@module 'fileops.util.git'
---Minimal git helpers for the `git_aware` feature. Argv-only (no shell), and
---every call runs with `cwd` set to the target file's own directory so it
---works regardless of Neovim's global cwd.
---
---Each blocking function (`is_tracked`/`mv`/`rm`) has an `_async` twin with
---the same argv/cwd contract, built on `vim.system`'s callback form instead
---of `:wait()` — for callers on a hot path (e.g. `features/on_hold.lua`'s
---CursorHold preview) where blocking the UI thread is the actual cost being
---avoided, not just a style preference.
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
    return vim
      .system({ git_cmd, "ls-files", "--error-unmatch", "--", name }, { text = true, cwd = dir })
      :wait()
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
  if not ok then
    return false, tostring(res)
  end
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
  if not ok then
    return false, tostring(res)
  end
  if res.code ~= 0 then
    return false, (res.stderr ~= "" and res.stderr) or "git rm failed"
  end
  return true, nil
end

-- ─── Async variants ─────────────────────────────────────────────────────────
-- Same argv/cwd contract as the blocking functions above, but built on
-- `vim.system`'s callback form instead of `:wait()`, so the caller never
-- blocks the UI thread on a slow filesystem (network shares, WSL interop) or
-- a large repo. `vim.system`'s callback runs off the main loop, so every `cb`
-- here is invoked via `vim.schedule` — required before touching any
-- `vim.api`/`vim.fn` call, and the only safe way for a caller to do the same.

---Async form of `M.is_tracked`.
---@param path string  Absolute path.
---@param cb fun(tracked: boolean)
---@param git_cmd? string  Defaults to "git".
---@return nil
function M.is_tracked_async(path, cb, git_cmd)
  git_cmd = git_cmd or "git"
  local dir = fn.fnamemodify(path, ":p:h")
  local name = fn.fnamemodify(path, ":t")
  local ok = pcall(function()
    vim.system(
      { git_cmd, "ls-files", "--error-unmatch", "--", name },
      { text = true, cwd = dir },
      function(res)
        vim.schedule(function()
          cb(res.code == 0)
        end)
      end
    )
  end)
  if not ok then
    vim.schedule(function()
      cb(false)
    end)
  end
end

---Async form of `M.mv`.
---@param old string  Absolute source path.
---@param new string  Absolute destination path.
---@param cb fun(ok: boolean, err: string|nil)
---@param git_cmd? string
---@return nil
function M.mv_async(old, new, cb, git_cmd)
  git_cmd = git_cmd or "git"
  local dir = fn.fnamemodify(old, ":p:h")
  local ok = pcall(function()
    vim.system({ git_cmd, "mv", "-f", "--", old, new }, { text = true, cwd = dir }, function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          cb(false, (res.stderr ~= "" and res.stderr) or "git mv failed")
        else
          cb(true, nil)
        end
      end)
    end)
  end)
  if not ok then
    vim.schedule(function()
      cb(false, "git mv failed to start")
    end)
  end
end

---Async form of `M.rm`.
---@param path string  Absolute path.
---@param cb fun(ok: boolean, err: string|nil)
---@param git_cmd? string
---@return nil
function M.rm_async(path, cb, git_cmd)
  git_cmd = git_cmd or "git"
  local dir = fn.fnamemodify(path, ":p:h")
  local ok = pcall(function()
    vim.system({ git_cmd, "rm", "-f", "--", path }, { text = true, cwd = dir }, function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          cb(false, (res.stderr ~= "" and res.stderr) or "git rm failed")
        else
          cb(true, nil)
        end
      end)
    end)
  end)
  if not ok then
    vim.schedule(function()
      cb(false, "git rm failed to start")
    end)
  end
end

return M
