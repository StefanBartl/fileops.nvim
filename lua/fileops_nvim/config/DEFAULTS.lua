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
}
