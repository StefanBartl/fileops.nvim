# Lua API

```lua
local fileops = require("fileops")

fileops.next(opts?, count?)          -- :File next equivalent
fileops.prev(opts?, count?)          -- :File prev equivalent
fileops.new_file(path, opts?)        -- :File new
fileops.rename(path, opts?)          -- :File rename
fileops.duplicate(path, opts?)       -- :File duplicate
fileops.delete_current(opts?)        -- :File delete
fileops.cd_here(opts?)               -- :File cd
```

See [Command reference](commands.md) for the equivalent `:File` subcommand
behaviour of each function.
