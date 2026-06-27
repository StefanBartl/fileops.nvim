---@module 'fileops_nvim.ops.file'
---File create / rename / duplicate / delete operations.
---All ops validate API handles and use libuv for I/O (no shell injection).
local M = {}

local notify   = require("fileops_nvim.util.notify")
local platform = require("fileops_nvim.util.platform")
local api, fn  = vim.api, vim.fn

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

-- ─── Create / open operations ─────────────────────────────────────────────────

---Ensure the parent directory of `path` exists (create recursively if needed).
---@param path string  Absolute path.
---@return boolean ok
function M.ensure_parent(path)
  local dir = fn.fnamemodify(path, ":p:h")
  if dir == "" then return false end
  if fn.isdirectory(dir) == 1 then return true end
  if not platform.mkdir_p(dir) then
    notify.error("cannot create directory: " .. dir)
    return false
  end
  return true
end

---Set the current buffer's file name (creates parent dirs if needed).
---Does NOT write the buffer to disk.
---@param path string  Destination path (may be relative or use ~).
---@param opts? { write?: boolean, bang?: boolean }
---@return boolean ok
function M.edit_new(path, opts)
  opts = opts or {}
  local abs = resolve_path(path)
  if not abs then notify.error("invalid path: " .. tostring(path)); return false end
  if not M.ensure_parent(abs) then return false end

  local esc = fn.fnameescape(abs)
  local cmd = "file " .. esc
  local ok, err = pcall(vim.cmd, cmd)
  if not ok then notify.error("file command failed: " .. tostring(err)); return false end

  if opts.write then
    local write_cmd = opts.bang and "write!" or "write"
    local wok, werr = pcall(vim.cmd, write_cmd)
    if not wok then notify.error("write failed: " .. tostring(werr)); return false end
  end

  notify.info("created " .. abs)
  return true
end

---Save a copy of the current buffer under a new path (like `:saveas`).
---Creates parent directories automatically.
---@param path string
---@param opts? { bang?: boolean }
---@return boolean ok
function M.save_as(path, opts)
  opts = opts or {}
  local abs = resolve_path(path)
  if not abs then notify.error("invalid path: " .. tostring(path)); return false end
  if not M.ensure_parent(abs) then return false end

  local esc = fn.fnameescape(abs)
  local cmd = opts.bang and "saveas! " or "saveas "
  local ok, err = pcall(vim.cmd, cmd .. esc)
  if not ok then notify.error("saveas failed: " .. tostring(err)); return false end

  notify.info("saved as " .. abs)
  return true
end

---Write a copy of the current buffer to `path` without changing buffer name.
---Creates parent directories automatically.
---@param path string
---@param opts? { bang?: boolean }
---@return boolean ok
function M.write_to(path, opts)
  opts = opts or {}
  local abs = resolve_path(path)
  if not abs then notify.error("invalid path: " .. tostring(path)); return false end
  if not M.ensure_parent(abs) then return false end

  local esc = fn.fnameescape(abs)
  local cmd = opts.bang and "write! " or "write "
  local ok, err = pcall(vim.cmd, cmd .. esc)
  if not ok then notify.error("write to failed: " .. tostring(err)); return false end

  notify.info("written to " .. abs)
  return true
end

---Ensure the parent directory of the current buffer's file exists.
---@return boolean ok
function M.mk_parent()
  local b = cur_buf()
  if not b then notify.error("no valid buffer"); return false end
  local p = buf_path(b)
  if not p then notify.error("current buffer has no file name"); return false end
  return M.ensure_parent(p)
end

-- ─── Rename ───────────────────────────────────────────────────────────────────

---Rename the file of the current buffer on disk and update the buffer name.
---@param new_path string  New path (may be relative or use ~).
---@param opts? { bang?: boolean }
---@return boolean ok
function M.rename(new_path, opts)
  opts = opts or {}
  local b = cur_buf()
  if not b then notify.error("no valid buffer"); return false end

  local old = buf_path(b)
  if not old then notify.error("current buffer has no file name"); return false end

  if fn.filereadable(old) ~= 1 then
    notify.error("source file does not exist or is not readable: " .. old)
    return false
  end

  local abs = resolve_path(new_path)
  if not abs then notify.error("invalid destination: " .. tostring(new_path)); return false end

  if fn.filereadable(abs) == 1 and not opts.bang then
    notify.error("destination already exists (use ! to overwrite): " .. abs)
    return false
  end

  if not M.ensure_parent(abs) then return false end

  -- Write unsaved changes before renaming so no data is lost
  if vim.bo[b].modified then
    local ok, err = pcall(vim.cmd, "write")
    if not ok then notify.error("save failed before rename: " .. tostring(err)); return false end
  end

  local ok, err = platform.rename_file(old, abs)
  if not ok then
    notify.error("rename failed: " .. tostring(err))
    return false
  end

  -- Update buffer to point at new path
  local esc = fn.fnameescape(abs)
  pcall(vim.cmd, "file " .. esc)
  pcall(vim.cmd, "edit")  -- reload from disk so signs/diagnostics reset

  notify.info(("renamed %s → %s"):format(fn.fnamemodify(old, ":t"), fn.fnamemodify(abs, ":t")))
  return true
