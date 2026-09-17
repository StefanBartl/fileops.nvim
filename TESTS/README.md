# Tests

Headless spec suite for fileops.nvim. It drives the real modules against real
files in a temporary directory: the filesystem operations, the `:File` command
as a user types it, the keymap preset, the autocmd-driven features, the health
check, and the public Lua API.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile TESTS/run.lua" -c "qa!"
```

The runner prints one line per spec with the number of assertions it ran, a
total at the end, and exits non-zero on the first failing spec
(`FILEOPS_TESTS_OK` on success).

## Conventions

A spec is a file `TESTS/<name>_spec.lua` returning `function(H) … end`, added
to the `specs` list in `run.lua`. `H` is the shared harness:

| Helper | What it does |
| --- | --- |
| `H.eq` / `H.ok` | The two assertions. Both count into the per-spec total. |
| `H.tmpdir()` | A fresh, empty directory under `vim.fn.tempname()`. |
| `H.write_file(path, content)` | Write a fixture, creating parent directories. |
| `H.edit(path)` | `:edit` a path and return its bufnr. |
| `H.is_windows()` | For the cases that pin platform-specific path behaviour. |
| `H.notifications(fn)` | Run `fn` with `vim.notify` captured; returns what it emitted. |
| `H.notified(seen, needle)` | Whether any captured notification contains `needle`. |
| `H.stub(module, value)` | Put a double on `package.loaded`; returns its restore function. |

Two rules the whole suite follows:

- **Nothing is ever written outside `vim.fn.tempname()`.** Every fixture tree
  is built and thrown away there; no spec operates on the repository. The
  cases that need a particular working directory `:cd` into their own scratch
  directory and restore the previous one.
- **No process is spawned that a spec does not need.** `git` is real, in the
  three specs that test git-awareness (and each skips itself if `git` cannot
  run). Everything else that shells out is replaced at `package.loaded`
  before the call that would resolve it — see below.

## Doubles, and why

`ui.nvim` is not on this suite's runtimepath and CI checks out only
`lib.nvim`, so the prompt/dialog layer is always a double. The rest of the
doubles exist to keep the suite off the OS.

| Module | Replaced because | Used in |
| --- | --- | --- |
| `ui.kit` | Not a CI checkout; `input`/`confirm` need an answer to continue. | `usrcmds*`, `cycle_edge`, `keymaps`, `filetree_assets` |
| `ui.contextmenu` | Not a CI checkout; the entries are the subject, not the rendering. | `health_menu` |
| `lib.nvim.fs.trash` | Real trashing spawns PowerShell/`osascript`/`gio` and would leave fixtures in the machine's recycle bin. | `file_delete`, `usrcmds_dispatch`, `keymaps` |
| `lib.nvim.cross.fs.lock` | The holder lookup spawns a helper process. | `file_delete`, `usrcmds_dispatch`, `keymaps`, `init_api` |
| `lib.nvim.cross.fs.mutate` | Swapped for one case each, to prove the retry budget is passed down — a Windows sharing violation cannot be provoked from inside this process. | `file_spec`, `usrcmds_dispatch` |
| `filetree.refs` | Soft integration with a plugin that is not a dependency. | `filetree_assets`, `keymaps` |

Each is restored immediately afterwards, so the specs stay independent of one
another with respect to them.

## Layout

| File | Covers |
| --- | --- |
| `harness.lua` | The assertions and helpers above. |
| `run.lua` | Resolves lib.nvim and this repo on `package.path`, runs every spec, counts assertions, sets the exit code. |
| `config_spec.lua` | `config/`: defaults, deep merge, the deliberately unset keymaps. |
| `notify_spec.lua` | `util/notify.lua`: the prefix, the levels, and `report()`'s relay contract. |
| `cycle_spec.lua` | `ops/cycle.lua`: listing, wrap, hidden files, patterns, recursion, case-insensitive order. |
| `cycle_edge_spec.lua` | `ops/cycle.lua`: every `open_target`, the unsaved-changes dialog, the `root` variants, counts, wrap boundaries, failure returns, and the `follow_symlinks = false` path comparison. |
| `file_spec.lua` | `ops/file.lua`: copy/move/rename/touch/delete, the retry contract, git-awareness, `session_compat`. |
| `file_paths_spec.lua` | `ops/file.lua`: path resolution (spaces, `%`/`#`, globs, drive letters, relative vs. absolute), `ensure_parent` failures, `edit_new`/`save_as`/`write_to`/`mk_parent`, `notify_change`, `copy_path`, the `info` size ladder. |
| `file_delete_spec.lua` | `ops/file.lua`: trash vs. permanent, the unsaved guard, window bookkeeping after a delete, `delete_path`, the `on_before_delete` veto, `diagnose_lock`, vanished sources. |
| `bulk_spec.lua` | `ops/bulk.lua`: plan/execute, conflicts, hidden-file filtering. |
| `bulk_edge_spec.lua` | `ops/bulk.lua`: invalid patterns, the separator normalization, what `plan` excludes, partial failures, buffers following a rename. |
| `git_spec.lua` | `util/git.lua`: `is_tracked`/`mv`/`rm` against a real temp git repo (skips if git is unusable). |
| `git_async_spec.lua` | `util/git.lua`: the `_async` twins, driven to completion via `vim.wait`. |
| `usrcmds_spec.lua` | `bindings/usrcmds.lua`: that `prompt_dest()` routes through `kit.input`. |
| `usrcmds_dispatch_spec.lua` | `bindings/usrcmds.lua`: every `:File[!]` subcommand through the real Ex command, the `%` scope form, the prompts and their defaults, the config flags the dispatch folds in (`retry`, `git_aware`, `session_compat`, `delete.mode`), bulk rename end to end, and completion for every slot. |
| `keymaps_spec.lua` | `bindings/keymaps.lua`: the declared action set, both family switches, per-key overrides, and what every action's `rhs` does. |
| `autocmds_spec.lua` | `bindings/autocmds.lua` (auto-mkdir, remote skipping), `features/conflict_marks.lua`, `features/on_hold.lua`'s event mapping and guards, and `bindings/init.lua`'s wiring. |
| `init_api_spec.lua` | `init.lua`: `setup()` and its idempotence, plus every public API function. |
| `health_menu_spec.lua` | `health.lua` against a recorded `vim.health`, and `integrations/menu.lua`'s entries and what they run. |
| `filetree_assets_spec.lua` | `integrations/filetree_assets.lua`: the cascade-delete-assets seam behind `:File delete`. |
| `explorer_integration_spec.lua` | `ops/file.lua`'s explorer-refresh path against REAL neo-tree.nvim/nvim-tree.lua — optional, see below. |

