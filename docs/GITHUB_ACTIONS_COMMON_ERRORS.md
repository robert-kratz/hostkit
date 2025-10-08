# GitHub Actions - Häufige Fehler & Lösungen

## Fehler 1: "This script must be run as root"

### Symptom

```
✗ This script must be run as root
Error: Process completed with exit code 1.
```

### Ursache

Der `hostkit deploy` Befehl wird **ohne `sudo`** ausgeführt.

### Lösung

Füge `sudo` vor dem hostkit-Befehl hinzu:

**❌ Falsch:**

```yaml
- name: Deploy on VPS
  run: |
      ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
        "hostkit deploy $DOMAIN /opt/domains/$DOMAIN/deploy/image.tar"
```

**✅ Richtig:**

```yaml
- name: Deploy on VPS
  run: |
      ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
        "sudo hostkit deploy $DOMAIN /opt/domains/$DOMAIN/deploy/image.tar"
```

### Erklärung

-   Der Deploy-User hat **keine Root-Rechte**
-   HostKit benötigt Root-Rechte für Docker-Operationen
-   Der User hat `NOPASSWD` sudo-Rechte für `hostkit deploy` (in `/etc/sudoers.d/hostkit-<username>`)
-   Der SSH-Wrapper erlaubt explizit `sudo hostkit deploy`

---

## Fehler 2: "error copy file to dest: Process exited with status 1"

### Symptom

```
error copy file to dest: ***, error message: Process exited with status 1
```

### Ursache

1. GitHub Actions führt `mkdir -p /opt/domains/.../deploy/` aus → wird blockiert
2. Fehlende Schreibrechte im Deploy-Verzeichnis

### Lösung

Führe das Fix-Script aus:

```bash
ssh root@your-vps
cd /tmp
wget https://raw.githubusercontent.com/robert-kratz/hostkit/main/fix-deploy-permissions.sh
chmod +x fix-deploy-permissions.sh
sudo ./fix-deploy-permissions.sh
```

Siehe auch: [QUICKFIX_SCP_UPLOAD.md](./QUICKFIX_SCP_UPLOAD.md)

---

## Fehler 3: "Command not allowed: mkdir -p /opt/domains/.../deploy/"

### Symptom

```
ERROR: Command not allowed: mkdir -p /opt/domains/***/deploy/
Allowed operations:
  - File upload to deployment directory
  - hostkit deploy commands
```

### Ursache

Veralteter SSH-Wrapper erlaubt `mkdir` nicht.

### Lösung

Update SSH-Wrapper mit dem Fix-Script (siehe Fehler 2) oder manuell:

```bash
sudo nano /opt/hostkit/ssh-wrapper.sh
```

Füge nach den Docker-Befehlen hinzu:

```bash
    # Allow mkdir for deployment directory (required by GitHub Actions SCP)
    "mkdir -p /opt/domains/"*"/deploy/"*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    mkdir\ -p\ /opt/domains/*/deploy/*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
```

---

## Fehler 4: "Keine Berechtigung: /var/log/hostkit-ssh.log"

### Symptom

```
err: /opt/hostkit/ssh-wrapper.sh: Zeile 6: /var/log/hostkit-ssh.log: Keine Berechtigung
```

### Ursache

Log-Datei existiert nicht oder hat falsche Berechtigungen.

### Lösung

```bash
sudo touch /var/log/hostkit-ssh.log
sudo chmod 666 /var/log/hostkit-ssh.log
```

Oder führe das Fix-Script aus (siehe Fehler 2).

---

## Fehler 5: SSH Key Authentication Failed

### Symptom

```
ssh: handshake failed: no supported methods remain
```

### Ursache

Falscher SSH-Key oder Key-Format wird nicht unterstützt.

### Lösung

**Option 1: RSA-Key verwenden (empfohlen für GitHub Actions)**

```bash
# Auf dem VPS: RSA Private Key anzeigen
sudo cat /home/deploy-example-com/.ssh/deploy-example-com-rsa
```

In GitHub Secrets als `DEPLOY_SSH_KEY` speichern (kompletten Inhalt inklusive `-----BEGIN...-----`).

**Option 2: Ed25519-Key verwenden**

```bash
# Auf dem VPS: Ed25519 Private Key anzeigen
sudo cat /home/deploy-example-com/.ssh/deploy-example-com
```

Beide Keys funktionieren mit HostKit v1.3.3+.

---

## Fehler 6: "Permission denied (publickey)"

### Symptom

```
Permission denied (publickey)
```

### Ursache

-   SSH-Key nicht korrekt in GitHub Secrets gespeichert
-   Falscher Benutzername
-   Key fehlt auf dem Server

### Lösung

1. **Überprüfe GitHub Secrets:**

    - `DEPLOY_SSH_KEY`: Kompletter Private Key (mit `-----BEGIN` und `-----END`)
    - `DEPLOY_USER`: Exakter Username (z.B. `deploy-example-com`, NICHT `root`)
    - `VPS_HOST`: IP oder Hostname
    - `VPS_PORT`: SSH Port (Standard: 22)

