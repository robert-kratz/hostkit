# GitHub Actions Deployment Guide

## Overview

This guide explains how to set up automated deployments from GitHub Actions to your VPS using HostKit.

## Prerequisites

1. HostKit installed on your VPS
2. Domain registered with `hostkit register`
3. SSH user created during registration or with `hostkit users add <domain>`
4. Docker image that can be built from your repository

## SSH Key Setup

HostKit generates two SSH keys during user creation:

-   **RSA 4096-bit**: Compatible with older systems and GitHub Actions
-   **Ed25519**: Recommended for modern systems (smaller, faster, more secure)

### For GitHub Actions (Recommended: RSA)

Use the **RSA private key** for maximum compatibility:

```bash
# On your VPS, display the RSA private key
sudo cat /home/deploy-<domain>/.ssh/deploy-<domain>-rsa
```

## GitHub Secrets Configuration

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name      | Description                      | Example                                  |
| ---------------- | -------------------------------- | ---------------------------------------- |
| `DEPLOY_SSH_KEY` | RSA private key (entire content) | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `DEPLOY_USER`    | SSH username from HostKit        | `deploy-example-com`                     |
| `DOMAIN`         | Your registered domain           | `example.com`                            |
| `VPS_HOST`       | Your VPS IP or hostname          | `192.168.1.100` or `vps.example.com`     |
| `VPS_PORT`       | SSH port (optional)              | `22` (default)                           |

## Example Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to VPS

on:
    push:
        branches: [main]
    workflow_dispatch: # Allows manual triggering

jobs:
    build-and-deploy:
        runs-on: ubuntu-latest

        steps:
            - name: Checkout Code
              uses: actions/checkout@v4

            - name: Set up Docker Buildx
              uses: docker/setup-buildx-action@v3

            - name: Build Docker Image
              run: |
                  docker build -t ${{ secrets.DOMAIN }} .
                  docker save ${{ secrets.DOMAIN }} > image.tar

            - name: Upload Image to VPS
              uses: appleboy/scp-action@v0.1.7
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  source: "image.tar"
                  target: "/opt/domains/${{ secrets.DOMAIN }}/deploy/"

            - name: Deploy on VPS
              uses: appleboy/ssh-action@v1.0.3
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  script: |
                      sudo hostkit deploy ${{ secrets.DOMAIN }} /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar
                      rm -f /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar

            - name: Health Check
              run: |
                  sleep 10
                  curl -f https://${{ secrets.DOMAIN }} || exit 1
```

## Environment Variables (.env)

### Option 1: Build-time Environment Variables

Include environment variables in your Docker image during build:

```yaml
- name: Build Docker Image
  run: |
      docker build \
        --build-arg DATABASE_URL=${{ secrets.DATABASE_URL }} \
        --build-arg API_KEY=${{ secrets.API_KEY }} \
        -t ${{ secrets.DOMAIN }} .
      docker save ${{ secrets.DOMAIN }} > image.tar
```

Your `Dockerfile` needs to accept these args:

```dockerfile
ARG DATABASE_URL
ARG API_KEY
ENV DATABASE_URL=$DATABASE_URL
ENV API_KEY=$API_KEY
```

### Option 2: Runtime Environment Variables (Server-side .env)

**Recommended for sensitive data that shouldn't be in the image.**

1. **Create `.env` file on the server:**

```bash
# SSH into your VPS
ssh user@your-vps

# Create .env file for your domain
sudo nano /opt/domains/example.com/.env
```

2. **Add your environment variables:**

```env
DATABASE_URL=postgresql://user:pass@localhost:5432/db
API_KEY=your-secret-api-key
NODE_ENV=production
```

3. **Set proper permissions:**

```bash
sudo chown deploy-example-com:deploy-example-com /opt/domains/example.com/.env
sudo chmod 600 /opt/domains/example.com/.env
```

4. **Deploy module will automatically use it** (if implemented - see note below)

> **Note**: The automatic `.env` file loading is not yet implemented in HostKit.
> You need to modify `/opt/hostkit/modules/deploy.sh` to add `--env-file` support.

### Option 3: Upload .env via GitHub Actions

**⚠️ Security Warning**: Only use this for non-production or if your repository is private.

```yaml
- name: Create .env file
  run: |
      cat > .env << EOF
      DATABASE_URL=${{ secrets.DATABASE_URL }}
      API_KEY=${{ secrets.API_KEY }}
      NODE_ENV=production
      EOF

