---@module 'fileops_nvim.bindings.which_key'
---Optional, guarded which-key group labels for fileops_nvim's cycle prefixes.
---which-key is a soft dependency: a no-op when it is not installed. Individual
---keys already carry their own `desc` (see bindings/keymaps.lua), so only the
---shared `<leader>n` / `<leader>p` group labels are registered here. Supports
---both which-key v3 (`add`) and v2 (`register`) APIs.
local M = {}

---Register fileops_nvim's group labels with which-key, if available.
---@return boolean registered
function M.setup()
  local ok, wk = pcall(require, "which-key")
  if not ok or type(wk) ~= "table" then
    return false
  end

  if type(wk.add) == "function" then
    wk.add({
      { "<leader>n", group = "fileops: next file" },
      { "<leader>p", group = "fileops: prev file" },
    })
    return true
  elseif type(wk.register) == "function" then
    wk.register({
      ["<leader>n"] = { name = "+fileops: next file" },
      ["<leader>p"] = { name = "+fileops: prev file" },
    })
    return true
  end

  return false
end

---Whether which-key is installed (for :checkhealth reporting).
---@return boolean
function M.available()
  local ok, wk = pcall(require, "which-key")
  return ok and type(wk) == "table"
end

return M
