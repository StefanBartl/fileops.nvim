# Quickstart

Rename the file you are in — disk and buffer together, prompting for the new
name:

```vim
:File rename
```

Then the rest follows the same shape; omit an argument and it asks:

```vim
:File duplicate            " copy it and open the copy
:File path rel             " the cwd-relative path, to the clipboard
:File next *.lua           " next Lua file in this directory
:File info                 " size, mtime, permissions
:File delete!              " delete it and force-close the buffer
```

Verify your setup any time with:

```vim
:checkhealth fileops
```

Full usage and examples for every subcommand: [commands.md](commands.md). For
the day-to-day gotchas — which subcommands resolve a relative path against the
buffer's directory vs. the cwd, the delete guard, `git_aware` semantics — see
[WORKFLOW.md](WORKFLOW.md).
