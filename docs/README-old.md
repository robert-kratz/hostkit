# HostKit

A comprehensive CLI tool for managing Docker-based websites on your VPS with automated deployment via GitHub Actions.

## Overview

HostKit simplifies the process of hosting multiple websites on a single VPS by providing an intuitive command

# Version Management

HostKit includes automatic version management and update capabilities:

-   **Automatic update checks** - Checks for new versions once per day when running any command
-   **Self-updating** - Use `hostkit update` to automatically download and install the latest version
-   **Version tracking** - Keep track of current version with `hostkit version`
-   **Safe updates** - Automatic backup of current installation before updating
-   **GitHub integration** - Pulls updates directly from the GitHub repository

The system will automatically warn you when a new version is available and provide instructions for updating.

## Security Features

-   **Isolated deployment users** - Each website gets its own limited SSH user
-   **Restricted file permissions** - Users can only access their own website files
-   **Automatic security updates** - System packages are kept up to date
-   **Firewall integration** - Only necessary ports are exposed
-   **SSH key authentication** - No password-based authentication for deploymentserface for managing Docker containers, Nginx configurations, SSL certificates, and automated deployments. It's designed to streamline the workflow from development to production deployment.

## Features

-   **Interactive website registration** - Guided setup process for new websites
-   **Hardened SSH key generation** - Dual RSA 4096-bit + Ed25519 keys for maximum security and compatibility
-   **Enhanced security** - Command restriction, SSH hardening, and isolated user environments
-   **User and key management** - List all users, show SSH keys, and regenerate keys with copy-paste commands
-   **Nginx configuration management** with automatic reverse proxy setup
-   **SSL/TLS with Certbot** - Automated HTTPS certificate management
-   **Docker container management** - Start, stop, restart containers with ease
-   **Version control** - Maintain and switch between the last 3 deployed versions
-   **Comprehensive website listing** with real-time status information
-   **Log management** - Easy access to container logs
-   **GitHub Actions integration** - Seamless CI/CD pipeline setup
-   **Multi-domain support** - Host multiple websites on a single VPS
-   **Automatic cleanup** - Old versions are automatically removed to save disk space

## System Requirements

-   Ubuntu/Debian Linux (tested on Ubuntu 22.04)
-   Root access
-   Docker installed and running
-   4GB RAM (recommended)
-   Nginx (will be installed if not present)
-   Certbot (will be installed if not present)
-   Git (for repository operations)

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/robert-kratz/hostkit.git
cd hostkit
```

### 2. Run the installation script

```bash
sudo bash install.sh
```

The installation script will:

-   Check all system requirements
-   Install missing packages (nginx, certbot, jq)
-   Create the `/opt/hostkit` directory
-   Set up the `hostkit` command globally
-   Configure necessary system permissions
-   Initialize the configuration files

### 3. Verify the installation

```bash
hostkit help
```

## Quick Start

### Step 1: Register your first website

```bash
hostkit register
```

You'll be guided through an interactive setup process:

-   Enter domain name (e.g., `example.com`)
-   Configure port settings for your Docker container
-   Create SSH deployment user with restricted permissions
-   Set up SSL certificates via Let's Encrypt
-   Configure Nginx reverse proxy with HTTPS redirect

**Important:** At the end of the process, you'll receive a private SSH key. Store this securely - it's required for GitHub Actions deployments!

### Step 2: Configure GitHub Actions

1. Navigate to your GitHub repository
2. Go to Settings → Secrets and variables → Actions
3. Add the following repository secrets:

    - `VPS_HOST` - IP address or domain of your VPS
    - `DEPLOY_USER` - Username created during registration (e.g., `deploy-example.com`)
    - `DEPLOY_SSH_KEY` - The private key from the registration process
    - `VPS_PORT` - SSH port (optional, default: 22)

4. Create a deployment workflow in your repository:

```yaml
# .github/workflows/deploy.yml
name: Deploy to VPS

on:
    push:
        branches: [main]

jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v3

            - name: Build Docker image
              run: |
                  docker build -t ${{ secrets.DEPLOY_USER }} .
                  docker save ${{ secrets.DEPLOY_USER }} > image.tar

            - name: Deploy to VPS
              run: |
                  echo "${{ secrets.DEPLOY_SSH_KEY }}" > private_key
                  chmod 600 private_key
                  scp -o StrictHostKeyChecking=no -i private_key image.tar ${{ secrets.DEPLOY_USER }}@${{ secrets.VPS_HOST }}:/tmp/
                  ssh -o StrictHostKeyChecking=no -i private_key ${{ secrets.DEPLOY_USER }}@${{ secrets.VPS_HOST }} "hostkit deploy your-domain.com /tmp/image.tar"
