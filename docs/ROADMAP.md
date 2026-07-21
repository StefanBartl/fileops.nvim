# fileops.nvim — Roadmap

## Geplante Features

### Integration

- **Git-Awareness** — Warnung wenn Datei git-tracked ist bei rename/delete/duplicate;
  optional automatisches `git mv` / `git rm` statt libuv-Op
  Konfigurierbar: `git_aware = true`

- **Session-Kompatibilität** — nach `rename` den Session-Eintrag automatisch aktualisieren
  wenn eine Session-Plugin (mksession, possession.nvim, etc.) erkannt wird

