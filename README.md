# HostKit

Professional VPS website management with Docker, Nginx and automated deployment.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.2.0-green.svg)](https://github.com/robert-kratz/hostkit)

## Overview

HostKit is a comprehensive CLI tool for managing Docker-based websites on your VPS with automated deployment via GitHub Actions. It simplifies the entire process from development to production deployment and provides enterprise-level features for security, monitoring and version management.

## Table of Contents

-   [Features](#features)
-   [System Requirements](#system-requirements)
-   [Installation](#installation)
-   [Quick Start](#quick-start)
-   [Command Reference](#command-reference)
-   [GitHub Actions Integration](#github-actions-integration)
-   [Documentation](#documentation)
-   [Examples](#examples)
-   [Troubleshooting](#troubleshooting)
-   [Changelog](#changelog)
-   [Support](#support)

## Features

### Security & SSH

-   Dual key generation (RSA 4096-bit + Ed25519) for maximum compatibility
-   Multi-key support with multiple named SSH keys per website
-   Command restriction - SSH users can only execute specific commands
-   Automatic authorized_keys synchronization
-   User isolation - each website gets its own dedicated system user
-   Password authentication disabled for deployment users
-   SSH connection logging and audit trails

### Deployment & Version Management

-   GitHub Actions ready with full CI/CD integration
-   Docker-based deployments for consistent environments
-   Version management - keeps last 3 versions for rollbacks
-   Zero-downtime deployments
-   Automatic cleanup of old versions
-   Manual deployment support via TAR files

### Nginx & SSL

-   Automatic reverse proxy configuration
-   SSL/TLS with Let's Encrypt certificates
-   Multi-domain support on a single VPS
-   Automatic HTTP to HTTPS redirects
-   Domain redirect support (www and other aliases)
-   Intelligent certificate management with rate limit protection
-   Certificate preservation to avoid Let's Encrypt rate limits

### Monitoring & Management

-   Real-time status monitoring (SSL, container, port mapping)
-   Easy log management and access
-   ID-based referencing - use short IDs instead of domain names
-   Comprehensive website information display
-   Health checks for SSL expiry, container health, version info
-   Container control (start, stop, restart)

### Resource Management

-   Per-website memory limits and reservations
-   System memory overview with allocation visualization
-   Automatic system reserve to protect OS performance
-   Interactive memory allocation during registration
-   Dynamic memory limit updates with container restart
-   Real-time memory usage monitoring for running containers

### Developer Experience

-   Interactive guided setup process
-   Tab-completion for domains, IDs, and keys
-   Input validation with retry logic
-   Color-coded output for clear visual distinction
-   Comprehensive help with categorized commands and examples
-   Automatic version checking and updates

## System Requirements

-   Operating System: Ubuntu 22.04+ or Debian 11+
-   Access: Root privileges required
-   RAM: Minimum 2GB, recommended 4GB+
-   Disk: Minimum 10GB free space

### Automatically Installed Dependencies

-   Docker Engine
-   Nginx
-   Certbot (Let's Encrypt)
-   jq (JSON parser)
-   curl

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/robert-kratz/hostkit.git
cd hostkit
```

### Step 2: Run the Installation Script

```bash
sudo bash install.sh
```

The installation script will:

-   Check all system requirements
-   Install missing packages (nginx, certbot, docker, jq)
-   Create necessary directories (`/opt/hostkit`, `/opt/domains`)
-   Make `hostkit` command globally available
-   Install bash completion
-   Set necessary permissions

### Step 3: Verify Installation

```bash
hostkit version
hostkit help
```

## Quick Start

### 1. Register Your First Website

```bash
sudo hostkit register
```

You will be guided through an interactive setup process:

-   Enter domain name (e.g., `example.com`)
-   Choose port for Docker container (e.g., `3000`)
-   SSH user is automatically created (`deploy-example-com`)
-   SSH keys are generated (RSA + Ed25519)
-   Nginx reverse proxy is configured
-   SSL certificate is requested (Let's Encrypt)

**Important:** At the end you will receive SSH keys - store them securely for GitHub Actions!

### 2. Configure GitHub Actions

#### a) Add Repository Secrets

Navigate to: **Settings → Secrets and variables → Actions**

Add the following secrets:

| Secret Name      | Value                    | Example                  |
| ---------------- | ------------------------ | ------------------------ |
| `VPS_HOST`       | IP or domain of your VPS | `192.168.1.100`          |
| `DEPLOY_USER`    | SSH username             | `deploy-example-com`     |
| `DEPLOY_SSH_KEY` | Private SSH key          | From `hostkit show-keys` |
| `DOMAIN`         | Your domain              | `example.com`            |

#### b) Create Workflow File

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to VPS

on:
    push:
        branches: [main]

jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4

            - name: Build Docker Image
              run: |
                  docker build -t ${{ secrets.DOMAIN }} .
                  docker save ${{ secrets.DOMAIN }} > image.tar

            - name: Upload to VPS
              uses: appleboy/scp-action@v0.1.7
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  source: "image.tar"
                  target: "/opt/domains/${{ secrets.DOMAIN }}/deploy/"

            - name: Deploy
              uses: appleboy/ssh-action@v1.0.3
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  script: |
                      sudo hostkit deploy ${{ secrets.DOMAIN }} /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar
                      rm -f /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar
```

See [GitHub Actions Examples](docs/github-actions-example.md) for more examples.

### 3. First Deployment

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

GitHub Actions will automatically:

1. Build Docker image
2. Upload image as TAR to VPS
3. Execute HostKit deployment
4. Start container

### 4. Check Status

```bash
sudo hostkit list
sudo hostkit info example.com
```

Your website is now live at `https://example.com`

## Command Reference

### Website Management

```bash
# Register a new website
hostkit register

# List all registered websites with IDs
hostkit list

# Show detailed information about a website
hostkit info <domain|id>

# Remove a website and cleanup all resources
hostkit remove <domain|id>
```

### Container Control

```bash
# Start a website container
hostkit start <domain|id>

# Stop a website container
hostkit stop <domain|id>

# Restart a website container
hostkit restart <domain|id>

# View container logs (last 50 lines by default)
hostkit logs <domain|id>

# Follow logs in real-time
hostkit logs <domain|id> -f

# View specific number of log lines
hostkit logs <domain|id> 100
```

### Deployment & Version Management

```bash
# Deploy a new version
hostkit deploy <domain|id> [tar-file]

# List available versions
hostkit versions <domain|id>

# Switch to a specific version
hostkit switch <domain|id> <version>

# Rollback to previous version
hostkit rollback <domain|id>
```

### SSL Management

```bash
# Check SSL certificate status for all domains
hostkit ssl-status

# Check SSL certificate status for specific domain
hostkit ssl-status <domain>

# Renew all SSL certificates
hostkit ssl-renew

# Renew certificate for specific domain
hostkit ssl-renew <domain>
```

### User & SSH Key Management

```bash
# List all deployment users with their websites
hostkit list-users

# Show default SSH keys for a domain (with copy-paste commands)
hostkit show-keys <domain|id>

# Regenerate default SSH keys for a domain
hostkit regenerate-keys <domain|id>

# Show detailed information about a user
hostkit user-info <username>
```

### Multi-Key SSH Management

```bash
# List all SSH keys for a website (including additional keys)
hostkit list-keys <domain|id>

# Create a new additional SSH key
hostkit add-key <domain|id> <key-name>

# Display SSH key content for copying to CI/CD
hostkit show-key <domain|id> <key-name>

# Remove a specific SSH key
hostkit remove-key <domain|id> <key-name>
```

For detailed information about multi-key management, see [SSH_KEY_MANAGEMENT.md](docs/SSH_KEY_MANAGEMENT.md).

### Memory Management

```bash
# Set memory limits for a website
hostkit set-memory <domain|id>

# Show system memory overview and allocation
hostkit memory-stats
```

The memory management system:

-   Shows total system memory and reserves 20% for the operating system (min 512MB, max 2GB)
-   Displays available memory for containers with visual progress bar
-   Allows you to set memory limit (hard limit) and reservation (soft limit)
-   Automatically calculates recommended reservation (50% of limit)
-   Validates allocation to prevent over-allocation
-   Optionally restarts running containers to apply new limits
-   Displays real-time memory usage in `hostkit info` command

### System Management

```bash
# Update HostKit to the latest version
hostkit update

# Show current version
hostkit version

# Show help for all commands
hostkit help

# Uninstall HostKit
hostkit uninstall
```

## GitHub Actions Integration

HostKit is fully optimized for GitHub Actions. Here are the most important workflows:

### Basic Deployment

Automatic deployment on push to `main`:

```yaml
name: Deploy to VPS

on:
    push:
        branches: [main]

jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4

            - name: Build Docker Image
              run: |
                  docker build -t ${{ secrets.DOMAIN }} .
                  docker save ${{ secrets.DOMAIN }} > image.tar

            - name: Upload to VPS
              uses: appleboy/scp-action@v0.1.7
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  source: "image.tar"
                  target: "/opt/domains/${{ secrets.DOMAIN }}/deploy/"

            - name: Deploy
              uses: appleboy/ssh-action@v1.0.3
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  script: |
                      sudo hostkit deploy ${{ secrets.DOMAIN }} /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar
                      rm -f /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar
```

### Multi-Stage Deployment (Staging & Production)

Separate deployments for different branches:

```yaml
on:
    push:
        branches:
            - develop # Staging
            - main # Production
```

### Blue-Green Deployment with Health Check

Zero-downtime with automatic rollback:

```yaml
- name: Health Check
  run: |
      if ! curl -f https://${{ secrets.DOMAIN }}/health; then
        hostkit switch ${{ secrets.DOMAIN }} $PREVIOUS_VERSION
        exit 1
      fi
```

For complete examples, see [GitHub Actions Examples](docs/github-actions-example.md).

## Documentation

Comprehensive documentation can be found in the `docs/` directory:

| Document                                                    | Description                                       |
| ----------------------------------------------------------- | ------------------------------------------------- |
| [GitHub Actions Examples](docs/github-actions-example.md)   | Complete CI/CD workflows and best practices       |
| [SSH Key Management](docs/SSH_KEY_MANAGEMENT.md)            | Multi-key system, key rotation, CI/CD integration |
| [SSH Key Workflows](docs/SSH_KEY_WORKFLOWS.md)              | Practical examples and use cases                  |
| [Input Validation](docs/INPUT_VALIDATION.md)                | Validation system and retry logic                 |
| [Security Enhancements](docs/SECURITY_ENHANCEMENTS.md)      | Security features and best practices              |
| [Uninstall Guide](docs/UNINSTALL.md)                        | Uninstallation options and cleanup                |
| [Migration Guide](docs/MIGRATION_WEB-MANAGER_TO_HOSTKIT.md) | Upgrade from web-manager to hostkit               |

## Examples

### Example 1: New Website with GitHub Actions

```bash
# 1. Register website
sudo hostkit register
# Input: example.com, Port 3000

# 2. Show SSH key for GitHub
sudo hostkit show-keys example.com

# 3. Add as GitHub Secret
# Settings → Secrets → DEPLOY_SSH_KEY

# 4. Create workflow (see above)
# .github/workflows/deploy.yml

# 5. Push and deploy
git push origin main
```

### Example 2: Multiple Keys for Different Pipelines

```bash
# GitHub Actions Key
sudo hostkit add-key example.com github-actions

# GitLab CI Key
sudo hostkit add-key example.com gitlab-ci

# Manual Deployment Key
sudo hostkit add-key example.com manual-deploy

# Show all keys
sudo hostkit list-keys example.com

# Show specific key for GitHub
sudo hostkit show-key example.com github-actions
```

### Example 3: Version Rollback

```bash
# Show available versions
sudo hostkit versions example.com

# Switch to previous version
sudo hostkit switch example.com 20250107-143022

# Check status
sudo hostkit info example.com
```

### Example 4: ID-Based Commands

```bash
# List with IDs
sudo hostkit list
# Output: 0 | example.com | running | ...

# Use ID instead of domain
sudo hostkit info 0
sudo hostkit logs 0 -f
sudo hostkit restart 0
sudo hostkit list-keys 0
```

## Troubleshooting

### Problem: "Permission denied" with SSH

**Solution:**

```bash
# 1. Check keys
sudo hostkit show-keys example.com

# 2. Check authorized keys
sudo cat /home/deploy-example-com/.ssh/authorized_keys

# 3. Regenerate keys if necessary
sudo hostkit regenerate-keys example.com
```

### Problem: Container Won't Start

**Solution:**

```bash
# 1. Check logs
sudo hostkit logs example.com 100

# 2. Check container status
sudo hostkit info example.com

# 3. Check Docker manually
sudo docker ps -a
sudo docker logs example-com
```

### Problem: SSL Certificate Expired

**Solution:**

```bash
# 1. Check status
sudo hostkit ssl-status example.com

# 2. Renew manually
sudo hostkit ssl-renew example.com

# 3. Reload Nginx
sudo systemctl reload nginx
```

### Problem: Port Already in Use

**Solution:**

```bash
# 1. Check port usage
sudo netstat -tulpn | grep :3000

# 2. Register website with different port
sudo hostkit register
# Choose different port (e.g., 3001)
```

### Problem: Deployment Fails

**Solution:**

```bash
# 1. Check TAR file
ls -lh /opt/domains/example.com/deploy/

# 2. Deploy manually for testing
sudo hostkit deploy example.com /opt/domains/example.com/deploy/image.tar

# 3. Check Docker image directly
sudo docker load -i /opt/domains/example.com/deploy/image.tar
```

For more help, see [Security Enhancements](docs/SECURITY_ENHANCEMENTS.md).

## Changelog

### Version 1.3.0 (October 2025)

#### New Features

-   **Memory Management System** - Per-website memory limits with interactive allocation
-   **System Memory Overview** - Visual memory allocation with progress bars
-   **Automatic System Reserve** - Protects OS performance by reserving 20% RAM
-   **Real-time Memory Monitoring** - Shows current memory usage for running containers
-   **Dynamic Memory Updates** - Change limits with optional container restart
-   New `hostkit set-memory` command to configure memory limits per website
-   New `hostkit memory-stats` command to show system-wide memory allocation

#### Improvements

-   Memory allocation during website registration
-   Memory limits enforced on container start
-   Memory usage displayed in `hostkit info` command
-   Docker memory limits and reservations (soft limits) support
-   Validation to prevent memory over-allocation

### Version 1.2.0 (October 2025)

#### New Features

-   Multi-key SSH management with multiple named keys per website
-   ID-based commands using IDs (0, 1, 2...) instead of domain names
-   Info command with comprehensive website information and SSL status
-   SSL monitoring with expiry date and status in list
-   Uninstall system with granular uninstallation options

#### Improvements

-   Tab completion with intelligent auto-completion for all commands
-   Input validation with retry logic to prevent script aborts
-   Enhanced help with categorized commands and examples
-   Command renaming from `web-manager` to `hostkit`

#### Documentation

-   Comprehensive GitHub Actions examples
-   SSH key management guide
-   Workflow examples and best practices
-   Migration guide for existing installations

### Version 1.1.0

-   Added automatic version checking and update functionality
-   New `hostkit update` command for self-updating
-   New `hostkit version` command to show current version
-   Automatic daily checks for new versions with user notifications
-   Safe update process with automatic backups
-   Enhanced installation script with all required dependencies

### Version 1.0.0

-   Initial release
-   Basic website management functionality
-   GitHub Actions integration
-   SSL certificate automation
-   Docker container management

## Support

### Community & Help

-   Documentation: [docs/](docs/)
-   Issues: [GitHub Issues](https://github.com/robert-kratz/hostkit/issues)
-   Discussions: [GitHub Discussions](https://github.com/robert-kratz/hostkit/discussions)

### Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Developed and maintained by [Robert Julian Kratz](https://github.com/robert-kratz)

---

Copyright (c) 2025 Robert Julian Kratz  
Repository: https://github.com/robert-kratz/hostkit  
Website: https://rjks.us
