# Installation

## Requirements

- Neovim **0.9+**
- [lib.nvim](https://github.com/StefanBartl/lib.nvim) — **required**. Supplies
  the `:File` command layer (`lib.nvim.bindings.usercmd.composer`), notifications, the
  injection-safe file primitives behind create/rename/duplicate/delete
  (`lib.nvim.cross.fs.mutate`), and background buffer opening

No CLI tools are required — all I/O goes through libuv directly, which is
what keeps behaviour identical on Windows and Unix.

### Optional

Each detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| [filetree.nvim](https://github.com/StefanBartl/filetree.nvim), neo-tree, nvim-tree | Refreshed in place after a tree-changing operation |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | Labels for the optional keymaps |
| [nvzone/menu](https://github.com/nvzone/menu) | A host for the context-menu entries — see [Integrations](FEATURES/INTEGRATIONS.md) |

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

`event = "VeryLazy"` rather than `cmd = "File"`: the `User FileopsChanged`
autocmd and the explorer refresh have to be live before the first operation,
not after it.

### packer.nvim / pckr.nvim

```lua
use({
  "StefanBartl/fileops.nvim",
  requires = { "StefanBartl/lib.nvim" }, -- required
  config = function()
    require("fileops").setup()
  end,
})
```

### vim-plug

```vim
Plug 'StefanBartl/lib.nvim'  " required
Plug 'StefanBartl/fileops.nvim'
```
```lua
require("fileops").setup()
```

See [Configuration](configuration.md) for all available `setup()` options.
