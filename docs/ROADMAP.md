# fileops.nvim — Roadmap

## Implemented (v0.2)

- `:File new / write / saveas / writeto / mkdir` — Dateierstellung
- `:File rename / duplicate / delete` — Dateioperationen
- `:File next / prev [target]` — Verzeichnis-Navigation
- Keymaps: `<leader>nf/pf` Familie + `<leader>dcf`
- Lua API: `next()`, `prev()`, `new_file()`, `rename()`, `duplicate()`, `delete_current()`
- Alles via `vim.uv` (libuv), kein Shell-Aufruf
- `:checkhealth fileops_nvim`
- Tab-Completion für alle Subcommands

---

## Geplante Features

### High Priority

- **`:File move {dest}`** — Datei in anderes Verzeichnis verschieben ohne Buffer-Name-Änderung
  (writeto-Logik + alten Buffer umhängen); Unterschied zu `rename`: kein Neuladen

- **`:File copy {dest}`** — wie `duplicate`, aber ohne automatisches Öffnen
  (stille Kopie); nützlich für Backup-Workflows

- **`:File open [target]`** — aktuellen Puffer-Pfad in neuem Target öffnen
  (z.B. `:File open vsplit` → aktuelle Datei in vsplit öffnen)

### Navigation Improvements

- **`:File next/prev` mit Glob-Filter** — z.B. `:File next *.lua` um nur Lua-Dateien zu cyclen
  Erweiterung der `list_files`-Funktion um `pattern`-Option in CycleConfig

- **`:File first / last`** — springe zur ersten/letzten Datei im Verzeichnis

- **Aufl isung von Verzeichnis-Tiefe** — optional rekursive Navigation (subdirs einschließen)
  z.B. `root = "buffer_dir_recursive"` als neuer Config-Wert

### File Info

- **`:File info`** — Dateigröße, Änderungsdatum, Permissions (cross-platform via libuv `fs_stat`)
  Ausgabe als floating window oder in der Statuszeile

- **`:File path [mode]`** — Pfad in die Zwischenablage kopieren
  Modi: `abs` (absolut), `rel` (relativ zu cwd), `name` (nur Dateiname), `dir` (nur Ordner)
  Integriert `usrcmds/copy`-Logik direkt im Plugin

### Bulk Operations

- **`:File touch {path}`** — leere Datei anlegen (Eltern-Dirs erstellen, 0-Byte schreiben)
  Abkürzung für `:File write` wenn Buffer leer ist

- **`:File bulk rename {pattern} {replacement}`** — Batch-Rename aller Dateien im Verzeichnis
  via lua-Regex; Vorschau-Modus mit Bestätigungsdialog

### Undo / Safety

- **Trash statt Delete** — `:File delete` in den OS-Papierkorb statt `fs_unlink`;
  OS-Detection: Windows (Recycle Bin via shell), macOS (`osascript`), Linux (`gio trash`)
  Konfigurierbar: `delete_mode = "trash"|"permanent"`

- **Pre-delete Hook** — `on_before_delete(path)` Callback in Config; kann `false` zurückgeben
  um Löschen abzubrechen (nützlich für Git-tracked-File-Warnung)

### Integration

- **Git-Awareness** — Warnung wenn Datei git-tracked ist bei rename/delete/duplicate;
  optional automatisches `git mv` / `git rm` statt libuv-Op
  Konfigurierbar: `git_aware = true`

- **Session-Kompatibilität** — nach `rename` den Session-Eintrag automatisch aktualisieren
  wenn eine Session-Plugin (mksession, possession.nvim, etc.) erkannt wird

- **neo-tree / nvim-tree Integration** — Event-Emission nach jeder Datei-Op
  damit Dateibaum-Plugins automatisch refreshen (`vim.api.nvim_exec_autocmds`)

### DX / UX

- **`:File help`** — kurze Usage-Übersicht direkt in der Befehlszeile (notify.info)
  ohne vim-help öffnen zu müssen

- **Input-Prompt für fehlende Argumente** — wenn `:File rename` ohne Ziel aufgerufen wird,
  `vim.ui.input` öffnen statt Fehlermeldung

- **Relativer Pfad-Completion** — Completion relativ zum aktuellen Buffer-Verzeichnis
  (nicht nur relativ zu cwd) für `rename`, `duplicate`, `new`

---

## Nicht geplant

- **Ordner-Operationen** (mkdir -p, rmdir, cp -r) — zu weit vom Scope "file ops" entfernt;
  gehört in ein separates `dirops.nvim`-Plugin

- **FTP/SSH-Pfade** — `netrw`-Integration ist Neovim-Core-Aufgabe

- **Binary-File-Handling** — `duplicate` und `copy` funktionieren bereits mit Binaries
  (libuv liest byteweise), aber kein explizites UI dafür nötig
