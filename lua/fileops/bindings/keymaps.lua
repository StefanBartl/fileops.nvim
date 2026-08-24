---@module 'fileops.bindings.keymaps'
---Keymap registration for fileops. Called only from bindings.setup().
---Individual keys are gated by config.keymaps.lhs.* — set an entry to `false`
---to disable just that one mapping, or to a different string to remap it.
local M = {}

local file = require("fileops.ops.file")
local cycle = require("fileops.ops.cycle")
local bulk = require("fileops.ops.bulk")
local notify = require("fileops.util.notify")
local config = require("fileops.config")

---@internal
---Set a keymap. Uses lib.nvim's map helper if available (soft dependency),
---else falls back to plain vim.keymap.set.
---@param lhs string
---@param fn fun()
---@param desc string
local function map(lhs, fn, desc)
  local ok, lib_map = pcall(require, "lib.nvim.map")
  if ok and type(lib_map) == "function" then
    local wrapped = pcall(lib_map, "n", lhs, fn, { silent = true }, desc)
    if wrapped then
      return
    end
  end
  vim.keymap.set("n", lhs, fn, { silent = true, desc = desc })
end

---Last glob used by the filtered cycle keys, so walking a `*.lua` set does
---not mean retyping the glob at every step. Session state, not persisted.
---@type string|nil
local last_pattern = nil

---@internal
---@return FileOps.KeymapLhs
local function lhs_cfg()
  local km = config.get().keymaps or {}
  return km.lhs or {}
end

---@internal
---@param direction FileOps.Direction
---@param target FileOps.OpenTarget
---@return fun()
local function cycle_fn(direction, target)
  return function()
    local cfg = config.get()
    local copts =
      vim.tbl_deep_extend("force", vim.deepcopy(cfg.cycle or {}), { open_target = target })
    local dir, err = cycle.get_root_dir(copts)
    if not dir then
      notify.warn(err or "cannot determine root directory")
      return
    end
    notify.report(cycle.navigate(dir, direction, copts, vim.v.count1))
  end
end

---@internal
---Bind a single cycle key if its lhs is configured (not `false`/nil).
---@param key string        Key into FileOps.KeymapLhs.
---@param direction FileOps.Direction
---@param target FileOps.OpenTarget
---@param desc string
local function bind_cycle(key, direction, target, desc)
  local lhs = lhs_cfg()[key]
  if type(lhs) ~= "string" or lhs == "" then
    return
  end
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

---@internal
---Bind one key from `keymaps.lhs`, if it is configured. Every entry added
---below is unset by default: these actions were command-only, and adding a
---key that nobody asked for is a different thing from making one possible.
---@param key string
---@param fn fun()
---@param desc string
local function bind(key, fn, desc)
  local lhs = lhs_cfg()[key]
  if type(lhs) ~= "string" or lhs == "" then
    return
  end
  map(lhs, fn, desc)
end

function M.attach_delete()
  bind("delete", function()
    notify.report(file.delete_current({}))
  end, "[fileops] Delete current file")

  -- `delete` refuses on a modified buffer and points at `:File! delete`. That
  -- is right for the default key, but it left the forced form reachable only
  -- by retyping the command -- so this is the `!` as a key.
  bind("delete_force", function()
    notify.report(file.delete_current({ force = true }))
  end, "[fileops] Delete current file (force, discards unsaved changes)")
end

---Bind the keys for actions that previously had no keymap option at all:
---`path`, `cd`, `info`, `lockinfo` and `bulk rename`. All unset by default.
---@return nil
function M.attach_actions()
  bind("path", function()
    notify.report(file.copy_path())
  end, "[fileops] Copy path to clipboard")

  bind("cd", function()
    notify.report(file.cd_here({}))
  end, "[fileops] cd to the current file's directory")

  bind("info", function()
    notify.report(file.info())
  end, "[fileops] Show file info")

  bind("lockinfo", function()
    file.diagnose_lock()
  end, "[fileops] Diagnose which process locks this file")

  bind("bulk_rename", function()
    -- Prompted rather than fixed: a bulk rename needs a pattern and a
    -- replacement, and a bare keypress has neither.
    local kit = require("lib.nvim.ui.kit")
    kit.input({
      title = "bulk rename — pattern: ",
      on_submit = function(pattern)
        pattern = vim.trim(pattern or "")
        if pattern == "" then
          return
        end
        kit.input({
          title = ("bulk rename — replace %q with: "):format(pattern),
          on_submit = function(replacement)
            local cfg = config.get()
            local dir, err = cycle.get_root_dir(cfg.cycle or {})
            if not dir then
              notify.warn(err or "cannot determine root directory")
              return
            end
            local plan = bulk.plan(dir, pattern, replacement or "", cfg.bulk or {})
            notify.report(bulk.execute(plan, cfg.bulk or {}))
          end,
        })
      end,
    })
  end, "[fileops] Bulk rename in this directory")
end

---Bind the pattern-filtered cycle keys.
---
--- `:File next *.lua` was command-only, so the keymaps could only ever walk
--- every file. These prompt for the glob once and then navigate with it,
--- which is the only shape a bare keypress can take.
---@return nil
function M.attach_cycle_filtered()
  local specs = {
    { key = "next_filtered", dir = "next", desc = "[fileops] Next file matching a glob" },
    { key = "prev_filtered", dir = "prev", desc = "[fileops] Previous file matching a glob" },
  }

  for _, spec in ipairs(specs) do
    bind(spec.key, function()
      require("lib.nvim.ui.kit").input({
        title = "cycle to files matching: ",
        default = last_pattern,
        on_submit = function(pattern)
          pattern = vim.trim(pattern or "")
          if pattern == "" then
            return
          end
          last_pattern = pattern
          local cfg = config.get()
          local copts = vim.tbl_deep_extend(
            "force",
            vim.deepcopy(cfg.cycle or {}),
            { open_target = "replace", pattern = pattern }
          )
          local dir, err = cycle.get_root_dir(copts)
          if not dir then
            notify.warn(err or "cannot determine root directory")
            return
          end
          notify.report(cycle.navigate(dir, spec.dir, copts, vim.v.count1))
        end,
      })
    end, spec.desc)
  end
end

return M
