# Docker Compose Deployment Example

Quick reference example for deploying a multi-service application with HostKit.

## Minimal Example

### Project Structure

```
my-fullstack-app/
├── docker-compose.yml
├── frontend/
│   ├── Dockerfile
│   └── (React/Vue/etc.)
├── backend/
│   ├── Dockerfile
│   └── (Node/Python/etc.)
└── .github/
    └── workflows/
        └── deploy.yml
```

### docker-compose.yml

```yaml
version: "3.8"

services:
    frontend:
        image: myapp-frontend:latest
        build: ./frontend
        ports:
            - "3000:3000"
        depends_on:
            - backend
        environment:
            - REACT_APP_API_URL=http://backend:8080
        labels:
            - "hostkit.port=3000"
            - "hostkit.expose=true"

    backend:
        image: myapp-backend:latest
        build: ./backend
        ports:
            - "8080:8080"
        environment:
            - NODE_ENV=production
            - DATABASE_URL=postgresql://db:5432/myapp
        depends_on:
            - db

    db:
        image: postgres:15-alpine
        volumes:
            - postgres_data:/var/lib/postgresql/data
        environment:
            - POSTGRES_PASSWORD=your_secure_password
            - POSTGRES_DB=myapp
            - POSTGRES_USER=myapp

volumes:
    postgres_data:
```

### GitHub Actions Workflow

**.github/workflows/deploy.yml:**

```yaml
name: Deploy to HostKit

on:
    push:
        branches: [main]

env:
    DOMAIN: myapp.com
    VPS_HOST: 123.45.67.89
    DEPLOY_USER: deploy-myapp-com

jobs:
    deploy:
        runs-on: ubuntu-latest

        steps:
            - name: Checkout
              uses: actions/checkout@v4

            - name: Build images
              run: docker-compose build

            - name: Create deployment package
              run: |
                  mkdir -p deploy
                  cp docker-compose.yml deploy/

                  # Save all images
                  docker save myapp-frontend:latest -o deploy/frontend.tar
                  docker save myapp-backend:latest -o deploy/backend.tar
                  docker pull postgres:15-alpine
                  docker save postgres:15-alpine -o deploy/postgres.tar

                  # Create final package
                  cd deploy
                  tar -cf ../myapp-deploy.tar docker-compose.yml *.tar

            - name: Setup SSH
              run: |
                  mkdir -p ~/.ssh
                  echo "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/id_rsa
                  chmod 600 ~/.ssh/id_rsa
                  ssh-keyscan -p 22 ${{ env.VPS_HOST }} >> ~/.ssh/known_hosts

            - name: Upload package
              run: |
                  scp myapp-deploy.tar \
                    ${{ env.DEPLOY_USER }}@${{ env.VPS_HOST }}:/opt/domains/${{ env.DOMAIN }}/deploy/

            - name: Deploy
              run: |
                  ssh ${{ env.DEPLOY_USER }}@${{ env.VPS_HOST }} \
                    "sudo hostkit deploy ${{ env.DOMAIN }}"
```

## Server Setup

### 1. Install HostKit

```bash
curl -fsSL https://raw.githubusercontent.com/robert-kratz/hostkit/main/install.sh | sudo bash
```

### 2. Register Domain

```bash
sudo hostkit register
# Enter: myapp.com
# Port: 3000
```

**HostKit automatically creates**:

-   Directory structure at `/opt/domains/myapp.com`
-   `.env` template file at `/opt/domains/myapp.com/.env`
-   SSH keys for deployment

### 3. Configure Environment Variables

```bash
# Edit the .env file
sudo nano /opt/domains/myapp.com/.env
```

Add your application variables:

```bash
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://user:pass@db:5432/myapp
POSTGRES_PASSWORD=your_secure_password
API_KEY=your_secret_key
NEXT_PUBLIC_API_URL=https://api.myapp.com
```

**Important**: These variables will be automatically loaded by Docker Compose!

