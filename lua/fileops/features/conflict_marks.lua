---@module 'fileops.features.conflict_marks'
---Highlight Git conflict markers (<<<<<<< / ======= / >>>>>>>) per-window,
---cleared on window leave.

local fn = vim.fn
local autocmd = require("lib.nvim.bindings.autocmd")

local M = {}

---@internal
---@param name string
---@return integer
local function augroup(name)
  -- `autocmd.group(name, true)` drops this module's binding-table *records*
  -- along with its autocmds, so a re-run can't leave stale rows behind.
  return autocmd.group("fileops_conflict_marks_" .. name, true)
end

---Remove this module's matches from the current window, if it has any.
---
---Both ends of the lifecycle need it: `BufWinLeave` to tidy up, and
---`BufWinEnter` because re-editing the same file in the same window fires
---without a `BufWinLeave` in front of it, which used to strand the previous
---three matches on the window with their ids overwritten.
---@return nil
function M.clear_window_matches()
  local ids = vim.w._fileops_conflict_match_ids
  if type(ids) == "table" then
    for _, id in ipairs(ids) do
      pcall(fn.matchdelete, id)
    end
  end
  vim.w._fileops_conflict_match_ids = nil
end

---Register the BufWinEnter/BufWinLeave conflict-marker highlight autocmds if enabled.
---@param cfg FileOps.ConflictMarksConfig
---@return nil
function M.setup(cfg)
  cfg = cfg or {}
  if cfg.enable == false then
    return
  end

  autocmd.create("BufWinEnter", function()
    -- Clear first: re-editing the same file in the same window is a
    -- BufWinEnter with no BufWinLeave in front of it, so without this the
    -- three previous ids were overwritten while their matches stayed on the
    -- window -- unremovable, and one more set per `:e`. Invisible (same
    -- patterns, same groups) but unbounded.
    M.clear_window_matches()

    local id_a = fn.matchadd(cfg.hl_a or "DiffDelete", [[^<<<<<<< .\+$]])
    local id_b = fn.matchadd(cfg.hl_b or "DiffChange", [[^=======\s*$]])
    local id_c = fn.matchadd(cfg.hl_c or "DiffAdd", [[^>>>>>>> .\+$]])
    vim.w._fileops_conflict_match_ids = { id_a, id_b, id_c }
  end, {
    group = augroup("on"),
    desc = "[fileops] Highlight conflict markers",
  })

  autocmd.create("BufWinLeave", function()
    M.clear_window_matches()
  end, {
    group = augroup("off"),
    desc = "[fileops] Clear conflict marker highlights",
  })
end

return M
