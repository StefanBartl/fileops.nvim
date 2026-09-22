---@module 'fileops.bindings.autocmds'
---Autocommand registration for fileops. Called only from bindings.setup().
local M = {}

local file = require("fileops.ops.file")
local autocmd = require("lib.nvim.bindings.autocmd")

local GROUP = "fileops_auto_mkdir"

---Register the BufWritePre auto-mkdir autocmd if `cfg.enable`.
---Creates the parent directory of the file about to be written, reusing the
---same `file.ensure_parent` logic behind `:File mkdir`.
---@param cfg FileOps.AutoMkdirConfig
function M.attach_auto_mkdir(cfg)
  cfg = cfg or {}
  if cfg.enable == false then
    return
  end

  local pattern = cfg.detect_remote_pattern or "^%w%w+:[\\/][\\/]"

  -- `autocmd.group(name, true)` drops this module's binding-table *records*
  -- along with its autocmds, so a re-run can't leave stale rows behind.
  local grp = autocmd.group(GROUP, true)

  autocmd.create("BufWritePre", function(event)
    if cfg.skip_remote ~= false and event.match:match(pattern) then
      return
    end
    file.ensure_parent(event.match)
  end, {
    group = grp,
    desc = "[fileops] Create parent directories before writing a file",
  })
end

---Register the ambient CursorHold/CursorHoldI line-diff preview autocmds if `cfg.enable`.
---@param cfg FileOps.OnHoldConfig
function M.attach_on_hold(cfg)
  require("fileops.features.on_hold").setup(cfg)
end

---Register the BufWinEnter/BufWinLeave conflict-marker highlight autocmds if `cfg.enable`.
---@param cfg FileOps.ConflictMarksConfig
function M.attach_conflict_marks(cfg)
  require("fileops.features.conflict_marks").setup(cfg)
end

local GITSUITE_EVENTS_GROUP = "fileops_gitsuite_events"

---@internal
---Path to hand `file.notify_change()` for one of gitsuite.nvim's events --
---the repo root for a branch switch (the whole tree may have changed), the
---buffer's own file for a conflict resolution (exactly one file changed).
---@param event { match: string, data: table|nil }
---@return string|nil
local function gitsuite_event_path(event)
  local data = event.data or {}
  if event.match == "GitsuiteBranchSwitched" then
    return data.dir
  end
  local bufnr = data.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and name or nil
end

---Register the `User GitsuiteBranchSwitched`/`GitsuiteConflictsResolved`
---explorer-refresh autocmd if `cfg.enable` (GS-25). No dependency on
---gitsuite.nvim either way: these `User` events simply never fire without
---it installed, so this is a plain, always-safe autocmd registration.
---@param cfg FileOps.GitsuiteEventsConfig
function M.attach_gitsuite_events(cfg)
  cfg = cfg or {}
  if cfg.enable == false then
    return
  end

  local grp = autocmd.group(GITSUITE_EVENTS_GROUP, true)

  autocmd.create("User", function(event)
    local path = gitsuite_event_path(event)
    if not path then
      return
    end
    local action = event.match == "GitsuiteBranchSwitched" and "git-checkout"
      or "git-conflict-resolved"
    file.notify_change(action, path)
  end, {
    group = grp,
    pattern = { "GitsuiteBranchSwitched", "GitsuiteConflictsResolved" },
    desc = "[fileops] Refresh explorers after a gitsuite.nvim branch switch or conflict resolution",
  })
end

return M
