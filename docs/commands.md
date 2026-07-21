# Command reference

```
:File[!] {subcommand} [args…]
```

`!` overrides safety checks (existing-file guard, modified-buffer confirm).
`%` is an optional explicit "current file" scope — always implied when omitted.

Every `{path}`/`{dest}` argument below is itself optional: omit it and the
command opens a `vim.ui.input` prompt instead of erroring. Cancelling the
prompt (`<Esc>` or an empty answer) is a silent no-op, same as `vim.ui.input`.

Tab-completion for these arguments is relative to the **current buffer's
directory**, not Neovim's cwd — `:File rename <Tab>` browses files next to
the one you're editing. Input starting with `~`, `/`, or a Windows drive
letter is left alone (treated as already absolute).

## `:File new [path]`

Set the current buffer's file name to `{path}`. Creates parent directories.
Does **not** write the buffer to disk.

```
:File new lua/mymodule/init.lua
```

## `:File[!] write [path]`

Like `new` but also writes the buffer to disk immediately. `!` overwrites an
existing file (`:write!`).

## `:File[!] saveas [path]`

Save the buffer under `{path}` (`:saveas`-equivalent). Buffer name changes.
`!` overwrites an existing file.

## `:File[!] writeto [path]`

Write a copy of the buffer to `{path}` without changing the buffer's name.
`!` overwrites an existing file.

## `:File mkdir`

Create the parent directory hierarchy for the current buffer's file. This
runs automatically before every save too — see [Autocommands](autocommands.md).

## `:File touch [path]`

Create an empty file at `{path}` if it doesn't already exist yet (creates
parent directories). Real `touch` semantics: an existing file is left
untouched, never truncated. Doesn't require or open a buffer.

```
:File touch notes/todo.md
```

## `:File[!] rename [%] [dest]`

Rename (or move) the current file on disk to `{dest}`. Updates the buffer
name and **reloads the buffer from disk** afterwards (resets signs/
diagnostics). Writes unsaved changes before renaming. `!` overwrites an
existing destination.

```
:File rename newname.lua
:File rename % newname.lua    (explicit %, same result)
:File! rename ../moved.lua    (overwrite if exists)
```

## `:File[!] move [%] [dest]`

Move the current file on disk to `{dest}` (possibly a different directory)
and update the buffer name — same underlying rename as `rename`, but the
buffer is **not** reloaded: content and undo history stay exactly as they
were. `!` overwrites an existing destination.

```
:File move ../elsewhere/file.lua
:File! move % ../elsewhere/file.lua
```

## `:File[!] duplicate [%] [dest]`

Copy the current file to `{dest}` and open the copy. `!` overwrites.

```
:File duplicate backup.lua
:File! duplicate % backup.lua
```

## `:File[!] copy [%] [dest]`

Copy the current file to `{dest}` using libuv, like `duplicate`, but without
opening the copy afterwards. `!` overwrites.

```
:File copy backup.lua
:File! copy % backup.lua
```

## `:File[!] delete [%]`

Delete the current file from disk and close the buffer. Uses libuv by
default (`delete.mode = "permanent"`), or the OS trash/recycle bin when
`delete.mode = "trash"` — see [Configuration](configuration.md). If the
buffer has unsaved changes, plain `:File delete` refuses (nothing is
deleted); `!` deletes the file and force-closes the buffer. If
`delete.on_before_delete` is configured, it runs first and can abort the
deletion by returning `false` (e.g. to warn about git-tracked files).

```
:File delete
:File delete %    (same)
:File! delete     (delete + force-close a modified buffer)
```

## `:[count]File[!] next [target]` / `:[count]File[!] prev [target]`

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

## `:File[!] first [target]` / `:File[!] last [target]`

Jump straight to the first / last file in the current directory listing
(alphabetical, respecting `cycle.include_hidden`/`cycle.case_insensitive`),
instead of stepping one at a time with `next`/`prev`. Same `[target]` values
and `!` behaviour as `next`/`prev`.

```
:File first              → jump to the first file
:File last vsplit        → jump to the last file, in a vertical split
```

## `:File[!] open [target]`

Reopen the current buffer's own path in a different window target, without
changing which file is shown — e.g. pop the file you're already editing into
a vertical split or a new tab. Same `[target]` values as `next`/`prev`; `!`
skips the modified-buffer confirm the same way it does there.

```
:File open vsplit        → current file, in a vertical split
:File open tab           → current file, in a new tab
:File! open              → current file, reloaded, skipping the modified check
```

## `:File path [mode]`

Copy the current file's path to the unnamed register and the system
clipboard (`+`). `[mode]` defaults to `abs`.

| Mode | Result |
|---|---|
| `abs` (default) | Absolute path |
| `rel` | Relative to cwd |
| `name` | File name only |
| `dir` | Containing directory only |

```
:File path              → absolute path
:File path rel          → path relative to cwd
:File path name         → just the file name
```

## `:File info`

Show size, last-modified time, and permissions for the current file, via
libuv `fs_stat` (works cross-platform, including Windows).

```
:File info
→ /home/me/project/init.lua
  size: 1.2 KiB (1234 bytes)
  modified: 2026-07-20 14:03:11
  permissions: 644
```

## `:File cd [scope]`

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

## `:File help`

Show a short usage overview for every subcommand directly in the command
line (via `notify.info`), without opening `:h fileops`.
