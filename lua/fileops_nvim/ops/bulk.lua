---@module 'fileops_nvim.ops.bulk'
---Batch-rename files in a directory via a Lua pattern/replacement pair.
---Split into `plan` (pure, side-effect free) and `execute` (does the actual
---renames) so the binding layer can preview a plan before confirming it.
local M = {}

local fsops = require("lib.nvim.cross.fs.mutate")
local file  = require("fileops_nvim.ops.file")
local api, fn = vim.api, vim.fn
local uv = vim.uv or vim.loop

---@class FileOps.BulkRenamePlanItem
---@field old string  Absolute current path.
---@field new string  Absolute path after applying the pattern/replacement.

---Build a rename plan for the regular files directly inside `dir` (no
---recursion) whose name changes under `name:gsub(pattern, replacement)`.
---Files the pattern doesn't match, or that gsub leaves unchanged, are
---excluded from the plan (nothing to do).
---@param dir string
---@param pattern string  Lua pattern (not a glob) matched against the file name only.
---@param replacement string
---@param opts? { include_hidden?: boolean }
---@return FileOps.BulkRenamePlanItem[] plan
---@return string|nil err
function M.plan(dir, pattern, replacement, opts)
  opts = opts or {}
  local acc = {}

  -- `dir` may or may not carry a trailing separator (H.tmpdir()/fnamemodify
  -- callers differ); normalize once so joins below never double it up.
  local base = dir:match("[\\/]$") and dir or (dir .. "/")

  local ok, iter = pcall(vim.fs.dir, dir)
  if not ok then return {}, "cannot read directory: " .. dir end

  for name, t in iter do
    local hidden = name:sub(1, 1) == "."
    if opts.include_hidden or not hidden then
      local full = base .. name
      local is_file = (t == "file")
      if not is_file and t == nil then
        local st = uv.fs_stat and uv.fs_stat(fn.fnamemodify(full, ":p"))
        is_file = (st and st.type == "file") or false
      end

      if is_file then
        local gok, new_name = pcall(string.gsub, name, pattern, replacement)
        if not gok then return {}, "invalid pattern: " .. tostring(new_name) end
        if new_name ~= name and new_name ~= "" then
          acc[#acc + 1] = {
            old = fn.fnamemodify(full, ":p"),
            new = fn.fnamemodify(base .. new_name, ":p"),
          }
        end
      end
    end
  end

  table.sort(acc, function(a, b) return a.old < b.old end)
  return acc, nil
end

---Execute a rename plan: renames each file on disk via libuv, re-points any
---open buffer showing the old path to the new one (no reload — same as
---`file.move`), and fires the usual `notify_change` per file. Stops
---collecting new failures once one occurs but still attempts every item
---(a conflict on file 3 shouldn't block files 4..N).
---@param plan FileOps.BulkRenamePlanItem[]
---@param opts? { bang?: boolean, refresh_explorers?: boolean }
---@return integer renamed  How many files were actually renamed.
---@return string|nil err   First error encountered, if any.
function M.execute(plan, opts)
  opts = opts or {}
  local renamed = 0
  local first_err = nil

  for _, item in ipairs(plan) do
    if fn.filereadable(item.new) == 1 and not opts.bang then
      first_err = first_err
        or ("destination already exists (use ! to overwrite): " .. item.new)
    else
      local ok, err = fsops.rename_file(item.old, item.new)
      if ok then
        renamed = renamed + 1
        local old_abs = fn.fnamemodify(item.old, ":p")
        for _, b in ipairs(api.nvim_list_bufs()) do
          if api.nvim_buf_is_valid(b) and fn.fnamemodify(api.nvim_buf_get_name(b), ":p") == old_abs then
            pcall(api.nvim_buf_set_name, b, item.new)
          end
        end
        file.notify_change("rename", item.new, opts)
      else
        first_err = first_err
          or (("rename failed: %s -> %s (%s)"):format(item.old, item.new, tostring(err)))
      end
    end
  end

  return renamed, first_err
end

return M
