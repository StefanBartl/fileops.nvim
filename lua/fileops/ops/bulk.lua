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
          -- `:p` appends a separator when the path names an existing
          -- directory, which left the destination with an empty tail (a
          -- preview line `a.txt → ` and a key that no longer matched the
          -- name). The destination is a name in `dir`, so strip it again.
          local new = fn.fnamemodify(base .. new_name, ":p")
          if new:match("[\\/]$") and not new_name:match("[\\/]$") then
            new = new:sub(1, -2)
          end
          acc[#acc + 1] = {
            old = fn.fnamemodify(full, ":p"),
            new = new,
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

---@alias FileOps.BulkTargetStatus
---| "free"       # nothing is there once the batch has moved its own files away
---| "exists"     # a file outside the batch is there: overwritten only on request
---| "directory"  # a directory is there: never overwritten
---| "modified"   # a file outside the batch is there, open with unsaved changes: never overwritten

---@class FileOps.BulkRenameAnalysis
---@field case_insensitive boolean  Whether the directory folds case (probed on disk).
---@field duplicates { new: string, olds: string[] }[]  Destinations two or more items rename onto.
---@field status FileOps.BulkTargetStatus[]  Per plan index.
---@field target_buf table<integer, integer>  Per plan index: a loaded buffer on an "exists" destination.

---@internal
---Whether the directory holding `path` (an existing file) folds case.
---
---Asked of the filesystem rather than the platform: a case-sensitive volume
---on macOS or Windows exists, and so does a case-insensitive one on Linux.
---The question is whether the same name with every letter's case swapped
---reaches the same file. Only when the name has no letters (or the
---filesystem reports no inode) does the platform default decide.
---@param path string
---@return boolean
local function probe_case_insensitive(path)
  local p = vim.fs.normalize(path)
  local dir, tail = p:match("^(.*)/([^/]+)$")
  if dir and tail then
    local swapped = tail:gsub("%a", function(c)
      local up = c:upper()
      return up == c and c:lower() or up
    end)
    local a = uv.fs_stat(p)
    if swapped ~= tail and a and (a.ino or 0) ~= 0 then
      local b = uv.fs_stat(dir .. "/" .. swapped)
      if not b then
        return false
      end
      return b.ino == a.ino and b.dev == a.dev
    end
  end
  return fn.has("win32") == 1 or fn.has("mac") == 1
end

---@internal
---The comparison key for one batch: `comparable`, folded on a filesystem
---that folds case. There `a_1.txt` and `A_1.txt` are one file, so a
---case-only rename is not a rename onto an existing file, and two sources
---whose new names differ only in case land on the same file.
---@param ci boolean
---@return fun(p: string): string
local function keyer(ci)
  return function(p)
    local k = comparable(p)
    return ci and fn.tolower(k) or k
  end
end

---@internal
---Every loaded buffer whose name has the key `k`.
---@param key fun(p: string): string
---@param k string
---@return integer[]
local function buffers_at(key, k)
  local out = {}
  for _, b in ipairs(api.nvim_list_bufs()) do
    local name = api.nvim_buf_get_name(b)
    if name ~= "" and key(name) == k then
      out[#out + 1] = b
    end
  end
  return out
end

---Look at a plan against the state the disk will be in *after* the batch,
---before anything is renamed:
---
---  * A destination that is itself a source of this batch is not an obstacle:
---    that file is moved away first (`execute` orders the renames). Only a
---    file outside the batch counts as "exists".
---  * Two items renaming onto one destination are `duplicates`: running both
---    would make one batch member overwrite another.
---  * A directory at the destination is never overwritable, and neither is a
---    file open in a buffer with unsaved changes.
---@param plan FileOps.BulkRenamePlanItem[]
---@return FileOps.BulkRenameAnalysis
function M.analyze(plan)
  local ci = #plan > 0 and probe_case_insensitive(plan[1].old) or false
  local key = keyer(ci)
  local sources = {}
  for _, item in ipairs(plan) do
    sources[key(item.old)] = true
  end

  local status, target_buf = {}, {}
  local by_target, target_order = {}, {}
  for i, item in ipairs(plan) do
    local kn = key(item.new)
    if not by_target[kn] then
      by_target[kn] = {}
      target_order[#target_order + 1] = kn
    end
    table.insert(by_target[kn], i)

    local st = uv.fs_stat(item.new)
    if not st or sources[kn] then
      status[i] = "free"
    elseif st.type == "directory" then
      status[i] = "directory"
    else
      local b = buffers_at(key, kn)[1]
      if b and vim.bo[b].modified then
        status[i] = "modified"
      else
        status[i] = "exists"
        target_buf[i] = b
      end
    end
  end

  local duplicates = {}
  for _, kn in ipairs(target_order) do
    local idx = by_target[kn]
    if #idx > 1 then
      local olds = {}
      for _, i in ipairs(idx) do
        olds[#olds + 1] = plan[i].old
      end
      duplicates[#duplicates + 1] = { new = plan[idx[1]].new, olds = olds }
    end
  end

  return {
    case_insensitive = ci,
    duplicates = duplicates,
    status = status,
    target_buf = target_buf,
  }
end

---The part of a plan one dialog answer runs, and the part it holds back.
---
---`mode = "overwrite"` marks the items whose destination `analyze` found
---existing with `overwrite = true` -- those and only those: a destination
---that was free at the preview and is taken by the time the dialog is
---answered is refused, not overwritten. `mode = "skip"` holds them back.
---Directories and destinations open with unsaved changes are held back in
---both modes. Holding an item back keeps its *source* in place, so an item
---whose destination is that source is held back as well: it would otherwise
---overwrite a file of the batch that never moved.
---@param plan FileOps.BulkRenamePlanItem[]
---@param analysis FileOps.BulkRenameAnalysis
---@param mode "skip"|"overwrite"
---@return (FileOps.BulkRenamePlanItem|{ overwrite?: boolean })[] run
---@return { item: FileOps.BulkRenamePlanItem, reason: string }[] held
function M.select(plan, analysis, mode)
  local key = keyer(analysis.case_insensitive)
  local reason = {}
  for i in ipairs(plan) do
    local s = analysis.status[i]
    if s == "directory" then
      reason[i] = "the destination is a directory"
    elseif s == "modified" then
      reason[i] = "the destination is open with unsaved changes"
    elseif s == "exists" and mode ~= "overwrite" then
      reason[i] = "the destination exists already"
    end
  end

  local by_old = {}
  for i, item in ipairs(plan) do
    by_old[key(item.old)] = i
  end
  local changed = true
  while changed do
    changed = false
    for i, item in ipairs(plan) do
      local j = by_old[key(item.new)]
      if not reason[i] and j and j ~= i and reason[j] then
        reason[i] = ("the destination stays, it is not renamed (%s)"):format(reason[j])
        changed = true
      end
    end
  end

  local run, held = {}, {}
  for i, item in ipairs(plan) do
    if reason[i] then
      held[#held + 1] = { item = item, reason = reason[i] }
    else
      run[#run + 1] = {
        old = item.old,
        new = item.new,
        overwrite = (mode == "overwrite" and analysis.status[i] == "exists") or nil,
      }
    end
  end
  return run, held
end

---@internal
---A name next to `old` that nothing has, to park a file on while a cycle
---(`a -> b`, `b -> a`) is resolved.
---@param old string
---@return string
local function temp_name(old)
  local dir = fn.fnamemodify(old, ":h")
  local sep = old:find("\\", 1, true) and "\\" or "/"
  local tail = fn.fnamemodify(old, ":t")
  local n = 1
  while uv.fs_stat(("%s%s.fileops-swap-%d-%s"):format(dir, sep, n, tail)) do
    n = n + 1
  end
  return ("%s%s.fileops-swap-%d-%s"):format(dir, sep, n, tail)
end

---@class FileOps.BulkStep
---@field kind "item"|"park"|"unpark"
---@field item FileOps.BulkRenamePlanItem|{ overwrite?: boolean }
---@field tmp? string
---@field park? FileOps.BulkStep
---@field parked? boolean

---@internal
---The order the renames run in: an item whose destination is another item's
---source runs after that one (`a -> aa` after `aa -> aaa`), so no source is
---overwritten before it has moved. Destinations are unique (duplicates are
---refused before this), so the items form chains and cycles. A cycle is
---broken by parking one file on a temporary name: `a -> tmp`, the rest of the
---cycle, then `tmp -> b`. A case-only rename on a case-folding filesystem is
---its own source and depends on nothing.
---@param plan (FileOps.BulkRenamePlanItem|{ overwrite?: boolean })[]
---@param key fun(p: string): string
---@return FileOps.BulkStep[]
local function order(plan, key)
  local by_old = {}
  for i, item in ipairs(plan) do
    by_old[key(item.old)] = i
  end
  local next_of, pred = {}, {}
  for i, item in ipairs(plan) do
    local j = by_old[key(item.new)]
    if j and j ~= i then
      next_of[i] = j
      pred[j] = i
    end
  end

  local steps, done = {}, {}
  local function emit_back(i)
    while i and not done[i] do
      done[i] = true
      steps[#steps + 1] = { kind = "item", item = plan[i] }
      i = pred[i]
    end
  end
  for i in ipairs(plan) do
    if not next_of[i] then
      emit_back(i)
    end
  end
  for i, item in ipairs(plan) do
    if not done[i] then
      done[i] = true
      local park = { kind = "park", item = item, tmp = temp_name(item.old) }
      steps[#steps + 1] = park
      emit_back(pred[i])
      steps[#steps + 1] = { kind = "unpark", item = item, tmp = park.tmp, park = park }
    end
  end
  return steps
end

---Execute a rename plan: renames each file on disk via libuv, re-points any
---open buffer showing the old path to the new one (no reload — same as
---`file.move`), and fires the usual `notify_change` per file. Stops
---collecting new failures once one occurs but still attempts every item
---(a conflict on file 3 shouldn't block files 4..N).
---
---Safe against the batch itself: two items onto one destination refuse the
---whole plan; renames run dependents-last (see `order`), cycles via a
---temporary name; a destination still held by a batch file that did not move
---is never overwritten, `!` or not. Otherwise an existing destination is
---overwritten only for an item carrying `overwrite = true` (what the dialog
---announced) or with `opts.bang`; never a directory, never a file open with
---unsaved changes. The buffer of an overwritten file is closed, with a note.
---@param plan (FileOps.BulkRenamePlanItem|{ overwrite?: boolean })[]
---@param opts? { bang?: boolean, refresh_explorers?: boolean }
---@return integer renamed  How many files were actually renamed.
---@return string|nil err   First error encountered, if any.
---@return string[] notes   What the user should know that is not a failure.
function M.execute(plan, opts)
  opts = opts or {}
  local renamed = 0
  local first_err = nil
  local notes = {}
  if #plan == 0 then
    return 0, nil, notes
  end

  local analysis = M.analyze(plan)
  if #analysis.duplicates > 0 then
    local d = analysis.duplicates[1]
    local tails = {}
    for _, o in ipairs(d.olds) do
      tails[#tails + 1] = fn.fnamemodify(o, ":t")
    end
    return 0,
      ("%s would all be renamed to %s; nothing renamed"):format(table.concat(tails, ", "), d.new),
      notes
  end
  local key = keyer(analysis.case_insensitive)

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
    local k = name ~= "" and key(name) or false
    buf_key[b] = k
    return k
  end
  ---@param k string
  ---@return integer[]
  local function bufs_with(k)
    local out = {}
    for _, b in ipairs(api.nvim_list_bufs()) do
      if key_of(b) == k then
        out[#out + 1] = b
      end
    end
    return out
  end

  -- Sources that have not moved yet. A destination in here is a batch file
  -- that is still in place (its own rename failed or was refused), and is
  -- never overwritten.
  local pending = {}
  for _, item in ipairs(plan) do
    pending[key(item.old)] = true
  end

  ---@param from string
  ---@param to string
  ---@param overwrite boolean|nil
  ---@return boolean ok
  ---@return string|nil err
  local function move(from, to, overwrite)
    local kf, kt = key(from), key(to)
    local overwritten = {}
    if kt ~= kf then
      if pending[kt] then
        return false, "the destination is a file of this batch that was not renamed: " .. to
      end
      local st = uv.fs_stat(to)
      if st then
        if st.type == "directory" then
          return false, "the destination is a directory: " .. to
        end
        if not (overwrite or opts.bang) then
          return false, "destination already exists (use ! to overwrite): " .. to
        end
        overwritten = bufs_with(kt)
        for _, b in ipairs(overwritten) do
          if vim.bo[b].modified then
            return false, "the destination is open with unsaved changes: " .. to
          end
        end
      end
    end

    local ok, err = fsops.rename_file(from, to)
    if not ok then
      return false, ("rename failed: %s -> %s (%s)"):format(from, to, tostring(err))
    end
    pending[kf] = nil

    -- The overwritten file's buffer would now show content the file no longer
    -- has, and its `:w` would overwrite what was just renamed there. It has
    -- no unsaved changes (checked above). When the renamed file has a buffer
    -- of its own (a loaded one: renaming a buffer leaves an unloaded one
    -- behind under the old name, the alternate file), that one takes over the
    -- name (below) and the windows: the old one is closed. Otherwise it stays
    -- and is reloaded from disk. Either way, said so.
    local src_bufs = bufs_with(kf)
    local loaded_src = vim.tbl_filter(api.nvim_buf_is_loaded, src_bufs)
    local function drop(b)
      if pcall(api.nvim_buf_delete, b, { force = true }) then
        buf_key[b] = nil
        return true
      end
      return false
    end
    for _, b in ipairs(overwritten) do
      local loaded = api.nvim_buf_is_loaded(b)
      if #loaded_src > 0 or (not loaded and #src_bufs > 0) then
        for _, w in ipairs(fn.win_findbuf(b)) do
          pcall(api.nvim_win_set_buf, w, loaded_src[1])
        end
        local listed = vim.bo[b].buflisted
        if drop(b) then
          if loaded or listed then
            notes[#notes + 1] = ("closed the buffer of the overwritten %s"):format(to)
          end
        else
          notes[#notes + 1] = ("the buffer of the overwritten %s is still open"):format(to)
        end
      elseif loaded then
        if
          pcall(api.nvim_buf_call, b, function()
            vim.cmd("silent edit!")
          end)
        then
          notes[#notes + 1] = ("reloaded the buffer of the overwritten %s"):format(to)
        else
          notes[#notes + 1] = ("the buffer of the overwritten %s shows its old content"):format(to)
        end
        -- The name stays with this buffer: an unloaded, unlisted leftover
        -- under the old name has nothing to follow it there.
        for _, s in ipairs(src_bufs) do
          if not vim.bo[s].buflisted then
            drop(s)
          end
        end
      end
    end
    src_bufs = vim.tbl_filter(api.nvim_buf_is_valid, src_bufs)

    -- Canonicalized on both sides (see `comparable`): the plan's spelling
    -- of a path and the one `nvim_buf_get_name` answers with are routinely
    -- different strings for one file. Comparing the raw forms left the
    -- open buffer pointing at the name the rename had just vacated -- and
    -- the next `:w` wrote that file back into existence.
    for _, b in ipairs(src_bufs) do
      -- Only advance the memo when the rename actually took (e.g. not E95,
      -- another buffer already named `to`): on failure the buffer's real
      -- name -- and so its key -- didn't change, and advancing the memo
      -- anyway would hide it from a later item in this same batch that
      -- should also match it by its true, still-old name. Not silent: that
      -- buffer's `:w` would write the old name back.
      if pcall(api.nvim_buf_set_name, b, to) then
        buf_key[b] = kt
      else
        notes[#notes + 1] = ("buffer %d still shows %s: another buffer is named %s"):format(
          b,
          from,
          to
        )
      end
    end
    return true, nil
  end

  local function done(item)
    renamed = renamed + 1
    file.notify_change("rename", item.new, { refresh_explorers = opts.refresh_explorers })
  end

  for _, step in ipairs(order(plan, key)) do
    local item = step.item
    if step.kind == "item" then
      local ok, err = move(item.old, item.new, item.overwrite)
      if ok then
        done(item)
      else
        first_err = first_err or err
      end
    elseif step.kind == "park" then
      local ok, err = move(item.old, step.tmp, false)
      step.parked = ok
      if not ok then
        first_err = first_err or err
      end
    elseif step.park.parked then
      local ok, err = move(step.tmp, item.new, item.overwrite)
      if ok then
        done(item)
      else
        first_err = first_err or err
        if move(step.tmp, item.old, false) then
          notes[#notes + 1] = ("%s was put back"):format(item.old)
        else
          notes[#notes + 1] = ("%s is left at %s"):format(item.old, step.tmp)
        end
      end
    end
  end

  return renamed, first_err, notes
end

return M
