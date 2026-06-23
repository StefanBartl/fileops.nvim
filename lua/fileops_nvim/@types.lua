---@meta
---@module 'fileops_nvim.@types'

---@alias FileOps.OpenTarget "replace"|"current"|"split"|"vsplit"|"tab"|"background"
---@alias FileOps.CycleRoot  "buffer_dir"|"cwd"
---@alias FileOps.Direction  "next"|"prev"

---@class FileOps.CycleConfig
---@field open_target?         FileOps.OpenTarget   How to open the target file.
---@field keep_focus?          boolean              Return focus to origin window after split.
---@field include_hidden?      boolean              Include dot-files.
---@field wrap?                boolean              Wrap at directory boundary.
---@field follow_symlinks?     boolean              Resolve symlinks for comparisons.
---@field root?                FileOps.CycleRoot    Which directory to list.
---@field confirm_on_modified? boolean              Prompt when current buffer is modified.
---@field case_insensitive?    boolean              Sort and compare paths case-insensitively.

---@class FileOps.KeymapConfig
---@field cycle?  boolean   Register cycle (next/prev) keymaps.
---@field delete? boolean   Register delete-current-file keymap.

---@class FileOps.Config
---@field cycle?    FileOps.CycleConfig   File-cycle options.
---@field keymaps?  FileOps.KeymapConfig  Keymap registration flags.
---@field commands? boolean               Register all user commands (default: true).

---@class FileOps.CycleState
---@field config FileOps.CycleConfig

return {}
