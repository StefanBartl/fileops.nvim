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

---@alias FileOps.OnHoldMode
---| '"n"'  # Normal mode
---| '"v"'  # Visual mode
---| '"i"'  # Insert mode

---@class FileOps.OnHoldConfig
--- Ambient, mode-aware line-diff preview on CursorHold/CursorHoldI. Prefers
--- gitsigns' `preview_hunk_inline()`; falls back to rendering the previous
--- committed content of the current line as EOL/right-aligned virtual text.
---@field enable?               boolean  Master switch for this feature. Default: true.
---@field modes?                (FileOps.OnHoldMode|string)[]|string|nil  Mode filter (any combination, e.g. "nv") or array. Default: nil (Normal+Visual).
---@field events_override?      string[]|nil  Fully replace the auto-mapped events, e.g. { "CursorHold", "CursorHoldI" }.
---@field delay?                integer|nil  Extra debounce (ms) beyond 'updatetime'. Default: 3000.
---@field throttle_ms?          integer|nil  Min time (ms) between triggers per window. Default: 1200.
---@field git_cmd?              string|nil  Git executable to use. Default: "git".
---@field ignore_buftypes?      string[]|nil  Skip these buftypes. Default: { "nofile", "prompt", "terminal" }.
---@field only_tracked?         boolean|nil  Skip files not tracked by git. Default: true.
---@field require_clean_buffer? boolean|nil  Skip if buffer has unsaved changes. Default: false.
---@field prefix?               string|nil  Prefix before the fallback EOL preview. Default: "previous: ".
---@field right_align?          boolean|nil  Place virt_text right-aligned instead of eol. Default: false.
---@field max_len?              integer|nil  Truncate fallback preview to this many characters. Default: 160.
---@field hl_prev?              string|nil  Highlight group for fallback preview text. Default: "Comment".
---@field virt_priority?        integer|nil  Extmark virt_text priority. Default: 1000.
---@field prefer_inline?        boolean|nil  Prefer gitsigns.preview_hunk_inline() when available. Default: true.
---@field restore_view?         boolean|nil  Save/restore winsaveview()+cursor around the inline preview. Default: true.

---@class FileOps.ConflictMarksConfig
--- Highlight Git conflict markers (<<<<<<< / ======= / >>>>>>>) per-window.
---@field enable? boolean     Master switch for this feature. Default: true.
---@field hl_a?   string|nil  Highlight group for "<<<<<<<" lines. Default: "DiffDelete".
---@field hl_b?   string|nil  Highlight group for "=======" separator. Default: "DiffChange".
---@field hl_c?   string|nil  Highlight group for ">>>>>>>" lines. Default: "DiffAdd".

---@class FileOps.Config
---@field cycle?          FileOps.CycleConfig          File-cycle options.
---@field cd?             FileOps.CdConfig             Change-directory options.
---@field keymaps?        FileOps.KeymapConfig         Keymap registration flags.
---@field commands?       boolean                      Register all user commands (default: true).
---@field auto_mkdir?     FileOps.AutoMkdirConfig      Auto-create parent dirs before writing (default: enabled).
---@field on_hold?        FileOps.OnHoldConfig         Ambient CursorHold line-diff preview (default: disabled; opt-in).
---@field conflict_marks? FileOps.ConflictMarksConfig  Conflict-marker highlighting (default: enabled).

---@class FileOps.CycleState
---@field config FileOps.CycleConfig

return {}