`platform_spec.lua` is gone: `util/platform.lua` was removed in favour of
`lib.nvim.cross.fs.mutate`, and that behaviour (`mkdir_p`, `copy_file`,
`rename_file`, `delete_file`) is covered by lib.nvim's own
`TESTS/nvim_helpers_spec.lua`. The coverage moved with the code.

## Deliberately not covered

- **`lua/fileops/@types/init.lua`** — annotations only, no runtime code.
- **`plugin/fileops.lua`** — a three-line `vim.g.loaded_fileops` guard with no
  branch of its own.
- **`config/DEFAULTS.lua`** as a table — every value that matters is asserted
  through the behaviour it produces (`config_spec.lua` and each feature's own
  spec) rather than by re-typing the table here.
- **`ops/file.lua`'s `reload_explorers`/`refresh_explorers`** beyond their
  `package.loaded[…]` guard — they need real neo-tree/nvim-tree instances,
  which is what the separate `explorer_integration_spec.lua` job is for.
- **`features/on_hold.lua`'s preview itself** — it chains `git blame` into
  `git show` and prefers `gitsigns.preview_hunk_inline()`. The event mapping
  per configured mode, the mode/buftype/file-name guards and the "not a repo"
  exit are covered; rendering the virtual text would need a real repo plus two
  subprocesses per idle event.
- **`lib.nvim.fs.trash`'s backends and `lib.nvim.cross.fs.lock`'s holder
  lookup** — other repo, other suite. What is asserted here is the argument
  fileops hands them and how it reports their answer.
- **The `:File` dispatcher's unknown-subcommand branch** — unreachable through
  the command: composer resolves the route first and reports
  `unknown subcommand '…'` before `dispatch` is ever called.
- **`ops/bulk.lua`'s "cannot read directory" guard** — also unreachable:
  everything `vim.fs.dir` would raise on already raises one line earlier,
  where `plan` normalizes the trailing separator. A directory that does not
  exist simply lists as empty.

## Pinned bugs

Assertions marked `BUG:` in the source pin *current* behaviour that is wrong,
so that fixing it is a deliberate, visible change rather than a surprise. Each
comment says why it was pinned instead of fixed.

