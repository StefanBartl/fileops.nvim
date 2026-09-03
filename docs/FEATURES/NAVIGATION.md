# Navigation & inspection

Moving through a directory without an explorer, reopening the current file in a
different window, and reading a file's path or metadata.

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
  `:File[!] last [target]` — see [docs/commands.md](../commands.md#filecount-next-target-glob--filecount-prev-target-glob)
- **Keymaps:** `<leader>nf`/`<leader>pf` family (8 keys total) — see
  [docs/keymaps.md](../keymaps.md). Since 2026-08-24 also `next_filtered` /
  `prev_filtered` (unset by default): they prompt once for a glob and then
  cycle within it, which is the only shape a bare keypress can take for
  `:File next *.lua`. The glob is remembered for the session, so walking a
  filtered set does not mean retyping it at every step.

## Keymap options for the command-only actions

`path`, `cd`, `info`, `lockinfo` and `bulk rename` were reachable only as
`:File` subcommands, and `delete` had no forced variant to match
`:File! delete`. All six now have an `lhs` config entry — and all six are
**unset by default**, because making a keymap possible is a different thing
from claiming a key for it. Closes the flag/option audit's entries.

`bulk_rename` prompts for a pattern and then a replacement; a bare keypress
carries neither. `delete_force` is the `!`: the plain `delete` key refuses on
a modified buffer and points at `:File! delete`, which is right for the
default key but left the forced form reachable only by retyping the command.

- **Module:** `bindings/keymaps.lua` (`attach_actions`,
  `attach_cycle_filtered`, `bind`)
- **Config:** `opts.keymaps.lhs.{path,cd,info,lockinfo,bulk_rename,delete_force,next_filtered,prev_filtered}`
- **Tests:** `TESTS/config_spec.lua` pins that none of them has a default
- **Config:** `opts.cycle.*` (`open_target`, `root`, `wrap`,
  `include_hidden`, `case_insensitive`, `follow_symlinks`,
  `confirm_on_modified`, `keep_focus`, `pattern`) — see
  [Configuration](../configuration.md)

## Reopen in a different window

Reopens the current buffer's own path in a different window target (split,
vsplit, tab, background, …) without changing which file is shown — e.g. pop
the file being edited into a vertical split.

- **Module:** `ops/cycle.lua` (`M.open_current`), `lua/fileops/init.lua`
  (`M.open`)
- **Usercmds:** `:File[!] open [target]` — see
  [docs/commands.md](../commands.md#file-open-target)

## Path to clipboard

Copies the current file's path to the unnamed register and the system
clipboard (`+` register) in one of four modes: absolute (default), relative
to cwd, file name only, or containing directory only.

- **Module:** `ops/file.lua` (`M.copy_path`), `lua/fileops/init.lua`
  (`M.copy_path`)
- **Usercmds:** `:File path [mode]` — see
  [docs/commands.md](../commands.md#file-path-mode)

## File info

Shows size (human-readable + raw bytes), last-modified time, and permissions
for the current file via libuv `fs_stat` — cross-platform, including
Windows (where the permission bits are libuv's own synthesized
approximation).

- **Module:** `ops/file.lua` (`M.info`, `human_size`),
  `lua/fileops/init.lua` (`M.info`)
- **Usercmds:** `:File info` — see [docs/commands.md](../commands.md#file-info)

