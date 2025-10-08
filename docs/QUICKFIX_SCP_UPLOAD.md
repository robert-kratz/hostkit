# Schnelllösung: GitHub Actions SCP Upload Fehler

## Problem

Der SCP-Upload in GitHub Actions schlägt fehl mit:

```
error copy file to dest: ***, error message: Process exited with status 1
```

## Ursache

-   GitHub Actions führt `mkdir -p /opt/domains/.../deploy/` vor dem Upload aus → wurde blockiert
-   SSH-Wrapper konnte nicht in Log-Datei schreiben (Berechtigungsfehler)
-   Fehlende Schreibrechte im `/opt/domains/<domain>/deploy/` Verzeichnis
-   SSH-Wrapper war zu restriktiv für GitHub Actions SCP-Format

## Sofortlösung (für bestehende Installationen)

### Option 1: Fix-Script ausführen (empfohlen)

```bash
# Auf dem VPS als root
cd /opt/hostkit
wget https://raw.githubusercontent.com/robert-kratz/hostkit/main/fix-deploy-permissions.sh
chmod +x fix-deploy-permissions.sh
sudo ./fix-deploy-permissions.sh
```

### Option 2: Manuelle Behebung

Ersetze `example.com` mit deiner Domain:

```bash
# 1. Domain und User identifizieren
DOMAIN="example.com"
USERNAME=$(jq -r '.users[0].username' /opt/domains/$DOMAIN/config.json)

# 2. Berechtigungen korrigieren
sudo chown -R "$USERNAME:$USERNAME" /opt/domains/$DOMAIN/deploy
sudo chmod 775 /opt/domains/$DOMAIN/deploy

# 3. ACL setzen (optional, falls unterstützt)
sudo setfacl -R -m u:${USERNAME}:rwx /opt/domains/$DOMAIN/deploy 2>/dev/null || true
sudo setfacl -d -m u:${USERNAME}:rwx /opt/domains/$DOMAIN/deploy 2>/dev/null || true

# 4. SSH-Wrapper aktualisieren
sudo nano /opt/hostkit/ssh-wrapper.sh
```

Ersetze die SCP-Sektion mit:

```bash
    # Allow SCP file uploads to deployment directory (target mode)
    scp\ *)
        if [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*/deploy/ ]] || [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*deploy/ ]]; then
            exec $SSH_ORIGINAL_COMMAND
        else
            echo "ERROR: SCP only allowed to deployment directories"
            exit 1
        fi
        ;;
```

## Test

```bash
# Lokal testen (ersetze Werte)
scp -i ~/.ssh/deploy-example-com-rsa \
    image.tar \
    deploy-example-com@your-vps.com:/opt/domains/example.com/deploy/
```

## Für neue Installationen

Einfach das aktualisierte HostKit installieren:

```bash
git clone https://github.com/robert-kratz/hostkit.git
cd hostkit
sudo bash install.sh
```

Die Fehlerbehebung ist bereits integriert!

## Wichtige Hinweise

1. **Backup vor Änderungen**: Das Fix-Script erstellt automatisch Backups
2. **SSH-Keys prüfen**: Stelle sicher, dass du den **RSA-Key** in GitHub Actions verwendest
3. **Port überprüfen**: Stelle sicher, dass `VPS_PORT` in GitHub Secrets korrekt ist (Standard: 22)
4. **Logs überprüfen**: `sudo tail -f /var/log/hostkit-ssh.log`

## GitHub Actions Secrets

Stelle sicher, dass folgende Secrets korrekt gesetzt sind:

| Secret           | Wert                                 |
| ---------------- | ------------------------------------ |
| `DEPLOY_SSH_KEY` | **RSA Private Key** (nicht Ed25519!) |
| `DEPLOY_USER`    | z.B. `deploy-example-com`            |
| `DOMAIN`         | z.B. `example.com`                   |
| `VPS_HOST`       | IP oder Hostname deines VPS          |
| `VPS_PORT`       | 22 (oder dein SSH Port)              |

## Weitere Hilfe

-   [Vollständige Bugfix Dokumentation](./BUGFIX_SCP_UPLOAD_PERMISSIONS.md)
-   [GitHub Actions Guide](./GITHUB_ACTIONS_DEPLOYMENT.md)
-   [SSH Key Management](./SSH_KEY_MANAGEMENT.md)

## Kontakt

Bei Problemen öffne ein Issue auf GitHub:
https://github.com/robert-kratz/hostkit/issues
