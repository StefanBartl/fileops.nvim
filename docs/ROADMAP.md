# fileops.nvim — Roadmap

## Geplante Features

### Navigation Improvements

- **`:File next/prev` mit Glob-Filter** — z.B. `:File next *.lua` um nur Lua-Dateien zu cyclen
  Erweiterung der `list_files`-Funktion um `pattern`-Option in CycleConfig

- **Aufl isung von Verzeichnis-Tiefe** — optional rekursive Navigation (subdirs einschließen)
  z.B. `root = "buffer_dir_recursive"` als neuer Config-Wert

### File Info

- **`:File info`** — Dateigröße, Änderungsdatum, Permissions (cross-platform via libuv `fs_stat`)
  Ausgabe als floating window oder in der Statuszeile

- **`:File path [mode]`** — Pfad in die Zwischenablage kopieren
  Modi: `abs` (absolut), `rel` (relativ zu cwd), `name` (nur Dateiname), `dir` (nur Ordner)
  Integriert `usrcmds/copy`-Logik direkt im Plugin

### Bulk Operations

- **`:File bulk rename {pattern} {replacement}`** — Batch-Rename aller Dateien im Verzeichnis
  via lua-Regex; Vorschau-Modus mit Bestätigungsdialog

### Integration

- **Git-Awareness** — Warnung wenn Datei git-tracked ist bei rename/delete/duplicate;
  optional automatisches `git mv` / `git rm` statt libuv-Op
  Konfigurierbar: `git_aware = true`

- **Session-Kompatibilität** — nach `rename` den Session-Eintrag automatisch aktualisieren
  wenn eine Session-Plugin (mksession, possession.nvim, etc.) erkannt wird

- **neo-tree / nvim-tree Integration** — Event-Emission nach jeder Datei-Op
  damit Dateibaum-Plugins automatisch refreshen (`vim.api.nvim_exec_autocmds`)
  (teilweise erledigt: `:File cd` refresht neo-tree/nvim-tree/netrw bereits)

### DX / UX

- **Relativer Pfad-Completion** — Completion relativ zum aktuellen Buffer-Verzeichnis
  (nicht nur relativ zu cwd) für `rename`, `duplicate`, `new`

