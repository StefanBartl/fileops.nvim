# fileops.nvim

File operations for Neovim — one command, all operations.

`:File` is a single unified command for creating, navigating, renaming,
duplicating, and deleting files. Designed as a standalone plugin (no lib.nvim
dependency), cross-platform (Windows + Unix), with all I/O going through
libuv directly.

---

## Quick reference

```
:File[!] {subcommand} [args…]
```

| Subcommand | Args | Description |
|---|---|---|
| `new` | `{path}` | Set buffer name (creates parent dirs, no write) |
| `write` | `{path}` | Set buffer name and write to disk |
| `saveas` | `{path}` | Save-as, buffer name changes (creates parents) |
| `writeto` | `{path}` | Write a copy, buffer name stays (creates parents) |
| `mkdir` | — | Create parent dirs for current buffer |
| `rename` | `[%] {dest}` | Rename/move file on disk + update buffer |
| `duplicate` | `[%] {dest}` | Copy file to new path and open the copy |
| `delete` | `[%]` | Delete file from disk and close buffer |
| `next` | `[target]` | Next file in directory |
| `prev` | `[target]` | Previous file in directory |

`!` overrides safety checks (existing-file guard, modified-buffer confirm).
`%` is an optional explicit "current file" scope — always implied when omitted.

---

## Requirements

- Neovim 0.9+
- No external plugins required

---

## Installation

### lazy.nvim

```lua
{
  dir = vim.env.REPOS_DIR .. "/fileops.nvim",  -- local checkout
  -- or: "your-gh-user/fileops.nvim" for remote
  event = "VeryLazy",
  opts = {},
}
```

---

## Configuration

```lua
require("fileops_nvim").setup({
  -- Options for :File next / :File prev
  cycle = {
    open_target         = "replace",    -- "replace"|"current"|"split"|"vsplit"|"tab"|"background"
    keep_focus          = true,         -- Return focus to origin after split/vsplit
    include_hidden      = false,        -- Include dot-files in directory listing
    wrap                = true,         -- Wrap around at directory boundary
    follow_symlinks     = true,         -- Resolve symlinks for comparisons
    root                = "buffer_dir", -- "buffer_dir"|"cwd"
    confirm_on_modified = true,         -- vim.ui.select prompt when buffer is modified
    case_insensitive    = true,         -- Case-insensitive sort and comparison
  },
  keymaps = {
    cycle  = true,   -- <leader>nf/pf and variants
    delete = true,   -- <leader>dcf
  },
  commands = true,   -- Register :File
})
```

---

## Command reference

### `:File new {path}`

Set the current buffer's file name to `{path}`. Creates parent directories.
Does **not** write the buffer to disk.

```
:File new lua/mymodule/init.lua
```

### `:File write {path}`

Like `new` but also writes the buffer to disk immediately.

### `:File[!] saveas {path}`

Save the buffer under `{path}` (`:saveas`-equivalent). Buffer name changes.
`!` overwrites an existing file.

### `:File[!] writeto {path}`

Write a copy of the buffer to `{path}` without changing the buffer's name.
`!` overwrites an existing file.

### `:File mkdir`

Create the parent directory hierarchy for the current buffer's file.

### `:File[!] rename [%] {dest}`

Rename (or move) the current file on disk to `{dest}`. Updates the buffer
name. Writes unsaved changes before renaming. `!` overwrites an existing
destination.

```
:File rename newname.lua
:File rename % newname.lua    (explicit %, same result)
:File! rename ../moved.lua    (overwrite if exists)
```

### `:File[!] duplicate [%] {dest}`

Copy the current file to `{dest}` and open the copy. `!` overwrites.

```
:File duplicate backup.lua
:File! duplicate % backup.lua
```

### `:File delete [%]`

Delete the current file from disk using libuv and close the buffer.

```
:File delete
:File delete %    (same)
```

### `:[count]File[!] next [target]` / `:[count]File[!] prev [target]`

Navigate to the next / previous file in the current directory.

```
:File next               → next file, configured open_target
:File next vsplit        → in a vertical split
:2File next              → skip 2 files
:File! next              → bypass modified-buffer confirm
```

**Target values:**

| Arg | Behaviour |
|---|---|
| `%` or `replace` | Open in current window (replaces buffer) |
| `stay` or `current` | Edit in-place, keep old buffer listed |
| `new` or `split` | Horizontal split |
| `vsplit` | Vertical split |
| `tab` | New tab |
| `bg` or `background` | Load into buffer list without switching |

---

## Keymaps

Registered only when `setup()` is called.

**Cycle** (`keymaps.cycle = true`):

| Key | Action |
|---|---|
| `<leader>nf` | Next file (replace) |
| `<leader>pf` | Previous file (replace) |
| `<leader>nfn` | Next file (current) |
| `<leader>pfn` | Previous file (current) |
| `<leader>nF` | Next file (background) |
| `<leader>pF` | Previous file (background) |
| `<leader>NF` | Next file (vsplit) |
| `<leader>PF` | Previous file (vsplit) |

All cycle keymaps respect `v:count1`.

**Delete** (`keymaps.delete = true`):

| Key | Action |
|---|---|
| `<leader>dcf` | Delete current file + close buffer |

---

## Lua API

```lua
local fileops = require("fileops_nvim")

fileops.next(opts?, count?)          -- :File next equivalent
fileops.prev(opts?, count?)          -- :File prev equivalent
fileops.new_file(path, opts?)        -- :File new
fileops.rename(path, opts?)          -- :File rename
fileops.duplicate(path, opts?)       -- :File duplicate
fileops.delete_current(opts?)        -- :File delete
```

---

## Architecture

```
lua/fileops_nvim/
  init.lua           Public API + setup()
  config.lua         Defaults and active-config store
  @types.lua         LuaLS type annotations
  commands.lua       Single :File command with subcommand dispatch
  keymaps.lua        vim.keymap.set registrations
  health.lua         :checkhealth fileops_nvim
  util/
    notify.lua       "[fileops] " prefixed vim.notify wrapper
    platform.lua     libuv delete/copy/rename/mkdir_p (no shell)
  ops/
    cycle.lua        Directory listing, indexing, navigation, open_path
    file.lua         Create, rename, duplicate, delete operations
plugin/
  fileops_nvim.lua   Load guard
```

All file I/O uses `vim.uv` (libuv) — no shell, no injection risk, fully
cross-platform.

---

## Health check

```
:checkhealth fileops_nvim
```

---

## License

MIT