end

-- ─── Duplicate ────────────────────────────────────────────────────────────────

---Copy the current buffer's file to `new_path` and open the duplicate.
---@param new_path string
---@param opts? { bang?: boolean, open?: boolean }
---@return boolean ok
function M.duplicate(new_path, opts)
  opts = opts or {}
  local open = opts.open ~= false  -- open by default

  local b = cur_buf()
  if not b then notify.error("no valid buffer"); return false end

  local src = buf_path(b)
  if not src then notify.error("current buffer has no file name"); return false end

  if fn.filereadable(src) ~= 1 then
    notify.error("source file does not exist: " .. src)
    return false
  end

  local abs = resolve_path(new_path)
  if not abs then notify.error("invalid destination: " .. tostring(new_path)); return false end

  if fn.filereadable(abs) == 1 and not opts.bang then
    notify.error("destination already exists (use ! to overwrite): " .. abs)
    return false
  end

  if not M.ensure_parent(abs) then return false end

  -- Flush unsaved content first
  if vim.bo[b].modified then
    local ok, err = pcall(vim.cmd, "write")
    if not ok then notify.error("save failed before duplicate: " .. tostring(err)); return false end
  end

  local ok, err = platform.copy_file(src, abs)
  if not ok then
    notify.error("copy failed: " .. tostring(err))
    return false
  end

  notify.info(("duplicated %s → %s"):format(fn.fnamemodify(src, ":t"), fn.fnamemodify(abs, ":t")))

  if open then
    local esc = fn.fnameescape(abs)
    pcall(vim.cmd, "edit " .. esc)
  end

  return true
end

-- ─── Delete ───────────────────────────────────────────────────────────────────

---Move every window currently displaying `bufnr` onto an alternate listed
---buffer, so that deleting `bufnr` does not spawn a throwaway empty buffer when
---other buffers still exist. Prefers the alternate file (`#`) for a natural
---"return to where I was" feel.
---@param bufnr integer
---@return boolean switched  True if an alternate was found and applied.
local function switch_windows_off(bufnr)
  local alt = nil

  local altfile = fn.bufnr("#")
  if altfile ~= -1 and altfile ~= bufnr
     and api.nvim_buf_is_valid(altfile)
     and vim.bo[altfile].buflisted then
    alt = altfile
  end

  if not alt then
    for _, b in ipairs(api.nvim_list_bufs()) do
      if b ~= bufnr and api.nvim_buf_is_valid(b)
         and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
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
---@param opts? { force?: boolean }
---@return boolean ok
function M.delete_current(opts)
  opts = opts or {}
  local b = cur_buf()
  if not b then notify.error("no valid buffer"); return false end

  local path = buf_path(b)
  if not path then notify.error("current buffer has no file name"); return false end

  if fn.filereadable(path) ~= 1 then
    notify.error("file does not exist or is not readable: " .. path)
    return false
  end

  -- Guard unsaved changes BEFORE touching the disk: abort unless forced, so a
  -- follow-up `:File! delete` still has a file to delete and can force-close.
  if vim.bo[b].modified and not opts.force then
    notify.error("buffer has unsaved changes — use :File! delete to delete and force-close")
    return false
  end

  local ok, err = platform.delete_file(path)
  if not ok then
    notify.error("delete failed: " .. tostring(err))
    return false
  end

  notify.info("deleted " .. fn.fnamemodify(path, ":t"))

  -- Close the buffer (force already implied by the guard above for modified ones).
  if api.nvim_buf_is_valid(b) then
    -- Steer any window off this buffer first, so closing it reuses an existing
    -- buffer instead of spawning an empty one when other buffers exist.
    switch_windows_off(b)
    pcall(api.nvim_buf_delete, b, { force = opts.force or false })
  end

  return true
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
function M.cd_here(opts)
  opts = opts or {}
  local b = cur_buf()
  if not b then notify.error("no valid buffer"); return false end

  local p = buf_path(b)
  if not p then notify.error("current buffer has no file name"); return false end

  local dir = fn.fnamemodify(p, ":p:h")
  if dir == "" or fn.isdirectory(dir) ~= 1 then
    notify.error("cannot resolve buffer directory")
    return false
  end

  local scope = opts.scope
  local cmd = (scope == "cd" or scope == "tcd") and scope or "lcd"
  local ok, err = pcall(vim.cmd, cmd .. " " .. fn.fnameescape(dir))
  if not ok then notify.error("cd failed: " .. tostring(err)); return false end

  if opts.refresh ~= false then
    refresh_explorers(dir)
  end

  notify.info("cwd → " .. dir)
  return true
end

return M
