---@module 'fileops.integrations.filetree_assets'
---@brief Cascade-delete-assets — soft integration with filetree.nvim's refs engine.
---@description
--- fileops.nvim has no reference-tracking of its own — that is filetree.nvim's
--- domain (`filetree.refs`, docs in that repo's
--- `docs/ROADMAP/IDEAS/Cascade_Delete_Assets.md`). This module is the seam
--- `:File delete` uses to ask, IF filetree.nvim happens to be installed and
--- its own `refs.outgoing_assets` feature is turned on, whether the file
--- about to be deleted links to now-orphaned assets (screenshots etc. under
--- a configured root) and offer to cascade-delete those too.
---
--- A no-op in every other case: filetree.nvim absent, or present but its
--- feature left at the upstream default (off). This module adds no config of
--- its own — filetree.nvim's own `refs.outgoing_assets.enabled`/`on_delete`
--- switch is the only thing that turns any of this on, exactly as it already
--- governs the same check from filetree's own `d`/trash keymap.

local notify = require("fileops.util.notify")

local M = {}

---@internal
---filetree.nvim's refs engine, or nil when the plugin isn't installed, not
---yet loaded, or too old to have the `outgoing_assets` API this integration
---calls (checking `require` alone isn't enough: an older filetree.nvim
---resolves fine but has neither function, which would otherwise turn every
---`:File delete` into an uncaught error instead of the documented no-op).
---Deliberately checks only these two functions, not filetree.refs' full
---shape: this integration is a soft dependency on purpose (see the module
---header), and depending on any more of filetree.nvim's internals than the
---two entry points it actually calls would recreate the lockstep-versioning
---problem the presence check exists to avoid.
---Resolved at call time, not module load time, so this file never errors on
---a machine without filetree.nvim and always reflects whatever is currently
---on `package.loaded`.
---@return table|nil
local function refs()
  local ok, mod = pcall(require, "filetree.refs")
  if
    not ok
    or type(mod.outgoing_assets_mode) ~= "function"
    or type(mod.outgoing_assets) ~= "function"
  then
    return nil
  end
  return mod
end

---@internal
---Basenames of `assets`, for a notify line — full paths would be noise once
---there is more than one (same convention as filetree's own trash dialog).
---@param assets FiletreeAssetCandidate[]
---@return string[]
local function basenames(assets)
  local out = {}
  for _, c in ipairs(assets) do
    out[#out + 1] = vim.fn.fnamemodify(c.resolved, ":t")
  end
  return out
end

---Ask (or not, per filetree's own config) whether to cascade-delete assets
---`path` links to. Must be called BEFORE `path` itself is deleted — the file
---has to still exist for the scan to read its links (same
---prefetch-before-mutation discipline filetree's own refs engine uses).
---
---`cb` receives the list of assets to actually delete afterward: nil when
---there is nothing to do (no path, no filetree.nvim, the feature is off,
---nothing qualified, or the user declined), never an empty non-nil table.
---@param path string|nil
---@param cb fun(approved: FiletreeAssetCandidate[]|nil)
function M.confirm(path, cb)
  local engine = refs()
  if not path or not engine or engine.outgoing_assets_mode() == "off" then
    return cb(nil)
  end

  engine.outgoing_assets(path, nil, function(candidates)
    local deletable, kept = {}, {}
    for _, c in ipairs(candidates) do
      if c.is_asset then
        if c.still_referenced then
          kept[#kept + 1] = c
        else
          deletable[#deletable + 1] = c
        end
      end
    end

    -- An asset that qualifies but is still linked from some OTHER surviving
    -- file is never offered — but shown, not silently skipped, same
    -- reasoning as filetree's own trash dialog.
    if #kept > 0 then
      notify.info(
        string.format(
          "%d asset(s) still referenced elsewhere, left alone: %s",
          #kept,
          table.concat(basenames(kept), ", ")
        )
      )
    end

    if #deletable == 0 then
      return cb(nil)
    end

    if engine.outgoing_assets_mode() == "auto" then
      notify.info(
        string.format(
          "%d orphaned asset(s) will also be deleted: %s",
          #deletable,
          table.concat(basenames(deletable), ", ")
        )
      )
      return cb(deletable)
    end

    require("ui.kit").confirm({
      question = string.format(
        "[fileops] Also delete %d orphaned asset(s)? %s",
        #deletable,
        table.concat(basenames(deletable), ", ")
      ),
      choices = { "Delete assets", "Keep assets" },
      on_answer = function(choice)
        cb(choice == "Delete assets" and deletable or nil)
      end,
    })
  end)
end

---Delete every approved asset from disk, via the same trash/permanent +
---git-awareness policy as the primary file (`fileops.ops.file.delete_path`),
---reporting one summary line rather than one notify per file.
---@param assets FiletreeAssetCandidate[]
---@param opts table  The same opts `:File delete` built for the primary file.
function M.delete(assets, opts)
  local file = require("fileops.ops.file")
  local ok_count = 0
  for _, c in ipairs(assets) do
    local ok = file.delete_path(c.resolved, opts)
    if ok then
      ok_count = ok_count + 1
    end
  end
  notify.info(string.format("cascade-deleted %d/%d asset(s)", ok_count, #assets))
end

return M