```

### Step 3: Deploy your application

Push to your main branch:

```bash
git push origin main
```

GitHub Actions will automatically:

1. Build your Docker image
2. Upload the image as a TAR file to your VPS
3. Execute the deployment script
4. Start your website with zero downtime

## Command Reference

### Website Management

```bash
# List all registered websites with status
hostkit list

# Start a website
hostkit start example.com

# Stop a website
hostkit stop example.com

# Restart a website
hostkit restart example.com

# View container logs (last 50 lines by default)
hostkit logs example.com

# View specific number of log lines
hostkit logs example.com 100

# Follow logs in real-time
hostkit logs example.com -f
```

### User and SSH Key Management

```bash
# List all users with their websites and SSH key status
hostkit list-users

# Show default SSH keys for a specific domain (with copy-paste commands)
hostkit show-keys example.com

# Regenerate default SSH keys for a domain
hostkit regenerate-keys example.com

# Show detailed information about a user
hostkit user-info deploy-example-com
```

### Additional SSH Key Management (Multi-Key Support)

```bash
# List all SSH keys for a website (including additional keys)
hostkit list-keys example.com

# Create a new additional SSH key
hostkit add-key example.com github-actions

# Display SSH key content for copying to CI/CD
hostkit show-key example.com github-actions

# Remove a specific SSH key
hostkit remove-key example.com old-key

# Use IDs instead of domain names
hostkit list-keys 0
hostkit add-key 0 gitlab-ci
hostkit show-key 0 gitlab-ci
```

For detailed information about multi-key management, see [SSH_KEY_MANAGEMENT.md](SSH_KEY_MANAGEMENT.md).

### Registration & Configuration

```bash
# Register a new website
hostkit register

# Remove a website and cleanup all resources
hostkit remove example.com

# Show detailed information about a website
hostkit info example.com
```

### Deployment & Version Management

```bash
# Manual deployment (if TAR file is available)
hostkit deploy example.com /path/to/image.tar

# List available versions for a website
hostkit versions example.com

# Switch to a different version
hostkit switch example.com v1.2.3

# Rollback to previous version
hostkit rollback example.com
```

### System Management

```bash
# Update HostKit to the latest version
hostkit update

# Show current version
hostkit version

# Check SSL certificate status
hostkit ssl-status

# Renew SSL certificates
hostkit ssl-renew

# Show help for all commands
hostkit help
```

## File Structure

After installation, HostKit creates the following directory structure:

```
/opt/hostkit/          # Main installation directory
├── config.json           # Global configuration
├── scripts/              # Management scripts
├── templates/            # Nginx and Docker templates
└── backups/              # Configuration backups

/opt/domains/             # Website data directory
├── example.com/          # Per-domain directory
│   ├── versions/         # Version history
│   ├── current/          # Current active version
│   └── config.json       # Domain-specific config

/etc/nginx/sites-available/  # Nginx configurations
/etc/nginx/sites-enabled/    # Active Nginx sites
```

## Docker Integration

HostKit expects your application to be containerized. Your Dockerfile should:

1. Expose a port (will be mapped automatically)
2. Be ready to run when the container starts
3. Handle graceful shutdowns for zero-downtime deployments

Example Dockerfile:

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

## SSL Certificate Management

HostKit includes intelligent SSL certificate management with Let's Encrypt rate limit protection:

### Features

-   **Smart Certificate Detection** - Avoids requesting new certificates if valid ones exist
-   **Rate Limit Protection** - Prevents hitting Let's Encrypt's 5 certificates per domain per week limit
-   **Certificate Preservation** - Certificates are never deleted during website removal (unless explicitly requested)
-   **Multi-Domain Support** - Single certificate covers main domain and all redirect domains
-   **Automatic Backup** - Certificates are backed up before any changes
-   **Auto-Renewal** - Configured via cron job to renew certificates before expiry
-   **Expiry Monitoring** - Check certificate status and expiry dates

### SSL Commands

```bash
# Check SSL certificate status for all domains
hostkit ssl-status

# Check SSL certificate status for specific domain
hostkit ssl-status example.com

# Renew all SSL certificates
hostkit ssl-renew