1. **`ops/cycle.lua` — `follow_symlinks = false` freezes navigation on
   Windows** (`cycle_edge_spec.lua`). `list_files` joins entries as
   `dir .. "/" .. name`; with `follow_symlinks` off, `canon` falls back to
   `fnamemodify(":p")`, which leaves that `/` in place, while
   `nvim_buf_get_name` spells the same file with `\`. `index_of` therefore
   never finds the current file, `navigate` appends it as an extra listing
   entry, `\` sorts after `/` so the copy lands last — and `next` wraps
   straight back onto the same file. `:File next`/`:File prev` are a silent
   no-op for anyone who sets that option.
2. **`ops/bulk.lua` — a bulk rename strands the open buffer on Windows**
   (`bulk_edge_spec.lua`, `usrcmds_dispatch_spec.lua`). `plan` joins with `/`
   whenever its root carries no trailing separator — which is exactly what
   `cycle.get_root_dir`, and therefore `:File bulk rename`, passes. `execute`
   re-points open buffers by comparing that path against `nvim_buf_get_name`,
   the two disagree in one character, and `nvim_buf_set_name` never runs:
   after the rename the buffer points at a file that no longer exists, and the
   next `:w` writes the old name back into being.
3. **`bindings/keymaps.lua` — the delete key ignored `delete.mode`** —
   **fixed**, assertions kept as regression guards (`keymaps_spec.lua`).
   `:File delete` reads `config.delete` (the mode and `on_before_delete`)
   plus the git-aware/retry/refresh flags; the keymap called `delete_fn({})`
   and passed none of them, so once the default flipped to `"trash"` the
   default delete key still unlinked the file permanently, with no undo, and
   never ran an `on_before_delete` hook. `delete_fn` now reads
   `delete.mode`/`delete.on_before_delete` per invocation — the way the other
   actions in that file read their config, so a later `setup()` still
   applies — while `force` stays the caller's. The git-aware/retry/refresh
   flags are deliberately still not pulled in: the keymaps never carried
   them, and adding them is a separate decision.
4. **`ops/file.lua` — `delete_path` accepts directories it cannot delete**
   (`file_delete_spec.lua`). Its existence check lets a directory through, but
   the deletion is `uv.fs_unlink`. On Windows libuv answers `EPERM`, which
   lib.nvim's retry loop treats as a transient sharing violation (so the full
   retry budget is spent first) and `explain_fs_error` then blames a virus
   scanner for what is really "this is a directory".
5. **`features/conflict_marks.lua` — matches leak per `:e`**
   (`autocmds_spec.lua`). Re-editing the same file in the same window is a
   `BufWinEnter` with no `BufWinLeave` in front of it: three fresh matches are
   added and the recorded ids are overwritten, so the previous set can never
   be deleted. Invisible (same lines, same groups) but unbounded.

Two related quirks are asserted as *documented* behaviour rather than as bugs:
`:saveas` normalizes the buffer name it stores while the `:file` command
behind `rename`/`edit_new` does not, so a renamed buffer carries a
mixed-separator name on Windows (`file_paths_spec.lua`); and a plan built from
a root *with* a trailing separator produces different path strings than the
same directory spelled without one (`bulk_edge_spec.lua`).

## lib.nvim

The suite needs `lib.nvim` on the runtimepath, since `ops/file.lua` and
`ops/cycle.lua` require it. `run.lua` resolves it in this order:

1. `$LIB_NVIM_PATH`
2. a sibling checkout (`../lib.nvim`)
3. the plugin-manager copy (`stdpath("data")/lazy/lib.nvim`)

The sibling checkout deliberately wins over the plugin-manager copy: the
bootstrap clone is often older than the working checkout, and testing against
a stale lib.nvim produces misleading failures.

`run.lua` also registers this repo's own `lua/` directory on `package.path` by
absolute path. `set rtp+=.` is a *relative* runtimepath entry resolved at
lookup time, so without that entry a spec that changes the working directory
would break every `require("fileops.…")` not yet resolved — a failure that
depends only on spec order.

## Explorer integration (optional)

`explorer_integration_spec.lua` exercises `ops/file.lua`'s explorer-refresh
code path against real `neo-tree.nvim` and `nvim-tree.lua` instances instead
of just the `package.loaded[...]`-guarded no-op every other spec exercises.
Neither plugin is a runtime dependency of fileops.nvim, so the spec skips
itself (prints `skip` and returns) unless both — plus neo-tree's own hard
deps, `nui.nvim` and `plenary.nvim` — are found, resolved the same way
`run.lua` resolves lib.nvim:

1. `$NEO_TREE_NVIM_DIR` / `$NVIM_TREE_LUA_DIR` / `$NUI_NVIM_DIR` / `$PLENARY_NVIM_DIR`
2. a sibling checkout (`../neo-tree.nvim`, `../nvim-tree.lua`, `../nui.nvim`, `../plenary.nvim`)

CI runs it as its own `explorer-integration` job in `.github/workflows/ci.yml`,
which checks the four repos out as siblings. A local run with nothing checked
out just skips it — the main `test` job (and this local `nvim --headless …`
command) never depend on it.

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` and add its filename to
the `specs` list in `run.lua`. Build fixtures with `H.tmpdir()` /
`H.write_file`, assert the *reported* error on a failure path (not just that
something failed), and restore anything global the spec touches — the working
directory, a stubbed module, an autocmd group, `vim.notify`.
