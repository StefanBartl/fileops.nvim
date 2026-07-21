-- docs/TESTS/file_spec.lua — ops/file.lua: copy/move/touch and friends.

return function(H)
  local eq, ok = H.eq, H.ok
  local file = require("fileops_nvim.ops.file")

  local dir = H.tmpdir()
  local src = dir .. "src.lua"
  H.write_file(src, "-- src")

  -- copy: creates the destination, does NOT switch the current buffer
  H.edit(src)
  local dest = dir .. "src_copy.lua"
  local cok, cmsg = file.copy(dest)
  ok(cok, "copy succeeds: " .. tostring(cmsg))
  eq(vim.fn.filereadable(dest), 1, "copy: destination file exists")
  eq(vim.fn.expand("%:p"), vim.fn.fnamemodify(src, ":p"), "copy: current buffer name unchanged")

  -- copy refuses to overwrite without bang
  local cok2, cmsg2 = file.copy(dest)
  ok(not cok2, "copy without bang refuses existing destination: " .. tostring(cmsg2))

  -- copy! overwrites
  local cok3 = file.copy(dest, { bang = true })
  ok(cok3, "copy! overwrites existing destination")

  -- move: renames on disk, updates the buffer name, does NOT reload the
  -- buffer (undo history survives — a fresh :edit would reset it to 0)
  local src2 = dir .. "movable.lua"
  H.write_file(src2, "line1")
  H.edit(src2)
  vim.api.nvim_buf_set_lines(0, 0, 1, false, { "line1 changed" })
  ok(vim.fn.undotree().seq_cur > 0, "setup: buffer has undo history before move")

  local dest2 = dir .. "moved.lua"
  local mok, mmsg = file.move(dest2)
  ok(mok, "move succeeds: " .. tostring(mmsg))
  eq(vim.fn.filereadable(dest2), 1, "move: destination file exists")
  eq(vim.fn.filereadable(src2), 0, "move: source file no longer exists")
  eq(vim.fn.expand("%:p"), vim.fn.fnamemodify(dest2, ":p"), "move: buffer renamed to destination")
  ok(vim.fn.undotree().seq_cur > 0, "move: undo history preserved (buffer not reloaded)")

  -- move refuses to overwrite without bang, move! overwrites
  local other = dir .. "other.lua"
  H.write_file(other, "other")
  H.edit(other)
  local mok2, mmsg2 = file.move(dest2)
  ok(not mok2, "move without bang refuses existing destination: " .. tostring(mmsg2))
  local mok3 = file.move(dest2, { bang = true })
  ok(mok3, "move! overwrites existing destination")
end
