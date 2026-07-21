# Configuration

```lua
require("fileops_nvim").setup({
  -- Options for :File next / :File prev
  cycle = {
    open_target         = "replace",    -- "replace"|"current"|"split"|"vsplit"|"tab"|"background"
    keep_focus          = true,         -- Return focus to origin after split/vsplit
    include_hidden      = false,        -- Include dot-files in directory listing
    wrap                = true,         -- Wrap around at directory boundary
    follow_symlinks     = true,         -- Resolve symlinks for comparisons
    root                = "buffer_dir", -- "buffer_dir"|"cwd"|"buffer_dir_recursive"|"cwd_recursive"
    confirm_on_modified = true,         -- vim.ui.select prompt when buffer is modified
    case_insensitive    = true,         -- Case-insensitive sort and comparison
    pattern             = nil,          -- Glob filter (e.g. "*.lua"), overridable via :File next's [glob] arg
  },
  -- Options for :File cd
  cd = {
    scope             = "window", -- "window" (:lcd) | "tab" (:tcd) | "global" (:cd)
    refresh_explorers = true,     -- Refresh neo-tree/nvim-tree/netrw after cd
  },
  -- Refresh tree explorers after any file op that changes the tree
  explorer = {
    refresh_on_change = true, -- reload neo-tree/nvim-tree after create/rename/move/duplicate/copy/delete
                               -- (a `User FileopsChanged` autocmd fires either way)
  },
  -- Options for :File[!] delete
  delete = {
    mode             = "permanent", -- "permanent" (fs_unlink) | "trash" (OS trash/recycle bin)
    on_before_delete = nil,         -- fun(path: string): boolean|nil — return false to abort
  },
  -- Git-tracked-file awareness for rename/move/duplicate/copy/delete
  git_aware = {
    enable    = false, -- master switch (opt-in — shells out to `git ls-files`)
    warn_only = true,  -- true: note tracked-ness in the result message only, still use libuv
                        -- false: use `git mv`/`git rm` for tracked files (delete: only when mode = "permanent")
    git_cmd   = "git",
  },
  keymaps = {
    cycle  = true,   -- master switch: <leader>nf/pf family
    delete = true,   -- master switch: <leader>dcf
    -- Per-key overrides: set an entry to `false` to disable just that one
    -- keymap, or to a different string to remap it. Master switches above
    -- still gate the whole family.
    lhs = {
      next_replace    = "<leader>nf",
      prev_replace    = "<leader>pf",
      next_current    = "<leader>nfn",
      prev_current    = "<leader>pfn",
      next_background = "<leader>nF",
      prev_background = "<leader>pF",
      next_vsplit     = "<leader>NF",
      prev_vsplit     = "<leader>PF",
      delete          = "<leader>dcf",
    },
  },
  commands = true,   -- Register :File
  -- Auto-create parent dirs on save (BufWritePre) — automatic counterpart to :File mkdir
  auto_mkdir = {
    enable                = true,
    skip_remote           = true,
    detect_remote_pattern = "^%w%w+:[\\/][\\/]", -- e.g. "ssh://", "http://"
  },
  -- Ambient CursorHold line-diff preview (opt-in)
  on_hold = {
    enable = false,
    modes = "n", -- "n"|"v"|"i" (any combination) or array; nil = n+v
    delay = 3000, -- extra debounce (ms) beyond 'updatetime'
    throttle_ms = 1200, -- min time (ms) between triggers per window
    git_cmd = "git",
    ignore_buftypes = { "nofile", "prompt", "terminal" },
    only_tracked = true, -- skip files not tracked by git
    require_clean_buffer = false, -- skip if buffer has unsaved changes
    prefix = "previous: ", -- prefix before fallback EOL preview text
    right_align = false, -- place virt_text right-aligned instead of eol
    max_len = 160, -- truncate fallback preview to this many characters
    hl_prev = "Comment",
    virt_priority = 1000,
    prefer_inline = true, -- prefer gitsigns.preview_hunk_inline() when available
    restore_view = true, -- save/restore winsaveview()+cursor to avoid scroll jumps
    events_override = nil, -- fully override auto-mapped events
  },
  -- Highlight Git conflict markers (<<<<<<< / ======= / >>>>>>>)
  conflict_marks = {
    enable = true,
    hl_a = "DiffDelete",
    hl_b = "DiffChange",
    hl_c = "DiffAdd",
  },
})
```

See [Keymaps](keymaps.md) for details on the `keymaps` table, and
[Autocommands](autocommands.md) for `auto_mkdir`, `on_hold`, and
`conflict_marks`.
