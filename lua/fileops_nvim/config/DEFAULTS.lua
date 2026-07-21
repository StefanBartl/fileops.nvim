---@module 'fileops_nvim.config.DEFAULTS'
---Immutable default configuration. Deep-merged with user opts in config/init.lua.

---@type FileOps.Config
return {
  cycle = {
    open_target         = "replace",
    keep_focus          = true,
    include_hidden      = false,
    wrap                = true,
    follow_symlinks     = true,
    root                = "buffer_dir",
    confirm_on_modified = true,
    case_insensitive    = true,
  },
  cd = {
    scope             = "window",  -- "window" (lcd) | "tab" (tcd) | "global" (cd)
    refresh_explorers = true,      -- refresh neo-tree/nvim-tree/netrw after cd
  },
  delete = {
    mode              = "permanent", -- "permanent" (fs_unlink) | "trash" (OS trash/recycle bin)
    on_before_delete  = nil,         -- fun(path: string): boolean|nil — return false to abort
  },
  keymaps = {
    cycle  = true,
    delete = true,
    -- Individual lhs overrides. Set any entry to `false` to disable just that
    -- one keymap, or to a different string to remap it. Master switches above
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
  commands = true,
  auto_mkdir = {
    enable                 = true,
    skip_remote            = true,
    detect_remote_pattern  = "^%w%w+:[\\/][\\/]", -- e.g. "ssh://", "http://", "file://" (both slash styles)
  },
  on_hold = {
    enable = false, -- master switch for this feature; opt-in explicitly in your setup() spec
    modes = "n", -- "n"|"v"|"i" (any combination) or array; nil = n+v
    delay = 3000, -- extra debounce (ms) beyond 'updatetime'
    throttle_ms = 1200, -- min time (ms) between triggers per window
    git_cmd = "git", -- git executable to use
    ignore_buftypes = { "nofile", "prompt", "terminal" },
    only_tracked = true, -- skip files not tracked by git
    require_clean_buffer = false, -- skip if buffer has unsaved changes
    prefix = "previous: ", -- prefix before fallback EOL preview text
    right_align = false, -- place virt_text right-aligned instead of eol
    max_len = 160, -- truncate fallback preview to this many characters
    hl_prev = "Comment", -- highlight group for fallback preview text
    virt_priority = 1000, -- extmark virt_text priority
    prefer_inline = true, -- prefer gitsigns.preview_hunk_inline() when available
    restore_view = true, -- save/restore winsaveview()+cursor to avoid scroll jumps
    events_override = nil, -- fully override auto-mapped events
  },
  conflict_marks = {
    enable = true,
    hl_a = "DiffDelete", -- "<<<<<<<" lines
    hl_b = "DiffChange", -- "=======" separator
    hl_c = "DiffAdd",    -- ">>>>>>>" lines
  },
}