# Renew certificate for specific domain
hostkit ssl-renew example.com
```

### Certificate Lifecycle

1. **Registration**: Certificates are requested only if none exist or if existing ones don't cover all domains
2. **Validation**: System checks if certificates cover all required domains before requesting new ones
3. **Preservation**: During website removal, certificates are preserved by default to avoid rate limits
4. **Renewal**: Automatic renewal 30 days before expiry via cron job
5. **Monitoring**: Built-in expiry monitoring and warnings

### Rate Limit Protection

-   Checks for existing valid certificates before requesting new ones
-   Warns about recent certificate requests to prevent rate limit violations
-   Uses certificate expansion (`--expand`) instead of requesting new certificates when possible
-   Provides rate limit information and troubleshooting guidance

## Security Features

HostKit implements comprehensive security measures to protect your deployment infrastructure:

### SSH Security Hardening

-   **Dual Key Authentication** - Both RSA 4096-bit and Ed25519 keys for maximum compatibility and security
-   **Command Restriction** - SSH wrapper script limits users to deployment-related commands only
-   **Password Authentication Disabled** - All deployment users have password authentication disabled
-   **Per-User SSH Configuration** - Individual SSH hardening rules for each deployment user
-   **Connection Logging** - All SSH connections and commands are logged for audit purposes

### User Isolation

-   **Isolated deployment users** - Each website gets its own limited SSH user with restricted permissions
-   **Restricted file permissions** - Users can only access their own website deployment directories
-   **Sudo Restrictions** - Limited sudo permissions only for specific deployment commands
-   **Account Hardening** - Deployment accounts are locked with no login passwords

### Network Security

-   **Firewall integration** - Only necessary ports are exposed
-   **Localhost binding** - Docker containers bind to localhost only, accessed via Nginx reverse proxy
-   **SSL/TLS enforcement** - Automatic HTTPS redirects and certificate management

### System Security

-   **Automatic security updates** - System packages are kept up to date
-   **SSH key rotation** - Easy regeneration of SSH keys when needed
-   **Audit trails** - Comprehensive logging of all deployment activities

## Troubleshooting

### Common Issues

**Website not accessible:**

```bash
# Check container status
hostkit list

# Check logs for errors
hostkit logs your-domain.com

# Verify Nginx configuration
sudo nginx -t
```

**Deployment failures:**

```bash
# Check SSH connectivity
ssh deploy-your-domain@your-vps

# Verify Docker image
docker images | grep your-domain

# Check disk space
df -h
```

**SSL certificate issues:**

```bash
# Manually renew certificates
sudo certbot renew

# Check certificate status
sudo certbot certificates
```

### Log Locations

-   HostKit logs: `/var/log/hostkit/`
-   Nginx logs: `/var/log/nginx/`
-   Container logs: `docker logs <container_name>`

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to the main branch.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature-name`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature-name`)
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

-   GitHub Issues: [https://github.com/robert-kratz/hostkit/issues](https://github.com/robert-kratz/hostkit/issues)
-   Documentation: [https://github.com/robert-kratz/hostkit/wiki](https://github.com/robert-kratz/hostkit/wiki)

## Changelog

### v1.2.0

-   **MAJOR SECURITY ENHANCEMENTS**: Hardened SSH key generation with dual RSA 4096-bit + Ed25519 keys
-   **New User Management**: `hostkit list-users` command showing all users with SSH key status
-   **Key Management**: `hostkit show-keys` and `hostkit regenerate-keys` commands
-   **Enhanced Key Display**: Copy-paste ready commands for both private and public keys
-   **SSH Security Hardening**: Command restriction, SSH configuration hardening, password lock
-   **SSH Wrapper**: Restricted command execution for deployment users
-   **User Information**: `hostkit user-info` command for detailed user analysis
-   **GitHub Actions Compatibility**: Dual key support ensures compatibility with CI/CD systems
-   **Comprehensive Logging**: SSH connection logging and audit trails

### v1.1.0

-   Added automatic version checking and update functionality
-   New `hostkit update` command for self-updating
-   New `hostkit version` command to show current version
-   Automatic daily checks for new versions with user notifications
-   Safe update process with automatic backups
-   Enhanced installation script with all required dependencies

### v1.0.0

-   Initial release
-   Basic website management functionality
-   GitHub Actions integration
-   SSL certificate automation
-   Docker container management

> **Copyright (c) 2025 Robert Julian Kratz**  
> **Repository:** https://github.com/robert-kratz/hostkit  
> **License:** MIT
> **Website:** https://rjks.us
