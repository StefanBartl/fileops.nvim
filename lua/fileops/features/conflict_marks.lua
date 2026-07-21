---@module 'fileops.features.conflict_marks'
---Highlight Git conflict markers (<<<<<<< / ======= / >>>>>>>) per-window,
---cleared on window leave.

local api, fn = vim.api, vim.fn
local autocmd = require("lib.nvim.autocmd")

local M = {}

---@param name string
---@return integer
local function augroup(name)
  -- Created directly via nvim_create_augroup(..., { clear = true }) rather
  -- than lib.nvim.autocmd.group(): that helper caches groups by name and
  -- skips the clear on subsequent calls, which would stack duplicate
  -- autocmds if setup() ever re-runs.
  return api.nvim_create_augroup("fileops_conflict_marks_" .. name, { clear = true })
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
    local id_a = fn.matchadd(cfg.hl_a or "DiffDelete", [[^<<<<<<< .\+$]])
    local id_b = fn.matchadd(cfg.hl_b or "DiffChange", [[^=======\s*$]])
    local id_c = fn.matchadd(cfg.hl_c or "DiffAdd", [[^>>>>>>> .\+$]])
    vim.w._fileops_conflict_match_ids = { id_a, id_b, id_c }
  end, {
    group = augroup("on"),
    desc = "[fileops] Highlight conflict markers",
  })

  autocmd.create("BufWinLeave", function()
    local ids = vim.w._fileops_conflict_match_ids
    if type(ids) == "table" then
      for _, id in ipairs(ids) do
        pcall(fn.matchdelete, id)
      end
    end
    vim.w._fileops_conflict_match_ids = nil
  end, {
    group = augroup("off"),
    desc = "[fileops] Clear conflict marker highlights",
  })
end

return M
