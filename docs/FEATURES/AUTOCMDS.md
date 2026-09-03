# Automatic behaviour

Things fileops.nvim does on its own in response to editor events — creating
missing parent directories on save, previewing unsaved line changes, and
highlighting conflict markers.

## Auto-mkdir on save

Creates the parent directory hierarchy for a file about to be written, on
`BufWritePre`, automatically — the always-on counterpart to `:File mkdir`.
Skips buffers whose name matches `auto_mkdir.detect_remote_pattern` (e.g.
`ssh://`, `http://`) when `auto_mkdir.skip_remote` is true, so a remote
buffer name is never mistaken for a local path to `mkdir -p`.

- **Module:** `bindings/autocmds.lua` (`M.attach_auto_mkdir`), reuses
  `ops/file.lua`'s `M.ensure_parent`
- **Autocmds:** `BufWritePre` in augroup `fileops_auto_mkdir` — see
  [docs/autocommands.md](../autocommands.md)
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
  [docs/autocommands.md#on_hold](../autocommands.md#on_hold)
- **Config:** `opts.on_hold.enable` (default `false`, opt-in), plus `modes`,
  `delay`, `throttle_ms`, `git_cmd`, `ignore_buftypes`, `only_tracked`,
  `require_clean_buffer`, `prefix`, `right_align`, `max_len`, `hl_prev`,
  `virt_priority`, `prefer_inline`, `restore_view`, `events_override` — see
  [Configuration](../configuration.md)

## Conflict-marker highlighting

Highlights unresolved Git conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
per-window via `matchadd`/`matchdelete` on `BufWinEnter`, cleared on
`BufWinLeave`.

- **Module:** `features/conflict_marks.lua` (`M.setup`),
  `bindings/autocmds.lua` (`M.attach_conflict_marks`)
- **Autocmds:** `BufWinEnter`/`BufWinLeave` — see
  [docs/autocommands.md#conflict_marks](../autocommands.md#conflict_marks)
- **Config:** `opts.conflict_marks.enable` (default `true`),
  `opts.conflict_marks.hl_a`/`hl_b`/`hl_c` (defaults `"DiffDelete"`,
  `"DiffChange"`, `"DiffAdd"`)

