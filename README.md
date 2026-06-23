# fileops.nvim

File operations for Neovim — create, navigate, rename, duplicate, delete.

Bundles three previously separate modules (`newfile`, `filecycle`,
`delete_current_file`) into one cohesive plugin with a consistent API,
cross-platform support, and zero external dependencies.

---

## Features

| Feature | Command | Keymap |
|---|---|---|
| Create new file (set buffer name) | `:NewFile {path}` | — |
| Create and write immediately | `:NewFileWrite {path}` | — |
| Save-as with parent creation | `:SaveAsR[!] {path}` | — |
| Write copy without renaming buffer | `:WriteToR[!] {path}` | — |
| Ensure parent directories exist | `:MkParent` | — |
| Rename current file on disk | `:RenameFile[!] {path}` | — |
| Duplicate file to new path | `:DuplicateFile[!] {path}` | — |
| Delete file from disk + close buffer | `:DeleteCurrentFile` | `<leader>dcf` |
| Next file in directory | `:NextFile [target]` | `<leader>nf` |
| Previous file in directory | `:PreviousFile [target]` | `<leader>pf` |

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
  opts = {},  -- uses defaults; see Configuration
}
```

---

## Configuration

```lua
require("fileops_nvim").setup({
  -- File-cycle (NextFile / PreviousFile) settings
  cycle = {
    open_target         = "replace",    -- "replace"|"current"|"split"|"vsplit"|"tab"|"background"
    keep_focus          = true,         -- Return focus to origin after split/vsplit
    include_hidden      = false,        -- Include dot-files in directory listing
    wrap                = true,         -- Wrap around at directory boundary
    follow_symlinks     = true,         -- Resolve symlinks for dedup comparisons
    root                = "buffer_dir", -- "buffer_dir"|"cwd"
    confirm_on_modified = true,         -- Prompt via vim.ui.select when buffer is modified
    case_insensitive    = true,         -- Sort and compare filenames case-insensitively
  },

  -- Keymap registration flags
  keymaps = {
    cycle  = true,  -- Register <leader>nf / pf and variants
    delete = true,  -- Register <leader>dcf
  },

  -- Register all user commands (set false to skip entirely)
  commands = true,
})
```

---

## Commands

### File Creation and Management

| Command | Bang | Description |
|---|---|---|
| `:NewFile {path}` | — | Set buffer name to `path` (creates parent dirs). Does not write. |
| `:NewFileWrite {path}` | — | Set buffer name and write to disk immediately. |
| `:SaveAsR[!] {path}` | Overwrite | Save buffer under a new path (creates parents). Buffer name changes. |
| `:WriteToR[!] {path}` | Overwrite | Write a copy to `path` without changing buffer name. |
| `:MkParent` | — | Create parent directories for the current buffer's file. |
| `:RenameFile[!] {path}` | Overwrite | Rename/move file on disk + update buffer name. Writes unsaved changes first. |
| `:DuplicateFile[!] {path}` | Overwrite | Copy file to `{path}` and open the duplicate. |
| `:DeleteCurrentFile` | — | Delete file from disk and close the buffer. |

**Notes:**
- All path arguments support `~`, environment variables, and relative paths.
- Parent directories are created automatically for all creation/rename commands.
- `!` (bang) overrides existing-file safety checks.

### File Navigation

| Command | Description |
|---|---|
| `:NextFile [target]` | Open the next file in the current directory. |
| `:PreviousFile [target]` | Open the previous file in the current directory. |

Both commands accept an optional `[target]` argument and an optional `[count]`:

```
:NextFile               → next file, uses configured open_target
:2NextFile              → skip 2 files
:NextFile vsplit        → open in a vertical split
:NextFile! replace      → bypass modified-buffer confirmation
```

**Target aliases:**

| Argument | Behaviour |
|---|---|
| `%` or `replace` | Open in current window (default) |
| `stay` or `current` | Edit in-place, keep old buffer listed |
| `new` or `split` | Horizontal split |
| `vsplit` | Vertical split |
| `tab` | New tab |
| `bg` or `background` | Add to buffer list, don't switch |

---

## Keymaps

All keymaps are registered only when `setup()` is called. Pass `keymaps.cycle = false`
or `keymaps.delete = false` to disable groups.

### Cycle keymaps

| Keymap | Action |
|---|---|
| `<leader>nf` | Next file (replace) |
| `<leader>pf` | Previous file (replace) |
| `<leader>nfn` | Next file (current / stay) |
| `<leader>pfn` | Previous file (current / stay) |
| `<leader>nF` | Next file (background) |
| `<leader>pF` | Previous file (background) |
| `<leader>NF` | Next file (vsplit) |
| `<leader>PF` | Previous file (vsplit) |

All cycle keymaps respect `vim.v.count1` — prefix with a count to skip N files.

### Delete keymap

| Keymap | Action |
|---|---|
| `<leader>dcf` | Delete current file + close buffer |

---

## Lua API

```lua
local fileops = require("fileops_nvim")

-- Navigate
fileops.next(opts?, count?)     -- next file; opts overrides cycle config
fileops.prev(opts?, count?)     -- previous file

-- File management
fileops.new_file(path, opts?)   -- create new file { write?, bang? }
fileops.rename(path, opts?)     -- rename current file { bang? }
fileops.duplicate(path, opts?)  -- copy to new path { bang?, open? }
fileops.delete_current(opts?)   -- delete current file { force? }
```

---

## Architecture

```
lua/fileops_nvim/
  init.lua           Public API + setup()
  config.lua         Defaults and active-config store
  @types.lua         LuaLS type annotations
  commands.lua       All :UserCommand registrations
  keymaps.lua        All vim.keymap.set registrations
  health.lua         :checkhealth fileops_nvim
  util/
    notify.lua       Prefixed vim.notify wrapper
    platform.lua     libuv helpers (delete, copy, rename, mkdir_p)
  ops/
    cycle.lua        Directory listing, indexing, navigation, open
    file.lua         Create, rename, duplicate, delete operations
plugin/
  fileops_nvim.lua   Load guard (vim.g.loaded_fileops_nvim)
```

All file I/O goes through `vim.uv` (libuv) directly — no shell commands, no injection risk, cross-platform by default.

---

## Health check

```
:checkhealth fileops_nvim
```

Checks: Neovim version, libuv availability, `vim.ui.select`, `vim.fs.dir`, plugin load status.

---

## License

MIT
