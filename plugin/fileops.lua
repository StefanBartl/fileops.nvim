-- Plugin guard — prevents double-loading.
if vim.g.loaded_fileops then
  return
end

-- Nothing is registered here on purpose.
-- All commands and keymaps are created by require('fileops').setup().
-- This file exists so that lazy.nvim knows the plugin entry point.
