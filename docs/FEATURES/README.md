# Features

fileops.nvim wraps the whole single-file lifecycle — create, write, rename,
move, duplicate, copy, delete, navigate, diagnose — behind one user command and
a small, focused Lua API, with libuv doing every bit of I/O (no shell,
cross-platform).

This folder is the feature catalog: what the plugin does and why. For reference
detail — exact arguments, defaults, event names — see
[commands.md](../commands.md), [configuration.md](../configuration.md),
[keymaps.md](../keymaps.md), [autocommands.md](../autocommands.md), and the
[bindings cheatsheet](../BINDINGS.md).

| Page | What it covers |
|---|---|
| [COMMAND.md](COMMAND.md) | The unified `:File` command, its subcommand surface, and why every operation is one verb instead of twenty. |
| [OPERATIONS.md](OPERATIONS.md) | The core lifecycle: create, write, rename, move, duplicate, copy, delete — plus the session bookkeeping that follows a move. |
| [NAVIGATION.md](NAVIGATION.md) | Cycling through a directory without an explorer, reopening a file in another window, and reading its path or metadata. |
| [SAFETY.md](SAFETY.md) | What happens when a mutation is risky or the filesystem refuses: git-aware moves, sharing-violation retry, and lock diagnosis. |
| [BULK.md](BULK.md) | Operations beyond the current file: pattern-based batch rename with a preview step, and changing the working directory. |
| [AUTOCMDS.md](AUTOCMDS.md) | What the plugin does on its own: auto-mkdir on save, ambient line-diff preview, conflict-marker highlighting. |
| [INTEGRATIONS.md](INTEGRATIONS.md) | Talking to the rest of the editor: right-click menu, the `User FileopsChanged` event, which-key labels, and the health check. |

## Where to start

Reading `COMMAND.md` first is worth it even if you only want one operation —
the argument conventions it describes (`!`, `%`, optional paths) apply to every
subcommand on every other page.
