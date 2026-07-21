# fileops.nvim — Roadmap

## Geplante Features

### High Priority

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
  (teilweise erledigt: `:File cd` refresht neo-tree/nvim-tree/netrw bereits)

### DX / UX

- **`:File help`** — kurze Usage-Übersicht direkt in der Befehlszeile (notify.info)
  ohne vim-help öffnen zu müssen

- **Input-Prompt für fehlende Argumente** — wenn `:File rename` ohne Ziel aufgerufen wird,
  `vim.ui.input` öffnen statt Fehlermeldung

- **Relativer Pfad-Completion** — Completion relativ zum aktuellen Buffer-Verzeichnis
  (nicht nur relativ zu cwd) für `rename`, `duplicate`, `new`

---

## Erledigt

- **`:File copy {dest}`** — wie `duplicate`, aber ohne automatisches Öffnen
  (stille Kopie); implementiert als dünner Wrapper um `duplicate(open=false)`.

- **`:File move {dest}`** — Datei in anderes Verzeichnis verschieben; Unterschied
  zu `rename`: kein Neuladen des Buffers (Inhalt/Undo-History bleiben erhalten).
  Implementiert als gemeinsame `move_or_rename`-Hilfsfunktion mit `reload`-Flag.

- **`:File touch {path}`** — leere Datei anlegen (Eltern-Dirs erstellen, 0-Byte
  schreiben), lässt eine bereits existierende Datei unangetastet (echte
  `touch`-Semantik). Braucht keinen Buffer.

