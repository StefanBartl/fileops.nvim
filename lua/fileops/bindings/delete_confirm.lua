---@module 'fileops.bindings.delete_confirm'
---@brief Shared "unsaved changes -> confirm, then delete" flow.
---@description
--- `:File delete` (bindings/usrcmds.lua) and the `delete`/`delete_force`
--- keymaps (bindings/keymaps.lua) both delete the current buffer's file and
--- both cascade filetree.nvim's orphaned-assets prompt afterwards -- they
--- used to each carry their own copy of that sequence, which is how they
--- drifted: the keymaps' copy kept deleting permanently after the default
--- moved to "trash", and never called `on_before_delete`. One shared
--- `M.run()` instead, so there is exactly one place to fix or extend it.
---
--- The confirm-on-unsaved-changes step exists so a modified buffer without
--- `!` doesn't just refuse and leave the user to retype the command with a
--- flag: `ui.kit.confirm` offers to force-delete right there.

local file = require("fileops.ops.file")
local notify = require("fileops.util.notify")
-- Soft dependency on filetree.nvim's refs engine (cascade-delete-assets):
-- a no-op (immediate cb(nil)) when filetree.nvim isn't installed or the
-- feature is off -- handled inside this module itself, same as every other
-- caller of it.
local filetree_assets = require("fileops.integrations.filetree_assets")

local M = {}

---Delete the current buffer's file, via `file.delete_current(dopts)`.
---When the buffer has unsaved changes and `dopts.force` isn't already
---true, asks first instead of letting `delete_current` just refuse --
---confirming retries with `force = true`; declining/leaving it unanswered
---deletes nothing, same as before this existed.
---@param dopts { force?: boolean, mode?: "trash"|"permanent", on_before_delete?: (fun(path: string): boolean|nil), refresh_explorers?: boolean, git_aware?: boolean, git_warn_only?: boolean, git_cmd?: string, retry?: table }
function M.run(dopts)
  ---@internal
  ---The delete + cascade-delete-assets sequence, given the final opts
  ---(force resolved, by `!`/`opts.force` or by the confirm below).
  ---@param final_opts table
  local function do_delete(final_opts)
    -- The cascade-delete-assets scan needs the file to still exist, so it
    -- runs BEFORE delete_current -- same prefetch-before-mutation ordering
    -- filetree.nvim's own refs engine uses.
    filetree_assets.confirm(file.current_path(), function(approved_assets)
      local ok = notify.report(file.delete_current(final_opts))
      -- Only cascade once the primary file is actually gone: delete_current
      -- can legitimately return false (unsaved buffer without force, an
      -- on_before_delete veto, a filesystem error), and the assets were
      -- only ever "orphaned" on the assumption that deletion went through.
      if ok and approved_assets then
        filetree_assets.delete(approved_assets, final_opts)
      end
    end)
  end

  if not dopts.force and vim.bo[vim.api.nvim_get_current_buf()].modified then
    require("ui.kit").confirm({
      question = "Buffer has unsaved changes — delete anyway (force-close)?",
      choices = { "Yes, delete", "Cancel" },
      on_answer = function(choice)
        if choice == "Yes, delete" then
          do_delete(vim.tbl_extend("force", dopts, { force = true }))
        end
      end,
    })
  else
    do_delete(dopts)
  end
end

return M
