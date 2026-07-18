# Installation

## Requirements

- Neovim **0.9+**
- [lib.nvim](https://github.com/StefanBartl/lib.nvim) — **required**. Supplies
  notifications, the injection-safe file primitives behind create/rename/
  duplicate/delete (`lib.nvim.cross.fs.mutate`), and background buffer opening

## Installation

**When to use which:**

| Variant | Startup impact | When to use |
|---|---|---|
| `event = "VeryLazy"` | Minimal, after UI init | **Recommended** |
| `lazy = false` | Loads immediately | Small config, want it available instantly |

### lazy.nvim

```lua
{
  "StefanBartl/fileops.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {},
}
```

### packer.nvim / pckr.nvim

```lua
use({
  "StefanBartl/fileops.nvim",
  requires = { "StefanBartl/lib.nvim" }, -- optional
  config = function()
    require("fileops_nvim").setup()
  end,
})
```

### vim-plug

```vim
Plug 'StefanBartl/lib.nvim'  " optional
Plug 'StefanBartl/fileops.nvim'
```
```lua
require("fileops_nvim").setup()
```

See [Configuration](configuration.md) for all available `setup()` options.
