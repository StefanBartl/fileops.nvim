---@module 'fileops_nvim.keymaps'
---Keymap registration for fileops_nvim. Called only from setup().
local M = {}

local file   = require("fileops_nvim.ops.file")
local cycle  = require("fileops_nvim.ops.cycle")
local notify = require("fileops_nvim.util.notify")
local config = require("fileops_nvim.config")

---@param lhs string
---@param fn fun()
---@param desc string
local function map(lhs, fn, desc)
  vim.keymap.set("n", lhs, fn, { silent = true, desc = desc })
end

---@param direction FileOps.Direction
---@param target FileOps.OpenTarget
---@return fun()
local function cycle_fn(direction, target)
  return function()
    local cfg   = config.get()
    local copts = vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), { open_target = target })
    local dir, err = cycle.get_root_dir(copts)
    if not dir then
      notify.warn(err or "cannot determine root directory")
      return
    end
    cycle.navigate(dir, direction, copts, vim.v.count1)
  end
end

function M.attach_cycle()
  -- replace (navigate away from current buffer)
  map("<leader>nf",  cycle_fn("next", "replace"),    "[fileops] Next file (replace)")
  map("<leader>pf",  cycle_fn("prev", "replace"),    "[fileops] Previous file (replace)")

  -- current (keep current buffer listed, just edit in-place)
  map("<leader>nfn", cycle_fn("next", "current"),    "[fileops] Next file (stay listed)")
  map("<leader>pfn", cycle_fn("prev", "current"),    "[fileops] Previous file (stay listed)")

  -- background (add to buffer list, don't switch)
  map("<leader>nF",  cycle_fn("next", "background"), "[fileops] Next file (background)")
  map("<leader>pF",  cycle_fn("prev", "background"), "[fileops] Previous file (background)")

  -- vsplit
  map("<leader>NF",  cycle_fn("next", "vsplit"),     "[fileops] Next file (vsplit)")
  map("<leader>PF",  cycle_fn("prev", "vsplit"),     "[fileops] Previous file (vsplit)")
end

function M.attach_delete()
  map("<leader>dcf", function()
    file.delete_current({})
  end, "[fileops] Delete current file")
end

return M
