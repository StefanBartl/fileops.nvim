-- docs/TESTS/usrcmds_spec.lua — bindings/usrcmds.lua: the :File dispatcher's
-- prompt_dest() helper (missing-path prompt, shared by 9 subcommands).

return function(H)
  local eq, ok = H.eq, H.ok

  require("fileops.config").setup({})

  -- prompt_dest() must route through kit.input (not a raw vim.ui.input),
  -- so it renders consistently with the author's other plugins. Require
  -- BEFORE cd'ing into the tmp dir below: `set rtp+=.` resolves "." against
  -- the cwd at lookup time, so changing cwd first would break this require.
  local captured_title
  package.loaded["lib.nvim.ui.kit"] = {
    input = function(opts)
      captured_title = opts.title
      opts.on_submit("newfile.txt")
    end,
  }
  package.loaded["fileops.bindings.usrcmds"] = nil
  local usrcmds = require("fileops.bindings.usrcmds")
  usrcmds.register()

  local tmp = H.tmpdir()
  vim.cmd("cd " .. vim.fn.fnameescape(tmp))

  vim.cmd("File touch")

  eq(
    captured_title,
    "File touch: ",
    "prompt_dest: routes through kit.input with the expected prompt"
  )
  ok(
    vim.fn.filereadable(tmp .. "newfile.txt") == 1,
    "prompt_dest: the submitted name is used to create the file"
  )

  package.loaded["lib.nvim.ui.kit"] = nil
end
