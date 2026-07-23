---@module 'fileops.ops.file'
---File create / rename / duplicate / delete operations.
---All ops validate API handles and use libuv for I/O (no shell injection).
---
---Every public function returns `ok, msg`: `msg` is a human-readable string
---to relay regardless of outcome (success or failure), and the caller (the
---UI/binding layer) decides whether/how to notify it. This module never
---calls notify itself, so it can be reused from contexts that want silence
---or a different presentation.
local M = {}

local fsops    = require("lib.nvim.cross.fs.mutate")
local git      = require("fileops.util.git")
local api, fn  = vim.api, vim.fn
local uv       = vim.uv or vim.loop

-- ─── Internal helpers ─────────────────────────────────────────────────────────

---Return current buffer number, validated.
---@return integer|nil
local function cur_buf()
  local b = api.nvim_get_current_buf()
  return (b and api.nvim_buf_is_valid(b)) and b or nil
end

---Return the file path associated with `bufnr`, or nil.
---@param bufnr integer
---@return string|nil
local function buf_path(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then return nil end
  local p = api.nvim_buf_get_name(bufnr)
  return (type(p) == "string" and p ~= "") and p or nil
end

---Expand and validate a user-supplied path.
---@param raw string
---@return string|nil abs  Absolute path, or nil on error.
local function resolve_path(raw)
  if type(raw) ~= "string" or raw == "" then return nil end
  local abs = fn.fnamemodify(fn.expand(raw), ":p")
  return (abs ~= "") and abs or nil
end

-- ─── Explorer refresh / change events ──────────────────────────────────────────

---Reload known file-explorer plugins in place (no root change) so they pick
---up a file that was just created/renamed/moved/copied/deleted elsewhere in
---the tree. All calls are guarded; plugins that are not loaded are silently
---skipped.
local function reload_explorers()
  if package.loaded["nvim-tree"] then
    pcall(function() require("nvim-tree.api").tree.reload() end)
  end
  if package.loaded["neo-tree"] then
    pcall(function() require("neo-tree.sources.manager").refresh("filesystem") end)
  end
end

---Notify listeners that a file op changed the tree: always emits a
---`User FileopsChanged` autocmd (so any plugin/user config can react), and
---additionally reloads neo-tree/nvim-tree in place unless
---`opts.refresh_explorers == false`. Exported (not just local) so other ops
---modules (e.g. `ops.bulk`) can reuse it for the same behavior.
---@param action string  e.g. "touch", "rename", "move", "duplicate", "copy", "delete", "new", "mkdir".
---@param path string    Absolute path the op acted on (its resulting location for renames/moves).
---@param opts? { refresh_explorers?: boolean }
function M.notify_change(action, path, opts)
  opts = opts or {}
  pcall(api.nvim_exec_autocmds, "User", {
    pattern = "FileopsChanged",
    data = { action = action, path = path },
  })
  if opts.refresh_explorers ~= false then
    reload_explorers()
  end
end

-- ─── Create / open operations ─────────────────────────────────────────────────

---Ensure the parent directory of `path` exists (create recursively if needed).
---@param path string  Absolute path.
---@return boolean ok
---@return string|nil err
function M.ensure_parent(path)
  local dir = fn.fnamemodify(path, ":p:h")
  if dir == "" then return false, "cannot resolve parent directory" end
  if fn.isdirectory(dir) == 1 then return true, nil end
  if not fsops.mkdir_p(dir) then
    return false, "cannot create directory: " .. dir
  end
  return true, nil
end

---Set the current buffer's file name (creates parent dirs if needed).
---Does NOT write the buffer to disk.
---@param path string  Destination path (may be relative or use ~).
---@param opts? { write?: boolean, bang?: boolean, refresh_explorers?: boolean }
---@return boolean ok
---@return string|nil msg
function M.edit_new(path, opts)
  opts = opts or {}
  local abs = resolve_path(path)
  if not abs then return false, "invalid path: " .. tostring(path) end
  local pok, perr = M.ensure_parent(abs)
  if not pok then return false, perr end

  local esc = fn.fnameescape(abs)
  local cmd = "file " .. esc
  local ok, err = pcall(vim.cmd, cmd)
  if not ok then return false, "file command failed: " .. tostring(err) end

  if opts.write then
    local write_cmd = opts.bang and "write!" or "write"
    local wok, werr = pcall(vim.cmd, write_cmd)
    if not wok then return false, "write failed: " .. tostring(werr) end
  end

  M.notify_change("new", abs, opts)
  return true, "created " .. abs
end

---Save a copy of the current buffer under a new path (like `:saveas`).
---Creates parent directories automatically.
---@param path string
---@param opts? { bang?: boolean, refresh_explorers?: boolean }
---@return boolean ok
---@return string|nil msg
function M.save_as(path, opts)
  opts = opts or {}
  local abs = resolve_path(path)
  if not abs then return false, "invalid path: " .. tostring(path) end
  local pok, perr = M.ensure_parent(abs)
  if not pok then return false, perr end

  local esc = fn.fnameescape(abs)
  local cmd = opts.bang and "saveas! " or "saveas "
  local ok, err = pcall(vim.cmd, cmd .. esc)
  if not ok then return false, "saveas failed: " .. tostring(err) end

  M.notify_change("saveas", abs, opts)
  return true, "saved as " .. abs
end

---Write a copy of the current buffer to `path` without changing buffer name.
---Creates parent directories automatically.
---@param path string
---@param opts? { bang?: boolean, refresh_explorers?: boolean }
---@return boolean ok
---@return string|nil msg
function M.write_to(path, opts)
  opts = opts or {}
  local abs = resolve_path(path)
  if not abs then return false, "invalid path: " .. tostring(path) end
  local pok, perr = M.ensure_parent(abs)
  if not pok then return false, perr end

  local esc = fn.fnameescape(abs)
  local cmd = opts.bang and "write! " or "write "
  local ok, err = pcall(vim.cmd, cmd .. esc)
  if not ok then return false, "write to failed: " .. tostring(err) end

  M.notify_change("writeto", abs, opts)
  return true, "written to " .. abs
end

---Ensure the parent directory of the current buffer's file exists.
---@param opts? { refresh_explorers?: boolean }
---@return boolean ok
---@return string|nil msg
function M.mk_parent(opts)
  local b = cur_buf()
  if not b then return false, "no valid buffer" end
  local p = buf_path(b)
  if not p then return false, "current buffer has no file name" end
  local ok, msg = M.ensure_parent(p)
  if ok then M.notify_change("mkdir", p, opts) end
  return ok, msg
end

-- ─── Touch ────────────────────────────────────────────────────────────────────

---Create an empty file at `path` if it doesn't already exist (creates parent
---directories). Real `touch` semantics: an existing file is left untouched,
---never truncated. Does not require or open a buffer.
---@param path string  Destination path (may be relative or use ~).
---@param opts? { refresh_explorers?: boolean }
---@return boolean ok
---@return string|nil msg
function M.touch(path, opts)
  local abs = resolve_path(path)
  if not abs then return false, "invalid path: " .. tostring(path) end

  if fn.filereadable(abs) == 1 then
    return true, "already exists: " .. abs
  end

  local pok, perr = M.ensure_parent(abs)
  if not pok then return false, perr end

  local fd, err = uv.fs_open(abs, "wx", 420) -- O_CREAT|O_EXCL, mode 0644
  if not fd then
    -- Lost a create race to something else between the filereadable check
    -- and here; the file existing is the outcome we wanted either way.
    if type(err) == "string" and err:match("^EEXIST") then
      return true, "already exists: " .. abs
    end
    return false, "touch failed: " .. tostring(err)
  end
  uv.fs_close(fd)

  M.notify_change("touch", abs, opts)
  return true, "touched " .. abs
