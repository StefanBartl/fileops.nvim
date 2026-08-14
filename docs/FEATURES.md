# Features

fileops.nvim wraps the whole single-file lifecycle — create, write, rename,
move, duplicate, copy, delete, navigate, diagnose — behind one user command
and a small, focused Lua API, with libuv doing every bit of I/O (no shell,
cross-platform). This file is the one-stop feature catalog; see
[docs/commands.md](commands.md), [docs/configuration.md](configuration.md),
[docs/keymaps.md](keymaps.md), [docs/autocommands.md](autocommands.md), and
[docs/BINDINGS.md](BINDINGS.md) for full reference detail on any entry below.

## Unified `:File` command

A single `:File[!] {subcommand} [args…]` command dispatches to every
operation the plugin offers instead of one command per verb. `!` overrides
safety checks (existing-file guard, modified-buffer confirm); `%` is an
explicit "current file" scope, always implied when omitted. Every
`[path]`/`[dest]` argument is optional — omitting it opens a `vim.ui.input`
(via `lib.nvim.ui.kit`) prompt instead of erroring, and cancelling the prompt
is a silent no-op. Tab-completion for path arguments resolves against the
**current buffer's directory**, not Neovim's cwd.

- **Tab:** true
- **Module:** `bindings/usrcmds.lua` (`M.register`, `dispatch`), built on
  `lib.nvim.usercmd.composer`
