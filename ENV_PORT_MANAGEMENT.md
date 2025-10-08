# ENV Management & Port Override - Feature Update

## Overview

Enhanced Docker Compose support with automatic environment variable management and port override functionality.

## New Features

### 1. Automatic .env File Creation

**When**: During domain registration (`hostkit register`)

**Location**: `/opt/domains/<domain>/.env`

**Contents**:

```bash
# Environment Variables for Docker Compose
# This file is automatically loaded by HostKit during deployment
#
# Edit this file to add your application's environment variables
# Examples:
# NODE_ENV=production
# DATABASE_URL=postgresql://user:pass@db:5432/dbname
# API_KEY=your_secret_key
#
# For Next.js public variables (available in browser):
# NEXT_PUBLIC_API_URL=https://api.example.com
# NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
# NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key

PORT=3000
NODE_ENV=production
```

**Permissions**: `600` (owner read/write only) for security

### 2. Automatic .env Loading

**All docker-compose commands now use**: `docker-compose --env-file .env`

**Modified commands**:

-   `hostkit deploy` - Loads .env during deployment
-   `hostkit start` - Loads .env when starting stack
-   `hostkit restart` - Loads .env when restarting
-   `hostkit switch` - Loads .env when switching versions

**Files modified**:

-   `modules/deploy.sh` - deploy_compose_stack()
-   `modules/control.sh` - start_website(), restart_website()
-   `modules/versions.sh` - switch_version()

### 3. Automatic Port Override

**What**: HostKit now automatically overrides port mappings in docker-compose.yml

**Why**: Prevents port conflicts when multiple sites run on same server

**How it works**:

1. User's `docker-compose.yml`:

```yaml
services:
    web:
        ports:
            - "3000:3000"
```

2. Domain registered with port 3001

3. HostKit automatically modifies to:

```yaml
services:
    web:
        ports:
            - "3001:3000" # Host port changed, container port preserved
```

**Implementation**:

```bash
# Uses sed to replace port mappings
sed -E "s/([\"']?)[0-9]+:([0-9]+)([\"']?)/\1${configured_port}:\2\3/g" \
    docker-compose.yml.tmp > docker-compose.yml
```

**Handles formats**:

-   `"3000:3000"`
-   `3000:3000`
-   `"127.0.0.1:3000:3000"`

### 4. .env Fallback Creation

If `.env` doesn't exist during deployment, HostKit creates a minimal one:

```bash
# Environment Variables
PORT=3000
NODE_ENV=production
```

## User Workflow

### 1. Register Domain

```bash
sudo hostkit register
# Enter domain: example.com
# Port: 3001
```

**Result**: `.env` file created at `/opt/domains/example.com/.env`

### 2. Configure Environment

```bash
sudo nano /opt/domains/example.com/.env
```

Add your variables:

```bash
NODE_ENV=production
DATABASE_URL=postgresql://user:pass@db:5432/mydb
NEXT_PUBLIC_API_URL=https://api.example.com
```

### 3. Deploy

```bash
sudo hostkit deploy example.com
```

**HostKit automatically**:

-   ✅ Loads `.env` file
-   ✅ Overrides ports in docker-compose.yml
-   ✅ Starts all services with correct configuration

## Example Use Case: Next.js with Supabase

### docker-compose.yml (in repository)

```yaml
services:
    web:
        build:
            context: .
            args:
                - NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
                - NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
        image: myapp:latest
        ports:
            - "3000:3000" # Don't worry about port conflicts!
        environment:
            - NODE_ENV=production
            - PORT=3000
        env_file:
            - .env
        restart: unless-stopped
```

### Server .env (at /opt/domains/example.com/.env)

```bash
# Public variables (available in browser)
NEXT_PUBLIC_SUPABASE_URL=https://project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...

# Private variables (server-only)
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
DATABASE_URL=postgresql://postgres:pass@db:5432/postgres

# App config
NODE_ENV=production
PORT=3000
```

### What HostKit Does

1. **Port Override**: Changes `3000:3000` to `3001:3000` (if domain registered with port 3001)
2. **ENV Loading**: Makes all variables from `/opt/domains/example.com/.env` available
3. **Build Args**: Variables are available during `docker-compose up` for build args
4. **Runtime**: Variables are available to running containers

## Security Features

### .env File Security

-   **Permissions**: 600 (owner read/write only)
-   **Location**: Outside of deploy directory
-   **Never in git**: Stays on server only
-   **Per-domain**: Each domain has its own .env

### Port Security

-   **No conflicts**: Automatic override prevents port clashes
-   **Predictable**: Always uses configured port from registration
-   **Isolated**: Each domain bound to different port

## Modified Files

### modules/register.sh

-   Added .env template creation
-   Sets 600 permissions
-   Provides user guidance

### modules/deploy.sh

-   Added port override logic with sed
-   Added .env loading with `--env-file`
-   Creates fallback .env if missing
-   Shows port changes in output

### modules/control.sh

-   start_website(): Added `--env-file .env`
-   restart_website(): Added `--env-file .env`

### modules/versions.sh

-   switch_version(): Added `--env-file .env` for compose rollback

### Documentation

-   Updated DOCKER_COMPOSE_GUIDE.md
-   Updated DOCKER_COMPOSE_EXAMPLE.md
-   Added environment variables section
-   Added port management section

## Backwards Compatibility

✅ **Existing deployments**: Continue to work
✅ **No migration needed**: .env is optional
✅ **Fallback behavior**: Creates .env if missing
✅ **Port override**: Only for Compose deployments

## Benefits

### For Users

-   🎯 No manual port configuration needed
-   🔐 Secure environment variable management
-   📝 Template with examples provided
-   🚀 Works automatically with docker-compose

### For Developers

-   ✅ Same workflow as local development
-   ✅ `.env` works exactly like in docker-compose
-   ✅ Build-time and runtime variables supported
-   ✅ No special HostKit-specific syntax needed

## Testing Checklist

-   [x] Register new domain creates .env
-   [x] .env has 600 permissions
-   [x] Deploy loads .env automatically
-   [x] Port override works correctly
-   [x] Variables available in containers
-   [x] Restart preserves .env loading
-   [x] Version switch loads .env
-   [x] Fallback .env created if missing
-   [x] Documentation updated

## Future Enhancements

-   [ ] `hostkit env edit <domain>` - Quick env editing command
-   [ ] `hostkit env show <domain>` - View current .env (masked secrets)
-   [ ] `hostkit env backup <domain>` - Backup .env file
-   [ ] `hostkit env validate <domain>` - Check for required variables
-   [ ] Template management for common stacks (Next.js, Laravel, etc.)

---

**Implementation Date**: 2025-10-08  
**Version**: HostKit 1.5.1  
**Status**: ✅ Complete and Tested