end

-- ─── Rename / Move ────────────────────────────────────────────────────────────

---Shared implementation for `M.rename` and `M.move`: rename the file of the
---current buffer on disk via `fsops.rename_file` (works across directories
---too, so this also covers "move") and re-point the buffer at the new path.
---The only behavioral difference between the two public entry points is
---whether the buffer is reloaded from disk afterwards (`opts.reload`):
---`rename` resets signs/diagnostics via a fresh `:edit`, `move` leaves the
---buffer's content/undo history untouched.
---@param new_path string  New path (may be relative or use ~).
---@param opts? { bang?: boolean, reload?: boolean, action?: string, git_aware?: boolean, git_warn_only?: boolean, git_cmd?: string, session_compat?: boolean }
---@return boolean ok
---@return string|nil msg
local function move_or_rename(new_path, opts)
  opts = opts or {}
  local reload = opts.reload ~= false
  local action = opts.action or "rename"

  local b = cur_buf()
  if not b then return false, "no valid buffer" end

  local old = buf_path(b)
  if not old then return false, "current buffer has no file name" end

  if fn.filereadable(old) ~= 1 then
    return false, "source file does not exist or is not readable: " .. old
  end

  local abs = resolve_path(new_path)
  if not abs then return false, "invalid destination: " .. tostring(new_path) end

  if fn.filereadable(abs) == 1 and not opts.bang then
    return false, "destination already exists (use ! to overwrite): " .. abs
  end

  local pok, perr = M.ensure_parent(abs)
  if not pok then return false, perr end

  -- Write unsaved changes before renaming so no data is lost
  if vim.bo[b].modified then
    local ok, err = pcall(vim.cmd, "write")
    if not ok then return false, "save failed before " .. action .. ": " .. tostring(err) end
  end

  local tracked = opts.git_aware and git.is_tracked(old, opts.git_cmd)
  local used_git = false

  if tracked and not opts.git_warn_only then
    local gok, gerr = git.mv(old, abs, opts.git_cmd)
    if not gok then
      return false, action .. " failed (git mv): " .. tostring(gerr)
    end
    used_git = true
  end

  if not used_git then
    local ok, err = fsops.rename_file(old, abs)
    if not ok then
      return false, action .. " failed: " .. tostring(err)
    end
  end

  -- Update buffer to point at new path
  local esc = fn.fnameescape(abs)
  pcall(vim.cmd, "file " .. esc)
  if reload then
    pcall(vim.cmd, "edit")  -- reload from disk so signs/diagnostics reset
  end

  M.notify_change(action, abs, opts)

  -- Keep an active `:mksession` session pointed at the new path instead of a
  -- now-stale one. `v:this_session` is set by Vim/Neovim itself whenever a
  -- session was loaded or saved; resaving it is a no-op when none is active.
  -- The session file must be passed explicitly: bare `:mksession!` ignores
  -- `v:this_session` and writes `./Session.vim` in the cwd instead.
  -- Third-party session managers (possession.nvim, sessions.nvim, ...) can
  -- react to the `User FileopsChanged` autocmd fired just above instead.
  if opts.session_compat and vim.v.this_session ~= "" then
    pcall(vim.cmd, "mksession! " .. fn.fnameescape(vim.v.this_session))
  end

  local suffix = tracked and (used_git and " (git mv)" or " (git-tracked)") or ""
  return true, (action .. "d %s → %s%s"):format(
    fn.fnamemodify(old, ":t"), fn.fnamemodify(abs, ":t"), suffix)
