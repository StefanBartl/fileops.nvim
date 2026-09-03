# Keymaps

How fileops.nvim's keymaps are enabled, disabled and remapped.

For the actual key list — every `lhs`, its config key, and what it does — see
the [bindings cheatsheet](BINDINGS.md#keymaps). That table is maintained in one
place so it cannot drift from this page.

Keymaps are registered only when `setup()` is called, and only for keys whose
`lhs` entry resolves to a string (see [Configuration](configuration.md)).

## Two master switches

| Option | Default | Covers |
|---|---|---|
| `keymaps.cycle` | `true` | The eight `<leader>n…` / `<leader>p…` directory-cycling keys |
| `keymaps.delete` | `true` | `<leader>dcf` — delete current file and close its buffer |

All cycle keymaps respect `v:count1`, so `3<leader>nf` jumps three files
forward.

Eight further actions have an `lhs` slot but are **unset by default** —
`next_filtered`, `prev_filtered`, `delete_force`, `path`, `cd`, `info`,
`lockinfo`, `bulk_rename`. Making a keymap possible is a different thing from
claiming a key for it, so you have to name the key yourself. They are reachable
as `:File …` subcommands either way.

## Per-key override

`keymaps.lhs.*` overrides individual keys without touching the rest of the
family — `false` disables one, a string remaps it:

```lua
require("fileops").setup({
  keymaps = {
    lhs = {
      next_replace = false,        -- disable just <leader>nf
      delete       = "<leader>X",  -- remap delete to <leader>X
      info         = "<leader>fi", -- bind one of the unset actions
    },
  },
})
```

## Which-key

[which-key.nvim](https://github.com/folke/which-key.nvim) is an **optional**
soft dependency. When installed, fileops.nvim groups the `<leader>n` and
`<leader>p` prefixes so the cycle family reads as a menu; when absent this is a
no-op and every key still carries its own `desc`. Both which-key v2
(`register`) and v3 (`add`) are supported.

The group labels are two fields in the keymap spec, applied by lib.nvim's
keymap registry — see
[`bindings/keymaps.lua`](../lua/fileops/bindings/keymaps.lua).
