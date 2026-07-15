---@meta
---@module 'fileops_nvim.@types'

---@alias FileOps.OpenTarget "replace"|"current"|"split"|"vsplit"|"tab"|"background"
---@alias FileOps.CycleRoot  "buffer_dir"|"cwd"
---@alias FileOps.Direction  "next"|"prev"
---@alias FileOps.CdScope    "window"|"tab"|"global"

---@class FileOps.CycleConfig
---@field open_target?         FileOps.OpenTarget   How to open the target file.
---@field keep_focus?          boolean              Return focus to origin window after split.
---@field include_hidden?      boolean              Include dot-files.
---@field wrap?                boolean              Wrap at directory boundary.
---@field follow_symlinks?     boolean              Resolve symlinks for comparisons.
---@field root?                FileOps.CycleRoot    Which directory to list.
---@field confirm_on_modified? boolean              Prompt when current buffer is modified.
---@field case_insensitive?    boolean              Sort and compare paths case-insensitively.

---@class FileOps.CdConfig
---@field scope?             FileOps.CdScope  cd scope: window (lcd), tab (tcd), global (cd).
---@field refresh_explorers? boolean          Refresh neo-tree/nvim-tree/netrw after cd.

---@class FileOps.KeymapLhs
---@field next_replace?    string|false  Next file, replace buffer.
---@field prev_replace?    string|false  Previous file, replace buffer.
---@field next_current?    string|false  Next file, edit in-place.
---@field prev_current?    string|false  Previous file, edit in-place.
---@field next_background? string|false  Next file, load into buffer list only.
---@field prev_background? string|false  Previous file, load into buffer list only.
---@field next_vsplit?     string|false  Next file, vertical split.
---@field prev_vsplit?     string|false  Previous file, vertical split.
---@field delete?          string|false  Delete current file + close buffer.

---@class FileOps.KeymapConfig
---@field cycle?  boolean          Master switch: register cycle (next/prev) keymaps.
---@field delete? boolean          Master switch: register delete-current-file keymap.
---@field lhs?    FileOps.KeymapLhs  Per-key lhs overrides; `false` disables a single key.

---@class FileOps.AutoMkdirConfig
---@field enable?                boolean  Auto-create parent dirs on BufWritePre. Default: true.
---@field skip_remote?           boolean  Skip remote/URL-style buffers (e.g. scheme://). Default: true.
---@field detect_remote_pattern? string   Lua pattern to detect remote buffers. Default: "^%w%w+:[\\/][\\/]".

---@class FileOps.Config
---@field cycle?      FileOps.CycleConfig      File-cycle options.
---@field cd?         FileOps.CdConfig         Change-directory options.
---@field keymaps?    FileOps.KeymapConfig     Keymap registration flags.
---@field commands?   boolean                  Register all user commands (default: true).
---@field auto_mkdir? FileOps.AutoMkdirConfig  Auto-create parent dirs before writing (default: enabled).

---@class FileOps.CycleState
---@field config FileOps.CycleConfig

return {}