- name: Upload .env to VPS
  uses: appleboy/scp-action@v0.1.7
  with:
      host: ${{ secrets.VPS_HOST }}
      username: ${{ secrets.DEPLOY_USER }}
      key: ${{ secrets.DEPLOY_SSH_KEY }}
      port: ${{ secrets.VPS_PORT || 22 }}
      source: ".env"
      target: "/opt/domains/${{ secrets.DOMAIN }}/"
```

## SSH Command Restrictions

For security, HostKit restricts SSH commands to deployment operations only:

### Allowed Commands

-   `scp -t /opt/domains/*/deploy/*` - File uploads to deploy directory
-   `sudo hostkit deploy <domain>` - Deployment execution
-   `rsync */deploy/*` - Rsync to deploy directory

### Blocked Commands

-   Interactive shell access
-   Commands outside deploy directory
-   Arbitrary command execution

## Troubleshooting

### "ssh: handshake failed: no supported methods remain"

**Cause**: SSH key authentication failed.

**Solutions**:

1. Verify you copied the **entire** private key including header/footer
2. Use the **RSA key** for GitHub Actions (better compatibility)
3. Check the key is properly formatted (no extra spaces or line breaks)
4. Verify the username matches exactly (`deploy-example-com`)

### "Permission denied (publickey)"

**Cause**: Key not authorized or wrong user.

**Solutions**:

1. Verify SSH user exists: `sudo hostkit users list <domain>`
2. Check authorized_keys: `sudo cat /home/<username>/.ssh/authorized_keys`
3. Verify SSH config: `sudo cat /etc/ssh/sshd_config.d/hostkit-<username>.conf`
4. Test locally: `ssh -i ~/.ssh/deploy-key -v deploy-user@vps`

### "scp: permission denied"

**Cause**: SSH wrapper blocking SCP command.

**Solutions**:

1. Update HostKit to latest version (includes SCP fixes)
2. Check wrapper logs: `sudo tail -f /var/log/hostkit-ssh.log`
3. Verify deploy directory permissions: `ls -la /opt/domains/<domain>/deploy/`

### "Container failed to start"

**Cause**: Various Docker or application issues.

**Solutions**:

1. Check container logs: `sudo docker logs <domain>`
2. Verify port not in use: `sudo netstat -tulpn | grep <port>`
3. Check memory limits: `sudo hostkit info <domain>`
4. Test image locally: `docker run <domain>:latest`

## Security Best Practices

### 1. Use Separate Keys per Environment

```bash
# Production
hostkit register prod.example.com

# Staging
hostkit register staging.example.com
```

### 2. Rotate Keys Regularly

```bash
sudo hostkit ssh-keys regenerate <domain> <key-name>
```

### 3. Monitor Deployment Logs

```bash
sudo tail -f /var/log/hostkit-ssh.log
```

### 4. Use GitHub Environment Protection

Configure deployment protection rules in GitHub:

-   Required reviewers
-   Wait timer
-   Branch restrictions

### 5. Limit Secret Access

-   Use GitHub Environments to scope secrets
-   Only give Actions minimum required permissions
-   Regularly audit who has access to secrets

## Advanced Configuration

### Multi-stage Deployment

```yaml
jobs:
    deploy-staging:
        runs-on: ubuntu-latest
        steps:
            # ... deploy to staging ...

    deploy-production:
        needs: deploy-staging
        runs-on: ubuntu-latest
        environment: production
        steps:
            # ... deploy to production ...
```

### Rollback on Failure

```yaml
- name: Deploy on VPS
  id: deploy
  continue-on-error: true
  uses: appleboy/ssh-action@v1.0.3
  with:
      script: sudo hostkit deploy ${{ secrets.DOMAIN }}

- name: Rollback on Failure
  if: steps.deploy.outcome == 'failure'
  uses: appleboy/ssh-action@v1.0.3
  with:
      script: sudo hostkit versions switch ${{ secrets.DOMAIN }} previous
```

### Slack Notifications

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
      status: ${{ job.status }}
      text: "Deployment to ${{ secrets.DOMAIN }}: ${{ job.status }}"
      webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Testing Locally

Before pushing to GitHub, test your deployment locally:

```bash
# Build image
docker build -t example.com .
docker save example.com > image.tar

# Upload to VPS
scp -i ~/.ssh/deploy-key image.tar deploy-user@vps:/opt/domains/example.com/deploy/

# Deploy
ssh -i ~/.ssh/deploy-key deploy-user@vps "sudo hostkit deploy example.com"
```

## Support

For issues or questions:

-   Check logs: `sudo tail -f /var/log/hostkit-ssh.log`
-   View documentation: `hostkit --help`
-   GitHub Issues: https://github.com/robert-kratz/hostkit/issues
