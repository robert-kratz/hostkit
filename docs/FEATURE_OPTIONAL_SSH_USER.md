# Feature: Optionale SSH User Erstellung - v1.3.2

## Neue Funktion

SSH User und Keys können jetzt während der Registrierung **übersprungen** werden!

## Motivation

Manchmal möchte man:

-   Zuerst die Website-Struktur einrichten
-   SSH-User später separat hinzufügen
-   Mehrere User für eine Domain erstellen
-   Die Registrierung schneller durchführen

## Änderungen im Registrierungsprozess

### Step 3: User Setup (jetzt optional)

**Vorher:**

```
Step 3: User Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deployment username [deploy-example-com]:
```

Musste eingegeben werden, konnte nicht übersprungen werden.

**Nachher:**

```
Step 3: User Setup (Optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
You can create an SSH user now or skip and do it later
Use 'hostkit users add <domain>' to add users later

Create deployment user now? [Y/n]: n
ℹ User creation skipped - you can add users later
```

### Step 5: SSH User Setup (angepasst)

Wird automatisch übersprungen wenn kein User in Step 3 erstellt wurde:

```
ℹ SSH user setup skipped (no user created)
```

Wenn User in Step 3 erstellt wurde:

```
Step 5: SSH User Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Creates a dedicated user with SSH keys for secure deployments

Create SSH user and keys now? [Y/n]:
```

## Workflows

### Workflow 1: Vollständige Setup (wie bisher)

```bash
sudo hostkit register

Step 3: Create deployment user now? [Y/n]: y
Deployment username [deploy-example-com]: [ENTER]

Step 5: Create SSH user and keys now? [Y/n]: y
✓ SSH keys generated
```

### Workflow 2: Ohne User (später hinzufügen)

```bash
sudo hostkit register

Step 3: Create deployment user now? [Y/n]: n
ℹ User creation skipped

# Step 5 wird automatisch übersprungen
ℹ SSH user setup skipped (no user created)

# Nach Registrierung:
sudo hostkit users add example.com
```

### Workflow 3: User ohne Keys

```bash
sudo hostkit register

Step 3: Create deployment user now? [Y/n]: y
Deployment username [deploy-example-com]: [ENTER]

Step 5: Create SSH user and keys now? [Y/n]: n
ℹ SSH user creation skipped

# Später Keys hinzufügen:
sudo hostkit ssh-keys add example.com
```

## Konfiguration in config.json

Wenn User übersprungen wird:

```json
{
    "domain": "example.com",
    "port": 3000,
    "username": "none",
    ...
}
```

## Nachträgliches Hinzufügen

### User hinzufügen

```bash
# User für Domain erstellen
sudo hostkit users add example.com

# Mit spezifischem Username
sudo hostkit users add example.com custom-deploy-user
```

### SSH Keys hinzufügen

```bash
# Keys für existierenden User generieren
sudo hostkit ssh-keys add example.com

# Oder mit Namen
sudo hostkit ssh-keys add example.com production-key
```

## Summary-Anzeige

### Mit User:

```
Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Domain:   example.com
  Port:     3000
  User:     deploy-example-com
  Memory:   512m
```

### Ohne User:

```
Configuration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Domain:   example.com
  Port:     3000
  User:     (skipped - add later)
  Memory:   512m
```

## Abschluss-Nachricht

Wenn User übersprungen wurde, werden hilfreiche nächste Schritte angezeigt:

```
✓ Website example.com successfully registered!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps:
  1. Create deployment user:
     hostkit users add example.com
  2. Deploy your application:
     hostkit deploy example.com /path/to/your-app.tar
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Vorteile

✅ **Flexibilität** - User können später erstellt werden  
✅ **Schnellere Registrierung** - Optional Steps überspringen  
✅ **Mehrere User** - Mehrere User für eine Domain möglich  
✅ **CI/CD freundlich** - Keys später separat hinzufügen  
✅ **Besserer Workflow** - Domain-Setup und User-Setup getrennt

## Kompatibilität

Diese Änderung ist **abwärtskompatibel**:

-   Existierende Websites funktionieren weiterhin
-   Der Standard-Workflow (mit User) bleibt gleich
-   Neue Option wird klar angeboten

## Use Cases

### 1. Schnelles Testing

```bash
# Schnell Domain registrieren ohne User-Setup
sudo hostkit register  # User überspringen
sudo hostkit deploy example.com app.tar  # Direkt deployen
```

### 2. Multi-Team Setup

```bash
# Admin registriert Domain
sudo hostkit register  # Ohne User

# Verschiedene Teams fügen ihre User hinzu
sudo hostkit users add example.com team-a-deploy
sudo hostkit users add example.com team-b-deploy
```

### 3. Staging & Production

```bash
# Gleiche Domain-Struktur, verschiedene User
sudo hostkit register staging.example.com  # User: staging-deploy
sudo hostkit register example.com          # User: production-deploy
```

## Befehl-Referenz

### User-Management

```bash
# User hinzufügen
hostkit users add <domain> [username]

# User auflisten
hostkit users list

# User-Info anzeigen
hostkit users info <domain>

# User entfernen
hostkit users remove <domain> <username>
```

### SSH-Key-Management

```bash
# Keys hinzufügen
hostkit ssh-keys add <domain> [key-name]

# Keys auflisten
hostkit ssh-keys list <domain>

# Key anzeigen
hostkit ssh-keys show <domain> <key-name>

# Key entfernen
hostkit ssh-keys remove <domain> <key-name>
```

## Implementierung

### Neue Variable: `skip_user`

```bash
local skip_user=false

if ask_yes_no "Create deployment user now?"; then
    # User erstellen
    username="deploy-..."
else
    skip_user=true
    username="none"
fi
```

### Bedingte Ausführung

```bash
if [ "$skip_user" = false ]; then
    # SSH User Setup anbieten
else
    # Skip-Nachricht anzeigen
fi
```

## Testing

Getestet mit:

-   ✅ User überspringen → Später hinzufügen
-   ✅ User erstellen → Keys überspringen
-   ✅ User erstellen → Keys erstellen (Standard)
-   ✅ Mehrere User für gleiche Domain
-   ✅ Config.json mit username="none"

## Version

-   **Feature in**: v1.3.2
-   **Befehl**: `hostkit register`
-   **Verwandte Befehle**: `users add`, `ssh-keys add`

## Migration

Keine Migration nötig - das Feature ist optional und additiv.

Existierende Workflows funktionieren exakt wie vorher!
