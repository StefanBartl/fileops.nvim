---@module 'fileops.health'
local M = {}

local function ok(msg)
  vim.health.ok(msg)
end

local function warn(msg)
  vim.health.warn(msg)
end

local function start(msg)
  vim.health.start(msg)
end

function M.check()
  start("fileops")

  -- Neovim version
  if vim.fn.has("nvim-0.9") == 1 then
    ok("Neovim >= 0.9")
  else
    warn("Neovim 0.9+ recommended (vim.uv may not be available)")
  end

  -- libuv (vim.uv or vim.loop)
  local uv = vim.uv or vim.loop
  if uv then
    ok("libuv available (" .. (vim.uv and "vim.uv" or "vim.loop") .. ")")
  else
    warn("libuv not found; file I/O will fail")
  end

  -- vim.ui.select (used for confirm_on_modified dialog)
  if type(vim.ui) == "table" and type(vim.ui.select) == "function" then
    ok("vim.ui.select is available")
  else
    warn("vim.ui.select is unavailable; confirm_on_modified dialogs will not work")
  end

  -- vim.fs.dir (used for directory listing)
  if vim.fs and type(vim.fs.dir) == "function" then
    ok("vim.fs.dir is available")
  else
    warn("vim.fs.dir is unavailable; :File next / :File prev will not work")
  end

  -- guard flag
  if vim.g.loaded_fileops then
    ok("plugin loaded (vim.g.loaded_fileops = " .. tostring(vim.g.loaded_fileops) .. ")")
  else
    warn("plugin guard not set — call require('fileops').setup() in your config")
  end

  -- treesitter (optional, not required)
  local has_ts = pcall(require, "nvim-treesitter")
  if has_ts then
    ok("nvim-treesitter present (optional)")
  else
    ok("nvim-treesitter not installed (not required)")
  end

  -- lib.nvim: required (:File command layer via lib.nvim.usercmd.composer,
  -- plus ops/file.lua's lib.nvim.cross.fs.mutate and ops/cycle.lua's
  -- lib.nvim.buffer.open_background — both already hard requires with no
  -- pcall, so this plugin has never actually run standalone). Only
  -- notify's own styling is a genuinely soft, cosmetic fallback.
  if pcall(require, "lib.nvim.usercmd.composer") then
    ok("lib.nvim detected (:File command layer available)")
  else
    warn("lib.nvim not found — :File will fail to register; install \"StefanBartl/lib.nvim\"")
  end
  if require("fileops.util.notify").using_lib() then
    ok("lib.nvim.notify in use (styled notifications)")
  else
    ok("lib.nvim.notify not in use — falling back to native vim.notify")
  end

  -- which-key (optional, groups the <leader>n / <leader>p prefixes)
  if require("fileops.bindings.which_key").available() then
    ok('which-key detected (<leader>n / <leader>p grouped)')
  else
    ok("which-key not found — mappings still carry their own descriptions")
  end

  -- git executable (used by on_hold, and by git_aware when opted in)
  if vim.fn.executable("git") == 1 then
    ok("git executable found (required for on_hold; used by git_aware when enabled)")
  else
    warn("git executable not found — on_hold will be a silent no-op, git_aware will fail if enabled")
  end

  -- gitsigns.nvim (optional, on_hold prefers its inline hunk preview)
  if pcall(require, "gitsigns") then
    ok("gitsigns.nvim found (on_hold prefers its inline hunk preview)")
  else
    ok("gitsigns.nvim not found — on_hold falls back to previous-content preview")
  end
end

return M
