# fileops.nvim — Roadmap

## Implemented

The `:File[!] {subcommand}` unified command already covers the full
create/navigate/rename/duplicate/delete lifecycle — see
[Command reference](commands.md) for the authoritative, per-subcommand list.
At a glance:

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

## Planned / ideas

Nothing is currently blocking a release. The items below are backlog ideas,
not commitments — pick them up opportunistically:

- Async variants of the `git_aware`/`on_hold` git shell-outs
  (`vim.system(..., { ... }, callback)`) to avoid blocking the UI thread on
  large repos or slow filesystems (network shares, WSL interop).
- Optional integration test against a real `neo-tree`/`nvim-tree` instance in
  CI (currently only unit-level coverage of the fileops side).

## Migrated features

See `RELEASE.md`'s one-time migration section in the personal Lua checklist
notes for the standing task of porting relevant `fileops.nvim` behavior into
`filetree.nvim` — that tracker lives outside this repo and isn't duplicated
here.