2. **Überprüfe auf dem Server:**

    ```bash
    # Als root auf dem VPS
    DOMAIN="example.com"
    USERNAME=$(jq -r '.users[0].username' /opt/domains/$DOMAIN/config.json)

    # Check authorized_keys
    sudo cat /home/$USERNAME/.ssh/authorized_keys

    # Check SSH config
    sudo cat /etc/ssh/sshd_config.d/hostkit-$USERNAME.conf
    ```

3. **Test lokal:**
    ```bash
    ssh -i ~/.ssh/deploy-key deploy-example-com@your-vps
    ```

---

## Fehler 7: Container startet nicht nach Deployment

### Symptom

Deployment läuft durch, aber Container ist nicht erreichbar.

### Ursache

-   Port-Konflikt
-   Docker Image fehlerhaft
-   Nginx nicht konfiguriert

### Lösung

```bash
# Auf dem VPS als root
hostkit info example.com

# Container-Logs prüfen
hostkit control example.com logs

# Container-Status
docker ps -a | grep example-com

# Nginx-Status
sudo nginx -t
sudo systemctl status nginx
```

---

## Fehler 8: Health Check schlägt fehl

### Symptom

```
curl: (7) Failed to connect to example.com port 443
```

### Ursache

-   Container noch nicht fertig gestartet (zu kurze Sleep-Zeit)
-   SSL-Zertifikat fehlt oder abgelaufen
-   Nginx nicht neu geladen

### Lösung

**Option 1: Längere Wartezeit**

```yaml
- name: Health Check
  run: |
      sleep 30  # Erhöhe auf 30 Sekunden
      curl -fsS "https://$DOMAIN" >/dev/null
```

**Option 2: Retry-Logic hinzufügen**

```yaml
- name: Health Check with Retry
  run: |
      for i in {1..10}; do
        if curl -fsS "https://$DOMAIN" >/dev/null; then
          echo "✅ Health check passed!"
          exit 0
        fi
        echo "Attempt $i failed, retrying in 5 seconds..."
        sleep 5
      done
      echo "❌ Health check failed after 10 attempts"
      exit 1
```

---

## Fehler 9: Environment Variables fehlen im Container

### Symptom

Container startet, aber Anwendung funktioniert nicht (fehlende DB-Verbindung, etc.)

### Ursache

`.env`-Datei fehlt oder wird nicht geladen.

### Lösung

**Option 1: Server-side .env (empfohlen)**

```bash
# Auf dem VPS
sudo nano /opt/domains/example.com/.env
```

Siehe: [GITHUB_ACTIONS_DEPLOYMENT.md - Environment Variables](./GITHUB_ACTIONS_DEPLOYMENT.md#environment-variables-env)

**Option 2: Build-time ARGs**

```yaml
- name: Build Docker Image
  run: |
      docker build \
        --build-arg DATABASE_URL=${{ secrets.DATABASE_URL }} \
        --build-arg API_KEY=${{ secrets.API_KEY }} \
        -t "$DOMAIN" .
      docker save "$DOMAIN" > image.tar
```

---

## Debugging-Tipps

### 1. SSH-Wrapper Logs prüfen

```bash
sudo tail -f /var/log/hostkit-ssh.log
```

### 2. Test SSH-Verbindung lokal

```bash
ssh -v -i ~/.ssh/deploy-key deploy-example-com@your-vps "echo 'Connection successful'"
```

### 3. Test Deploy-Befehl lokal

```bash
ssh -i ~/.ssh/deploy-key deploy-example-com@your-vps \
  "sudo hostkit deploy example.com /opt/domains/example.com/deploy/test.tar"
```

### 4. Docker Logs in Echtzeit

```bash
ssh root@your-vps "docker logs -f example-com"
```

### 5. Nginx Error Logs

```bash
ssh root@your-vps "sudo tail -f /var/log/nginx/error.log"
```

---

## Checkliste für erfolgreiche Deployments

-   [ ] HostKit v1.3.3+ installiert
-   [ ] Domain mit `hostkit register` registriert
-   [ ] Deploy-User erstellt
-   [ ] SSH-Keys in GitHub Secrets gespeichert (kompletter Private Key)
-   [ ] Alle GitHub Secrets korrekt gesetzt:
    -   `DEPLOY_SSH_KEY` (RSA oder Ed25519 Private Key)
    -   `DEPLOY_USER` (z.B. `deploy-example-com`)
    -   `DOMAIN` (z.B. `example.com`)
    -   `VPS_HOST` (IP oder Hostname)
    -   `VPS_PORT` (optional, Standard: 22)
-   [ ] Workflow-Datei verwendet `sudo hostkit deploy`
-   [ ] `.env`-Datei auf Server vorhanden (falls benötigt)
-   [ ] SSL-Zertifikat vorhanden
-   [ ] Nginx konfiguriert und läuft
-   [ ] Health Check konfiguriert

---

## Weitere Hilfe

-   [Vollständige Deployment-Anleitung](./GITHUB_ACTIONS_DEPLOYMENT.md)
-   [SCP Upload Fix](./QUICKFIX_SCP_UPLOAD.md)
-   [SSH Key Management](./SSH_KEY_MANAGEMENT.md)
-   [Complete Working Workflow](./github-actions-complete-workflow.yml)

Bei weiteren Problemen öffne ein Issue auf GitHub:
https://github.com/robert-kratz/hostkit/issues
