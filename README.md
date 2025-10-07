# HostKit# HostKit

<div align="center">A comprehensive CLI tool for managing Docker-based websites on your VPS with automated deployment via GitHub Actions.

![HostKit Logo](https://img.shields.io/badge/HostKit-VPS%20Management-blue?style=for-the-badge)## Overview

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

[![Version](https://img.shields.io/badge/version-1.2.0-green?style=for-the-badge)](https://github.com/robert-kratz/hostkit)HostKit simplifies the process of hosting multiple websites on a single VPS by providing an intuitive command

**Professionelles VPS-Website-Management mit Docker, Nginx und automatisiertem Deployment**# Version Management

[Features](#-features) • [Installation](#-installation) • [Quick Start](#-quick-start) • [Dokumentation](#-dokumentation) • [GitHub Actions](#-github-actions-integration)HostKit includes automatic version management and update capabilities:

</div>-   **Automatic update checks** - Checks for new versions once per day when running any command

-   **Self-updating** - Use `hostkit update` to automatically download and install the latest version

---- **Version tracking** - Keep track of current version with `hostkit version`

-   **Safe updates** - Automatic backup of current installation before updating

## 📋 Inhaltsverzeichnis- **GitHub integration** - Pulls updates directly from the GitHub repository

-   [Über HostKit](#-über-hostkit)The system will automatically warn you when a new version is available and provide instructions for updating.

-   [Features](#-features)

-   [System-Anforderungen](#-system-anforderungen)## Security Features

-   [Installation](#-installation)

-   [Quick Start](#-quick-start)- **Isolated deployment users** - Each website gets its own limited SSH user

-   [Befehls-Referenz](#-befehls-referenz)- **Restricted file permissions** - Users can only access their own website files

-   [GitHub Actions Integration](#-github-actions-integration)- **Automatic security updates** - System packages are kept up to date

-   [Dokumentation](#-dokumentation)- **Firewall integration** - Only necessary ports are exposed

-   [Beispiele](#-beispiele)- **SSH key authentication** - No password-based authentication for deploymentserface for managing Docker containers, Nginx configurations, SSL certificates, and automated deployments. It's designed to streamline the workflow from development to production deployment.

-   [Fehlerbehebung](#-fehlerbehebung)

-   [Changelog](#-changelog)## Features

-   [Support](#-support)

-   **Interactive website registration** - Guided setup process for new websites

---- **Hardened SSH key generation** - Dual RSA 4096-bit + Ed25519 keys for maximum security and compatibility

-   **Enhanced security** - Command restriction, SSH hardening, and isolated user environments

## 🎯 Über HostKit- **User and key management** - List all users, show SSH keys, and regenerate keys with copy-paste commands

-   **Nginx configuration management** with automatic reverse proxy setup

HostKit ist ein umfassendes CLI-Tool für die Verwaltung von Docker-basierten Websites auf Ihrem VPS mit automatisiertem Deployment über GitHub Actions. Es vereinfacht den gesamten Prozess vom Development bis zur Produktions-Bereitstellung und bietet dabei Enterprise-Level-Features für Sicherheit, Monitoring und Version-Management.- **SSL/TLS with Certbot** - Automated HTTPS certificate management

-   **Docker container management** - Start, stop, restart containers with ease

### Was macht HostKit besonders?- **Version control** - Maintain and switch between the last 3 deployed versions

-   **Comprehensive website listing** with real-time status information

-   ✅ **Zero-Config-Deployment** - Registrieren, deployen, fertig- **Log management** - Easy access to container logs

-   ✅ **Multi-Key SSH-Management** - Verschiedene Keys für verschiedene Zwecke- **GitHub Actions integration** - Seamless CI/CD pipeline setup

-   ✅ **Automatisches SSL** - Let's Encrypt Integration mit Auto-Renewal- **Multi-domain support** - Host multiple websites on a single VPS

-   ✅ **Version-Rollback** - Zurück zu jeder vorherigen Version in Sekunden- **Automatic cleanup** - Old versions are automatically removed to save disk space

-   ✅ **ID-basierte Commands** - Nutzen Sie IDs statt langer Domain-Namen

-   ✅ **Tab-Completion** - Intelligente Auto-Vervollständigung für alle Commands## System Requirements

-   ✅ **Input-Validierung** - Retry-Logik verhindert Fehler-Abbrüche

-   Ubuntu/Debian Linux (tested on Ubuntu 22.04)

---- Root access

-   Docker installed and running

## ✨ Features- 4GB RAM (recommended)

-   Nginx (will be installed if not present)

### 🔐 Sicherheit & SSH- Certbot (will be installed if not present)

-   Git (for repository operations)

-   **Dual-Key-Generation** - RSA 4096-bit + Ed25519 für maximale Kompatibilität

-   **Multi-Key-Support** - Mehrere benannte SSH-Keys pro Website## Installation

-   **Command Restriction** - SSH-User können nur spezifische Commands ausführen

-   **Automatische authorized_keys Synchronisation** - Keys werden automatisch verwaltet### 1. Clone the repository

-   **User-Isolation** - Jede Website erhält einen dedizierten System-User

````bash

### 🚀 Deployment & Versioninggit clone https://github.com/robert-kratz/hostkit.git

cd hostkit

- **GitHub Actions Ready** - Vollständige CI/CD-Integration```

- **Docker-basiert** - Konsistente Umgebungen von Dev bis Production

- **Version-Management** - Halte die letzten 3 Versionen für Rollbacks### 2. Run the installation script

- **Zero-Downtime-Deployments** - Nahtlose Updates ohne Ausfallzeiten

- **Automatisches Cleanup** - Alte Versionen werden automatisch entfernt```bash

sudo bash install.sh

### 🌐 Nginx & SSL```



- **Reverse Proxy** - Automatische Nginx-KonfigurationThe installation script will:

- **SSL/TLS mit Let's Encrypt** - Kostenlose, automatisch erneuerte Zertifikate

- **Multi-Domain-Support** - Mehrere Websites auf einem VPS-   Check all system requirements

- **HTTP → HTTPS Redirect** - Automatische sichere Umleitung-   Install missing packages (nginx, certbot, jq)

- **Domain-Redirects** - Unterstützung für www und andere Aliase-   Create the `/opt/hostkit` directory

-   Set up the `hostkit` command globally

### 📊 Monitoring & Management-   Configure necessary system permissions

-   Initialize the configuration files

- **Echtzeit-Status** - SSL-Status, Container-Status, Port-Mapping

- **Log-Management** - Einfacher Zugriff auf Container-Logs### 3. Verify the installation

- **ID-basierte Referenzierung** - Nutzen Sie kurze IDs statt Domain-Namen

- **Info-Command** - Umfassende Website-Informationen auf einen Blick```bash

- **Health-Checks** - SSL-Ablaufdatum, Container-Health, Version-Infohostkit help

````

### 🛠️ Developer Experience

## Quick Start

-   **Interactive Setup** - Geführter Registrierungsprozess

-   **Tab-Completion** - Intelligente Auto-Vervollständigung (Domains, IDs, Keys)### Step 1: Register your first website

-   **Input-Validierung mit Retry** - Keine abrupten Script-Abbrüche

-   **Farbcodierte Ausgabe** - Klare visuelle Unterscheidung```bash

-   **Ausführliche Hilfe** - Kategorisierte Commands mit Beispielenhostkit register

````

---

You'll be guided through an interactive setup process:

## 💻 System-Anforderungen

-   Enter domain name (e.g., `example.com`)

- **Betriebssystem**: Ubuntu 22.04+ oder Debian 11+-   Configure port settings for your Docker container

- **Zugriff**: Root-Rechte erforderlich-   Create SSH deployment user with restricted permissions

- **Software**: Docker (wird automatisch installiert)-   Set up SSL certificates via Let's Encrypt

- **RAM**: Minimum 2GB, empfohlen 4GB+-   Configure Nginx reverse proxy with HTTPS redirect

- **Disk**: Minimum 10GB freier Speicher

**Important:** At the end of the process, you'll receive a private SSH key. Store this securely - it's required for GitHub Actions deployments!

**Automatisch installierte Abhängigkeiten:**

- Docker Engine### Step 2: Configure GitHub Actions

- Nginx

- Certbot (Let's Encrypt)1. Navigate to your GitHub repository

- jq (JSON-Parser)2. Go to Settings → Secrets and variables → Actions

- curl3. Add the following repository secrets:



---    - `VPS_HOST` - IP address or domain of your VPS

    - `DEPLOY_USER` - Username created during registration (e.g., `deploy-example.com`)

## 📦 Installation    - `DEPLOY_SSH_KEY` - The private key from the registration process

    - `VPS_PORT` - SSH port (optional, default: 22)

### Schritt 1: Repository klonen

4. Create a deployment workflow in your repository:

```bash

git clone https://github.com/robert-kratz/hostkit.git```yaml

cd hostkit# .github/workflows/deploy.yml

```name: Deploy to VPS



### Schritt 2: Installations-Skript ausführenon:

    push:

```bash        branches: [main]

sudo bash install.sh

```jobs:

    deploy:

Das Installations-Skript wird:        runs-on: ubuntu-latest

- ✅ System-Anforderungen prüfen        steps:

- ✅ Fehlende Pakete installieren (nginx, certbot, docker, jq)            - uses: actions/checkout@v3

- ✅ Verzeichnisse erstellen (`/opt/hostkit`, `/opt/domains`)

- ✅ `hostkit` Command global verfügbar machen            - name: Build Docker image

- ✅ Bash-Completion installieren              run: |

- ✅ Notwendige Berechtigungen setzen                  docker build -t ${{ secrets.DEPLOY_USER }} .

                  docker save ${{ secrets.DEPLOY_USER }} > image.tar

### Schritt 3: Installation verifizieren

            - name: Deploy to VPS

```bash              run: |

hostkit version                  echo "${{ secrets.DEPLOY_SSH_KEY }}" > private_key

hostkit help                  chmod 600 private_key

```                  scp -o StrictHostKeyChecking=no -i private_key image.tar ${{ secrets.DEPLOY_USER }}@${{ secrets.VPS_HOST }}:/tmp/

                  ssh -o StrictHostKeyChecking=no -i private_key ${{ secrets.DEPLOY_USER }}@${{ secrets.VPS_HOST }} "hostkit deploy your-domain.com /tmp/image.tar"

---```



## 🚀 Quick Start### Step 3: Deploy your application



### 1. Erste Website registrierenPush to your main branch:



```bash```bash

sudo hostkit registergit push origin main

````

Sie werden durch einen interaktiven Setup-Prozess geführt:GitHub Actions will automatically:

-   📝 Domain-Name eingeben (z.B. `example.com`)

-   🔢 Port für Docker-Container wählen (z.B. `3000`)1. Build your Docker image

-   👤 SSH-User wird automatisch erstellt (`deploy-example-com`)2. Upload the image as a TAR file to your VPS

-   🔐 SSH-Keys werden generiert (RSA + Ed25519)3. Execute the deployment script

-   🌐 Nginx Reverse Proxy wird konfiguriert4. Start your website with zero downtime

-   🔒 SSL-Zertifikat wird beantragt (Let's Encrypt)

## Command Reference

**Wichtig:** Am Ende erhalten Sie SSH-Keys - diese **sicher aufbewahren** für GitHub Actions!

### Website Management

### 2. GitHub Actions konfigurieren

```````bash

#### a) Repository Secrets hinzufügen# List all registered websites with status

hostkit list

Navigieren Sie zu: **Settings → Secrets and variables → Actions**

# Start a website

Fügen Sie folgende Secrets hinzu:hostkit start example.com



| Secret Name | Wert | Beispiel |# Stop a website

|------------|------|----------|hostkit stop example.com

| `VPS_HOST` | IP oder Domain Ihres VPS | `192.168.1.100` |

| `DEPLOY_USER` | SSH-Username | `deploy-example-com` |# Restart a website

| `DEPLOY_SSH_KEY` | Private SSH-Key | Von `hostkit show-key` |hostkit restart example.com

| `DOMAIN` | Ihre Domain | `example.com` |

# View container logs (last 50 lines by default)

#### b) Workflow-Datei erstellenhostkit logs example.com



Erstellen Sie `.github/workflows/deploy.yml`:# View specific number of log lines

hostkit logs example.com 100

```yaml

name: Deploy to VPS# Follow logs in real-time

hostkit logs example.com -f

on:```

  push:

    branches: [main]### User and SSH Key Management



jobs:```bash

  deploy:# List all users with their websites and SSH key status

    runs-on: ubuntu-latesthostkit list-users

    steps:

      - uses: actions/checkout@v4# Show default SSH keys for a specific domain (with copy-paste commands)

      hostkit show-keys example.com

      - name: Build Docker Image

        run: |# Regenerate default SSH keys for a domain

          docker build -t ${{ secrets.DOMAIN }} .hostkit regenerate-keys example.com

          docker save ${{ secrets.DOMAIN }} > image.tar

      # Show detailed information about a user

      - name: Upload to VPShostkit user-info deploy-example-com

        uses: appleboy/scp-action@v0.1.7```

        with:

          host: ${{ secrets.VPS_HOST }}### Additional SSH Key Management (Multi-Key Support)

          username: ${{ secrets.DEPLOY_USER }}

          key: ${{ secrets.DEPLOY_SSH_KEY }}```bash

          source: "image.tar"# List all SSH keys for a website (including additional keys)

          target: "/opt/domains/${{ secrets.DOMAIN }}/deploy/"hostkit list-keys example.com



      - name: Deploy# Create a new additional SSH key

        uses: appleboy/ssh-action@v1.0.3hostkit add-key example.com github-actions

        with:

          host: ${{ secrets.VPS_HOST }}# Display SSH key content for copying to CI/CD

          username: ${{ secrets.DEPLOY_USER }}hostkit show-key example.com github-actions

          key: ${{ secrets.DEPLOY_SSH_KEY }}

          script: |# Remove a specific SSH key

            sudo hostkit deploy ${{ secrets.DOMAIN }} /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tarhostkit remove-key example.com old-key

            rm -f /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar

```# Use IDs instead of domain names

hostkit list-keys 0

📚 **Mehr Beispiele:** Siehe [GitHub Actions Examples](docs/github-actions-example.md)hostkit add-key 0 gitlab-ci

hostkit show-key 0 gitlab-ci

### 3. Erste Deployment```



```bashFor detailed information about multi-key management, see [SSH_KEY_MANAGEMENT.md](SSH_KEY_MANAGEMENT.md).

git add .

git commit -m "Initial deployment"### Registration & Configuration

git push origin main

``````bash

# Register a new website

GitHub Actions wird automatisch:hostkit register

1. ✅ Docker-Image bauen

2. ✅ Image als TAR auf VPS hochladen# Remove a website and cleanup all resources

3. ✅ HostKit-Deployment ausführenhostkit remove example.com

4. ✅ Container starten

# Show detailed information about a website

### 4. Status überprüfenhostkit info example.com

```````

```````bash

sudo hostkit list### Deployment & Version Management

sudo hostkit info example.com

``````bash

# Manual deployment (if TAR file is available)

🎉 **Fertig!** Ihre Website ist jetzt live unter `https://example.com`hostkit deploy example.com /path/to/image.tar



---# List available versions for a website

hostkit versions example.com

## 📚 Befehls-Referenz

# Switch to a different version

### Website-Managementhostkit switch example.com v1.2.3



```bash# Rollback to previous version

# Website registrierenhostkit rollback example.com

hostkit register```



# Alle Websites auflisten (mit IDs)### System Management

hostkit list

```bash

# Detaillierte Info zu Website# Update HostKit to the latest version

hostkit info <domain|id>hostkit update



# Website entfernen# Show current version

hostkit remove <domain|id>hostkit version

```````

# Check SSL certificate status

### Container-Controlhostkit ssl-status

```````bash# Renew SSL certificates

# Container startenhostkit ssl-renew

hostkit start <domain|id>

# Show help for all commands

# Container stoppenhostkit help

hostkit stop <domain|id>```



# Container neustarten## File Structure

hostkit restart <domain|id>

After installation, HostKit creates the following directory structure:

# Logs anzeigen (letzte 50 Zeilen)

hostkit logs <domain|id>```

/opt/hostkit/          # Main installation directory

# Logs live verfolgen├── config.json           # Global configuration

hostkit logs <domain|id> -f├── scripts/              # Management scripts

```├── templates/            # Nginx and Docker templates

└── backups/              # Configuration backups

### Deployment & Versioning

/opt/domains/             # Website data directory

```bash├── example.com/          # Per-domain directory

# Neue Version deployen│   ├── versions/         # Version history

hostkit deploy <domain|id> [tar-file]│   ├── current/          # Current active version

│   └── config.json       # Domain-specific config

# Verfügbare Versionen anzeigen

hostkit versions <domain|id>/etc/nginx/sites-available/  # Nginx configurations

/etc/nginx/sites-enabled/    # Active Nginx sites

# Zu Version wechseln```

hostkit switch <domain|id> <version>

```## Docker Integration



### SSL-ManagementHostKit expects your application to be containerized. Your Dockerfile should:



```bash1. Expose a port (will be mapped automatically)

# SSL-Status prüfen2. Be ready to run when the container starts

hostkit ssl-status [domain]3. Handle graceful shutdowns for zero-downtime deployments



# SSL-Zertifikat erneuernExample Dockerfile:

hostkit ssl-renew [domain]

``````dockerfile

FROM node:18-alpine

### SSH-User & Standard-KeysWORKDIR /app

COPY package*.json ./

```bashRUN npm ci --only=production

# Alle Deployment-User auflistenCOPY . .

hostkit list-usersEXPOSE 3000

CMD ["npm", "start"]

# Standard-SSH-Keys anzeigen```

hostkit show-keys <domain|id>

## SSL Certificate Management

# Standard-Keys neu generieren

hostkit regenerate-keys <domain|id>HostKit includes intelligent SSL certificate management with Let's Encrypt rate limit protection:



# User-Info anzeigen### Features

hostkit user-info <username>

```-   **Smart Certificate Detection** - Avoids requesting new certificates if valid ones exist

-   **Rate Limit Protection** - Prevents hitting Let's Encrypt's 5 certificates per domain per week limit

### Multi-Key SSH-Management-   **Certificate Preservation** - Certificates are never deleted during website removal (unless explicitly requested)

-   **Multi-Domain Support** - Single certificate covers main domain and all redirect domains

```bash-   **Automatic Backup** - Certificates are backed up before any changes

# Alle Keys einer Website auflisten-   **Auto-Renewal** - Configured via cron job to renew certificates before expiry

hostkit list-keys <domain|id>-   **Expiry Monitoring** - Check certificate status and expiry dates



# Neuen SSH-Key erstellen### SSL Commands

hostkit add-key <domain|id> <key-name>

```bash

# Key-Inhalt anzeigen (für CI/CD)# Check SSL certificate status for all domains

hostkit show-key <domain|id> <key-name>hostkit ssl-status



# Key entfernen# Check SSL certificate status for specific domain

hostkit remove-key <domain|id> <key-name>hostkit ssl-status example.com

```````

# Renew all SSL certificates

📖 **Detaillierte Anleitung:** [SSH Key Management](docs/SSH_KEY_MANAGEMENT.md)hostkit ssl-renew

### System# Renew certificate for specific domain

hostkit ssl-renew example.com

`bash`

# HostKit updaten

hostkit update### Certificate Lifecycle

# Version anzeigen1. **Registration**: Certificates are requested only if none exist or if existing ones don't cover all domains

hostkit version2. **Validation**: System checks if certificates cover all required domains before requesting new ones

3. **Preservation**: During website removal, certificates are preserved by default to avoid rate limits

# Hilfe anzeigen4. **Renewal**: Automatic renewal 30 days before expiry via cron job

hostkit help5. **Monitoring**: Built-in expiry monitoring and warnings

# HostKit deinstallieren### Rate Limit Protection

hostkit uninstall

````- Checks for existing valid certificates before requesting new ones

-   Warns about recent certificate requests to prevent rate limit violations

----   Uses certificate expansion (`--expand`) instead of requesting new certificates when possible

-   Provides rate limit information and troubleshooting guidance

## 🔄 GitHub Actions Integration

## Security Features

HostKit ist vollständig für GitHub Actions optimiert. Hier sind die wichtigsten Workflows:

HostKit implements comprehensive security measures to protect your deployment infrastructure:

### Basis-Deployment

### SSH Security Hardening

Automatisches Deployment bei Push auf `main`:

-   **Dual Key Authentication** - Both RSA 4096-bit and Ed25519 keys for maximum compatibility and security

```yaml-   **Command Restriction** - SSH wrapper script limits users to deployment-related commands only

name: Deploy to VPS-   **Password Authentication Disabled** - All deployment users have password authentication disabled

on:-   **Per-User SSH Configuration** - Individual SSH hardening rules for each deployment user

  push:-   **Connection Logging** - All SSH connections and commands are logged for audit purposes

    branches: [main]

jobs:### User Isolation

  deploy:

    runs-on: ubuntu-latest-   **Isolated deployment users** - Each website gets its own limited SSH user with restricted permissions

    steps:-   **Restricted file permissions** - Users can only access their own website deployment directories

      - uses: actions/checkout@v4-   **Sudo Restrictions** - Limited sudo permissions only for specific deployment commands

      - name: Build & Deploy-   **Account Hardening** - Deployment accounts are locked with no login passwords

        # ... siehe GitHub Actions Examples

```### Network Security



### Multi-Stage (Staging & Production)-   **Firewall integration** - Only necessary ports are exposed

-   **Localhost binding** - Docker containers bind to localhost only, accessed via Nginx reverse proxy

Separate Deployments für verschiedene Branches:-   **SSL/TLS enforcement** - Automatic HTTPS redirects and certificate management



```yaml### System Security

on:

  push:-   **Automatic security updates** - System packages are kept up to date

    branches:-   **SSH key rotation** - Easy regeneration of SSH keys when needed

      - develop  # → Staging-   **Audit trails** - Comprehensive logging of all deployment activities

      - main     # → Production

```## Troubleshooting



### Blue-Green Deployment### Common Issues



Zero-Downtime mit automatischem Rollback:**Website not accessible:**



```yaml```bash

- name: Health Check# Check container status

  run: |hostkit list

    if ! curl -f https://${{ secrets.DOMAIN }}/health; then

      hostkit switch ${{ secrets.DOMAIN }} $PREVIOUS_VERSION# Check logs for errors

      exit 1hostkit logs your-domain.com

    fi

```# Verify Nginx configuration

sudo nginx -t

📄 **Vollständige Beispiele:** [GitHub Actions Examples](docs/github-actions-example.md)```



---**Deployment failures:**



## 📖 Dokumentation```bash

# Check SSH connectivity

Ausführliche Dokumentation finden Sie im `docs/` Verzeichnis:ssh deploy-your-domain@your-vps



| Dokument | Beschreibung |# Verify Docker image

|----------|--------------|docker images | grep your-domain

| [GitHub Actions Examples](docs/github-actions-example.md) | Vollständige CI/CD-Workflows und Best Practices |

| [SSH Key Management](docs/SSH_KEY_MANAGEMENT.md) | Multi-Key-System, Key-Rotation, CI/CD-Integration |# Check disk space

| [SSH Key Workflows](docs/SSH_KEY_WORKFLOWS.md) | Praktische Beispiele und Use Cases |df -h

| [Input Validation](docs/INPUT_VALIDATION.md) | Validierungs-System und Retry-Logik |```

| [Security Enhancements](docs/SECURITY_ENHANCEMENTS.md) | Sicherheits-Features und Best Practices |

| [Uninstall Guide](docs/UNINSTALL.md) | Deinstallations-Optionen und Cleanup |**SSL certificate issues:**

| [Migration Guide](docs/MIGRATION_WEB-MANAGER_TO_HOSTKIT.md) | Upgrade von web-manager zu hostkit |

```bash

---# Manually renew certificates

sudo certbot renew

## 💡 Beispiele

# Check certificate status

### Beispiel 1: Neue Website mit GitHub Actionssudo certbot certificates

````

```bash

# 1. Website registrieren### Log Locations

sudo hostkit register

# Eingabe: example.com, Port 3000-   HostKit logs: `/var/log/hostkit/`

-   Nginx logs: `/var/log/nginx/`

# 2. SSH-Key für GitHub anzeigen-   Container logs: `docker logs <container_name>`

sudo hostkit show-key example.com default

## Contributing

# 3. Als GitHub Secret hinzufügen

# Settings → Secrets → DEPLOY_SSH_KEYContributions are welcome! Please read our contributing guidelines and submit pull requests to the main branch.



# 4. Workflow erstellen (siehe oben)1. Fork the repository

# .github/workflows/deploy.yml2. Create a feature branch (`git checkout -b feature-name`)

3. Commit your changes (`git commit -am 'Add new feature'`)

# 5. Pushen und deployen4. Push to the branch (`git push origin feature-name`)

git push origin main5. Create a Pull Request

```

## License

### Beispiel 2: Mehrere Keys für verschiedene Pipelines

This project is licensed under the MIT License - see the LICENSE file for details.

````bash

# GitHub Actions Key## Support

sudo hostkit add-key example.com github-actions

-   GitHub Issues: [https://github.com/robert-kratz/hostkit/issues](https://github.com/robert-kratz/hostkit/issues)

# GitLab CI Key-   Documentation: [https://github.com/robert-kratz/hostkit/wiki](https://github.com/robert-kratz/hostkit/wiki)

sudo hostkit add-key example.com gitlab-ci

## Changelog

# Manual Deployment Key

sudo hostkit add-key example.com manual-deploy### v1.2.0



# Alle Keys anzeigen-   **MAJOR SECURITY ENHANCEMENTS**: Hardened SSH key generation with dual RSA 4096-bit + Ed25519 keys

sudo hostkit list-keys example.com-   **New User Management**: `hostkit list-users` command showing all users with SSH key status

-   **Key Management**: `hostkit show-keys` and `hostkit regenerate-keys` commands

# Spezifischen Key für GitHub anzeigen-   **Enhanced Key Display**: Copy-paste ready commands for both private and public keys

sudo hostkit show-key example.com github-actions-   **SSH Security Hardening**: Command restriction, SSH configuration hardening, password lock

```-   **SSH Wrapper**: Restricted command execution for deployment users

-   **User Information**: `hostkit user-info` command for detailed user analysis

### Beispiel 3: Version-Rollback-   **GitHub Actions Compatibility**: Dual key support ensures compatibility with CI/CD systems

-   **Comprehensive Logging**: SSH connection logging and audit trails

```bash

# Verfügbare Versionen anzeigen### v1.1.0

sudo hostkit versions example.com

-   Added automatic version checking and update functionality

# Zu vorheriger Version wechseln-   New `hostkit update` command for self-updating

sudo hostkit switch example.com 20250107-143022-   New `hostkit version` command to show current version

-   Automatic daily checks for new versions with user notifications

# Status prüfen-   Safe update process with automatic backups

sudo hostkit info example.com-   Enhanced installation script with all required dependencies

````

### v1.0.0

### Beispiel 4: ID-basierte Commands

-   Initial release

```bash- Basic website management functionality

# Liste mit IDs anzeigen-   GitHub Actions integration

sudo hostkit list-   SSL certificate automation

# Output: 0 | example.com | running | ...-   Docker container management



# Mit ID statt Domain arbeiten> **Copyright (c) 2025 Robert Julian Kratz**

sudo hostkit info 0> **Repository:** https://github.com/robert-kratz/hostkit

sudo hostkit logs 0 -f> **License:** MIT

sudo hostkit restart 0> **Website:** https://rjks.us

sudo hostkit list-keys 0
```

---

## 🐛 Fehlerbehebung

### Problem: "Permission denied" bei SSH

**Lösung:**

```bash
# 1. Keys überprüfen
sudo hostkit show-key example.com github-actions

# 2. Authorized keys prüfen
sudo cat /home/deploy-example-com/.ssh/authorized_keys

# 3. Key neu generieren falls nötig
sudo hostkit regenerate-keys example.com
```

### Problem: Container startet nicht

**Lösung:**

```bash
# 1. Logs prüfen
sudo hostkit logs example.com 100

# 2. Container-Status prüfen
sudo hostkit info example.com

# 3. Manuell Docker prüfen
sudo docker ps -a
sudo docker logs example-com
```

### Problem: SSL-Zertifikat abgelaufen

**Lösung:**

```bash
# 1. Status prüfen
sudo hostkit ssl-status example.com

# 2. Manuell erneuern
sudo hostkit ssl-renew example.com

# 3. Nginx neu laden
sudo systemctl reload nginx
```

### Problem: Port bereits belegt

**Lösung:**

```bash
# 1. Port-Belegung prüfen
sudo netstat -tulpn | grep :3000

# 2. Website mit neuem Port registrieren
sudo hostkit register
# Anderen Port wählen (z.B. 3001)
```

### Problem: Deployment schlägt fehl

**Lösung:**

```bash
# 1. TAR-Datei prüfen
ls -lh /opt/domains/example.com/deploy/

# 2. Manuell deployen zum Testen
sudo hostkit deploy example.com /opt/domains/example.com/deploy/image.tar

# 3. Docker-Image direkt prüfen
sudo docker load -i /opt/domains/example.com/deploy/image.tar
```

📖 **Mehr Hilfe:** [Security Enhancements](docs/SECURITY_ENHANCEMENTS.md)

---

## 📝 Changelog

### Version 1.2.0 (Oktober 2025)

#### 🎉 Neue Features

-   **Multi-Key SSH-Management** - Mehrere benannte Keys pro Website
-   **ID-basierte Commands** - Nutzen Sie IDs (0, 1, 2...) statt Domain-Namen
-   **Info-Command** - Umfassende Website-Informationen mit SSL-Status
-   **SSL-Monitoring** - Ablaufdatum und Status in Liste
-   **Uninstall-System** - Granulare Deinstallations-Optionen

#### 🔧 Verbesserungen

-   **Tab-Completion** - Intelligente Auto-Vervollständigung für alle Commands
-   **Input-Validierung** - Retry-Logik verhindert Script-Abbrüche
-   **Enhanced Help** - Kategorisierte Commands mit Beispielen
-   **Command Umbenennung** - `web-manager` → `hostkit`

#### 📚 Dokumentation

-   Umfassende GitHub Actions Beispiele
-   SSH-Key-Management-Guide
-   Workflow-Beispiele und Best Practices
-   Migration-Guide für bestehende Installationen

---

## 🤝 Support

### Community & Hilfe

-   📖 **Dokumentation**: [docs/](docs/)
-   🐛 **Issues**: [GitHub Issues](https://github.com/robert-kratz/hostkit/issues)
-   💬 **Diskussionen**: [GitHub Discussions](https://github.com/robert-kratz/hostkit/discussions)

### Contribution

Contributions sind willkommen! Bitte beachten Sie:

1. Fork das Repository
2. Erstellen Sie einen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. Committen Sie Ihre Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Pushen Sie zum Branch (`git push origin feature/AmazingFeature`)
5. Öffnen Sie einen Pull Request

### Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe [LICENSE](LICENSE) für Details.

---

## 🙏 Credits

Entwickelt und maintained von [Robert Julian Kratz](https://github.com/robert-kratz)

**Danke an alle Contributors!**

---

<div align="center">

**[⬆ Zurück nach oben](#hostkit)**

Made with ❤️ for the DevOps Community

</div>