- **Usercmds:** [`:File`](commands.md) — see
  [docs/BINDINGS.md#user-commands](BINDINGS.md#user-commands) for the full
  subcommand table
- **Config:** `opts.commands` (default `true`) — master switch for
  registering `:File` at all

- Create/write: `new`, `write`, `saveas`, `writeto`, `mkdir`, `touch`
- Mutate: `rename`, `move`, `duplicate`, `copy`, `delete` (git-aware, retrying,
  session-compat, trash-mode opt-in)
- Navigate: `next`, `prev`, `first`, `last`, `open` (glob filter, recursive
  root, configurable open target)
- Diagnose: `info`, `lockinfo` (Windows sharing-violation holder lookup)
- Bulk: `bulk rename` (Lua-pattern batch rename with preview + confirm)
- Misc: `path` (clipboard), `cd` (+ explorer refresh), `help`
- Ambient features: `auto_mkdir`, `on_hold` (line-diff preview, opt-in),
  `conflict_marks`
- Full Lua API mirroring every subcommand (`docs/api.md`), which-key groups,
  per-key remappable keymaps, `:checkhealth fileops`, headless test suite
  (`docs/TESTS/`) run in CI alongside stylua/luacheck.

### Why one command instead of many

Every subcommand shares the same `!`/`%`/prompt-on-missing-arg conventions,
the same tab-completion base (buffer directory), and the same
git-aware/retry/session-compat plumbing for the five mutating subcommands
(`rename`/`move`/`duplicate`/`copy`/`delete`). Dispatching through one
`lib.nvim.usercmd.composer` verb with per-subcommand routes means that
plumbing is written once in `bindings/usrcmds.lua`'s `dispatch()` function
instead of once per command definition, and `:File help` can enumerate every
subcommand from the same `SUBCMDS` table the router itself uses.

## Create & write operations

`new`, `write`, `saveas`, `writeto`, `mkdir`, and `touch` cover every way to
put a file on disk without an existing source file to act on. `new` only sets
the buffer name (creates parent dirs, no write); `write` does the same and
writes immediately; `saveas` changes the buffer name and saves
(`:saveas`-equivalent); `writeto` writes a copy without changing the buffer's
name; `touch` creates an empty file with real `touch` semantics (an existing
file is left untouched, never truncated) and does not require or open a
buffer. All of them create missing parent directories automatically.

- **Module:** `ops/file.lua` (`M.edit_new`, `M.save_as`, `M.write_to`,
  `M.touch`, `M.ensure_parent`, `M.mk_parent`)
- **Usercmds:** `:File new`, `:File[!] write`, `:File[!] saveas`,
  `:File[!] writeto`, `:File mkdir`, `:File touch` — see
  [docs/commands.md](commands.md)

## Rename & move

Renames or moves the current file on disk and re-points the buffer at the new
path, resolving a typed relative destination against the **current file's
directory** (so `:File rename NEW.md` renames in place). Unsaved changes are
written first. The only difference between the two: `rename` reloads the
buffer from disk afterwards (resetting signs/diagnostics), `move` leaves
buffer content and undo history untouched. Both are git-aware and
session-compat aware (see below) and retry a transient sharing violation.

- **Module:** `ops/file.lua` (`M.rename`, `M.move`, shared
  `move_or_rename` internal), `lua/fileops/init.lua` (`M.rename`, `M.move`)
- **Usercmds:** `:File[!] rename [%] [dest]`, `:File[!] move [%] [dest]` —
  see [docs/commands.md](commands.md#file-rename--dest)
- **Config:** `opts.git_aware`, `opts.retry`, `opts.session_compat` (see
  [Configuration](configuration.md))

## Duplicate & copy

Copies the current file to a new path via libuv. `duplicate` opens the copy
afterwards; `copy` is the silent counterpart (same validation and copy path,
just `opts.open` forced off). Both accept `!` to overwrite an existing
destination and share the same retry budget as rename/move.

- **Module:** `ops/file.lua` (`M.duplicate`, `M.copy`)
- **Usercmds:** `:File[!] duplicate [%] [dest]`, `:File[!] copy [%] [dest]`
  — see [docs/commands.md](commands.md#file-duplicate--dest)
- **Config:** `opts.retry`, `opts.git_aware` (adds a tracked-source note to
  the result message only — duplicate/copy never run a git command)

## Delete (permanent or trash)

Deletes the current file from disk and closes its buffer, steering any window
showing that buffer onto an alternate listed buffer first so closing it
doesn't spawn an empty scratch buffer. Refuses on unsaved changes unless `!`
force-closes. `delete.mode = "trash"` sends the file to the OS trash/recycle
bin (`lib.nvim.fs.trash`) instead of a permanent `fs_unlink`.
`delete.on_before_delete` runs first and can abort the deletion by returning
`false`.

- **Module:** `ops/file.lua` (`M.delete_current`, `switch_windows_off`)
- **Usercmds:** `:File[!] delete [%]` — see
  [docs/commands.md](commands.md#file-delete-)
- **Config:** `opts.delete.mode` (default `"permanent"`),
  `opts.delete.on_before_delete` (default `nil`)

## Git-aware mutation

Opt-in awareness of git-tracked files for `rename`/`move`/`duplicate`/`copy`/
`delete`. With `git_aware.warn_only = true` (default) the tracked-ness is
only noted in the result message and libuv still does the I/O; with
`warn_only = false`, rename/move use `git mv -f` and delete uses `git rm -f`
so the git index stays in sync (delete only when `delete.mode = "permanent"`
— trashing is a different operation than `git rm`). All git calls are
argv-only (no shell) and run with `cwd` set to the target file's own
directory, independent of Neovim's global cwd.

- **Module:** `util/git.lua` (`M.is_tracked`, `M.mv`, `M.rm`)
- **Config:** `opts.git_aware.enable` (default `false`),
  `opts.git_aware.warn_only` (default `true`), `opts.git_aware.git_cmd`
  (default `"git"`)

## Sharing-violation retry

Rename/move/duplicate/copy/delete retry a transient `EBUSY`/`EPERM`/`EACCES`
failure with a doubling backoff before giving up, and fire `User
FileopsRetry` (`{path, attempt, err}`) before each new attempt so another
plugin can release its own handle on the path — waiting alone can't outlast a
handle held inside the same Neovim process. Also releases neo-tree's own
leaked `fs_event` watch handles on the path automatically
(`lib.nvim.neotree.watch`) when that guard is installed.

- **Module:** `ops/file.lua` (`retry_opts`, `explain_fs_error`)
- **Autocmds:** `User FileopsRetry` — see
  [docs/autocommands.md#user-fileopsretry](autocommands.md#user-fileopsretry)
- **Config:** `opts.retry.attempts` (default `6` on Windows, `1` elsewhere —
  non-Windows errors are real, not transient), `opts.retry.backoff_ms`
  (default `60`, doubling each round)

## Directory cycling (next/prev/first/last)

Navigates to the next/previous/first/last file in a directory listing,
alphabetically sorted, with an optional glob filter (`vim.fn.glob2regpat`)
narrowing the listing first. `next`/`prev` respect `[count]` (`:2File next`
skips 2). `cycle.root` chooses between the buffer's own directory or cwd, and
`_recursive` variants of either walk subdirectories (symlinked directories
are never descended into, so a symlink cycle can't cause an infinite walk).
Six open targets are available per call or via config default: replace,
current (stay listed), split, vsplit, tab, background.

- **Module:** `ops/cycle.lua` (`M.navigate`, `M.jump_edge`, `M.get_root_dir`,
  `M.open_path`), `lua/fileops/init.lua` (`M.next`, `M.prev`, `M.first`,
  `M.last`)
- **Usercmds:** `:[count]File[!] next [target] [glob]`,
  `:[count]File[!] prev [target] [glob]`, `:File[!] first [target]`,
  `:File[!] last [target]` — see [docs/commands.md](commands.md#filecount-next-target-glob--filecount-prev-target-glob)
- **Keymaps:** `<leader>nf`/`<leader>pf` family (8 keys total) — see
  [docs/keymaps.md](keymaps.md)
- **Config:** `opts.cycle.*` (`open_target`, `root`, `wrap`,
  `include_hidden`, `case_insensitive`, `follow_symlinks`,
  `confirm_on_modified`, `keep_focus`, `pattern`) — see
  [Configuration](configuration.md)

## Reopen in a different window

Reopens the current buffer's own path in a different window target (split,
vsplit, tab, background, …) without changing which file is shown — e.g. pop
the file being edited into a vertical split.

- **Module:** `ops/cycle.lua` (`M.open_current`), `lua/fileops/init.lua`
  (`M.open`)
- **Usercmds:** `:File[!] open [target]` — see
  [docs/commands.md](commands.md#file-open-target)

## Path to clipboard

Copies the current file's path to the unnamed register and the system
clipboard (`+` register) in one of four modes: absolute (default), relative
to cwd, file name only, or containing directory only.

- **Module:** `ops/file.lua` (`M.copy_path`), `lua/fileops/init.lua`
  (`M.copy_path`)
- **Usercmds:** `:File path [mode]` — see
  [docs/commands.md](commands.md#file-path-mode)

## File info

Shows size (human-readable + raw bytes), last-modified time, and permissions
for the current file via libuv `fs_stat` — cross-platform, including
Windows (where the permission bits are libuv's own synthesized
approximation).

- **Module:** `ops/file.lua` (`M.info`, `human_size`),
  `lua/fileops/init.lua` (`M.info`)
- **Usercmds:** `:File info` — see [docs/commands.md](commands.md#file-info)

## Lock diagnosis (`:File lockinfo`)

Diagnoses an `EBUSY`/`EPERM`/`EACCES` failure by probing whether the file is
renameable right now and, on Windows, naming the actual process holding it
open via the Restart Manager API (no administrator rights needed). An open
Neovim buffer is never the cause — Neovim closes a file after reading it and
keeps only its swap file open. The full report also goes to `:messages` so
it survives past the notification timeout and can be pasted into a bug
report. Asynchronous (the holder lookup spawns a helper process), so it takes
a callback rather than returning `ok, msg` directly like the other ops.

- **Tab:** true
- **Module:** `ops/file.lua` (`M.diagnose_lock`), delegates to
  `lib.nvim.cross.fs.lock`; `lua/fileops/init.lua` (`M.diagnose_lock`)
- **Usercmds:** `:File lockinfo [path]` — see
  [docs/commands.md](commands.md#file-lockinfo-path)

### Reading the probe/holder table

| Probe | Holders | Meaning |
|---|---|---|
| not renameable | a foreign process | That process is the cause — an antivirus scan, the search indexer, OneDrive. |
| not renameable | `nvim` itself | A handle leaked inside this Neovim (a watcher that was never closed); no retry can outwait it. |
| not renameable | none | A kernel-level lock not registered with the Restart Manager. |
| renameable | any | The lock was transient and is already gone — what the `retry` budget exists for. |

Holder lookup is Windows-only; the rename probe itself works everywhere.
`lib.nvim.cross.fs.lock` is shared with `filetree.nvim`, so both plugins
report the same findings in the same words.

## Bulk rename

Batch-renames every regular file directly inside the current buffer's
directory (no recursion) whose name changes under a Lua-pattern
`gsub(pattern, replacement)` applied to the file name only. Files the
pattern doesn't match, or that `gsub` leaves unchanged, are excluded from
the plan. Split into a pure `plan()` (side-effect free — used by the test
suite to assert the plan without touching disk) and an `execute()` that
performs the renames; the command layer previews every `old → new` pair via
a notification, then confirms via `vim.ui.select` (`lib.nvim.ui.kit.confirm`)
before touching disk. `!` allows overwriting existing destinations;
otherwise a conflicting destination is skipped and reported while the rest
of the batch still proceeds. Any open buffer pointing at a renamed file is
re-pointed at the new path (no reload, same as `move`).

- **Module:** `ops/bulk.lua` (`M.plan`, `M.execute`)
- **Usercmds:** `:File[!] bulk rename {pattern} {replacement}` — see
  [docs/commands.md](commands.md#file-bulk-rename-pattern-replacement)

## Change directory (`:File cd`)

Sets the working directory to the current buffer's file's directory —
window-local (`:lcd`, default), tab-local (`:tcd`), or global (`:cd`) — then
refreshes any open file explorer (neo-tree, nvim-tree, netrw) so it tracks
the new root.

- **Module:** `ops/file.lua` (`M.cd_here`, `refresh_explorers`),
  `lua/fileops/init.lua` (`M.cd_here`)
- **Usercmds:** `:File cd [scope]` — see
  [docs/commands.md](commands.md#file-cd-scope)
- **Config:** `opts.cd.scope` (default `"window"`),
  `opts.cd.refresh_explorers` (default `true`)

## Explorer refresh & the `User FileopsChanged` event

Every tree-changing op (`new`/`write`/`saveas`/`writeto`/`mkdir`/`touch`/
`rename`/`move`/`duplicate`/`copy`/`delete`, including each file in a bulk
rename) fires a `User FileopsChanged` autocmd (`{action, path}`)
unconditionally, and separately reloads neo-tree/nvim-tree in place unless
`explorer.refresh_on_change = false`. The event exists so any plugin —
including session managers that aren't `v:this_session`-based, like
possession.nvim — can react without fileops needing to know about it
directly.

- **Module:** `ops/file.lua` (`M.notify_change`, `reload_explorers`)
- **Autocmds:** `User FileopsChanged` — see
  [docs/autocommands.md#user-fileopschanged](autocommands.md#user-fileopschanged)
- **Config:** `opts.explorer.refresh_on_change` (default `true`)

## Auto-mkdir on save

Creates the parent directory hierarchy for a file about to be written, on
`BufWritePre`, automatically — the always-on counterpart to `:File mkdir`.
Skips buffers whose name matches `auto_mkdir.detect_remote_pattern` (e.g.
`ssh://`, `http://`) when `auto_mkdir.skip_remote` is true, so a remote
buffer name is never mistaken for a local path to `mkdir -p`.

- **Module:** `bindings/autocmds.lua` (`M.attach_auto_mkdir`), reuses
  `ops/file.lua`'s `M.ensure_parent`
- **Autocmds:** `BufWritePre` in augroup `fileops_auto_mkdir` — see
  [docs/autocommands.md](autocommands.md)
- **Config:** `opts.auto_mkdir.enable` (default `true`),
  `opts.auto_mkdir.skip_remote` (default `true`),
  `opts.auto_mkdir.detect_remote_pattern` (default
  `"^%w%w+:[\\/][\\/]"`)

## Ambient line-diff preview (`on_hold`)

On `CursorHold`/`CursorHoldI`, previews what changed on the current line:
prefers gitsigns' `preview_hunk_inline()` when available, otherwise falls
back to rendering the previous committed content of the line as virtual text
via argv-only `git blame`/`git show` (no shell). Every git shell-out on this
path — the repo check, the `only_tracked` check, and the `blame`/`show` pair
— is fully async (`vim.system` with a callback, scheduled onto the main loop),
so a large repo or a slow filesystem (network share, WSL interop) never
blocks the UI thread on every `CursorHold`. Mode-aware (`on_hold.modes`),
per-window throttled, and cleared on the next cursor move via a generation
counter that invalidates a stale run — whether still waiting on git or
delayed via `cfg.delay` — after a mode change. Skips buffers outside a git
repo, untracked files (when `only_tracked`), and files with unsaved changes
(when `require_clean_buffer`). Sets `vim.o.updatetime = 100` when enabled to
match the responsiveness the fallback preview needs.

- **Module:** `features/on_hold.lua` (`M.setup`),
  `bindings/autocmds.lua` (`M.attach_on_hold`)
- **Autocmds:** `CursorHold`/`CursorHoldI`, `ModeChanged`,
  `CursorMoved`/`BufHidden`/`InsertEnter` (once, buffer-local cleanup) — see
  [docs/autocommands.md#on_hold](autocommands.md#on_hold)
- **Config:** `opts.on_hold.enable` (default `false`, opt-in), plus `modes`,
  `delay`, `throttle_ms`, `git_cmd`, `ignore_buftypes`, `only_tracked`,
  `require_clean_buffer`, `prefix`, `right_align`, `max_len`, `hl_prev`,
  `virt_priority`, `prefer_inline`, `restore_view`, `events_override` — see
  [Configuration](configuration.md)

## Conflict-marker highlighting

Highlights unresolved Git conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
per-window via `matchadd`/`matchdelete` on `BufWinEnter`, cleared on
`BufWinLeave`.

- **Module:** `features/conflict_marks.lua` (`M.setup`),
  `bindings/autocmds.lua` (`M.attach_conflict_marks`)
- **Autocmds:** `BufWinEnter`/`BufWinLeave` — see
  [docs/autocommands.md#conflict_marks](autocommands.md#conflict_marks)
- **Config:** `opts.conflict_marks.enable` (default `true`),
  `opts.conflict_marks.hl_a`/`hl_b`/`hl_c` (defaults `"DiffDelete"`,
  `"DiffChange"`, `"DiffAdd"`)

## Session-compat resave

After `rename`/`move`, resaves the active `:mksession` session
(`v:this_session`) so it doesn't keep pointing at the stale path — a
no-op when no session is active. The session file must be passed explicitly
to `:mksession!`, since a bare `:mksession!` ignores `v:this_session` and
writes `./Session.vim` in the cwd instead. Other session managers
(possession.nvim, [sessions.nvim](https://github.com/StefanBartl/sessions.nvim))
can hook `User FileopsChanged` instead of relying on `v:this_session`.

- **Module:** `ops/file.lua` (inside `move_or_rename`)
- **Config:** `opts.session_compat.enable` (default `true`)

## Which-key group labels

When [which-key.nvim](https://github.com/folke/which-key.nvim) is installed
(soft dependency, no-op otherwise), groups the `<leader>n` and `<leader>p`
prefixes so the cycle keymap family reads as a menu. Supports both which-key
v2 (`register`) and v3 (`add`) APIs. Every individual key already carries its
own `desc`, so this only adds the shared group label.

- **Module:** `bindings/which_key.lua` (`M.setup`, `M.available`)

## `:checkhealth fileops`

Reports the runtime environment and every optional-dependency status in one
place: Neovim version, libuv availability, `vim.ui.select`/`vim.fs.dir`
presence, the `vim.g.loaded_fileops` guard, `lib.nvim` (hard requirement —
`:File` cannot register without it), which-key, `git`, and gitsigns.nvim.

- **Module:** `health.lua` (`M.check`)
