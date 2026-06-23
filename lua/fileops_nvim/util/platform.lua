---@module 'fileops_nvim.util.platform'
---Cross-platform helpers. All file I/O goes through libuv to avoid shell injection.
local M = {}

---@return boolean
function M.is_windows()
  return vim.fn.has("win32") == 1
end

---Delete a file from disk using libuv (no shell, cross-platform, no injection risk).
---@param path string Absolute path to file.
---@return boolean ok
---@return string|nil err
function M.delete_file(path)
  local uv = vim.uv or vim.loop
  local ok, err = uv.fs_unlink(path)
  if not ok then
    return false, err or "fs_unlink failed"
  end
  return true, nil
end

---Copy a file from src to dst using libuv (no shell).
---@param src string
---@param dst string
---@return boolean ok
---@return string|nil err
function M.copy_file(src, dst)
  local uv = vim.uv or vim.loop

  local fd_r, err_r = uv.fs_open(src, "r", 0)
  if not fd_r then
    return false, "cannot open source: " .. (err_r or "")
  end

  local stat, err_s = uv.fs_fstat(fd_r)
  if not stat then
    uv.fs_close(fd_r)
    return false, "cannot stat source: " .. (err_s or "")
  end

  local data, err_rd = uv.fs_read(fd_r, stat.size, 0)
  uv.fs_close(fd_r)
  if not data then
    return false, "cannot read source: " .. (err_rd or "")
  end

  local fd_w, err_w = uv.fs_open(dst, "w", 420) -- 0644
  if not fd_w then
    return false, "cannot create destination: " .. (err_w or "")
  end

  local _, err_wr = uv.fs_write(fd_w, data, 0)
  uv.fs_close(fd_w)
  if err_wr then
    return false, "cannot write destination: " .. err_wr
  end

  return true, nil
end

---Rename/move a file using libuv.
---@param old_path string
---@param new_path string
---@return boolean ok
---@return string|nil err
function M.rename_file(old_path, new_path)
  local uv = vim.uv or vim.loop
  local ok, err = uv.fs_rename(old_path, new_path)
  if not ok then
    return false, err or "fs_rename failed"
  end
  return true, nil
end

---Ensure a directory exists (create recursively if needed).
---@param dir string
---@return boolean ok
function M.mkdir_p(dir)
  if dir == "" then return false end
  return (vim.fn.mkdir(dir, "p") == 1) or (vim.fn.isdirectory(dir) == 1)
end

return M
