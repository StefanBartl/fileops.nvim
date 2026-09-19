---@module 'fileops.util.excmd'
---Run a file-taking Ex command on the path it was handed, and no other.
---
---`vim.cmd("edit " .. fn.fnameescape(p))` does not do that. Neovim expands the
---argument of an Ex command marked `XFILE` a second time, as a wildcard, and
---`fnameescape` cannot prevent it:
---
---  * On Windows `[`, `{` and `!` are legal filename characters, so a backslash
---    in front of one would be part of the name rather than an escape.
---    `fnameescape` therefore leaves them unescaped on purpose, and
---    `:edit C:\dir\note[1].txt` opens `C:\dir\note1.txt` instead -- a
---    different file, silently, whenever that one happens to exist.
---  * `~` is never escaped on any platform, and Neovim treats a `~` *anywhere*
---    in the argument as a wildcard, not only a leading one. On Windows that is
---    the everyday case rather than an exotic one: a user name longer than
---    eight characters gets an 8.3 alias, so paths come back spelled
---    `C:\Users\RUNNER~1\...` and every one of them is re-globbed.
---
---`nvim_cmd` with `magic.file = false` skips that expansion entirely, which is
---the only spelling that is correct for every legal path. `magic.bar = false`
---goes with it: a `|` in a filename must not start a second command either.
---
---This is for paths the plugin has already resolved. Expanding what the *user*
---typed is `resolve_path`'s job in `ops/file.lua`, and it deliberately expands
---`~` and `$VAR` without globbing.
local M = {}

---Execute `{cmd} {path}`, using `path` verbatim.
---@param cmd string  Ex command name, e.g. "edit", "saveas", "lcd".
---@param path string  Path argument, passed through unexpanded.
---@param opts? { bang?: boolean }
function M.with_path(cmd, path, opts)
  vim.cmd({
    cmd = cmd,
    args = { path },
    bang = (opts and opts.bang) or false,
    magic = { file = false, bar = false },
  })
end

return M