### 4. Get SSH Keys

```bash
sudo hostkit show-keys myapp.com
# Copy the SSH public key
```

### 5. Add to GitHub Secrets

1. Go to your repository on GitHub
2. Settings → Secrets and variables → Actions
3. New repository secret
4. Name: `DEPLOY_SSH_KEY`
5. Value: (paste the private key from `show-keys` output)

## Deploy

```bash
# Push to main branch
git push origin main

# GitHub Actions will automatically:
# 1. Build all Docker images
# 2. Create deployment package
# 3. Upload to server
# 4. HostKit deploys automatically
```

## Verify Deployment

```bash
# Check status
sudo hostkit info myapp.com

# View logs
sudo hostkit logs myapp.com

# View specific service
cd /opt/domains/myapp.com
docker-compose logs frontend
```

## Common Patterns

### Automatic Port Management

**HostKit automatically manages ports for you!**

Don't worry about port conflicts - define any port in your compose file:

```yaml
services:
    web:
        ports:
            - "3000:3000" # Your development port
```

HostKit will automatically override the host port to match your registered port:

-   If you registered the domain with port 3001, HostKit changes it to `3001:3000`
-   The container still uses port 3000 internally
-   Nginx proxies traffic correctly

**You don't need to change anything** - just deploy!

### Environment Variables

**HostKit automatically creates and loads `.env` file!**

Located at: `/opt/domains/<domain>/.env`

```bash
# /opt/domains/myapp.com/.env
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://db:5432/myapp
API_KEY=your_secret_key

# Next.js public variables
NEXT_PUBLIC_API_URL=https://api.myapp.com
NEXT_PUBLIC_SUPABASE_URL=https://project.supabase.co
```

**Usage in docker-compose.yml**:

```yaml
services:
    web:
        # Option 1: Reference variables directly
        environment:
            - NODE_ENV=${NODE_ENV}
            - DATABASE_URL=${DATABASE_URL}

        # Option 2: Variables are auto-loaded, no need to specify
        build:
            args:
                - NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
```

**Security**: `.env` is set to 600 permissions (owner only)

### Health Checks

```yaml
services:
    backend:
        healthcheck:
            test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 40s
```

### Database Initialization

```yaml
services:
    db:
        image: postgres:15-alpine
        volumes:
            - postgres_data:/var/lib/postgresql/data
            - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql
```

### Redis Cache

```yaml
services:
    redis:
        image: redis:7-alpine
        volumes:
            - redis_data:/data
        command: redis-server --appendonly yes

volumes:
    redis_data:
```

## Tips

1. **Use .dockerignore** to speed up builds:

    ```
    node_modules
    .git
    .env*
    *.md
    ```

2. **Pin image versions** for reproducibility:

    ```yaml
    image: postgres:15.4-alpine
    image: redis:7.2-alpine
    ```

3. **Use multi-stage builds** to reduce image size:

    ```dockerfile
    FROM node:18 AS builder
    WORKDIR /app
    COPY package*.json ./
    RUN npm ci
    COPY . .
    RUN npm run build

    FROM node:18-alpine
    WORKDIR /app
    COPY --from=builder /app/dist ./dist
    CMD ["node", "dist/server.js"]
    ```

4. **Set proper restart policies**:
    ```yaml
    services:
        backend:
            restart: unless-stopped
    ```

## Troubleshooting

### Service won't start

```bash
cd /opt/domains/myapp.com
docker-compose logs backend
docker-compose ps
```

### Port conflicts

```bash
# Check which ports are in use
sudo hostkit list
netstat -tulpn | grep 3000
```

### Database connection issues

```bash
# Check if DB is running
docker-compose ps db

# Test connection
docker-compose exec backend nc -zv db 5432
```

### Memory issues

```bash
# Check memory usage
sudo hostkit memory
docker stats
```

## Full Documentation

See [DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) for complete documentation.
