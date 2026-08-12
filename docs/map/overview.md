# fileops.nvim — module map

> **Generated** by `documentation`. Do not edit by hand — run `:DocMap`
> (or `nvim --headless -l scripts/gen_map.lua`) to regenerate.

**3 modules** · 4 namespaces · 13 helper files

The [interactive map](index.html) has filtering, full descriptions and
source links; this page is the version the code host renders directly.


## Namespaces

```mermaid
flowchart LR
  nlua["fileops.nvim"]
  nlua_fileops["fileopsbr/smallEntry point for fileops./small"]
  nlua_fileops_bindings["bindingsbr/smallOrchestrates fileops's bindings: usrcmds,…/small"]
  nlua_fileops_config["configbr/smallRuntime config store: merge user options…/small"]
  nlua_fileops_features["features"]
  nlua_fileops_ops["ops"]
  nlua_fileops_util["util"]
  nlua --> nlua_fileops
  nlua_fileops --> nlua_fileops_bindings
  nlua_fileops --> nlua_fileops_config
  nlua_fileops --> nlua_fileops_features
  nlua_fileops --> nlua_fileops_ops
  nlua_fileops --> nlua_fileops_util
```


## Dependencies

Which parts of the tree require which, rolled up to the second level.
The [interactive map](index.html)'s **Deps** view has this per module,
in both directions, with load-time and lazy requires told apart.

```mermaid
flowchart LR
  nlua_fileops_bindings["fileops.bindings"]
  nlua_fileops_config["fileops.config"]
  nlua_fileops_features["features"]
  nlua_fileops_health_lua["fileops.health"]
  nlua_fileops_ops["ops"]
  nlua_fileops_util["util"]
  nlua_fileops_bindings --> nlua_fileops_config
  nlua_fileops_bindings --> nlua_fileops_features
  nlua_fileops_bindings --> nlua_fileops_ops
  nlua_fileops_bindings --> nlua_fileops_util
  nlua_fileops_health_lua --> nlua_fileops_bindings
  nlua_fileops_health_lua --> nlua_fileops_util
  nlua_fileops_ops --> nlua_fileops_util
```


## Modules

| Module | Description | Fns | Docs |
|---|---|---|---|
| `fileops` | Entry point for fileops. | 17 | [src](../../lua/fileops/init.lua) |
| &nbsp;&nbsp;`fileops.bindings` | Orchestrates fileops's bindings: usrcmds, keymaps, which-key. | 1 | [src](../../lua/fileops/bindings/init.lua) |
| &nbsp;&nbsp;`fileops.config` | Runtime config store: merge user options over DEFAULTS, expose get(). | 2 | [src](../../lua/fileops/config/init.lua) |
| &nbsp;&nbsp;`features` |  |  |  |
| &nbsp;&nbsp;`ops` |  |  |  |
| &nbsp;&nbsp;`util` |  |  |  |

## Drift

0 errors · 0 warnings · 4 info

No errors or warnings.


<details>
<summary>4 informational findings</summary>


| Check | Message |
|---|---|
| `missing-readme` | lua/fileops has no README.md |
| `missing-readme` | lua/fileops/bindings has no README.md |
| `missing-readme` | lua/fileops/config has no README.md |
| `unreferenced-module` | fileops.health is required by no other file in the tree |

</details>
