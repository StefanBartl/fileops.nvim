---@module 'fileops.config'
---Runtime config store: merge user options over DEFAULTS, expose get().
local M = {}

---@type FileOps.Config
M.DEFAULTS = require("fileops.config.DEFAULTS")

---@type FileOps.Config
local _active = vim.deepcopy(M.DEFAULTS)

---Issues found by the last `setup()` call (unknown keys, rejected values),
---for `:checkhealth`. Empty when the config was clean.
---@type string[]
local _issues = {}

-- Known keys per config section, kept in sync with `@types/init.lua`. Listed
-- explicitly rather than derived from `pairs(DEFAULTS)` because a few fields
-- (`delete.on_before_delete`, `on_hold.events_override`, ...) default to
-- `nil` and would otherwise vanish from a scan of DEFAULTS, misreporting a
-- real option as unknown. `true` marks a leaf; a nested table is a section
-- with its own known keys.
---@type table<string, any>
local SCHEMA = {
  cycle = {
    open_target = true,
    keep_focus = true,
    include_hidden = true,
    wrap = true,
    follow_symlinks = true,
    root = true,
    confirm_on_modified = true,
    case_insensitive = true,
    pattern = true,
  },
  cd = { scope = true, refresh_explorers = true },
  explorer = { refresh_on_change = true },
  delete = { mode = true, on_before_delete = true },
  git_aware = { enable = true, warn_only = true, git_cmd = true },
  retry = { attempts = true, backoff_ms = true },
  session_compat = { enable = true },
  keymaps = {
    cycle = true,
    delete = true,
    lhs = {
      next_replace = true,
      prev_replace = true,
      next_current = true,
      prev_current = true,
      next_background = true,
      prev_background = true,
      next_vsplit = true,
      prev_vsplit = true,
      next_filtered = true,
      prev_filtered = true,
      delete = true,
      delete_force = true,
      path = true,
      cd = true,
      info = true,
      lockinfo = true,
      bulk_rename = true,
    },
  },
  commands = true,
  auto_mkdir = { enable = true, skip_remote = true, detect_remote_pattern = true },
  on_hold = {
    enable = true,
    modes = true,
    events_override = true,
    delay = true,
    throttle_ms = true,
    git_cmd = true,
    ignore_buftypes = true,
    only_tracked = true,
    require_clean_buffer = true,
    prefix = true,
    right_align = true,
    max_len = true,
    hl_prev = true,
    virt_priority = true,
    prefer_inline = true,
    restore_view = true,
  },
  conflict_marks = { enable = true, hl_a = true, hl_b = true, hl_c = true },
}

---@internal
---Nearest known key to `key`, as a hint, or nil when nothing is close enough
---to be a plausible typo.
---@param key string
---@param known string[]
---@return string|nil
local function suggest(key, known)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local best, best_d = nil, nil
  for _, k in ipairs(known) do
    local d = levenshtein(key, k)
    if d <= 3 and (best_d == nil or d < best_d) then
      best, best_d = k, d
    end
  end
  return best
end

---@internal
---Drop, in place, any key `opts` has that `schema` doesn't -- recording one
---issue per drop -- and recurse into sub-tables `schema` marks as sections.
---A section-shaped key whose value is not itself a table is dropped too, so
---it degrades to the section's defaults instead of surviving as a scalar
---that every consumer of that section would have to guard against.
---@param opts table
---@param schema table
---@param prefix string
---@param issues string[]
local function drop_unknown(opts, schema, prefix, issues)
  local known = {}
  for k in pairs(schema) do
    known[#known + 1] = k
  end

  for key, value in pairs(opts) do
    local expected = schema[key]
    if expected == nil then
      local hint = type(key) == "string" and suggest(key, known)
      issues[#issues + 1] = hint
          and ("unknown option %q (did you mean %q?)"):format(prefix .. tostring(key), hint)
        or ("unknown option %q"):format(prefix .. tostring(key))
      opts[key] = nil
    elseif type(expected) == "table" then
      if type(value) == "table" then
        drop_unknown(value, expected, prefix .. key .. ".", issues)
      else
        issues[#issues + 1] = ("option %q must be a table; using defaults for it"):format(
          prefix .. key
        )
        opts[key] = nil
      end
    end
    -- expected == true: a leaf. Left unchecked -- several accept a type
    -- union DEFAULTS' own value doesn't capture (`on_hold.modes` is a
    -- string default but an array is equally valid; `keymaps.lhs.*` is a
    -- string default but `false` disables the key) -- so a generic
    -- "matches the default's type" check would reject legitimate values.
  end
end

---@internal
---Reject an unrecognized `delete.mode`, degrading to the default ("trash")
---instead of silently landing on its opposite ("permanent", no undo).
---@param opts table
---@param issues string[]
local function validate_delete_mode(opts, issues)
  local d = opts.delete
  if type(d) ~= "table" or d.mode == nil then
    return
  end
  if d.mode ~= "trash" and d.mode ~= "permanent" then
    issues[#issues + 1] = ('delete.mode %q is not "trash" or "permanent"; using default %q'):format(
      tostring(d.mode),
      M.DEFAULTS.delete.mode
    )
    d.mode = nil
  end
end

---@internal
---Copy `src` into `dst` in place: a sub-table `dst` already has keeps its
---identity, only its contents change. `bindings.autocmds` hands sub-tables
---of this config straight to feature modules (`auto_mkdir`, `on_hold`,
---`conflict_marks`), which keep that reference alive in their autocmd
---closures for the rest of the session -- replacing the table wholesale on a
---second `setup()` would silently decouple those closures from the new
---values.
---@param dst table
---@param src table
local function deep_assign(dst, src)
  for k in pairs(dst) do
    if src[k] == nil then
      dst[k] = nil
    end
  end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deep_assign(dst[k], v)
    else
      dst[k] = v
    end
  end
end

---Merge user opts over defaults and store result. Unknown keys (typos in a
---nested option included) and an invalid `delete.mode` are reported here,
---before the merge, and dropped rather than silently kept -- see `issues()`.
---@param user_opts FileOps.Config|nil
---@return FileOps.Config
function M.setup(user_opts)
  local issues = {}
  local opts = user_opts and vim.deepcopy(user_opts) or {}

  drop_unknown(opts, SCHEMA, "", issues)
  validate_delete_mode(opts, issues)
  _issues = issues

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.DEFAULTS), opts)
  deep_assign(_active, merged)
  return _active
end

---Return the active config (read-only view).
---@return FileOps.Config
function M.get()
  return _active
end

---Validation issues from the last `setup()` call (unknown keys, rejected
---values), for `:checkhealth`. Empty when the config was clean.
---@return string[]
function M.issues()
  return _issues
end

return M
