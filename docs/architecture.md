# Architecture

```
lua/fileops_nvim/
  init.lua              Public API + setup()
  config/
    init.lua             Merge user opts over DEFAULTS, expose get()
    DEFAULTS.lua          Immutable default configuration
  @types/init.lua        LuaLS type annotations
  bindings/
    init.lua              Orchestrates usrcmds + keymaps + autocmds + which-key
    usrcmds.lua           Single :File command with subcommand dispatch
    keymaps.lua           Per-key configurable vim.keymap.set registrations
    autocmds.lua           auto_mkdir/on_hold/conflict_marks registration
    which_key.lua         Optional which-key group labels (soft dependency)
  health.lua             :checkhealth fileops_nvim
  util/
    notify.lua            "[fileops] " prefixed notifier; upgrades to
                           lib.nvim.notify when lib.nvim is installed
  ops/
    cycle.lua              Directory listing, indexing, navigation, open_path
    file.lua               Create, rename, duplicate, delete operations
  features/
    on_hold.lua             Ambient CursorHold line-diff preview
    conflict_marks.lua      Conflict-marker highlighting
plugin/
  fileops_nvim.lua        Load guard
docs/
  BINDINGS.md             Cheatsheet of every keymap, user command, autocmd
  ROADMAP.md              Planned features
  TESTS/                  Headless spec suite (see docs/TESTS/README.md)
```

All file I/O uses `vim.uv` (libuv) — no shell, no injection risk, fully
cross-platform. `lib.nvim` is a **required** dependency (see
[Requirements](installation.md#requirements)): it supplies the `:File`
command layer (`lib.nvim.usercmd.composer`), the injection-safe file
primitives behind create/rename/duplicate/delete (`lib.nvim.cross.fs.mutate`),
and background buffer opening (`lib.nvim.buffer.open_background`). Only
notifications are a genuinely soft, cosmetic fallback: if `lib.nvim.notify`
is present it is used for styling; otherwise fileops.nvim falls back to
plain `vim.notify`.
