# Bugfix: Fehlende Container-Funktionen - v1.3.1

## Problem

Nach der Registrierung eines Websites funktionierte der `hostkit list` Befehl nicht:

```bash
/opt/hostkit/modules/list.sh: Zeile 39: get_container_name: Kommando nicht gefunden.
/opt/hostkit/modules/list.sh: Zeile 40: get_container_status: Kommando nicht gefunden.
```

## Ursache

Bei der Vereinfachung des Registrierungsprozesses wurden versehentlich die Funktionen `get_container_name()` und `get_container_status()` aus dem `hostkit` Hauptscript entfernt oder nie implementiert, obwohl sie von `modules/list.sh` benötigt werden.

## Lösung

Hinzugefügt in `hostkit` (nach den SSL-Funktionen):

```bash
# Get container name from domain
get_container_name() {
    local domain="$1"
    # Convert domain to container name (replace dots with dashes)
    echo "${domain//./-}"
}

# Get container status
get_container_status() {
    local domain="$1"
    local container_name=$(get_container_name "$domain")

    # Check if container exists and its status
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo "running"
            return 0
        else
            echo "stopped"
            return 1
        fi
    else
        echo "not_found"
        return 2
    fi
}
```

## Funktionsweise

### `get_container_name()`

-   Nimmt einen Domain-Namen als Input (z.B. `example.com`)
-   Konvertiert Punkte zu Bindestrichen (z.B. `example-com`)
-   Gibt den Container-Namen zurück

### `get_container_status()`

-   Nimmt einen Domain-Namen als Input
-   Holt den Container-Namen via `get_container_name()`
-   Prüft Docker-Container-Status:
    -   `running` - Container läuft
    -   `stopped` - Container existiert, ist aber gestoppt
    -   `not_found` - Kein Container vorhanden

## Verwendung in list.sh

```bash
# Zeile 39
local container_name=$(get_container_name "$domain")
# Zeile 40
local status=$(get_container_status "$domain")
```

Diese Funktionen werden für die Anzeige des Container-Status in der Website-Liste benötigt.

## Zusätzliche Hinweise

### Mögliches config.json Problem

Falls nach dem Update immer noch Fehler auftreten wie:

```
║ 0   ║ Main             ║              ║ null   ║ - None       ║ N/A             ║ none               ║
```

Das deutet auf eine fehlerhafte `config.json` Datei hin. Überprüfen Sie:

```bash
# Alle config.json Dateien anzeigen
find /opt/domains -name "config.json" -exec cat {} \;

# Oder für eine spezifische Domain
cat /opt/domains/<domain>/config.json
```

Eine gültige config.json sollte so aussehen:

```json
{
    "domain": "example.com",
    "redirect_domains": ["www.example.com"],
    "all_domains": ["example.com", "www.example.com"],
    "port": 3000,
    "username": "deploy-example-com",
    "memory_limit": "512m",
    "memory_reservation": "256m",
    "created": "2025-10-08T10:30:00+00:00",
    "current_version": null
}
```

Falls die Datei fehlerhaft ist:

```bash
# Website entfernen und neu registrieren
sudo hostkit remove <domain>
sudo hostkit register
```

## Update installieren

```bash
cd ~/hostkit
git pull origin main
sudo ./install.sh
```

## Testen

Nach dem Update:

```bash
# Liste anzeigen
sudo hostkit list

# Sollte funktionieren und alle Domains korrekt anzeigen mit:
# - ID
# - Domain-Name
# - Container-Status (running/stopped/no container)
# - Port
# - SSL-Status
# - Version
```

## Betroffene Befehle

Diese Funktionen werden auch von anderen Modulen verwendet:

-   `hostkit list` ✓
-   `hostkit info` (verwendet ebenfalls Container-Status)
-   `hostkit start/stop/restart` (Container-Management)

## Version

-   **Gefixt in**: v1.3.1
-   **Betrifft**: Alle Installationen seit Vereinfachung des Registrierungsprozesses
