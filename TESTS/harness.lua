-- TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by TESTS/run.lua.

local H = {}

--- How many assertions have run so far, across every spec.
---
--- Counted rather than read off the source: most specs assert inside loops or
--- helper functions, so the number of `eq`/`ok` call *sites* says very little
--- about how much was actually checked. `run.lua` reports the per-spec delta
--- and the total.
---@type integer
H.checks = 0

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  H.checks = H.checks + 1
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  H.checks = H.checks + 1
  if not v then
    error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Create a fresh, empty scratch directory under vim.fn.tempname().
---
--- Handed out with symlinks already resolved, which is what makes this suite
--- comparable to the paths the plugin reports. On macOS `$TMPDIR` is
--- `/var/folders/…` and `/var` is a symlink to `/private/var`: Neovim resolves
--- that when it names a buffer on Unix (`fix_fname`) and `getcwd()` reports
--- the resolved form too, while `fnamemodify(…, ":p")` leaves the raw
--- spelling alone. A spec that joined an expected path onto the
--- raw `tempname()` and compared it against a path the plugin had read off a
--- buffer was therefore comparing the two spellings of one directory and
--- failing on the difference alone.
---
--- Resolving here rather than at each assertion keeps the fixture in the one
--- spelling the platform itself uses, so both sides of such a comparison start
--- out equal and a real disagreement still shows. A no-op on Linux and
--- Windows, where the temp directory is not reached through a symlink.
---@return string dir  Absolute path with a trailing slash.
function H.tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local uv = vim.uv or vim.loop
  local real = uv.fs_realpath and uv.fs_realpath(dir)
  if type(real) == "string" and real ~= "" then
    dir = real
  end
  return vim.fn.fnamemodify(dir, ":p")
end

--- Write `content` to `path`, creating parent directories.
---@param path string
---@param content string|nil
function H.write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local fd = assert(io.open(path, "w"))
  fd:write(content or "")
  fd:close()
end

--- Open `path` as the current buffer of the current window (scratch, no swap noise).
---@param path string
---@return integer bufnr
function H.edit(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

--- Whether this suite is running on native Windows.
---
--- Used by the specs that pin platform-specific path behaviour: a path is
--- joined with `/` in several places here and compared against a buffer name
--- Neovim spells with `\`, which only differ on Windows.
---@return boolean
function H.is_windows()
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

--- Run `fn` with `vim.notify` captured, and return everything it emitted.
---
--- The seam is `vim.notify` rather than `fileops.util.notify`: every module
--- here binds that module's functions at load time, so replacing the module
--- in `package.loaded` afterwards would capture nothing. lib.nvim's notifier
--- (which `util/notify.lua` upgrades to when lib.nvim is present, as it is in
--- this suite) ends at `vim.notify` too, so both paths land here.
---
--- Deliberately swallowed rather than forwarded: Neovim renders an
--- ERROR-level notification as a real error message, and one raised from
--- inside a `:File …` invocation would abort `vim.cmd` — turning "the command
--- reported a failure", which several cases here assert, into a spec crash.
---@param fn fun()
---@return { msg: string, level: integer|nil }[]
function H.notifications(fn)
  local seen = {}
  local real = vim.notify
  vim.notify = function(msg, level, _opts)
    seen[#seen + 1] = { msg = tostring(msg), level = level }
  end
  local ok, err = pcall(fn)
  vim.notify = real
  if not ok then
    error(err, 0)
  end
  return seen
end

--- Whether any captured notification contains `needle` (plain substring).
---@param seen { msg: string, level: integer|nil }[]
---@param needle string
---@return boolean
function H.notified(seen, needle)
  for _, n in ipairs(seen) do
    if n.msg:find(needle, 1, true) then
      return true
    end
  end
  return false
end

--- Put `value` on `package.loaded[name]` and return a restore function.
---
--- The specs stub modules that are not on this suite's runtimepath (`ui.kit`,
--- `ui.contextmenu`, `filetree.refs`) or that would shell out to the OS
--- (`lib.nvim.fs.trash`, `lib.nvim.cross.fs.lock`). Always paired with its
--- restore so the next spec sees the real module again.
---@param name string
---@param value any
---@return fun() restore
function H.stub(name, value)
  local previous = package.loaded[name]
  package.loaded[name] = value
  return function()
    package.loaded[name] = previous
  end
end

return H
