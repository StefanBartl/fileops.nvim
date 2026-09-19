---@module 'fileops.ops.bulk'
---Batch-rename files in a directory via a Lua pattern/replacement pair.
---Split into `plan` (pure, side-effect free) and `execute` (does the actual
---renames) so the binding layer can preview a plan before confirming it.
local M = {}

local fsops = require("lib.nvim.cross.fs.mutate")
local file = require("fileops.ops.file")
local api, fn = vim.api, vim.fn
local uv = vim.uv or vim.loop

---@class FileOps.BulkRenamePlanItem
---@field old string  Absolute current path.
---@field new string  Absolute path after applying the pattern/replacement.

---@internal
---A path in the one spelling used for *comparing* two of them.
---
---`execute` looks an open buffer up by its path, so this is a key, and a key
---that changes with the spelling its caller happened to use is not one. Two
---things make two spellings of a single file differ:
---
---  1. Separators. `plan` joins with `/`, `nvim_buf_get_name` hands back `\`
---     on Windows, and `:p` leaves separators as it finds them.
---  2. Symlinks on the way to the file. Neovim resolves those when it names a
---     buffer on Unix (`fix_fname`), `:p` does not. On macOS
---     that is the everyday case rather than an exotic one: the whole temp
---     tree hangs off `/var`, a symlink to `/private/var`, so a plan rooted
---     there never matched the buffer Neovim had named `/private/var/…` --
---     the same file.
---
---Only the *directory* is resolved, not the full path: `execute` asks this
---question after the rename has already happened, when `item.old` no longer
---exists and `fs_realpath` would fail on it. The directory it lived in is
---still there, and it is the part symlinks are reached through anyway.
---
---Only comparisons go through this. The paths the plugin renames to, reports
---and hands to `nvim_buf_set_name` keep their platform spelling, so nothing a
---user sees changes.
---@param p string
---@return string
local function comparable(p)
  local abs = vim.fs.normalize(fn.fnamemodify(p, ":p"))
  local dir, tail = abs:match("^(.*)/([^/]*)$")
  if not dir or dir == "" then
    return abs
  end
  local real = uv.fs_realpath and uv.fs_realpath(dir)
  if type(real) ~= "string" or real == "" then
    return abs
  end
  return vim.fs.normalize(real) .. "/" .. tail
end

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

  -- `pcall(vim.fs.dir, dir)` never fails here -- `vim.fs.dir` builds a lazy
  -- iterator and only the first `next()` call would touch the filesystem, by
  -- which point it just yields nothing for a missing/unreadable directory.
  -- Check with `isdirectory` first so this `"cannot read directory"` return
  -- is reachable instead of dead code.
  if fn.isdirectory(dir) ~= 1 then
    return {}, "cannot read directory: " .. dir
  end

  for name, t in vim.fs.dir(dir) do
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
        if not gok then
          return {}, "invalid pattern: " .. tostring(new_name)
        end
        if new_name ~= name and new_name ~= "" then
          acc[#acc + 1] = {
            old = fn.fnamemodify(full, ":p"),
            new = fn.fnamemodify(base .. new_name, ":p"),
          }
        end
      end
    end
  end

  table.sort(acc, function(a, b)
    return a.old < b.old
  end)
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

  -- Every open buffer's canonical name, memoized per buffer rather than
  -- recomputed from scratch for every renamed item: `comparable()` does a
  -- real `uv.fs_realpath()` syscall, and a plain per-item, per-buffer
  -- re-derive is O(items x buffers) -- a bulk rename of 30 files with 40
  -- buffers open is up to 1200 blocking syscalls for what is, for all but
  -- the handful of buffers actually being renamed, the same answer every
  -- time. A buffer's key only changes when THIS loop renames it
  -- (`nvim_buf_set_name` below), so the memo is kept in sync there instead
  -- of invalidated wholesale -- correctness for a rename *chain* within one
  -- batch (a.txt->b.txt then b.txt->c.txt, with a buffer open on a.txt)
  -- depends on that: freezing the memo before the loop would leave a
  -- buffer's entry pointing at its pre-batch name and miss a later item
  -- that should also move it.
  local buf_key = {}
  ---@param b integer
  ---@return string|false key  `false` for an unnamed/invalid buffer
  local function key_of(b)
    local cached = buf_key[b]
    if cached ~= nil then
      return cached
    end
    local name = api.nvim_buf_is_valid(b) and api.nvim_buf_get_name(b) or ""
    local k = name ~= "" and comparable(name) or false
    buf_key[b] = k
    return k
  end

  for _, item in ipairs(plan) do
    if fn.filereadable(item.new) == 1 and not opts.bang then
      first_err = first_err or ("destination already exists (use ! to overwrite): " .. item.new)
    else
      local ok, err = fsops.rename_file(item.old, item.new)
      if ok then
        renamed = renamed + 1
        -- Canonicalized on both sides (see `comparable`): the plan's spelling
        -- of a path and the one `nvim_buf_get_name` answers with are routinely
        -- different strings for one file. Comparing the raw forms left the
        -- open buffer pointing at the name the rename had just vacated -- and
        -- the next `:w` wrote that file back into existence.
        local old_key = comparable(item.old)
        for _, b in ipairs(api.nvim_list_bufs()) do
          if key_of(b) == old_key then
            -- Only advance the memo when the rename actually took (e.g. not
            -- E95, another buffer already named item.new): on failure the
            -- buffer's real name -- and so its key -- didn't change, and
            -- advancing the memo anyway would hide it from a later item in
            -- this same batch that should also match it by its true,
            -- still-old name.
            local set_ok = pcall(api.nvim_buf_set_name, b, item.new)
            if set_ok then
              buf_key[b] = comparable(item.new)
            end
          end
        end
        file.notify_change("rename", item.new, { refresh_explorers = opts.refresh_explorers })
      else
        first_err = first_err
          or (("rename failed: %s -> %s (%s)"):format(item.old, item.new, tostring(err)))
      end
    end
  end

  return renamed, first_err
end

return M
