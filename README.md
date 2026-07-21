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

## Quickstart

Requires Neovim **0.9+** and [lib.nvim](https://github.com/StefanBartl/lib.nvim).

```lua
{
  "StefanBartl/fileops.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {},
}
```

```
:File[!] {subcommand} [args…]
```

| Subcommand | Args | Description |
|---|---|---|
| `new` | `[path]` | Set buffer name (creates parent dirs, no write) |
| `write` | `[path]` | Set buffer name and write to disk (`!` overwrites existing) |
| `saveas` | `[path]` | Save-as, buffer name changes (creates parents) |
| `writeto` | `[path]` | Write a copy, buffer name stays (creates parents) |
| `mkdir` | — | Create parent dirs for current buffer |
| `touch` | `[path]` | Create an empty file if it doesn't exist yet |
| `rename` | `[%] [dest]` | Rename file on disk + update buffer (reloads) |
| `move` | `[%] [dest]` | Move file on disk + update buffer (no reload) |
| `duplicate` | `[%] [dest]` | Copy file to new path and open the copy |
| `copy` | `[%] [dest]` | Copy file to new path without opening it |
| `delete` | `[%]` | Delete file from disk and close buffer (`!` force-closes if modified) |
| `next` | `[target] [glob]` | Next file in directory, optionally filtered (e.g. `*.lua`) |
| `prev` | `[target] [glob]` | Previous file in directory, optionally filtered |
| `first` | `[target]` | Jump to the first file in directory |
| `last` | `[target]` | Jump to the last file in directory |
| `open` | `[target]` | Reopen the current file in a different window target |
| `path` | `[mode]` | Copy the current file's path to the clipboard (abs/rel/name/dir) |
| `info` | — | Show size/mtime/permissions for the current file |
| `cd` | `[scope]` | Set cwd to buffer's dir + refresh file explorer |
| `help` | — | Show a short usage overview in the command line |

`!` overrides safety checks (existing-file guard, modified-buffer confirm).
`%` is an optional explicit "current file" scope — always implied when omitted.
Every `[path]`/`[dest]` argument is optional: omit it and a `vim.ui.input`
prompt opens instead of an error.

Verify your setup any time with:

```
:checkhealth fileops_nvim
```

---

## Documentation

- [Installation](docs/installation.md) — requirements and setup for lazy.nvim, packer.nvim/pckr.nvim, and vim-plug.
- [Configuration](docs/configuration.md) — all available `setup()` options and their defaults.
- [Command reference](docs/commands.md) — full usage and examples for every `:File` subcommand.
- [Keymaps](docs/keymaps.md) — default keybindings, per-key overrides, and which-key integration.
- [Autocommands](docs/autocommands.md) — auto-created parent dirs, ambient diff preview, and conflict-marker highlighting.
- [Lua API](docs/api.md) — calling fileops.nvim functions directly from Lua.
- [Architecture](docs/architecture.md) — module layout and design notes.
- [Bindings cheatsheet](docs/BINDINGS.md) — quick-reference table of every keymap, command, and autocommand.
- [Roadmap](docs/ROADMAP.md) — implemented and planned features.
