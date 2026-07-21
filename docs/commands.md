# Command reference

```
:File[!] {subcommand} [args…]
```

`!` overrides safety checks (existing-file guard, modified-buffer confirm).
`%` is an optional explicit "current file" scope — always implied when omitted.

## `:File new {path}`

Set the current buffer's file name to `{path}`. Creates parent directories.
Does **not** write the buffer to disk.

```
:File new lua/mymodule/init.lua
```

## `:File[!] write {path}`

Like `new` but also writes the buffer to disk immediately. `!` overwrites an
existing file (`:write!`).

## `:File[!] saveas {path}`

Save the buffer under `{path}` (`:saveas`-equivalent). Buffer name changes.
`!` overwrites an existing file.

## `:File[!] writeto {path}`

Write a copy of the buffer to `{path}` without changing the buffer's name.
`!` overwrites an existing file.

## `:File mkdir`

Create the parent directory hierarchy for the current buffer's file. This
runs automatically before every save too — see [Autocommands](autocommands.md).

## `:File[!] rename [%] {dest}`

Rename (or move) the current file on disk to `{dest}`. Updates the buffer
name and **reloads the buffer from disk** afterwards (resets signs/
diagnostics). Writes unsaved changes before renaming. `!` overwrites an
existing destination.

```
:File rename newname.lua
:File rename % newname.lua    (explicit %, same result)
:File! rename ../moved.lua    (overwrite if exists)
```

## `:File[!] move [%] {dest}`

Move the current file on disk to `{dest}` (possibly a different directory)
and update the buffer name — same underlying rename as `rename`, but the
buffer is **not** reloaded: content and undo history stay exactly as they
were. `!` overwrites an existing destination.

```
:File move ../elsewhere/file.lua
:File! move % ../elsewhere/file.lua
```

## `:File[!] duplicate [%] {dest}`

Copy the current file to `{dest}` and open the copy. `!` overwrites.

```
:File duplicate backup.lua
:File! duplicate % backup.lua
```

## `:File[!] copy [%] {dest}`

Copy the current file to `{dest}` using libuv, like `duplicate`, but without
opening the copy afterwards. `!` overwrites.

```
:File copy backup.lua
:File! copy % backup.lua
```

## `:File[!] delete [%]`

Delete the current file from disk using libuv and close the buffer. If the
buffer has unsaved changes, plain `:File delete` refuses (nothing is deleted);
`!` deletes the file and force-closes the buffer.

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
