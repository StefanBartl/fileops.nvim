# Tests

Headless spec suite for fileops.nvim. Covers the pure / buffer-level logic
that is trivially testable without a UI.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
```

The runner prints one line per spec and exits non-zero on the first failure
(`FILEOPS_TESTS_OK` on success).

## Layout

| File                | Covers                                                          |
| ------------------- | ---------------------------------------------------------------- |
| `harness.lua`       | Shared `eq`/`ok` assertions, `tmpdir()`, `write_file()`, `edit()`. |
| `config_spec.lua`   | Config defaults + deep-merge of user options, incl. `keymaps.lhs`. |
| `cycle_spec.lua`    | `ops/cycle.lua`: directory listing, wrap, hidden-file filter, navigate. |
| `file_spec.lua`     | `ops/file.lua`: copy/move/touch and other non-buffer-destructive mutations. |
| `bulk_spec.lua`     | `ops/bulk.lua`: bulk-rename plan/execute, conflicts, hidden-file filtering. |
| `run.lua`           | Runner: resolves lib.nvim, loads every spec, reports results, sets the exit code. |

`platform_spec.lua` is gone: `util/platform.lua` was removed in favour of
`lib.nvim.cross.fs.mutate`, and that behaviour (`mkdir_p`, `copy_file`,
`rename_file`, `delete_file`) is covered by lib.nvim's own
`docs/TESTS/nvim_helpers_spec.lua`. The coverage moved with the code.

## lib.nvim

The suite needs `lib.nvim` on the runtimepath, since `ops/file.lua` and
`ops/cycle.lua` require it. `run.lua` resolves it in this order:

1. `$LIB_NVIM_PATH`
2. a sibling checkout (`../lib.nvim`)
3. the plugin-manager copy (`stdpath("data")/lazy/lib.nvim`)

The sibling checkout deliberately wins over the plugin-manager copy: the
bootstrap clone is often older than the working checkout, and testing against
a stale lib.nvim produces misleading failures.

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.tmpdir` / `H.write_file` / `H.edit`) and add its filename to the `specs`
list in `run.lua`.
