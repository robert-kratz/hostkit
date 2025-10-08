# SCHNELLLÖSUNG: "sudo: Ein Passwort ist notwendig" Fehler

## Das Problem

```
sudo: Zum Lesen des Passworts ist ein Terminal erforderlich
sudo: Ein Passwort ist notwendig
Error: Process completed with exit code 1
```

## Ursache

Die sudoers-Konfiguration ist nicht vollständig oder `hostkit` ist nicht in allen Pfaden erlaubt.

## Sofortlösung

### Auf dem VPS ausführen:

```bash
ssh root@5.45.109.222

# Fix-Script herunterladen
cd /tmp
wget https://raw.githubusercontent.com/robert-kratz/hostkit/main/fix-sudo-permissions.sh
chmod +x fix-sudo-permissions.sh
sudo ./fix-sudo-permissions.sh
```

### Oder manuell fixen:

```bash
# Deine Domain und User
DOMAIN="www.zaremba-service.de"
USERNAME="deploy-www-zaremba-service-de"

# Sudoers-Datei bearbeiten
sudo nano /etc/sudoers.d/hostkit-$USERNAME
```

Füge ein (ersetze `$DOMAIN` und `$USERNAME` mit echten Werten):

```bash
# Deployment permissions for deploy-www-zaremba-service-de
Defaults:deploy-www-zaremba-service-de !requiretty
Defaults:deploy-www-zaremba-service-de !authenticate
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/bin/hostkit deploy www.zaremba-service.de *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/local/bin/hostkit deploy www.zaremba-service.de *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /opt/hostkit/hostkit deploy www.zaremba-service.de *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/bin/hostkit deploy *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/local/bin/hostkit deploy *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /opt/hostkit/hostkit deploy *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/bin/docker load
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/bin/docker run *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/bin/docker stop *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/bin/docker rm *
deploy-www-zaremba-service-de ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx
```

Dann:

```bash
sudo chmod 440 /etc/sudoers.d/hostkit-$USERNAME
sudo visudo -c  # Syntax prüfen
```

## Test

```bash
# Als Deploy-User testen
sudo -u deploy-www-zaremba-service-de sudo hostkit --version
# Sollte KEINE Passwort-Abfrage zeigen!

# Von GitHub Actions aus (simuliert)
ssh -p 22 deploy-www-zaremba-service-de@5.45.109.222 \
  "sudo hostkit deploy www.zaremba-service.de /opt/domains/www.zaremba-service.de/deploy/test.tar"
```

## Was wurde geändert?

**Neu hinzugefügt:**

-   `Defaults:$username !authenticate` - Deaktiviert Passwort-Authentifizierung komplett
-   Mehrere Pfade für `hostkit`: `/usr/bin/`, `/usr/local/bin/`, `/opt/hostkit/`
-   Wildcard-Pattern für alle Domains: `hostkit deploy *`

**Wichtig:**

-   `!requiretty` - Erlaubt sudo ohne Terminal
-   `!authenticate` - Kein Passwort erforderlich
-   `NOPASSWD:` - Bestätigt kein Passwort

## Warum ist das sicher?

1. **Nur spezifische Befehle** erlaubt (hostkit deploy, docker load, etc.)
2. **Nur für einen User** (deploy-www-zaremba-service-de)
3. **SSH-Wrapper** blockiert alle anderen Befehle
4. **Key-based Auth** - kein Passwort-Login möglich

## Debugging

### Sudoers testen

```bash
sudo -l -U deploy-www-zaremba-service-de
```

Sollte zeigen:

```
User deploy-www-zaremba-service-de may run the following commands:
    (root) NOPASSWD: /usr/bin/hostkit deploy www.zaremba-service.de *
    (root) NOPASSWD: /usr/local/bin/hostkit deploy www.zaremba-service.de *
    ...
```

### Wo ist hostkit installiert?

```bash
which hostkit
# Sollte /usr/bin/hostkit oder /usr/local/bin/hostkit zeigen
```

### Test von lokalem Rechner

```bash
ssh -i ~/.ssh/deploy-www-zaremba-service-de-ed25519 \
  deploy-www-zaremba-service-de@5.45.109.222 \
  "sudo hostkit --version"
```

## Weitere Hilfe

-   [GitHub Actions Common Errors](./GITHUB_ACTIONS_COMMON_ERRORS.md)
-   [Complete Workflow Example](./github-actions-complete-workflow.yml)
-   [Root Error Fix](./QUICKFIX_ROOT_ERROR.md)

## Noch Probleme?

Falls es immer noch nicht funktioniert:

```bash
# Als root auf dem VPS
sudo -u deploy-www-zaremba-service-de bash
# Jetzt bist du der Deploy-User

# Test sudo
sudo hostkit --version

# Wenn immer noch Passwort gefragt wird:
sudo visudo /etc/sudoers.d/hostkit-deploy-www-zaremba-service-de
# Prüfe Syntax und speichere
```
