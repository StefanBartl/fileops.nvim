# Keymaps

Registered only when `setup()` is called, and only for keys whose `lhs` entry
resolves to a string (see [Configuration](configuration.md)).

**Cycle** (`keymaps.cycle = true`):

| Key | Action |
|---|---|
| `<leader>nf` | Next file (replace) |
| `<leader>pf` | Previous file (replace) |
| `<leader>nfn` | Next file (current) |
| `<leader>pfn` | Previous file (current) |
| `<leader>nF` | Next file (background) |
| `<leader>pF` | Previous file (background) |
| `<leader>NF` | Next file (vsplit) |
| `<leader>PF` | Previous file (vsplit) |

All cycle keymaps respect `v:count1`.

**Delete** (`keymaps.delete = true`):

| Key | Action |
|---|---|
| `<leader>dcf` | Delete current file + close buffer |

Disable or remap a single key without touching the rest of the family:

```lua
require("fileops").setup({
  keymaps = {
    lhs = {
      next_replace = false,       -- disable just <leader>nf
      delete       = "<leader>X", -- remap delete to <leader>X
    },
  },
})
```

## Which-key

[which-key.nvim](https://github.com/folke/which-key.nvim) is an **optional**
soft dependency. When installed, fileops.nvim groups the `<leader>n` and
`<leader>p` prefixes so the cycle family reads as a menu; when absent, this is
a no-op and every key still carries its own `desc`. Supports both which-key v2
(`register`) and v3 (`add`).

For the full keymap/command/autocommand cheatsheet, see
[docs/BINDINGS.md](BINDINGS.md).
