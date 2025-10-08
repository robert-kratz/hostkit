# Docker Compose Support Guide

## Overview

HostKit now automatically detects and supports Docker Compose deployments alongside traditional single-container deployments. The system transparently handles both deployment types without requiring any special commands or flags.

## Key Features

-   ✅ **Automatic Detection**: HostKit automatically recognizes Docker Compose archives
-   ✅ **Seamless Integration**: Same commands work for both single-container and Compose deployments
-   ✅ **Multi-Service Support**: Deploy full-stack applications with multiple interconnected services
-   ✅ **Version Management**: Rollback entire Compose stacks atomically
-   ✅ **Service Status**: View status of all services in your stack
-   ✅ **Unified Control**: Use standard `start`, `stop`, `restart`, `logs` commands

## How It Works

HostKit detects deployment type based on TAR archive contents:

-   **Single Container**: TAR contains only Docker images → deployed as single container
-   **Docker Compose**: TAR contains `docker-compose.yml` → deployed as Compose stack

The user doesn't need to specify the type – HostKit handles it automatically!

## Creating a Compose Deployment Package

### 1. Project Structure

```
my-app/
├── docker-compose.yml
├── web/
│   └── Dockerfile
├── api/
│   └── Dockerfile
└── .github/
    └── workflows/
        └── deploy.yml
```

### 2. Docker Compose Configuration

**docker-compose.yml:**

```yaml
version: "3.8"

services:
    web:
        image: myapp-web:latest
        ports:
            - "3000:3000"
        depends_on:
            - api
        environment:
            - API_URL=http://api:8080
        labels:
            - "hostkit.port=3000"
            - "hostkit.expose=true"

    api:
        image: myapp-api:latest
        ports:
            - "8080:8080"
        depends_on:
            - db
        environment:
            - DATABASE_URL=postgresql://db:5432/myapp

    db:
        image: postgres:15
        volumes:
            - db_data:/var/lib/postgresql/data
        environment:
            - POSTGRES_PASSWORD=secret
            - POSTGRES_DB=myapp

volumes:
    db_data:
```

**Important Labels:**

-   `hostkit.port`: Port of the main service (exposed via Nginx)
-   `hostkit.expose`: Set to `true` for the service exposed to the internet

### 3. GitHub Actions Workflow

**.github/workflows/deploy.yml:**

```yaml
name: Deploy to HostKit

on:
    push:
        branches: [main]
    workflow_dispatch:

env:
    DOMAIN: example.com
    VPS_HOST: your-server.com
    SSH_PORT: 22
    DEPLOY_USER: deploy-example-com

jobs:
    deploy:
        runs-on: ubuntu-latest
        steps:
            - name: Checkout code
              uses: actions/checkout@v4

            - name: Set up Docker Buildx
              uses: docker/setup-buildx-action@v3

            - name: Build all images
              run: |
                  docker-compose build

            - name: Save all images to TAR files
              run: |
                  mkdir -p build
                  # Save each service image
                  docker save myapp-web:latest -o build/web.tar
                  docker save myapp-api:latest -o build/api.tar
                  docker save postgres:15 -o build/db.tar

            - name: Create deployment package
              run: |
                  # Copy docker-compose.yml
                  cp docker-compose.yml build/
                  # Create final TAR with compose file and all images
                  cd build
                  tar -czf ../deploy-package.tar.gz docker-compose.yml *.tar

            - name: Upload deployment package
              run: |
                  mkdir -p ~/.ssh
                  echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
                  chmod 600 ~/.ssh/id_rsa
                  ssh-keyscan -p $SSH_PORT $VPS_HOST >> ~/.ssh/known_hosts

                  scp -P $SSH_PORT deploy-package.tar.gz \
                    $DEPLOY_USER@$VPS_HOST:/opt/domains/$DOMAIN/deploy/

            - name: Extract and deploy
              run: |
                  ssh -p $SSH_PORT $DEPLOY_USER@$VPS_HOST << 'EOF'
                    cd /opt/domains/${{ env.DOMAIN }}/deploy
                    tar -xzf deploy-package.tar.gz
                    tar -cf deploy.tar docker-compose.yml *.tar
                    sudo hostkit deploy ${{ env.DOMAIN }}
                  EOF
```

### Alternative: Simplified Workflow

If you want to keep it simple, you can create a single TAR file directly:

