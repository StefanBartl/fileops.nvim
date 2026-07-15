```
  ██████╗██╗██╗     ███████╗ ██████╗ ██████╗ ███████╗
 ██╔════╝██║██║     ██╔════╝██╔═══██╗██╔══██╗██╔════╝
 ██║     ██║██║     █████╗  ██║   ██║██████╔╝███████╗
 ██║     ██║██║     ██╔══╝  ██║   ██║██╔═══╝ ╚════██║
 ╚██████╗██║███████╗███████╗╚██████╔╝██║     ███████║
  ╚═════╝╚═╝╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝
                                               .nvim
```

![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)

> Pairs well with [sessions.nvim](https://github.com/StefanBartl/sessions.nvim):
> fileops handles the lifecycle of a single file (create, rename, duplicate,
> delete, cycle), sessions handles the lifecycle of the whole workspace
> (save/restore) — same "no mandatory dependency, direct libuv/mksession" style.

File operations for Neovim — one command, all operations.

`:File` is a single unified command for creating, navigating, renaming,
duplicating, and deleting files. Cross-platform (Windows + Unix), with all
I/O going through libuv directly.

---

## Table of contents

- [Quick reference](#quick-reference)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Command reference](#command-reference)
- [Keymaps](#keymaps)
- [Autocommands](#autocommands)
- [Which-key](#which-key)
- [Lua API](#lua-api)
- [Architecture](#architecture)
- [Health check](#health-check)

---

## Quick reference

```
:File[!] {subcommand} [args…]
```

| Subcommand | Args | Description |
|---|---|---|
| `new` | `{path}` | Set buffer name (creates parent dirs, no write) |
| `write` | `{path}` | Set buffer name and write to disk (`!` overwrites existing) |
| `saveas` | `{path}` | Save-as, buffer name changes (creates parents) |
| `writeto` | `{path}` | Write a copy, buffer name stays (creates parents) |
| `mkdir` | — | Create parent dirs for current buffer |
| `rename` | `[%] {dest}` | Rename/move file on disk + update buffer |
| `duplicate` | `[%] {dest}` | Copy file to new path and open the copy |
| `delete` | `[%]` | Delete file from disk and close buffer (`!` force-closes if modified) |
| `next` | `[target]` | Next file in directory |
| `prev` | `[target]` | Previous file in directory |
| `cd` | `[scope]` | Set cwd to buffer's dir + refresh file explorer |

`!` overrides safety checks (existing-file guard, modified-buffer confirm).
`%` is an optional explicit "current file" scope — always implied when omitted.

---

## Requirements

- Neovim **0.9+**
- *(optional)* [lib.nvim](https://github.com/StefanBartl/lib.nvim) — used for
  notifications when present; fileops.nvim runs fully standalone without it

---

## Installation

**When to use which:**

| Variant | Startup impact | When to use |
|---|---|---|
| `event = "VeryLazy"` | Minimal, after UI init | **Recommended** |
| `lazy = false` | Loads immediately | Small config, want it available instantly |

### lazy.nvim

```lua
{
  "StefanBartl/fileops.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- optional
  event = "VeryLazy",
  opts = {},
}
```

### packer.nvim / pckr.nvim

```lua
use({
  "StefanBartl/fileops.nvim",
  requires = { "StefanBartl/lib.nvim" }, -- optional
  config = function()
    require("fileops_nvim").setup()
  end,
})
```

### vim-plug

```vim
Plug 'StefanBartl/lib.nvim'  " optional
Plug 'StefanBartl/fileops.nvim'
```
```lua
require("fileops_nvim").setup()
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
  -- Options for :File cd
  cd = {
    scope             = "window", -- "window" (:lcd) | "tab" (:tcd) | "global" (:cd)
    refresh_explorers = true,     -- Refresh neo-tree/nvim-tree/netrw after cd
  },
  keymaps = {
    cycle  = true,   -- master switch: <leader>nf/pf family
    delete = true,   -- master switch: <leader>dcf
    -- Per-key overrides: set an entry to `false` to disable just that one
    -- keymap, or to a different string to remap it. Master switches above
    -- still gate the whole family.
    lhs = {
      next_replace    = "<leader>nf",
      prev_replace    = "<leader>pf",
      next_current    = "<leader>nfn",
      prev_current    = "<leader>pfn",
      next_background = "<leader>nF",
      prev_background = "<leader>pF",
      next_vsplit     = "<leader>NF",
      prev_vsplit     = "<leader>PF",
      delete          = "<leader>dcf",
    },
  },
  commands = true,   -- Register :File
  -- Auto-create parent dirs on save (BufWritePre) — automatic counterpart to :File mkdir
  auto_mkdir = {
    enable                = true,
    skip_remote           = true,
    detect_remote_pattern = "^%w%w+:[\\/][\\/]", -- e.g. "ssh://", "http://"
  },
  -- Ambient CursorHold line-diff preview
  on_hold = {
    enable = true,
    modes = "n", -- "n"|"v"|"i" (any combination) or array; nil = n+v
    delay = 3000, -- extra debounce (ms) beyond 'updatetime'
    throttle_ms = 1200, -- min time (ms) between triggers per window
    git_cmd = "git",
    ignore_buftypes = { "nofile", "prompt", "terminal" },
    only_tracked = true, -- skip files not tracked by git
    require_clean_buffer = false, -- skip if buffer has unsaved changes
    prefix = "previous: ", -- prefix before fallback EOL preview text
    right_align = false, -- place virt_text right-aligned instead of eol
    max_len = 160, -- truncate fallback preview to this many characters
    hl_prev = "Comment",
    virt_priority = 1000,
    prefer_inline = true, -- prefer gitsigns.preview_hunk_inline() when available
    restore_view = true, -- save/restore winsaveview()+cursor to avoid scroll jumps
    events_override = nil, -- fully override auto-mapped events
  },
  -- Highlight Git conflict markers (<<<<<<< / ======= / >>>>>>>)
  conflict_marks = {
    enable = true,
    hl_a = "DiffDelete",
    hl_b = "DiffChange",
    hl_c = "DiffAdd",
  },
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

### `:File[!] write {path}`

Like `new` but also writes the buffer to disk immediately. `!` overwrites an
existing file (`:write!`).

### `:File[!] saveas {path}`

Save the buffer under `{path}` (`:saveas`-equivalent). Buffer name changes.
`!` overwrites an existing file.

### `:File[!] writeto {path}`

Write a copy of the buffer to `{path}` without changing the buffer's name.
`!` overwrites an existing file.

### `:File mkdir`

Create the parent directory hierarchy for the current buffer's file. This
runs automatically before every save too — see [Autocommands](#autocommands).

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

### `:File[!] delete [%]`

Delete the current file from disk using libuv and close the buffer. If the
buffer has unsaved changes, plain `:File delete` refuses (nothing is deleted);
`!` deletes the file and force-closes the buffer.

```
:File delete
:File delete %    (same)
:File! delete     (delete + force-close a modified buffer)
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

### `:File cd [scope]`

Change the working directory to the directory of the current buffer's file,
then refresh any open file explorer (neo-tree, nvim-tree, netrw) so it tracks
the new root. Optional `[scope]` overrides `cd.scope` for this call.

```
:File cd            → :lcd to buffer's dir (window-local, default)
:File cd tab        → :tcd (tab-local)
:File cd global     → :cd (global)
```

| Scope | Command | Effect |
|---|---|---|
| `window` | `:lcd` | Window-local working directory (default) |
| `tab` | `:tcd` | Tab-local working directory |
| `global` | `:cd` | Global working directory |

---

## Keymaps

Registered only when `setup()` is called, and only for keys whose `lhs` entry
resolves to a string (see [Configuration](#configuration)).

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

Disable or remap a single key without touching the rest of the family:

```lua
require("fileops_nvim").setup({
  keymaps = {
    lhs = {
      next_replace = false,       -- disable just <leader>nf
      delete       = "<leader>X", -- remap delete to <leader>X
    },
  },
})
```

---

## Autocommands

| Event | augroup | Action |
|---|---|---|
| `BufWritePre` | `fileops_nvim_auto_mkdir` | Create parent directories for the file about to be written — the automatic-on-save counterpart to [`:File mkdir`](#file-mkdir) |

Gated by `config.auto_mkdir.enable` (default `true`). Disable it entirely:

```lua
require("fileops_nvim").setup({
  auto_mkdir = { enable = false },
})
```

`auto_mkdir.skip_remote` (default `true`) skips buffers whose name matches
`auto_mkdir.detect_remote_pattern` (e.g. `ssh://`, `http://`).

### `on_hold`

On `CursorHold`/`CursorHoldI`, previews what changed on the current line:
prefers gitsigns' inline hunk preview when available, otherwise falls back to
showing the previous committed content of the line as virtual text (via
`git blame`/`git show`, argv-only — no shell). Per-window throttled, mode-aware
(`on_hold.modes`), and cleared on the next cursor move. Sets
`vim.o.updatetime = 100` when enabled, matching the responsiveness the
fallback preview needs.

Gated by `config.on_hold.enable` (default `true`). Disable it entirely:

```lua
require("fileops_nvim").setup({
  on_hold = { enable = false },
})
```

### `conflict_marks`

On `BufWinEnter`/`BufWinLeave`, highlights unresolved Git conflict markers
(`<<<<<<<`, `=======`, `>>>>>>>`) using `matchadd`/`matchdelete`, scoped
per-window.

Gated by `config.conflict_marks.enable` (default `true`). Disable it entirely:

```lua
require("fileops_nvim").setup({
  conflict_marks = { enable = false },
})
```

---

## Which-key

[which-key.nvim](https://github.com/folke/which-key.nvim) is an **optional**
soft dependency. When installed, fileops.nvim groups the `<leader>n` and
`<leader>p` prefixes so the cycle family reads as a menu; when absent, this is
a no-op and every key still carries its own `desc`. Supports both which-key v2
(`register`) and v3 (`add`).

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
fileops.cd_here(opts?)               -- :File cd
```

---

## Architecture

```
lua/fileops_nvim/
  init.lua              Public API + setup()
  config/
    init.lua             Merge user opts over DEFAULTS, expose get()
    DEFAULTS.lua          Immutable default configuration
  @types/init.lua        LuaLS type annotations
  bindings/
    init.lua              Orchestrates usrcmds + keymaps + autocmds + which-key
    usrcmds.lua           Single :File command with subcommand dispatch
    keymaps.lua           Per-key configurable vim.keymap.set registrations
    autocmds.lua           auto_mkdir/on_hold/conflict_marks registration
    which_key.lua         Optional which-key group labels (soft dependency)
  health.lua             :checkhealth fileops_nvim
  util/
    notify.lua            "[fileops] " prefixed notifier; upgrades to
                           lib.nvim.notify when lib.nvim is installed
    platform.lua           libuv delete/copy/rename/mkdir_p (no shell)
  ops/
    cycle.lua              Directory listing, indexing, navigation, open_path
    file.lua               Create, rename, duplicate, delete operations
  features/
    on_hold.lua             Ambient CursorHold line-diff preview
    conflict_marks.lua      Conflict-marker highlighting
plugin/
  fileops_nvim.lua        Load guard
docs/
  BINDINGS.md             Cheatsheet of every keymap, user command, autocmd
  ROADMAP.md              Planned features
  TESTS/                  Headless spec suite (see docs/TESTS/README.md)
```

All file I/O uses `vim.uv` (libuv) — no shell, no injection risk, fully
cross-platform. `lib.nvim` is a **soft, guarded** dependency (see
[Requirements](#requirements)): if present, `lib.nvim.notify` is used for
notifications; otherwise fileops.nvim falls back to plain `vim.notify` and
runs fully standalone.

---

## Health check

```
:checkhealth fileops_nvim
```
