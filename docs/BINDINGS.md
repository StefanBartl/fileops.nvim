# Bindings cheatsheet

Every keymap, user command, and autocommand fileops.nvim defines. Mirrors the
source of truth in `lua/fileops_nvim/bindings/`. If a binding is added or
renamed there, update this file to match.

## Keymaps

Registered by `require("fileops_nvim").setup()`, gated by
`config.keymaps.cycle` / `config.keymaps.delete` (master switches) and
`config.keymaps.lhs.*` (per-key, set to `false` to disable or a string to
remap). See [`bindings/keymaps.lua`](../lua/fileops_nvim/bindings/keymaps.lua).

| Key | `lhs` config key | Mode | Action |
|---|---|---|---|
| `<leader>nf` | `next_replace` | n | Next file (replace) |
| `<leader>pf` | `prev_replace` | n | Previous file (replace) |
| `<leader>nfn` | `next_current` | n | Next file (stay listed) |
| `<leader>pfn` | `prev_current` | n | Previous file (stay listed) |
| `<leader>nF` | `next_background` | n | Next file (background) |
| `<leader>pF` | `prev_background` | n | Previous file (background) |
| `<leader>NF` | `next_vsplit` | n | Next file (vsplit) |
| `<leader>PF` | `prev_vsplit` | n | Previous file (vsplit) |
| `<leader>dcf` | `delete` | n | Delete current file + close buffer |

All cycle keymaps respect `v:count1`.

## User commands

Registered by [`bindings/usrcmds.lua`](../lua/fileops_nvim/bindings/usrcmds.lua),
gated by `config.commands` (a single boolean — there is only one command).

| Command | Args | Description |
|---|---|---|
| `:File new` | `{path}` | Set buffer name (creates parent dirs, no write) |
| `:File[!] write` | `{path}` | Set buffer name and write to disk |
| `:File[!] saveas` | `{path}` | Save-as, buffer name changes |
| `:File[!] writeto` | `{path}` | Write a copy, buffer name stays |
| `:File mkdir` | — | Create parent dirs for current buffer |
| `:File[!] rename` | `[%] {dest}` | Rename/move file on disk + update buffer |
| `:File[!] duplicate` | `[%] {dest}` | Copy file to new path and open the copy |
| `:File[!] copy` | `[%] {dest}` | Copy file to new path without opening it |
| `:File[!] delete` | `[%]` | Delete file from disk and close buffer |
| `:[count]File[!] next` | `[target]` | Next file in directory |
| `:[count]File[!] prev` | `[target]` | Previous file in directory |
| `:File cd` | `[scope]` | Set cwd to buffer's dir + refresh file explorer |

Full reference: [README.md § Command reference](../README.md#command-reference)
or `:h fileops-command`.

## Autocommands

Registered by [`bindings/autocmds.lua`](../lua/fileops_nvim/bindings/autocmds.lua),
gated by `config.auto_mkdir.enable` / `config.on_hold.enable` /
`config.conflict_marks.enable`.

| Event | augroup | Action | gated by |
|---|---|---|---|
| `BufWritePre` | `fileops_nvim_auto_mkdir` | Create parent directories for the file about to be written (same logic as `:File mkdir`) | `auto_mkdir.enable` |
| `CursorHold`/`CursorHoldI` | `fileops_nvim_on_hold_preview` | Preview what changed on the current line (gitsigns inline preview, or previous-content fallback) | `on_hold.enable` |
| `ModeChanged` | `fileops_nvim_on_hold_modeclear` | Clear/abort the line-diff preview when leaving an allowed mode | `on_hold.enable` |
| `CursorMoved`/`BufHidden`/`InsertEnter` (once, buffer-local) | `fileops_nvim_on_hold_cleanup` | Clear the line-diff preview on next move | `on_hold.enable` |
| `BufWinEnter` | `fileops_nvim_conflict_marks_on` | Highlight Git conflict markers (`<<<<<<<`/`=======`/`>>>>>>>`) | `conflict_marks.enable` |
| `BufWinLeave` | `fileops_nvim_conflict_marks_off` | Clear conflict marker highlights | `conflict_marks.enable` |

`config.auto_mkdir.skip_remote` (default `true`) skips buffers whose name
matches `config.auto_mkdir.detect_remote_pattern` (e.g. `ssh://`, `http://`).

## Which-key groups

Registered by [`bindings/which_key.lua`](../lua/fileops_nvim/bindings/which_key.lua)
when [which-key.nvim](https://github.com/folke/which-key.nvim) is installed
(soft dependency, no-op otherwise):

| Prefix | Group label |
|---|---|
| `<leader>n` | fileops: next file |
| `<leader>p` | fileops: prev file |
