# Planned / ideas

Nothing is currently blocking a release. The items below are backlog ideas,
not commitments — pick them up opportunistically:

- Async variants of the `git_aware`/`on_hold` git shell-outs
  (`vim.system(..., { ... }, callback)`) to avoid blocking the UI thread on
  large repos or slow filesystems (network shares, WSL interop).
- Optional integration test against a real `neo-tree`/`nvim-tree` instance in
  CI (currently only unit-level coverage of the fileops side).


---
