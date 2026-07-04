-- docs/TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by docs/TESTS/run.lua.

local H = {}

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  if not v then
    error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Create a fresh, empty scratch directory under vim.fn.tempname().
---@return string dir  Absolute path with a trailing slash.
function H.tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return vim.fn.fnamemodify(dir, ":p")
end

--- Write `content` to `path`, creating parent directories.
---@param path string
---@param content string|nil
function H.write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local fd = assert(io.open(path, "w"))
  fd:write(content or "")
  fd:close()
end

--- Open `path` as the current buffer of the current window (scratch, no swap noise).
---@param path string
---@return integer bufnr
function H.edit(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

return H