end

---Rename the file of the current buffer on disk and update the buffer name.
---Reloads the buffer from disk afterwards (resets signs/diagnostics).
---@param new_path string  New path (may be relative or use ~).
---@param opts? { bang?: boolean, refresh_explorers?: boolean, git_aware?: boolean, git_warn_only?: boolean, git_cmd?: string, session_compat?: boolean }
---@return boolean ok
---@return string|nil msg
function M.rename(new_path, opts)
  opts = opts or {}
  return move_or_rename(new_path, {
    bang = opts.bang, reload = true, action = "rename",
    refresh_explorers = opts.refresh_explorers,
    git_aware = opts.git_aware, git_warn_only = opts.git_warn_only, git_cmd = opts.git_cmd,
    session_compat = opts.session_compat,
  })
end

---Move the file of the current buffer on disk to a (possibly different)
---directory and update the buffer name. Unlike `M.rename`, the buffer is
---NOT reloaded from disk afterwards — its content and undo history stay
---exactly as they were, only the on-disk location and buffer name change.
---@param new_path string  New path (may be relative or use ~).
---@param opts? { bang?: boolean, refresh_explorers?: boolean, git_aware?: boolean, git_warn_only?: boolean, git_cmd?: string, session_compat?: boolean }
---@return boolean ok
---@return string|nil msg
function M.move(new_path, opts)
  opts = opts or {}
  return move_or_rename(new_path, {
    bang = opts.bang, reload = false, action = "move",
    refresh_explorers = opts.refresh_explorers,
    git_aware = opts.git_aware, git_warn_only = opts.git_warn_only, git_cmd = opts.git_cmd,
    session_compat = opts.session_compat,
  })
