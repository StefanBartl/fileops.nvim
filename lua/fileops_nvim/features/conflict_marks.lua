---@module 'fileops_nvim.features.conflict_marks'
---Highlight Git conflict markers (<<<<<<< / ======= / >>>>>>>) per-window,
---cleared on window leave.

local api, fn = vim.api, vim.fn

local M = {}

---@param name string
---@return integer
local function augroup(name)
  return api.nvim_create_augroup("fileops_nvim_conflict_marks_" .. name, { clear = true })
end

---Register the BufWinEnter/BufWinLeave conflict-marker highlight autocmds if enabled.
---@param cfg FileOps.ConflictMarksConfig
---@return nil
function M.setup(cfg)
  cfg = cfg or {}
  if cfg.enable == false then
    return
  end

  api.nvim_create_autocmd("BufWinEnter", {
    group = augroup("on"),
    callback = function()
      local id_a = fn.matchadd(cfg.hl_a or "DiffDelete", [[^<<<<<<< .\+$]])
      local id_b = fn.matchadd(cfg.hl_b or "DiffChange", [[^=======\s*$]])
      local id_c = fn.matchadd(cfg.hl_c or "DiffAdd", [[^>>>>>>> .\+$]])
      vim.w._fileops_nvim_conflict_match_ids = { id_a, id_b, id_c }
    end,
    desc = "[fileops] Highlight conflict markers",
  })

  api.nvim_create_autocmd("BufWinLeave", {
    group = augroup("off"),
    callback = function()
      local ids = vim.w._fileops_nvim_conflict_match_ids
      if type(ids) == "table" then
        for _, id in ipairs(ids) do
          pcall(fn.matchdelete, id)
        end
      end
      vim.w._fileops_nvim_conflict_match_ids = nil
    end,
    desc = "[fileops] Clear conflict marker highlights",
  })
end

return M
