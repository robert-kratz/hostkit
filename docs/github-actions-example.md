# GitHub Actions Deployment Examples

Diese Beispiele zeigen, wie Sie GitHub Actions verwenden können, um Ihre Anwendung automatisch mit HostKit auf Ihrem VPS zu deployen.

## Inhaltsverzeichnis

-   [Basis-Workflow](#basis-workflow)
-   [Multi-Stage Deployment](#multi-stage-deployment)
-   [Docker Build mit Caching](#docker-build-mit-caching)
-   [Blue-Green Deployment](#blue-green-deployment)
-   [Rollback bei Fehlern](#rollback-bei-fehlern)
-   [Secrets Konfiguration](#secrets-konfiguration)

---

## Basis-Workflow

Einfacher Workflow für automatisches Deployment bei Push auf main branch.

### `.github/workflows/deploy.yml`

```yaml
name: Deploy to VPS

on:
    push:
        branches: [main]
    workflow_dispatch: # Erlaubt manuelles Triggern

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

---

## Multi-Stage Deployment

Deployment für verschiedene Umgebungen (Staging & Production).

### `.github/workflows/deploy-multi-stage.yml`

```yaml
name: Multi-Stage Deployment

on:
    push:
        branches:
            - develop # Staging
            - main # Production
    workflow_dispatch:
        inputs:
            environment:
                description: "Environment to deploy"
                required: true
                type: choice
                options:
                    - staging
                    - production

jobs:
    determine-environment:
        runs-on: ubuntu-latest
        outputs:
            environment: ${{ steps.set-env.outputs.environment }}
            domain: ${{ steps.set-env.outputs.domain }}
        steps:
            - name: Determine Environment
              id: set-env
              run: |
                  if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
                    echo "environment=${{ inputs.environment }}" >> $GITHUB_OUTPUT
                  elif [ "${{ github.ref }}" == "refs/heads/main" ]; then
                    echo "environment=production" >> $GITHUB_OUTPUT
                  else
                    echo "environment=staging" >> $GITHUB_OUTPUT
                  fi

                  if [ "$(cat $GITHUB_OUTPUT | grep environment | cut -d= -f2)" == "production" ]; then
                    echo "domain=${{ secrets.PRODUCTION_DOMAIN }}" >> $GITHUB_OUTPUT
                  else
                    echo "domain=${{ secrets.STAGING_DOMAIN }}" >> $GITHUB_OUTPUT
                  fi

    build:
        needs: determine-environment
        runs-on: ubuntu-latest
        environment: ${{ needs.determine-environment.outputs.environment }}

        steps:
            - name: Checkout Code
              uses: actions/checkout@v4

            - name: Set up Docker Buildx
              uses: docker/setup-buildx-action@v3

            - name: Build Docker Image
              run: |
                  docker build \
                    --build-arg ENVIRONMENT=${{ needs.determine-environment.outputs.environment }} \
                    -t ${{ needs.determine-environment.outputs.domain }} .
                  docker save ${{ needs.determine-environment.outputs.domain }} > image.tar

            - name: Upload Artifact
              uses: actions/upload-artifact@v4
              with:
                  name: docker-image
                  path: image.tar
                  retention-days: 1

    deploy:
        needs: [determine-environment, build]
        runs-on: ubuntu-latest
        environment: ${{ needs.determine-environment.outputs.environment }}

        steps:
            - name: Download Artifact
              uses: actions/download-artifact@v4
              with:
                  name: docker-image

            - name: Upload to VPS
              uses: appleboy/scp-action@v0.1.7
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  source: "image.tar"
                  target: "/opt/domains/${{ needs.determine-environment.outputs.domain }}/deploy/"

            - name: Deploy on VPS
              uses: appleboy/ssh-action@v1.0.3
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  script: |
                      sudo hostkit deploy ${{ needs.determine-environment.outputs.domain }} \
                        /opt/domains/${{ needs.determine-environment.outputs.domain }}/deploy/image.tar
                      rm -f /opt/domains/${{ needs.determine-environment.outputs.domain }}/deploy/image.tar

            - name: Verify Deployment
              run: |
                  sleep 15
                  for i in {1..5}; do
                    if curl -f https://${{ needs.determine-environment.outputs.domain }}; then
                      echo "Deployment successful!"
                      exit 0
                    fi
                    echo "Attempt $i failed, retrying..."
                    sleep 10
                  done
                  exit 1
```

---

## Docker Build mit Caching

Optimierter Workflow mit Docker Layer Caching für schnellere Builds.

### `.github/workflows/deploy-cached.yml`

```yaml
name: Deploy with Docker Cache

on:
    push:
        branches: [main]

jobs:
    build-and-deploy:
        runs-on: ubuntu-latest

        steps:
            - name: Checkout Code
              uses: actions/checkout@v4

            - name: Set up Docker Buildx
              uses: docker/setup-buildx-action@v3

            - name: Cache Docker Layers
              uses: actions/cache@v4
              with:
                  path: /tmp/.buildx-cache
                  key: ${{ runner.os }}-buildx-${{ github.sha }}
                  restore-keys: |
                      ${{ runner.os }}-buildx-

            - name: Build Docker Image
              uses: docker/build-push-action@v5
              with:
                  context: .
                  push: false
                  outputs: type=docker,dest=/tmp/image.tar
                  tags: ${{ secrets.DOMAIN }}:latest
                  cache-from: type=local,src=/tmp/.buildx-cache
                  cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max

            - name: Move Cache
              run: |
                  rm -rf /tmp/.buildx-cache
                  mv /tmp/.buildx-cache-new /tmp/.buildx-cache

            - name: Load and Save Image
              run: |
                  docker load -i /tmp/image.tar
                  docker save ${{ secrets.DOMAIN }}:latest > image.tar

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
```

---

## Blue-Green Deployment

Zero-Downtime Deployment mit automatischem Rollback bei Fehlern.

### `.github/workflows/blue-green-deploy.yml`

```yaml
name: Blue-Green Deployment

on:
    push:
        branches: [main]

jobs:
    deploy:
        runs-on: ubuntu-latest

        steps:
            - name: Checkout Code
              uses: actions/checkout@v4

            - name: Build Docker Image
              run: |
                  docker build -t ${{ secrets.DOMAIN }}:${{ github.sha }} .
                  docker save ${{ secrets.DOMAIN }}:${{ github.sha }} > image.tar

            - name: Upload Image to VPS
              uses: appleboy/scp-action@v0.1.7
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  source: "image.tar"
                  target: "/opt/domains/${{ secrets.DOMAIN }}/deploy/"

            - name: Deploy New Version
              uses: appleboy/ssh-action@v1.0.3
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  script: |
                      # Save current version for rollback
                      CURRENT_VERSION=$(sudo hostkit versions ${{ secrets.DOMAIN }} | grep "current" | awk '{print $1}')
                      echo "Current version: $CURRENT_VERSION"

                      # Deploy new version
                      sudo hostkit deploy ${{ secrets.DOMAIN }} /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar

                      # Wait for container to be ready
                      sleep 10

                      # Health check
                      if curl -f -s --max-time 10 https://${{ secrets.DOMAIN }}/health > /dev/null; then
                        echo "Health check passed!"
                        rm -f /opt/domains/${{ secrets.DOMAIN }}/deploy/image.tar
                      else
                        echo "Health check failed! Rolling back..."
                        sudo hostkit switch ${{ secrets.DOMAIN }} $CURRENT_VERSION
                        exit 1
                      fi

            - name: Notify Success
              if: success()
              run: |
                  echo "✅ Deployment successful: ${{ github.sha }}"

            - name: Notify Failure
              if: failure()
              run: |
                  echo "❌ Deployment failed and was rolled back"
                  exit 1
```

---

## Rollback bei Fehlern

Separater Workflow für manuelles Rollback auf vorherige Version.

### `.github/workflows/rollback.yml`

```yaml
name: Rollback Deployment

on:
    workflow_dispatch:
        inputs:
            version:
                description: "Version to rollback to (leave empty for previous)"
                required: false
                type: string

jobs:
    rollback:
        runs-on: ubuntu-latest

        steps:
            - name: Get Available Versions
              uses: appleboy/ssh-action@v1.0.3
              id: versions
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  script: |
                      sudo hostkit versions ${{ secrets.DOMAIN }}

            - name: Rollback to Version
              uses: appleboy/ssh-action@v1.0.3
              with:
                  host: ${{ secrets.VPS_HOST }}
                  username: ${{ secrets.DEPLOY_USER }}
                  key: ${{ secrets.DEPLOY_SSH_KEY }}
                  port: ${{ secrets.VPS_PORT || 22 }}
                  script: |
                      if [ -n "${{ inputs.version }}" ]; then
                        echo "Rolling back to version: ${{ inputs.version }}"
                        sudo hostkit switch ${{ secrets.DOMAIN }} ${{ inputs.version }}
                      else
                        echo "Rolling back to previous version"
                        VERSIONS=$(sudo hostkit versions ${{ secrets.DOMAIN }} | grep -v "current" | head -2 | tail -1 | awk '{print $1}')
                        sudo hostkit switch ${{ secrets.DOMAIN }} $VERSIONS
                      fi

            - name: Verify Rollback
              run: |
                  sleep 10
                  curl -f https://${{ secrets.DOMAIN }} || exit 1
                  echo "✅ Rollback successful!"

            - name: Notify
              run: |
                  echo "Rolled back to version: ${{ inputs.version || 'previous' }}"
```

---

## Secrets Konfiguration

### Erforderliche GitHub Secrets

Navigieren Sie zu: **Settings → Secrets and variables → Actions → New repository secret**

| Secret Name         | Beschreibung                       | Beispiel                               |
| ------------------- | ---------------------------------- | -------------------------------------- |
| `VPS_HOST`          | IP-Adresse oder Domain des VPS     | `192.168.1.100` oder `vps.example.com` |
| `DEPLOY_USER`       | SSH-Benutzername für Deployment    | `deploy-example-com`                   |
| `DEPLOY_SSH_KEY`    | Private SSH-Key (RSA oder Ed25519) | Inhalt von `hostkit show-key`          |
| `VPS_PORT`          | SSH-Port (optional)                | `22` (Standard)                        |
| `DOMAIN`            | Domain der Website                 | `example.com`                          |
| `STAGING_DOMAIN`    | Staging-Domain (optional)          | `staging.example.com`                  |
| `PRODUCTION_DOMAIN` | Production-Domain (optional)       | `example.com`                          |

### SSH-Key erstellen und konfigurieren

1. **SSH-Key auf VPS erstellen:**

    ```bash
    sudo hostkit add-key example.com github-actions
    ```

2. **Private Key anzeigen:**

    ```bash
    sudo hostkit show-key example.com github-actions
    ```

3. **Key als GitHub Secret hinzufügen:**
    - Kopieren Sie den **Private Key** Inhalt
    - Fügen Sie ihn als `DEPLOY_SSH_KEY` Secret hinzu

### Environment Secrets (für Multi-Stage)

Für verschiedene Umgebungen können Sie auch **Environment Secrets** verwenden:

**Settings → Environments → New environment**

Erstellen Sie Environments wie `staging` und `production` mit eigenen Secrets:

-   `VPS_HOST`
-   `DEPLOY_USER`
-   `DEPLOY_SSH_KEY`

---

## Best Practices

### 1. Deployment-Benachrichtigungen

Fügen Sie Slack/Discord-Benachrichtigungen hinzu:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1.25.0
  with:
      payload: |
          {
            "text": "Deployment ${{ job.status }}: ${{ github.repository }}",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "Deployment *${{ job.status }}* for `${{ secrets.DOMAIN }}`\n*Commit:* ${{ github.sha }}\n*Author:* ${{ github.actor }}"
                }
              }
            ]
          }
  env:
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 2. Security Scanning

Integrieren Sie Security Scans vor dem Deployment:

```yaml
- name: Run Trivy Vulnerability Scanner
  uses: aquasecurity/trivy-action@master
  with:
      image-ref: ${{ secrets.DOMAIN }}:latest
      format: "sarif"
      output: "trivy-results.sarif"

- name: Upload Trivy Results
  uses: github/codeql-action/upload-sarif@v3
  with:
      sarif_file: "trivy-results.sarif"
```

### 3. Deployment Gates

Fügen Sie manuelle Approval für Production hinzu:

```yaml
deploy-production:
    needs: build
    runs-on: ubuntu-latest
    environment:
        name: production
        url: https://${{ secrets.PRODUCTION_DOMAIN }}
    steps:
        # ... deployment steps
```

Konfigurieren Sie in **Settings → Environments → production**:

-   Required reviewers
-   Wait timer
-   Deployment branches

### 4. Automatische Tests

Führen Sie Tests vor dem Deployment durch:

```yaml
test:
    runs-on: ubuntu-latest
    steps:
        - uses: actions/checkout@v4

        - name: Run Tests
          run: |
              docker build -t test-image .
              docker run test-image npm test

deploy:
    needs: test
    runs-on: ubuntu-latest
    # ... deployment steps
```

---

## Fehlerbehebung

### Problem: "Permission denied"

**Lösung:** Überprüfen Sie SSH-Key und Berechtigungen:

```bash
sudo hostkit show-key example.com github-actions
sudo hostkit list-keys example.com
```

### Problem: "Container failed to start"

**Lösung:** Prüfen Sie Logs:

```bash
sudo hostkit logs example.com 100
```

### Problem: "Deployment timeout"

**Lösung:** Erhöhen Sie Timeouts und fügen Sie Retry-Logik hinzu:

```yaml
- name: Deploy with Retry
  uses: nick-invision/retry@v2
  with:
      timeout_minutes: 10
      max_attempts: 3
      command: |
          # deployment command
```

---

## Weiterführende Ressourcen

-   [HostKit Dokumentation](../README.md)
-   [SSH Key Management](./SSH_KEY_MANAGEMENT.md)
-   [GitHub Actions Dokumentation](https://docs.github.com/en/actions)
-   [Docker Build Optimization](https://docs.docker.com/build/cache/)

---

## Beispiel Dockerfile

Für optimale Kompatibilität mit HostKit:

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM node:18-alpine

WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

CMD ["node", "dist/index.js"]
```

**Wichtig:**

-   Der Container muss auf einem Port lauschen (z.B. 3000)
-   Health-Check-Endpoint implementieren
-   Proper Signal-Handling für graceful shutdown
