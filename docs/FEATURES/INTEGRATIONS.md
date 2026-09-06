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
`:File` cannot register without it), which-key, `git`, and gitsigns.nvim.

- **Module:** `health.lua` (`M.check`)