```yaml
- name: Create deployment package
  run: |
      # Build images
      docker-compose build

      # Create TAR with compose file and all images in one go
      mkdir -p deploy
      cp docker-compose.yml deploy/

      # Save all images
      docker save $(docker-compose config --services | \
        xargs -I {} docker-compose config | \
        grep 'image:' | awk '{print $2}') -o deploy/images.tar

      # Package everything
      cd deploy
      tar -cf ../deploy-package.tar docker-compose.yml images.tar

- name: Upload and deploy
  run: |
      scp -P $SSH_PORT deploy-package.tar \
        $DEPLOY_USER@$VPS_HOST:/opt/domains/$DOMAIN/deploy/
        
      ssh -p $SSH_PORT $DEPLOY_USER@$VPS_HOST \
        "sudo hostkit deploy $DOMAIN"
```

## Usage Examples

### Deploy (Automatic Detection)

```bash
# HostKit automatically detects if it's Compose or single container
sudo hostkit deploy example.com
```

### View Status

```bash
# Shows all services for Compose deployments
sudo hostkit info example.com
```

**Example Output:**

```
DEPLOYMENT TYPE
  Type:                Docker Compose
  Services:
    - web (running)
    - api (running)
    - db (running)
  Main Service:        web

CONTAINER STATUS
  Status:              ● Running
```

### Control Commands

```bash
# Start entire stack
sudo hostkit start example.com

# Stop entire stack
sudo hostkit stop example.com

# Restart all services
sudo hostkit restart example.com

# View logs from all services
sudo hostkit logs example.com
```

### Version Management

```bash
# List all versions
sudo hostkit versions example.com

# Rollback entire stack to previous version
sudo hostkit switch example.com 20240101-120000
```

### Remove

```bash
# Removes entire Compose stack
sudo hostkit remove example.com
```

## Configuration

### Automatic Configuration

HostKit automatically:

-   Creates isolated Docker network for your stack
-   Detects main service (labeled with `hostkit.expose=true`)
-   **Overrides port mappings** to match your configured port (prevents conflicts)
-   Configures Nginx to proxy to main service port
-   Manages all services together as a unit
-   **Loads `.env` file** from domain directory for environment variables

### Environment Variables (.env)

HostKit automatically creates a `.env` file in `/opt/domains/<domain>/.env` during registration.

**How it works:**

1. **During Registration**: A template `.env` file is created
2. **During Deployment**: HostKit automatically loads this file with `docker-compose --env-file .env`
3. **For Your App**: Edit `/opt/domains/<domain>/.env` to configure your application

**Example `.env` file:**

```bash
# /opt/domains/example.com/.env

# Application Settings
NODE_ENV=production
PORT=3000

# Database
DATABASE_URL=postgresql://user:password@db:5432/myapp
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=myapp

# API Keys (never commit to git!)
API_SECRET_KEY=your_secret_key
JWT_SECRET=your_jwt_secret

# Next.js Public Variables (available in browser)
NEXT_PUBLIC_API_URL=https://api.example.com
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

**Important Notes:**

-   ✅ The `.env` file is automatically loaded by docker-compose
-   ✅ Variables are available to all services
-   ✅ File permissions are set to 600 (owner read/write only) for security
-   ⚠️ Never commit `.env` files to git (add to `.gitignore`)
-   ⚠️ For build-time variables, use `args:` in docker-compose.yml

**Using in docker-compose.yml:**

```yaml
services:
    web:
        image: myapp:latest
        # Variables from .env are automatically available
        environment:
            - NODE_ENV=${NODE_ENV}
            - DATABASE_URL=${DATABASE_URL}
        # Or just reference them directly (docker-compose loads .env)
```

### Port Management

**HostKit automatically overrides ports** in your docker-compose.yml to prevent conflicts.

**Example:**

Your `docker-compose.yml`:

```yaml
services:
    web:
        ports:
            - "3000:3000" # Your original port
```

After HostKit processing (if domain is configured for port 3001):

```yaml
services:
    web:
        ports:
            - "3001:3000" # HostKit changes host port, keeps container port
