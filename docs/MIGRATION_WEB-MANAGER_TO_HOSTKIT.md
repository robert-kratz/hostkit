# Migration: web-manager → hostkit

## Durchgeführte Änderungen

### Datum: 7. Oktober 2025

Alle Referenzen von `web-manager` wurden zu `hostkit` umbenannt, um die Konsistenz mit dem Projektnamen zu gewährleisten.

## Geänderte Dateien

### Haupt-Binärdateien
- ✅ `web-manager` → `hostkit` (Hauptskript)
- ✅ `completions/web-manager` → `completions/hostkit` (Bash-Completion)

### Funktionsnamen
- ✅ `_web_manager_completion()` → `_hostkit_completion()` in completions/hostkit
- ✅ `complete -F _web_manager_completion` → `complete -F _hostkit_completion`

### Dokumentation
Alle Markdown-Dateien aktualisiert:
- ✅ README.md
- ✅ SSH_KEY_MANAGEMENT.md
- ✅ SSH_KEY_WORKFLOWS.md
- ✅ INPUT_VALIDATION.md
- ✅ SECURITY_ENHANCEMENTS.md
- ✅ UNINSTALL.md
- ✅ .github/copilot-instructions.md

### Module
Alle Module in `modules/*.sh` aktualisiert:
- ✅ modules/control.sh
- ✅ modules/deploy.sh
- ✅ modules/info.sh
- ✅ modules/list.sh
- ✅ modules/register.sh
- ✅ modules/remove.sh
- ✅ modules/ssh-keys.sh
- ✅ modules/uninstall.sh
- ✅ modules/users.sh
- ✅ modules/versions.sh

### Installation
- ✅ install.sh aktualisiert

## Befehlsänderungen

### Alt (web-manager) → Neu (hostkit)

```bash
# Vorher
web-manager list
web-manager register
web-manager deploy example.com
web-manager info 0
web-manager start example.com
web-manager list-keys 0
web-manager add-key example.com github-actions

# Jetzt
hostkit list
hostkit register
hostkit deploy example.com
hostkit info 0
hostkit start example.com
hostkit list-keys 0
hostkit add-key example.com github-actions
```

## Syntax-Checks

Alle Syntax-Checks erfolgreich bestanden:
- ✅ hostkit (Hauptskript)
- ✅ completions/hostkit
- ✅ modules/control.sh
- ✅ modules/deploy.sh
- ✅ modules/info.sh
- ✅ modules/list.sh
- ✅ modules/register.sh (Syntax-Fehler behoben)
- ✅ modules/remove.sh
- ✅ modules/ssh-keys.sh
- ✅ modules/uninstall.sh
- ✅ modules/users.sh
- ✅ modules/versions.sh

## Behobene Probleme

1. **Überzähliges `fi` in register.sh**: 
   - Zeile 308 hatte ein `fi` ohne entsprechendes `if`
   - Wurde entfernt
   - Syntax-Check jetzt erfolgreich

## Backup

Ein vollständiges Backup wurde erstellt in:
```
.backup-before-rename/
├── modules/
├── completions/
├── *.md
└── web-manager (original)
```

## Installation

Nach dem Update muss die Installation wie folgt durchgeführt werden:

```bash
# Alte Installation entfernen (falls vorhanden)
sudo rm -f /usr/local/bin/web-manager

# Neue Installation
sudo bash install.sh

# Binärdatei wird installiert als:
/usr/local/bin/hostkit

# Tab-Completion wird installiert als:
/etc/bash_completion.d/hostkit
# oder
/usr/share/bash-completion/completions/hostkit
```

## Verzeichnisstruktur (unverändert)

Die internen Verzeichnisse bleiben gleich:
```
/opt/web-manager/          # Installationsverzeichnis (Name bleibt)
/opt/domains/<domain>/     # Domain-Konfigurationen
```

Nur der Befehlsname ändert sich: `web-manager` → `hostkit`

## GitHub Actions Update

Workflows müssen aktualisiert werden:

```yaml
# Alt
- name: Deploy
  run: |
    ssh user@host "web-manager deploy domain.com /tmp/image.tar"

# Neu
- name: Deploy
  run: |
    ssh user@host "hostkit deploy domain.com /tmp/image.tar"
```

## Kompatibilität

- ✅ Alle bisherigen Funktionen erhalten
- ✅ Alle Parameter und Optionen identisch
- ✅ Dateistruktur unverändert
- ✅ Konfigurationsdateien kompatibel
- ⚠️ Befehlsname geändert: `web-manager` → `hostkit`

## Nächste Schritte

1. Repository aktualisieren und pushen
2. GitHub Release erstellen mit neuem Tag
3. Dokumentation in Wiki aktualisieren
4. Migrations-Hinweis in README hinzufügen
