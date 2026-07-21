# Autocommands

| Event | augroup | Action |
|---|---|---|
| `BufWritePre` | `fileops_nvim_auto_mkdir` | Create parent directories for the file about to be written — the automatic-on-save counterpart to [`:File mkdir`](commands.md#file-mkdir) |

Gated by `config.auto_mkdir.enable` (default `true`). Disable it entirely:

```lua
require("fileops_nvim").setup({
  auto_mkdir = { enable = false },
})
```

`auto_mkdir.skip_remote` (default `true`) skips buffers whose name matches
`auto_mkdir.detect_remote_pattern` (e.g. `ssh://`, `http://`).

## `on_hold`

On `CursorHold`/`CursorHoldI`, previews what changed on the current line:
prefers gitsigns' inline hunk preview when available, otherwise falls back to
showing the previous committed content of the line as virtual text (via
`git blame`/`git show`, argv-only — no shell). Per-window throttled, mode-aware
(`on_hold.modes`), and cleared on the next cursor move. Sets
`vim.o.updatetime = 100` when enabled, matching the responsiveness the
fallback preview needs.

Gated by `config.on_hold.enable` (default `false` — opt-in). Enable it:

```lua
require("fileops_nvim").setup({
  on_hold = { enable = true },
})
```

## `conflict_marks`

On `BufWinEnter`/`BufWinLeave`, highlights unresolved Git conflict markers
(`<<<<<<<`, `=======`, `>>>>>>>`) using `matchadd`/`matchdelete`, scoped
per-window.

Gated by `config.conflict_marks.enable` (default `true`). Disable it entirely:

```lua
require("fileops_nvim").setup({
  conflict_marks = { enable = false },
})
```

## `User FileopsChanged`

Every op that changes the file tree (`new`, `write`, `saveas`, `writeto`,
`mkdir`, `touch`, `rename`, `move`, `duplicate`, `copy`, `delete`) fires a
`User FileopsChanged` autocmd on success, so any plugin or user config can
react — not just the two tree explorers fileops.nvim knows about directly.

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "FileopsChanged",
  callback = function(ev)
    -- ev.data = { action = "rename"|"move"|"duplicate"|"copy"|"delete"|
    --                      "touch"|"new"|"saveas"|"writeto"|"mkdir",
    --             path = "/abs/path/to/file" }
    vim.notify(ev.data.action .. ": " .. ev.data.path)
  end,
})
```

fileops.nvim itself also reloads neo-tree/nvim-tree in place after these ops
(no root change, unlike `:File cd`), gated by `config.explorer.refresh_on_change`
(default `true`) — the event fires regardless of that setting.

See [Configuration](configuration.md) for the full option list.
