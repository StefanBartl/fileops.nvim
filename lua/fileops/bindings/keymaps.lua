---@module 'fileops.bindings.keymaps'
---Keymap registration for fileops. Called only from bindings.setup().
---Individual keys are gated by config.keymaps.lhs.* — set an entry to `false`
---to disable just that one mapping, or to a different string to remap it.
local M = {}

local file   = require("fileops.ops.file")
local cycle  = require("fileops.ops.cycle")
local notify = require("fileops.util.notify")
local config = require("fileops.config")

---Set a keymap. Uses lib.nvim's map helper if available (soft dependency),
---else falls back to plain vim.keymap.set.
---@param lhs string
---@param fn fun()
---@param desc string
local function map(lhs, fn, desc)
  local ok, lib_map = pcall(require, "lib.nvim.map")
  if ok and type(lib_map) == "function" then
    local wrapped = pcall(lib_map, "n", lhs, fn, { silent = true }, desc)
    if wrapped then return end
  end
  vim.keymap.set("n", lhs, fn, { silent = true, desc = desc })
end

---@return FileOps.KeymapLhs
local function lhs_cfg()
  local km = config.get().keymaps or {}
  return km.lhs or {}
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
    notify.report(cycle.navigate(dir, direction, copts, vim.v.count1))
  end
end

---Bind a single cycle key if its lhs is configured (not `false`/nil).
---@param key string        Key into FileOps.KeymapLhs.
---@param direction FileOps.Direction
---@param target FileOps.OpenTarget
---@param desc string
local function bind_cycle(key, direction, target, desc)
  local lhs = lhs_cfg()[key]
  if type(lhs) ~= "string" or lhs == "" then return end
  map(lhs, cycle_fn(direction, target), desc)
end

function M.attach_cycle()
  -- replace (navigate away from current buffer)
  bind_cycle("next_replace", "next", "replace", "[fileops] Next file (replace)")
  bind_cycle("prev_replace", "prev", "replace", "[fileops] Previous file (replace)")

  -- current (keep current buffer listed, just edit in-place)
  bind_cycle("next_current", "next", "current", "[fileops] Next file (stay listed)")
  bind_cycle("prev_current", "prev", "current", "[fileops] Previous file (stay listed)")

  -- background (add to buffer list, don't switch)
  bind_cycle("next_background", "next", "background", "[fileops] Next file (background)")
  bind_cycle("prev_background", "prev", "background", "[fileops] Previous file (background)")

  -- vsplit
  bind_cycle("next_vsplit", "next", "vsplit", "[fileops] Next file (vsplit)")
  bind_cycle("prev_vsplit", "prev", "vsplit", "[fileops] Previous file (vsplit)")
end

function M.attach_delete()
  local lhs = lhs_cfg().delete
  if type(lhs) ~= "string" or lhs == "" then return end
  map(lhs, function()
    notify.report(file.delete_current({}))
  end, "[fileops] Delete current file")
end

return M
