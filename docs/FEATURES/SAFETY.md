# Safety nets

What fileops.nvim does when a mutation is risky or when the filesystem refuses:
git-aware moves, automatic retry on a Windows sharing violation, and a probe
that names the process holding a locked file.

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
  [docs/autocommands.md#user-fileopsretry](../autocommands.md#user-fileopsretry)
- **Config:** `opts.retry.attempts` (default `6` on Windows, `1` elsewhere —
  non-Windows errors are real, not transient), `opts.retry.backoff_ms`
  (default `60`, doubling each round)


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
  [docs/commands.md](../commands.md#file-lockinfo-path)

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

