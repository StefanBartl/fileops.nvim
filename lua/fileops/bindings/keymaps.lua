---@module 'fileops.bindings.keymaps'
---The keymap preset, declared as named actions.
---
---Declared through `lib.nvim.bindings.keymap`'s registry, and the config shape
---is preserved exactly: individual keys still live under `keymaps.lhs`, an
---entry set to `false` still drops just that mapping, and the `cycle` /
---`delete` master switches still gate their whole family.
---
---The family switches are applied by turning every key of a switched-off
---family into `false` before handing the table over, rather than by leaving
---those actions undeclared -- `:checkhealth` and generated docs ask what
---EXISTS, and "declared, currently switched off" is a different answer from
---"there is no such action".
---
---A wrong name is now reported instead of silently binding nothing, which for
---a table this size is the difference between a typo costing five seconds and
---costing an afternoon.

local file = require("fileops.ops.file")
local cycle = require("fileops.ops.cycle")
local bulk = require("fileops.ops.bulk")
local notify = require("fileops.util.notify")
local config = require("fileops.config")
local keymap = require("lib.nvim.bindings.keymap")

local M = {}

---Last glob used by the filtered cycle keys, so walking a `*.lua` set does
---not mean retyping the glob at every step. Session state, not persisted.
---@type string|nil
local last_pattern = nil

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
---The pattern-filtered cycle keys.
---
---`:File next *.lua` was command-only, so the keymaps could only ever walk
---every file. These prompt for the glob once and then navigate with it, which
---is the only shape a bare keypress can take.
---@param direction FileOps.Direction
---@return fun()
local function filtered_fn(direction)
  return function()
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
        notify.report(cycle.navigate(dir, direction, copts, vim.v.count1))
      end,
    })
  end
end

---@internal
---A bulk rename is prompted rather than fixed: it needs a pattern and a
---replacement, and a bare keypress has neither.
---@return nil
local function bulk_rename()
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
          -- `cfg.bulk` is not a config section and never was, so this read
          -- always produced `{}`: bulk's own options (`include_hidden`,
          -- `bang`, `refresh_explorers`) are not configurable from `setup()`.
          -- Passing the empty table outright says so, instead of looking like
          -- a setting a reader could go and set.
          local plan = bulk.plan(dir, pattern, replacement or "", {})
          -- `execute` answers `(renamed_count, err)`, not `(ok, msg)`, so
          -- `notify.report` was handed a number as its `ok` and nil as its
          -- message -- and reports nothing at all when the message is nil.
          -- The keymap therefore said neither "12 renamed" nor why it failed.
          -- Same wording as the `:File bulk` path in bindings/usrcmds.lua.
          local renamed, err = bulk.execute(plan, {})
          if err then
            notify.error(
              ("bulk rename: %d/%d renamed, first failure: %s"):format(renamed, #plan, err)
            )
          else
            notify.info(("bulk rename: %d file(s) renamed"):format(renamed))
          end
        end,
      })
    end,
  })
end

--- Which actions belong to which master switch.
---@type table<string, string[]>
local FAMILIES = {
  cycle = {
    "next_replace",
    "prev_replace",
    "next_current",
    "prev_current",
    "next_background",
    "prev_background",
    "next_vsplit",
    "prev_vsplit",
    "next_filtered",
    "prev_filtered",
  },
  delete = { "delete", "delete_force" },
}

---@internal
---The user's `keymaps.lhs` table with every key of a switched-off family
---forced to `false`.
---
---A copy: writing `false` into the live config would make the switch
---indistinguishable from a per-key opt-out on the next read.
---@param km table
---@return table
local function resolve_user(km)
  local user = vim.deepcopy(km.lhs or {})
  for switch, names in pairs(FAMILIES) do
    if km[switch] == false then
      for _, name in ipairs(names) do
        user[name] = false
      end
    end
  end
  return user
end

--- Declare and bind the preset's actions.
---@param cfg FileOps.Config
---@return Lib.Keymap.Registered[]
function M.setup(cfg)
  local km = cfg.keymaps or {}

  ---@type Lib.Keymap.Spec
  local spec = {
    -- Two groups, not one: `<leader>n` and `<leader>p` are "next file" and
    -- "prev file", and labelling them together would say neither.
    which_key = {
      { prefix = "<leader>n", group = "fileops: next file" },
      { prefix = "<leader>p", group = "fileops: prev file" },
    },
    order = {
      "next_replace",
      "prev_replace",
      "next_current",
      "prev_current",
      "next_background",
      "prev_background",
      "next_vsplit",
      "prev_vsplit",
      "next_filtered",
      "prev_filtered",
      "delete",
      "delete_force",
      "path",
      "cd",
      "info",
      "lockinfo",
      "bulk_rename",
    },
    actions = {
      -- replace: navigate away from the current buffer
      next_replace = { rhs = cycle_fn("next", "replace"), desc = "Next file (replace)" },
      prev_replace = { rhs = cycle_fn("prev", "replace"), desc = "Previous file (replace)" },

      -- current: keep the current buffer listed, just edit in place
      next_current = { rhs = cycle_fn("next", "current"), desc = "Next file (stay listed)" },
      prev_current = {
        rhs = cycle_fn("prev", "current"),
        desc = "Previous file (stay listed)",
      },

      -- background: add to the buffer list, do not switch
      next_background = {
        rhs = cycle_fn("next", "background"),
        desc = "Next file (background)",
      },
      prev_background = {
        rhs = cycle_fn("prev", "background"),
        desc = "Previous file (background)",
      },

      next_vsplit = { rhs = cycle_fn("next", "vsplit"), desc = "Next file (vsplit)" },
      prev_vsplit = { rhs = cycle_fn("prev", "vsplit"), desc = "Previous file (vsplit)" },

      next_filtered = { rhs = filtered_fn("next"), desc = "Next file matching a glob" },
      prev_filtered = { rhs = filtered_fn("prev"), desc = "Previous file matching a glob" },

      delete = {
        rhs = function()
          notify.report(file.delete_current({}))
        end,
        desc = "Delete current file",
      },

      -- `delete` refuses on a modified buffer and points at `:File! delete`.
      -- That is right for the default key, but it left the forced form
      -- reachable only by retyping the command -- so this is the `!` as a key.
      delete_force = {
        rhs = function()
          notify.report(file.delete_current({ force = true }))
        end,
        desc = "Delete current file (force, discards unsaved changes)",
      },

      path = {
        rhs = function()
          notify.report(file.copy_path())
        end,
        desc = "Copy path to clipboard",
      },

      cd = {
        rhs = function()
          notify.report(file.cd_here({}))
        end,
        desc = "cd to the current file's directory",
      },

      info = {
        rhs = function()
          notify.report(file.info())
        end,
        desc = "Show file info",
      },

      lockinfo = {
        rhs = function()
          -- Through the public entry point, which supplies the notify-based
          -- callback. `ops.file.diagnose_lock` is asynchronous and takes the
          -- callback as a required first argument -- called bare, as it was
          -- here, it raised instead of reporting anything.
          require("fileops").diagnose_lock()
        end,
        desc = "Diagnose which process locks this file",
      },

      bulk_rename = { rhs = bulk_rename, desc = "Bulk rename in this directory" },
    },
  }

  return keymap.register("fileops", spec, resolve_user(km))
end

return M
