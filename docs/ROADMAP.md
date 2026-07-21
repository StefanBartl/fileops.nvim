# fileops.nvim — Roadmap

## Geplante Features

### Navigation Improvements

- **Aufl isung von Verzeichnis-Tiefe** — optional rekursive Navigation (subdirs einschließen)
  z.B. `root = "buffer_dir_recursive"` als neuer Config-Wert

### Bulk Operations

- **`:File bulk rename {pattern} {replacement}`** — Batch-Rename aller Dateien im Verzeichnis
  via lua-Regex; Vorschau-Modus mit Bestätigungsdialog

### Integration

- **Git-Awareness** — Warnung wenn Datei git-tracked ist bei rename/delete/duplicate;
  optional automatisches `git mv` / `git rm` statt libuv-Op
  Konfigurierbar: `git_aware = true`

- **Session-Kompatibilität** — nach `rename` den Session-Eintrag automatisch aktualisieren
  wenn eine Session-Plugin (mksession, possession.nvim, etc.) erkannt wird

