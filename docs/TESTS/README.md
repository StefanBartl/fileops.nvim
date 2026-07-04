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
| `platform_spec.lua` | `util/platform.lua`: mkdir_p, copy_file, rename_file, delete_file. |
| `cycle_spec.lua`    | `ops/cycle.lua`: directory listing, wrap, hidden-file filter, navigate. |
| `run.lua`           | Runner: loads every spec, reports results, sets the exit code.   |

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.tmpdir` / `H.write_file` / `H.edit`) and add its filename to the `specs`
list in `run.lua`.
