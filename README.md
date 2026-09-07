> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

# fileops.nvim

```
 ███████╗██╗██╗     ███████╗ ██████╗ ██████╗ ███████╗
 ██╔════╝██║██║     ██╔════╝██╔═══██╗██╔══██╗██╔════╝
 █████╗  ██║██║     █████╗  ██║   ██║██████╔╝███████╗
 ██╔══╝  ██║██║     ██╔══╝  ██║   ██║██╔═══╝ ╚════██║
 ██║     ██║███████╗███████╗╚██████╔╝██║     ███████║
 ╚═╝     ╚═╝╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝
                                               .nvim
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)

File operations for Neovim — one command, all operations.

`:File` creates, navigates, renames, duplicates and deletes files, keeping the
buffer and the disk in agreement. Cross-platform, with all I/O going through
libuv directly rather than a shell.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [Integrations](#integrations)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which lists every page and says what
each one answers.

- [Features](docs/FEATURES/README.md) — one page per area, with the reasoning behind each.
- [Installation](docs/installation.md) — requirements and setup for every plugin manager.
- [Configuration](docs/configuration.md) — every `setup()` option and its default.
- [Command reference](docs/commands.md) — full usage and examples for every `:File` subcommand.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, command and autocommand in one table.
- [Keymaps](docs/keymaps.md) — the bindable action surface, for wiring your own keys.
- [Autocommands](docs/autocommands.md) — the `User FileopsChanged` event and what fires it.
- [Lua API](docs/api.md) — calling fileops.nvim functions directly from Lua.
- [Architecture](docs/architecture.md) — module layout and responsibilities.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add a subcommand.

`:help fileops` is the same reference inside the editor.

---

## What it does

Renaming a file from inside an editor is two operations that must not come
apart: the one on disk, and the one on the buffer that is pointing at it. Do
them in the wrong order, or forget the second, and you are editing a file that
no longer exists. Neovim ships `:saveas` and leaves the rest to you.

`:File` is that missing half — every filesystem operation, with the buffer kept
in step:

- **Creating** — `new`, `write`, `saveas`, `writeto`, `mkdir`, `touch`, each
  creating parent directories rather than failing on them.
- **Moving** — `rename` (reloads the buffer), `move` (does not), `duplicate`
  (opens the copy), `copy` (does not).
- **Deleting** — `delete`, closing the buffer with it.
- **Navigating** — `next`, `prev`, `first`, `last` walk the directory, optionally
  filtered by a glob; `open` reopens the current file in a different window
  target.
- **Asking** — `path` copies the path in four shapes, `info` reports size, mtime
  and permissions, `lockinfo` diagnoses an `EBUSY`/`EPERM` by probing the lock
  live and naming the process holding it.
- **Bulk** — `bulk rename` batch-renames through a Lua pattern, with a preview
  and a confirmation.

Two conventions run through all of it. `!` overrides the safety checks (the
existing-file guard, the modified-buffer confirmation). Every `[path]` and
`[dest]` argument is optional: omit it and a `vim.ui.input` prompt opens instead
of an error.

Every tree-changing operation fires a `User FileopsChanged` autocmd carrying
`{action, path}`, so a file explorer or a session manager can react without
fileops knowing it exists.

---

## Around it

> **[sessions.nvim](https://github.com/StefanBartl/sessions.nvim)** — fileops
> handles the lifecycle of a single file (create, rename, duplicate, delete,
> cycle); sessions handles the lifecycle of the whole workspace. Same "no
> mandatory dependency, straight to libuv" style, one scale up.
>
> **[filetree.nvim](https://github.com/StefanBartl/filetree.nvim)** — the tree
> view over the same directory. It listens for `User FileopsChanged` like any
> other explorer, so a rename here refreshes it without either plugin depending
> on the other.
>
> **[buffer-ctx.nvim](https://github.com/StefanBartl/buffer-ctx.nvim)** — reads
> the current file's identity (path, module, line) rather than changing it.
>
> All of the above are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the `:File` command tree and the cross-platform layer |

No CLI tools. All I/O goes through libuv directly, which is what makes the
behaviour identical on Windows and Unix.

Optional, each detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| [filetree.nvim](https://github.com/StefanBartl/filetree.nvim), neo-tree, nvim-tree | Refreshed in place after a tree-changing operation |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | Labels for the optional keymaps |
| [nvzone/menu](https://github.com/nvzone/menu) | A host for the context-menu entries — see [Integrations](#integrations) |

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/fileops.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {},
}
```

