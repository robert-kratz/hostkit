# SCHNELLLÖSUNG: "This script must be run as root" Fehler

## Das Problem

```yaml
- name: Deploy on VPS
  run: |
      ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
        "hostkit deploy $DOMAIN /opt/domains/$DOMAIN/deploy/image.tar"
```

**Fehler:**

```
✗ This script must be run as root
Error: Process completed with exit code 1.
```

## Die Lösung

Füge **`sudo`** vor `hostkit` hinzu:

```yaml
- name: Deploy on VPS
  run: |
      ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
        "sudo hostkit deploy $DOMAIN /opt/domains/$DOMAIN/deploy/image.tar"
```

## Warum?

-   Der Deploy-User ist **kein Root-User**
-   HostKit benötigt Root-Rechte für Docker-Operationen
-   Der User hat bereits `NOPASSWD` sudo-Rechte für `hostkit deploy`
-   Kein Passwort erforderlich!

## Komplettes funktionierendes Workflow-Beispiel

```yaml
name: Deploy to VPS

on:
    push:
        branches: [main]
    workflow_dispatch:

concurrency:
    group: deploy-${{ github.ref }}
    cancel-in-progress: true

jobs:
    build-and-deploy:
        runs-on: ubuntu-latest

        env:
            DOMAIN: ${{ secrets.DOMAIN }}
            VPS_HOST: ${{ secrets.VPS_HOST }}
            DEPLOY_USER: ${{ secrets.DEPLOY_USER }}
            SSH_PORT: ${{ secrets.VPS_PORT != '' && secrets.VPS_PORT || '22' }}

        steps:
            - name: Checkout Code
              uses: actions/checkout@v4

            - name: Set up Docker Buildx
              uses: docker/setup-buildx-action@v3

            - name: Build Docker Image
              run: |
                  docker build -t "$DOMAIN" .
                  docker save "$DOMAIN" > image.tar

            - name: Start ssh-agent and add key
              uses: webfactory/ssh-agent@v0.8.0
              with:
                  ssh-private-key: ${{ secrets.DEPLOY_SSH_KEY }}

            - name: Add server host key to known_hosts
              run: |
                  mkdir -p ~/.ssh
                  ssh-keyscan -p "$SSH_PORT" "$VPS_HOST" >> ~/.ssh/known_hosts

            - name: Upload Image to VPS via SCP
              run: |
                  scp -P "$SSH_PORT" image.tar \
                    "$DEPLOY_USER@$VPS_HOST:/opt/domains/$DOMAIN/deploy/image.tar"

            - name: Deploy on VPS
              run: |
                  ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
                    "sudo hostkit deploy $DOMAIN /opt/domains/$DOMAIN/deploy/image.tar"
              # ^^^^^ WICHTIG: sudo vor hostkit!

            - name: Cleanup deployment file
              run: |
                  ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
                    "rm -f /opt/domains/$DOMAIN/deploy/image.tar"
              continue-on-error: true

            - name: Health Check
              run: |
                  sleep 10
                  curl -fsS "https://$DOMAIN" >/dev/null || exit 1
```

## Noch Probleme mit SCP Upload?

Falls der Upload-Schritt fehlschlägt, führe das Fix-Script aus:

```bash
ssh root@your-vps
cd /tmp
wget https://raw.githubusercontent.com/robert-kratz/hostkit/main/fix-deploy-permissions.sh
chmod +x fix-deploy-permissions.sh
sudo ./fix-deploy-permissions.sh
```

Siehe: [QUICKFIX_SCP_UPLOAD.md](./QUICKFIX_SCP_UPLOAD.md)

## Weitere häufige Fehler

Siehe: [GITHUB_ACTIONS_COMMON_ERRORS.md](./GITHUB_ACTIONS_COMMON_ERRORS.md)

## Vollständige Dokumentation

Siehe: [GITHUB_ACTIONS_DEPLOYMENT.md](./GITHUB_ACTIONS_DEPLOYMENT.md)
