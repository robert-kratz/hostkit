# Feature Request: Docker Compose Support

## Overview

Add support for deploying multi-container applications using Docker Compose.

## Use Cases

1. **Full-stack applications**: Frontend + Backend + Database
2. **Microservices**: Multiple interconnected services
3. **Development environments**: Complex setups with multiple dependencies
4. **Existing projects**: Teams already using docker-compose.yml

## Current Limitations

HostKit currently only supports single-container deployments:

-   One Docker image per website
-   No multi-container orchestration
-   No service dependencies
-   No shared networks/volumes between containers

## Proposed Solution

### Option 1: docker-compose.yml Deployment

**Workflow:**

1. Upload `docker-compose.yml` + images
2. HostKit runs `docker-compose up -d`
3. Nginx proxies to main service

**Pros:**

-   Standard Docker Compose format
-   Easy migration for existing projects
-   Full feature support (networks, volumes, dependencies)

**Cons:**

-   More complex deployment
-   Harder to manage versions/rollbacks
-   Port conflicts need careful handling

### Option 2: Multi-Image TAR Support

**Workflow:**

1. GitHub Actions builds multiple images
2. Saves all images to single TAR
3. HostKit loads and orchestrates containers

**Pros:**

-   Similar to current workflow
-   Better version control
-   Simpler rollback

**Cons:**

-   Custom orchestration logic needed
-   Less flexibility than Compose

## Implementation Plan

### Phase 1: Basic Compose Support

1. **Detect compose file during deployment:**

    ```bash
    hostkit deploy <domain> <compose-file> [--compose]
    ```

2. **Store compose configuration:**

    ```json
    {
        "domain": "example.com",
        "type": "compose",
        "compose_file": "/opt/domains/example.com/docker-compose.yml",
        "services": ["web", "api", "db"],
        "main_service": "web"
    }
    ```

3. **Network management:**

    - Create isolated network per domain
    - Connect all services to same network
    - Expose only main service to Nginx

4. **Port management:**
    - Allocate port range per domain (e.g., 3000-3010)
    - Map services to sequential ports
    - Update Nginx to proxy to main service

### Phase 2: GitHub Actions Integration

**Example workflow:**

```yaml
- name: Build and save compose images
  run: |
      docker-compose build
      docker-compose config --services | while read service; do
        docker save $(docker-compose config | yq .services.$service.image) >> images.tar
      done

- name: Upload compose configuration
  run: |
      scp -P "$SSH_PORT" docker-compose.yml images.tar \
        "$DEPLOY_USER@$VPS_HOST:/opt/domains/$DOMAIN/deploy/"

- name: Deploy with Compose
  run: |
      ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
        "sudo hostkit deploy $DOMAIN /opt/domains/$DOMAIN/deploy/images.tar --compose"
```

### Phase 3: Version Management

-   Track compose stack versions
-   Rollback entire stack atomically
-   Health checks for all services

## File Structure

```
/opt/domains/example.com/
├── config.json                 # Domain configuration
├── docker-compose.yml          # Compose file
├── docker-compose.v1.yml       # Version 1 backup
├── docker-compose.v2.yml       # Version 2 backup
├── deploy/                     # Deployment files
│   ├── images.tar             # All service images
│   └── docker-compose.yml     # Current compose file
├── images/                     # Image versions
│   ├── web-v1.tar
│   ├── api-v1.tar
│   └── db-v1.tar
└── logs/                       # Service logs
    ├── web.log
    ├── api.log
    └── db.log
```

## New Commands

```bash
# Deploy with compose
hostkit deploy <domain> <compose-tar> --compose

# Show all services
hostkit compose services <domain>

# Logs for specific service
hostkit compose logs <domain> <service>

# Restart specific service
hostkit compose restart <domain> <service>

# Scale service (if supported)
hostkit compose scale <domain> <service> <replicas>
```

## Configuration Example

**docker-compose.yml:**

```yaml
version: "3.8"
services:
    web:
        image: example.com-web:latest
        depends_on:
            - api
        labels:
            - "hostkit.expose=true"
            - "hostkit.port=3000"

    api:
        image: example.com-api:latest
        depends_on:
            - db
        environment:
            - DATABASE_URL=postgresql://db:5432/app

    db:
        image: postgres:15
        volumes:
            - db_data:/var/lib/postgresql/data
        environment:
            - POSTGRES_PASSWORD=secret

volumes:
    db_data:

networks:
    default:
        name: example-com-network
```

**HostKit config.json:**

```json
{
    "domain": "example.com",
    "type": "compose",
    "compose_file": "/opt/domains/example.com/docker-compose.yml",
    "services": {
        "web": {
            "exposed": true,
            "internal_port": 3000,
            "external_port": 3000
        },
        "api": {
            "exposed": false,
            "internal_port": 8080
        },
        "db": {
            "exposed": false,
            "internal_port": 5432
        }
    },
    "main_service": "web",
    "network": "example-com-network",
    "current_version": "v1",
    "versions": ["v1"]
}
```

## Security Considerations

1. **Network Isolation**: Each domain gets its own Docker network
2. **Port Binding**: Only main service exposed via Nginx
3. **Volume Management**: Isolated volumes per domain
4. **Secrets Management**: Support for Docker secrets or env files
5. **Resource Limits**: Apply limits to compose stack as a whole

## Migration Path

For existing single-container deployments:

1. **Auto-generate compose file** from current config
2. **Gradual migration**: Support both modes simultaneously
3. **Backward compatibility**: Keep single-container mode as default

## Challenges

1. **Version Management**: Harder to track individual service versions
2. **Rollback Complexity**: Need to rollback entire stack
3. **Port Allocation**: Multiple services need port coordination
4. **Health Checks**: Monitor health of all services
5. **Resource Limits**: Apply per-service and per-stack limits
6. **Database Migrations**: Handle schema changes during updates

## Alternative: Kubernetes/Podman

For production-grade orchestration, consider:

-   **K3s**: Lightweight Kubernetes for single-node
-   **Podman**: Docker-compatible with better security
-   **Docker Swarm**: Native Docker orchestration

## Priority

**Low-Medium Priority**

Rationale:

-   Current single-container model works well for most use cases
-   Docker Compose adds significant complexity
-   Most simple websites don't need multi-container setup
-   Can be added later without breaking changes

## Community Feedback

Would users benefit from this feature?

-   Vote on GitHub Issues
-   Share use cases
-   Contribute implementation ideas

## Related Features

-   [ ] Environment variable management
-   [ ] Volume backup/restore
-   [ ] Database management commands
-   [ ] Service dependencies
-   [ ] Health check monitoring
-   [ ] Auto-scaling support

---

**Status**: Proposed  
**Version**: HostKit v2.0 (future)  
**Maintainer**: @robert-kratz