```

**Why?** This prevents port conflicts when multiple sites run on the same server.

**You don't need to worry about this** - HostKit handles it automatically!

### Config File Structure

When deploying Compose, HostKit creates:

```json
{
    "domain": "example.com",
    "type": "compose",
    "port": 3000,
    "main_service": "web",
    "services": ["web", "api", "db"],
    "compose_file": "docker-compose.yml",
    "current_version": "20240101-120000",
    "username": "deploy-example-com"
}
```

## File Structure

```
/opt/domains/example.com/
├── config.json                    # Domain configuration
├── .env                           # Environment variables (auto-created)
├── docker-compose.yml             # Current active Compose file
├── docker-compose.20240101-120000.yml  # Version backups
├── docker-compose.20240102-140000.yml
├── deploy/                        # Deployment uploads
│   └── deploy-package.tar
├── images/                        # Version archives
│   ├── 20240101-120000.tar
│   ├── 20240101-120000.info
│   ├── 20240102-140000.tar
│   └── 20240102-140000.info
└── logs/                          # Service logs
```

## Best Practices

### 1. Port Configuration

-   Bind services to internal ports only in Compose
-   Use `hostkit.port` label on main service
-   HostKit configures Nginx reverse proxy automatically

### 2. Environment Variables

```yaml
services:
    api:
        environment:
            - NODE_ENV=production
            - DATABASE_URL=postgresql://db:5432/myapp
            # Use Docker's service names for internal networking
```

### 3. Volumes

```yaml
volumes:
    db_data:
        # Volumes are preserved across deployments
    app_uploads:
        driver: local
```

### 4. Health Checks

```yaml
services:
    api:
        healthcheck:
            test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
            interval: 30s
            timeout: 10s
            retries: 3
```

### 5. Resource Limits

```yaml
services:
    web:
        deploy:
            resources:
                limits:
                    cpus: "0.5"
                    memory: 512M
                reservations:
                    memory: 256M
```

## Migration from Single Container

### Automatic Migration

If you have an existing single-container deployment, you can migrate to Compose:

1. Create `docker-compose.yml` for your application
2. Package with GitHub Actions
3. Deploy with `hostkit deploy` – HostKit automatically detects the change
4. Previous single container is replaced by Compose stack

### Example Migration

**Before (Single Container):**

```yaml
# GitHub Actions
- name: Save image
  run: docker save myapp:latest -o image.tar
```

**After (Docker Compose):**

```yaml
# GitHub Actions
- name: Create Compose package
  run: |
      cp docker-compose.yml build/
      docker save myapp:latest -o build/app.tar
      cd build && tar -cf ../deploy.tar docker-compose.yml app.tar
```

## Troubleshooting

### Check Service Status

```bash
# View info
sudo hostkit info example.com

# View logs
sudo hostkit logs example.com

# Check individual service
cd /opt/domains/example.com
docker-compose ps
docker-compose logs web
```

### Restart Specific Service

```bash
cd /opt/domains/example.com
export COMPOSE_PROJECT_NAME="example-com"
docker-compose restart web
```

### Rebuild Service

```bash
cd /opt/domains/example.com
export COMPOSE_PROJECT_NAME="example-com"
docker-compose up -d --build web
```

### Network Issues

```bash
# List networks
docker network ls

# Inspect network
docker network inspect example-com_default
```

## Advanced Features

### Multiple Environments

You can use different compose files for different environments:

```yaml
# docker-compose.prod.yml
services:
    web:
        image: myapp-web:latest
        environment:
            - NODE_ENV=production
```

Then reference it in your archive as `docker-compose.yml`.

### Scaling Services

While HostKit doesn't directly support scaling, you can modify compose file:

```yaml
services:
    worker:
        image: myapp-worker:latest
        deploy:
            replicas: 3
```

### Custom Networks

```yaml
networks:
    frontend:
        driver: bridge
    backend:
        driver: bridge
        internal: true

services:
    web:
        networks:
            - frontend
    api:
        networks:
            - frontend
            - backend
    db:
        networks:
            - backend
```

## Limitations

-   All services must use image-based deployments (no build contexts in Compose file)
-   Services are not directly exposed – only main service via Nginx
-   No direct support for Docker Swarm mode
-   Scaling must be configured in compose file

## Comparison

| Feature              | Single Container | Docker Compose    |
| -------------------- | ---------------- | ----------------- |
| Setup Complexity     | Simple           | Moderate          |
| Multi-Service        | ❌               | ✅                |
| Service Dependencies | ❌               | ✅                |
| Internal Networking  | ❌               | ✅                |
| Shared Volumes       | ❌               | ✅                |
| Version Management   | ✅               | ✅                |
| Rollback             | ✅               | ✅ (entire stack) |
| Resource Limits      | ✅               | ✅ (per service)  |

## Questions?

For more examples and help:

-   Check [GitHub Actions Examples](GITHUB_ACTIONS_DEPLOYMENT.md)
-   Review [Docker Compose Documentation](https://docs.docker.com/compose/)
-   Open an issue on GitHub

---

**Maintained by**: @robert-kratz  
**Version**: HostKit v1.5+