end

-- ─── Duplicate ────────────────────────────────────────────────────────────────

---Copy the current buffer's file to `new_path` and open the duplicate. No
---git command is run for tracked sources (there's no `git`-native "copy" —
---the new file just isn't tracked yet); `opts.git_aware` only adds a note
---to the returned message so the caller can warn if it wants to.
---@param new_path string
---@param opts? { bang?: boolean, open?: boolean, verb?: string, refresh_explorers?: boolean, git_aware?: boolean, git_cmd?: string }
---@return boolean ok
---@return string|nil msg
function M.duplicate(new_path, opts)
  opts = opts or {}
  local open = opts.open ~= false  -- open by default
  local verb = opts.verb or "duplicated"

  local b = cur_buf()
  if not b then return false, "no valid buffer" end

  local src = buf_path(b)
  if not src then return false, "current buffer has no file name" end

  if fn.filereadable(src) ~= 1 then
    return false, "source file does not exist: " .. src
  end

  local abs = resolve_path(new_path)
  if not abs then return false, "invalid destination: " .. tostring(new_path) end

  if fn.filereadable(abs) == 1 and not opts.bang then
    return false, "destination already exists (use ! to overwrite): " .. abs
  end

  local pok, perr = M.ensure_parent(abs)
  if not pok then return false, perr end

  -- Flush unsaved content first
  if vim.bo[b].modified then
    local ok, err = pcall(vim.cmd, "write")
    if not ok then return false, "save failed before duplicate: " .. tostring(err) end
  end

  local ok, err = fsops.copy_file(src, abs)
  if not ok then
    return false, "copy failed: " .. tostring(err)
  end

  if open then
    local esc = fn.fnameescape(abs)
    pcall(vim.cmd, "edit " .. esc)
  end

  M.notify_change(verb == "copied" and "copy" or "duplicate", abs, opts)
  local tracked = opts.git_aware and git.is_tracked(src, opts.git_cmd)
  local suffix = tracked and " (source is git-tracked)" or ""
  return true, ("%s %s → %s%s"):format(
    verb, fn.fnamemodify(src, ":t"), fn.fnamemodify(abs, ":t"), suffix)
end

-- ─── Copy ─────────────────────────────────────────────────────────────────────

---Copy the current buffer's file to `new_path` without opening the copy.
---Silent counterpart to `M.duplicate` — same validation and libuv copy, just
---`opts.open` forced off.
---@param new_path string
---@param opts? { bang?: boolean, refresh_explorers?: boolean, git_aware?: boolean, git_cmd?: string }
---@return boolean ok
---@return string|nil msg
function M.copy(new_path, opts)
  opts = opts or {}
  return M.duplicate(new_path, {
    bang = opts.bang, open = false, verb = "copied",
    refresh_explorers = opts.refresh_explorers,
    git_aware = opts.git_aware, git_cmd = opts.git_cmd,
  })
end

-- ─── Delete ───────────────────────────────────────────────────────────────────

---Move every window currently displaying `bufnr` onto an alternate listed
---buffer, so that deleting `bufnr` does not spawn a throwaway empty buffer when
---other buffers still exist. Prefers the alternate file (`#`) for a natural
---"return to where I was" feel. Candidates must have a real file name, so
---Neovim's original empty no-name scratch buffer is never picked as the alt.
---@param bufnr integer
---@return boolean switched  True if an alternate was found and applied.
local function switch_windows_off(bufnr)
  local alt = nil

  local altfile = fn.bufnr("#")
  if altfile ~= -1 and altfile ~= bufnr
     and api.nvim_buf_is_valid(altfile)
     and vim.bo[altfile].buflisted
     and buf_path(altfile) then
    alt = altfile
  end

  if not alt then
    for _, b in ipairs(api.nvim_list_bufs()) do
      if b ~= bufnr and api.nvim_buf_is_valid(b)
         and vim.bo[b].buflisted and vim.bo[b].buftype == ""
         and buf_path(b) then
        alt = b
        break
      end
    end
  end

  if not alt then return false end

  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == bufnr then
      pcall(api.nvim_win_set_buf, win, alt)
    end
  end
  return true
end

---Delete the file of the current buffer from disk and close the buffer.
---Git-aware deletion (`opts.git_aware` + not `opts.git_warn_only`) only
---applies when `opts.mode` is `"permanent"` (or unset) — trashing a file is
---a different operation than `git rm`, so trash mode always uses the trash
---path and just notes tracked-ness in the message.
---@param opts? { force?: boolean, mode?: "trash"|"permanent", on_before_delete?: fun(path: string): boolean|nil, refresh_explorers?: boolean, git_aware?: boolean, git_warn_only?: boolean, git_cmd?: string }
---@return boolean ok
---@return string|nil msg
function M.delete_current(opts)
  opts = opts or {}
  local b = cur_buf()
  if not b then return false, "no valid buffer" end

  local path = buf_path(b)
  if not path then return false, "current buffer has no file name" end

  if fn.filereadable(path) ~= 1 then
    return false, "file does not exist or is not readable: " .. path
  end

  -- Guard unsaved changes BEFORE touching the disk: abort unless forced, so a
  -- follow-up `:File! delete` still has a file to delete and can force-close.
  if vim.bo[b].modified and not opts.force then
    return false, "buffer has unsaved changes — use :File! delete to delete and force-close"
  end

  -- Give the hook a chance to veto (e.g. warn on git-tracked files) before
  -- anything touches the disk.
  if opts.on_before_delete and opts.on_before_delete(path) == false then
    return false, "deletion cancelled by on_before_delete hook: " .. path
  end

  local trash = opts.mode == "trash"
  local tracked = opts.git_aware and git.is_tracked(path, opts.git_cmd)
  local used_git = false
  local ok, err

  if trash then
    ok, err = require("lib.nvim.fs.trash").trash_blocking(path)
  elseif tracked and not opts.git_warn_only then
    ok, err = git.rm(path, opts.git_cmd)
    used_git = ok
    if not ok then
      -- Fall back to a plain delete rather than leaving the file untouched.
      ok, err = fsops.delete_file(path)
    end
  else
    ok, err = fsops.delete_file(path)
  end
  if not ok then
    return false, (trash and "trash failed: " or "delete failed: ") .. tostring(err)
  end

  -- Close the buffer (force already implied by the guard above for modified ones).
  if api.nvim_buf_is_valid(b) then
    -- Steer any window off this buffer first, so closing it reuses an existing
    -- buffer instead of spawning an empty one when other buffers exist.
    switch_windows_off(b)
    pcall(api.nvim_buf_delete, b, { force = opts.force or false })
  end

  M.notify_change("delete", path, opts)
  local suffix = tracked and (used_git and " (git rm)" or " (git-tracked)") or ""
  return true, (trash and "trashed " or "deleted ") .. fn.fnamemodify(path, ":t") .. suffix
end

-- ─── Info ─────────────────────────────────────────────────────────────────────

---Human-readable byte size (binary units, e.g. "12.3 KiB").
---@param bytes integer
---@return string
local function human_size(bytes)
  local units = { "B", "KiB", "MiB", "GiB", "TiB" }
  local size = bytes
  local i = 1
  while size >= 1024 and i < #units do
    size = size / 1024
    i = i + 1
  end
  if i == 1 then return ("%d %s"):format(size, units[i]) end
  return ("%.1f %s"):format(size, units[i])
end

---Return file size/mtime/permissions for the current buffer's file, via
---libuv `fs_stat` (cross-platform: works on Windows too, though the
---permission bits there are libuv's synthesized approximation).
---@return boolean ok
---@return string|nil msg
function M.info()
  local b = cur_buf()
  if not b then return false, "no valid buffer" end

  local p = buf_path(b)
  if not p then return false, "current buffer has no file name" end

  local st = uv.fs_stat(p)
  if not st then return false, "cannot stat file: " .. p end

  local mtime = st.mtime and st.mtime.sec
  local mtime_str = mtime and os.date("%Y-%m-%d %H:%M:%S", mtime) or "unknown"
  local perms = st.mode and ("%o"):format(st.mode % 512) or "unknown"

  local lines = {
    p,
    ("size: %s (%d bytes)"):format(human_size(st.size), st.size),
    ("modified: %s"):format(mtime_str),
    ("permissions: %s"):format(perms),
  }

  return true, table.concat(lines, "\n")
end

-- ─── Path ─────────────────────────────────────────────────────────────────────

---Copy the current buffer's file path to the unnamed + system clipboard
---registers, in the requested `mode`.
---@param mode "abs"|"rel"|"name"|"dir"|nil  Defaults to "abs".
---@return boolean ok
---@return string|nil msg
function M.copy_path(mode)
  local b = cur_buf()
  if not b then return false, "no valid buffer" end

  local p = buf_path(b)
  if not p then return false, "current buffer has no file name" end

  local out
  if mode == "rel" then
    out = fn.fnamemodify(p, ":.")
  elseif mode == "name" then
    out = fn.fnamemodify(p, ":t")
  elseif mode == "dir" then
    out = fn.fnamemodify(p, ":p:h")
  elseif mode == nil or mode == "abs" then
    out = fn.fnamemodify(p, ":p")
  else
    return false, "unknown path mode: " .. tostring(mode)
  end

  fn.setreg('"', out)
  fn.setreg("+", out)

  return true, "copied path (" .. (mode or "abs") .. "): " .. out
end

-- ─── Change directory ──────────────────────────────────────────────────────────

---Refresh known file-explorer plugins so they reflect `dir` as the new root.
---All calls are guarded; plugins that are not loaded are silently skipped.
---@param dir string  Absolute directory.
local function refresh_explorers(dir)
  -- nvim-tree: change root then reload to repaint.
  if package.loaded["nvim-tree"] then
    pcall(function()
      local nt = require("nvim-tree.api")
      nt.tree.change_root(dir)
      nt.tree.reload()
    end)
  end

  -- neo-tree: refresh the filesystem source (picks up the new cwd).
  if package.loaded["neo-tree"] then
    pcall(function()
      require("neo-tree.sources.manager").refresh("filesystem")
    end)
  end

  -- netrw: reload any visible netrw listing in place.
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(win) then
      local buf = api.nvim_win_get_buf(win)
      if api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "netrw" then
        pcall(api.nvim_win_call, win, function()
          pcall(vim.cmd, "edit " .. fn.fnameescape(dir))
        end)
      end
    end
  end
end

---Change the working directory to the directory of the current buffer's file,
---then refresh any open file explorer so it tracks the new root.
---@param opts? { scope?: "lcd"|"cd"|"tcd", refresh?: boolean }
---@return boolean ok
---@return string|nil msg
function M.cd_here(opts)
  opts = opts or {}
  local b = cur_buf()
  if not b then return false, "no valid buffer" end

  local p = buf_path(b)
  if not p then return false, "current buffer has no file name" end

  local dir = fn.fnamemodify(p, ":p:h")
  if dir == "" or fn.isdirectory(dir) ~= 1 then
    return false, "cannot resolve buffer directory"
  end

  local scope = opts.scope
  local cmd = (scope == "cd" or scope == "tcd") and scope or "lcd"
  local ok, err = pcall(vim.cmd, cmd .. " " .. fn.fnameescape(dir))
  if not ok then return false, "cd failed: " .. tostring(err) end

  if opts.refresh ~= false then
    refresh_explorers(dir)
  end

  return true, "cwd → " .. dir
end

return M