`event = "VeryLazy"` rather than `cmd = "File"`: the `User FileopsChanged`
autocmd and the explorer refresh have to be live before the first operation, not
after it. Other plugin managers are in
[docs/installation.md](docs/installation.md).

---

## Quickstart

Rename the file you are in — disk and buffer together, prompting for the new
name:

```vim
:File rename
```

Then the rest follows the same shape; omit an argument and it asks:

```vim
:File duplicate            " copy it and open the copy
:File path rel             " the cwd-relative path, to the clipboard
:File next *.lua           " next Lua file in this directory
:File info                 " size, mtime, permissions
:File delete!              " delete it and force-close the buffer
```

Verify your setup any time with:

```vim
:checkhealth fileops
```

---

## What you get with the defaults

`:File[!] {subcommand} [args…]` — one command, and `<Tab>` completes the rest.

| Subcommand | Args | Does |
| --- | --- | --- |
| `new` | `[path]` | Set the buffer name, creating parent dirs; no write |
| `write` | `[path]` | Set the buffer name and write it (`!` overwrites) |
| `saveas` | `[path]` | Save-as; the buffer name changes |
| `writeto` | `[path]` | Write a copy; the buffer name stays |
| `mkdir` | — | Create the parent dirs for the current buffer |
| `touch` | `[path]` | Create an empty file if it does not exist |
| `rename` | `[%] [dest]` | Rename on disk and update the buffer (reloads) |
| `move` | `[%] [dest]` | Move on disk and update the buffer (no reload) |
| `duplicate` | `[%] [dest]` | Copy to a new path and open the copy |
| `copy` | `[%] [dest]` | Copy to a new path without opening it |
| `delete` | `[%]` | Delete and close the buffer (`!` force-closes if modified) |
| `next` / `prev` | `[target] [glob]` | Next / previous file in the directory, optionally filtered |
| `first` / `last` | `[target]` | Jump to the first / last file in the directory |
| `open` | `[target]` | Reopen the current file in a different window target |
| `path` | `[mode]` | Copy the path to the clipboard: `abs`, `rel`, `name`, `dir` |
| `info` | — | Size, mtime and permissions for the current file |
| `lockinfo` | `[path]` | Diagnose an `EBUSY`/`EPERM`: probe it live and name the holding process |
| `bulk rename` | `{pattern} {replacement}` | Batch-rename via a Lua pattern, with preview and confirmation (`!` overwrites) |
| `cd` | `[scope]` | Set the cwd to the buffer's directory and refresh the explorer |
| `help` | — | A short usage overview in the command line |

`!` overrides the safety checks; `%` is an optional explicit "current file"
scope, always implied when omitted. Full usage and examples:
[docs/commands.md](docs/commands.md).

---

## Integrations

### File explorers

Every tree-changing operation fires a `User FileopsChanged` autocmd carrying
`{action, path}`, unconditionally — so any plugin can react to a rename without
fileops knowing about it. On top of that, neo-tree and nvim-tree are reloaded in
place unless `explorer.refresh_on_change = false`.
[filetree.nvim](https://github.com/StefanBartl/filetree.nvim) listens for the
same event. See
[docs/FEATURES/INTEGRATIONS.md](docs/FEATURES/INTEGRATIONS.md).

### Context menu

`fileops.integrations.menu` contributes entries — Rename, Duplicate, Delete,
Copy path, Show info, Next/Previous file — in the shape
[nvzone/menu](https://github.com/nvzone/menu) expects, all acting on the current
buffer's file. fileops.nvim has **no** dependency on `menu` and never opens a
context menu itself; a host — typically your own `<RightMouse>` dispatcher —
composes them into its own menu:

```lua
local items = require("fileops.integrations.menu").items()
-- prepend or append `items` to your own menu table, then menu.open(composed)
```

Each entry runs the equivalent `:File <subcommand>` with no arguments, so
prompting and options stay identical to typing the command. Entries that need a
real file are omitted on an unnamed buffer.

---

## Health check

```vim
:checkhealth fileops
```

Reports whether `lib.nvim` resolved, which file explorer was detected for the
refresh, and whether the configured keymaps were installed.

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the project
layout; [docs/architecture.md](docs/architecture.md) says which module owns what.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/fileops.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/fileops.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
