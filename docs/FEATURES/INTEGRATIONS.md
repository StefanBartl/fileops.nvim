# Integrations

How fileops.nvim talks to the rest of the editor: the right-click menu, the
`User FileopsChanged` event that file explorers can listen to, which-key
labels, and the health check.

## Right-click context menu (nvzone/menu)

`fileops.integrations.menu` contributes entries — Rename, Duplicate,
Delete, Copy path, Show info, Next/Previous file — in the shape
[nvzone/menu](https://github.com/nvzone/menu) expects, all acting on the
current buffer's file. Each entry just runs the equivalent `:File
<subcommand>` with no arguments, so options and destination prompting
stay identical to running the command directly. Entries needing a real
file are omitted on an unnamed buffer. fileops.nvim has no dependency on
`menu` and never opens a context menu itself — a host (typically your own
`<RightMouse>` dispatcher) composes the entries into its own menu.

- **Module:** `fileops/integrations/menu.lua` (`M.items`, `M.submenu`)
- **Docs:** [docs/BINDINGS.md#context-menu-optional](../BINDINGS.md#context-menu-optional)


## Cascade-delete-assets (filetree.nvim)

`fileops.integrations.filetree_assets` is the seam `:File delete` and the
`delete`/`delete_force` keymaps use to ask, IF filetree.nvim happens to be
installed and its own `refs.outgoing_assets` feature is turned on, whether
the file about to be deleted links to now-orphaned assets (screenshots
etc. under a configured root) and offer to cascade-delete those too. A
no-op in every other case: filetree.nvim absent, or present but its
feature left at the upstream default (off). This module adds no config of
its own — filetree.nvim's own `refs.outgoing_assets.enabled`/`on_delete`
switch is the only thing that turns any of this on. See that plugin's
`docs/FEATURES/FILEOPS.md#cascade-delete-assets` for the feature itself.

- **Module:** `fileops/integrations/filetree_assets.lua` (`M.confirm`, `M.delete`)
- **Config:** none — governed entirely by filetree.nvim's `refs.outgoing_assets`


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
  [docs/autocommands.md#user-fileopschanged](../autocommands.md#user-fileopschanged)
- **Config:** `opts.explorer.refresh_on_change` (default `true`)

## gitsuite.nvim post-action events (GS-25)

`bindings/autocmds.lua` listens for gitsuite.nvim's `User
GitsuiteBranchSwitched`/`GitsuiteConflictsResolved` events and reuses the
same `file.notify_change` path any other tree-changing op goes through — a
branch switch refreshes explorers with the repo root as `path` (action
`git-checkout`), a resolved conflict with the buffer's own file (action
`git-conflict-resolved`). No dependency in either direction: these are
plain `User` autocmds, so this feature is simply inert without
gitsuite.nvim installed.

- **Module:** `bindings/autocmds.lua` (`M.attach_gitsuite_events`)
- **Autocmds:** `User GitsuiteBranchSwitched`, `User GitsuiteConflictsResolved`
- **Config:** `opts.gitsuite_events.enable` (default `true`)

## gitsuite.nvim backing conflict_marks and on_hold (GS-26)

Two more, quieter delegations to `gitsuite.nvim` (optional soft dep, pcall
per call site — no dependency the other way):

- `features/conflict_marks.lua` calls `gitsuite.features.conflict.refresh(bufnr)`
  on `BufWinEnter` instead of its own fixed `matchadd` patterns, when
  gitsuite.nvim is installed. Its parser matches markers by *exact* length
  (git's `conflict-marker-size`) and understands diff3/zdiff3 base sections
  and ambiguous `=======` lines — the fixed `^<<<<<<< .\+$`-style patterns
  match a same-length-or-longer run too eagerly and know neither. Extmarks
  are buffer-scoped, so this path needs no `BufWinLeave` counterpart; falls
  back to the original per-window `matchadd` highlighting, `hl_a`/`hl_b`/`hl_c`
  and all, when gitsuite.nvim is absent.
- `features/on_hold.lua`'s blame/show fallback chain gets its blame step
  (which commit last touched the cursor line) from
  `gitsuite.features.blame.for_location` instead of fileops' own
  `git blame --porcelain` parsing, when installed. That path always spawns
  plain `git`, not the configured `on_hold.git_cmd` — the `git show` step
  right after it still honours that setting either way, since gitsuite has
  no blob-content equivalent to delegate that half to.

- **Modules:** `features/conflict_marks.lua`, `features/on_hold.lua`
- **Config:** none of its own — governed by `conflict_marks.enable` /
  `on_hold.enable` as already documented; whether gitsuite.nvim backs either
  one is detected at runtime, not configurable

## Which-key group labels

When [which-key.nvim](https://github.com/folke/which-key.nvim) is installed,
the `<leader>n` and `<leader>p` prefixes get group labels
("fileops: next file" / "fileops: prev file"). Every individual key also
carries its own `desc`.

- **Module:** the `which_key` field of the keymap spec in
  `bindings/keymaps.lua`, applied by lib.nvim's keymap registry

## `:checkhealth fileops`

Reports the runtime environment and every optional-dependency status in one
place: Neovim version, libuv availability, `vim.ui.select`/`vim.fs.dir`
presence, the `vim.g.loaded_fileops` guard, `lib.nvim` (hard requirement —
`:File` cannot register without it), which-key, `git`, and gitsigns.nvim —
plus which file explorer (if any) was detected for the tree refresh, and
whether the configured keymaps were installed.

- **Module:** `health.lua` (`M.check`)
