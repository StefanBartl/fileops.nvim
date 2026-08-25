---@module 'fileops.integrations.menu'
---@brief Context-menu entries for nvzone/menu (soft, opt-in integration).
---@description
--- fileops.nvim does not depend on a menu plugin. It *provides* a list of
--- entries in the shape nvzone/menu expects, built with
--- `lib.nvim.contextmenu`'s helpers, and a host — typically the user's own
--- RightMouse dispatcher — composes them into its own menu, e.g.:
--- >
---   local items = require("fileops.integrations.menu").items()
---   -- prepend/append `items` to your own menu table, then menu.open(composed)
--- <
--- Every entry acts on "the current buffer's file" — the same target every
--- `:File <subcommand>` acts on — and each just runs `:File <subcommand>`
--- with no arguments rather than re-deriving the op's options (git-aware
--- flags, retry flags, refresh-explorers, delete confirmation mode, …):
--- the command's own handler (`fileops.bindings.usrcmds`) already builds
--- those correctly from config and prompts for any missing destination via
--- `lib.nvim.ui.kit.input`, so re-running that path here keeps this module
--- from drifting out of sync with it. Entries needing a real file (rename,
--- duplicate, delete, copy path, info) are omitted on an unnamed buffer;
--- "Next/Previous file in directory" stay available everywhere `:File
--- next`/`:File prev` already work from.

local contextmenu = require("lib.nvim.contextmenu")

local M = {}

---@internal
---@param bufnr integer
---@return boolean
local function has_file(bufnr)
  return vim.api.nvim_buf_get_name(bufnr) ~= ""
end

---Build the fileops.nvim menu entries for `bufnr`.
---@param bufnr? integer defaults to the current buffer
---@return Lib.ContextMenu.Item[]
function M.items(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local named = has_file(bufnr)

  local out = {}

  contextmenu.group(
    out,
    contextmenu.entry(named, "  Rename file…", function()
      vim.cmd("File rename")
    end),
    contextmenu.entry(named, "  Duplicate file…", function()
      vim.cmd("File duplicate")
    end),
    contextmenu.entry(named, "  Delete file", function()
      vim.cmd("File delete")
    end)
  )

  contextmenu.group(
    out,
    contextmenu.entry(named, "  Copy path", function()
      vim.cmd("File path")
    end),
    contextmenu.entry(named, "  Show file info", function()
      vim.cmd("File info")
    end)
  )

  contextmenu.group(
    out,
    contextmenu.entry(true, "  Next file in directory", function()
      vim.cmd("File next")
    end),
    contextmenu.entry(true, "  Previous file in directory", function()
      vim.cmd("File prev")
    end)
  )

  return out
end

--- Convenience: the fileops.nvim entries wrapped as a single nested submenu
--- entry, for hosts that prefer a "File ▸" fly-out instead of inline
--- entries. Returns nil when there is nothing to show.
---@param label? string submenu label (default "  File")
---@param bufnr? integer
---@return Lib.ContextMenu.Item|nil
function M.submenu(label, bufnr)
  return contextmenu.submenu(label or "  File", M.items(bufnr))
end

return M
