# fileops.nvim — Documentation

Everything written down about fileops.nvim, and what each page is for.
The [repository README](../README.md) is the short version; this is the index.

## Start here

| Page | What it answers |
|---|---|
| [installation.md](installation.md) | How do I install it, and what does it need? |
| [WORKFLOW.md](WORKFLOW.md) | What does using this look like day to day? |
| [FEATURES/](FEATURES/README.md) | What can it actually do? |

## Reference

| Page | What it answers |
|---|---|
| [commands.md](commands.md) | What does each `:File` subcommand do, with which arguments? |
| [configuration.md](configuration.md) | Which `setup()` options exist, and what are their defaults? |
| [keymaps.md](keymaps.md) | Which keys are bound, and how do I override them? |
| [autocommands.md](autocommands.md) | Which autocommands does the plugin create, and which events does it emit? |
| [BINDINGS.md](BINDINGS.md) | All of the above at a glance — one table per binding kind. |
| [api.md](api.md) | Which Lua functions can I call directly? |

## Under the hood

| Page | What it answers |
|---|---|
| [architecture.md](architecture.md) | How are the modules laid out, and why? |

There is no module map in this repository. `:DocMap` builds one from the
current tree in seconds (`:DocMap full` for LuaLS-enriched detail), which is
why the generated output is gitignored rather than committed: it would be
stale by the next commit.

## Conventions

Two argument conventions run through every command and are worth knowing once:

- **`!`** overrides safety checks — the existing-file guard and the
  modified-buffer confirmation.
- **`%`** is an explicit "current file" scope. It is always implied when
  omitted, so it exists only to make a command read unambiguously.

Every `[path]` and `[dest]` argument is optional. Omitting one opens a
`vim.ui.input` prompt instead of raising an error.
