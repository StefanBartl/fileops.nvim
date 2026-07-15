---@module 'fileops_nvim.health'
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
  start("fileops_nvim")

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
  if vim.g.loaded_fileops_nvim then
    ok("plugin loaded (vim.g.loaded_fileops_nvim = " .. tostring(vim.g.loaded_fileops_nvim) .. ")")
  else
    warn("plugin guard not set — call require('fileops_nvim').setup() in your config")
  end

  -- treesitter (optional, not required)
  local has_ts = pcall(require, "nvim-treesitter")
  if has_ts then
    ok("nvim-treesitter present (optional)")
  else
    ok("nvim-treesitter not installed (not required)")
  end

  -- lib.nvim (optional, soft dependency for notify/map)
  if require("fileops_nvim.util.notify").using_lib() then
    ok("lib.nvim detected (using lib.nvim.notify)")
  else
    ok("lib.nvim not found — using native vim.notify (standalone mode)")
  end

  -- which-key (optional, groups the <leader>n / <leader>p prefixes)
  if require("fileops_nvim.bindings.which_key").available() then
    ok('which-key detected (<leader>n / <leader>p grouped)')
  else
    ok("which-key not found — mappings still carry their own descriptions")
  end

  -- git executable (used by the on_hold feature)
  if vim.fn.executable("git") == 1 then
    ok("git executable found (required for on_hold)")
  else
    warn("git executable not found — on_hold will be a silent no-op")
  end

  -- gitsigns.nvim (optional, on_hold prefers its inline hunk preview)
  if pcall(require, "gitsigns") then
    ok("gitsigns.nvim found (on_hold prefers its inline hunk preview)")
  else
    ok("gitsigns.nvim not found — on_hold falls back to previous-content preview")
  end
end

return M
