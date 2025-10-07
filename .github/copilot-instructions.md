# HostKit - AI Coding Assistant Instructions

## Project Overview

HostKit is a comprehensive bash-based CLI tool for managing Docker-based websites on VPS servers with automated deployment via GitHub Actions. It provides SSH hardening, Nginx configuration, SSL/TLS management, and isolated deployment environments.

## Architecture & Core Patterns

### Modular Design

-   **Main entry point**: `hostkit` (bash script with 611 lines)
-   **Module system**: `/modules/*.sh` scripts loaded via `source_module()` function
-   **Domain configuration**: Each website stored in `/opt/domains/<domain>/config.json`
-   **Installation base**: All tools installed to `/opt/hostkit/`

### Configuration Management

-   **Domain configs**: JSON files at `/opt/domains/<domain>/config.json`
-   **Global config**: `/opt/hostkit/config.json`
-   **Version tracking**: `/opt/hostkit/VERSION`
-   Use `load_domain_config()` and `save_domain_config()` helper functions consistently
-   All configuration uses `jq` for JSON parsing

### Key Directory Structure

```
/opt/hostkit/          # Installation base
/opt/domains/<domain>/     # Website-specific data
├── config.json           # Domain configuration
├── deploy/               # TAR files from CI/CD
├── images/               # Docker image versions
└── nginx/                # Nginx config fragments
```

## Command Architecture

### Main Commands (hostkit script)

Commands are handled via case statement in main() function:

-   `register` → `modules/register.sh::register_website()`
-   `deploy` → `modules/deploy.sh::deploy_website()`
-   `list` → `modules/list.sh::list_websites()`
-   `info` → `modules/info.sh::show_website_info()`
-   `control` → `modules/control.sh` (start/stop/restart/logs)
-   `versions` → `modules/versions.sh` (versions/switch)
-   `users` → `modules/users.sh` (list-users/show-keys/regenerate-keys/user-info)
-   `ssh-keys` → `modules/ssh-keys.sh` (list-keys/add-key/show-key/remove-key)
-   `remove` → `modules/remove.sh::remove_website()`
-   `uninstall` → `modules/uninstall.sh::uninstall_hostkit()`

### Module Loading Pattern

```bash
source_module() {
    local module="$1"
    source "$SCRIPT_DIR/modules/${module}.sh"
}
```

## Security Patterns

### SSH Hardening (Unique to HostKit)

-   **Dual key generation**: RSA 4096-bit + Ed25519 for compatibility
-   **Command restriction**: SSH wrapper at `/opt/hostkit/ssh-wrapper.sh`
-   **User isolation**: Each domain gets dedicated system user (e.g., `deploy-example-com`)
-   **SSH configs**: Per-user hardening in `/etc/ssh/sshd_config.d/`
-   **Multi-key support**: Multiple named SSH keys per website in `/opt/domains/<domain>/.ssh/keys/`
-   **Automatic authorized_keys sync**: Keys automatically added/removed from user's authorized_keys

### Container Naming Convention

-   **Container names**: Domain with dots replaced by dashes (e.g., `example-com`)
-   **Image tagging**: `<domain>:<version>` and `<domain>:latest`

## Development Workflows

### Version Management

-   **Auto-update checks**: Once per day via `check_for_updates()`
-   **Version comparison**: Custom `version_compare()` function handles semver
-   **GitHub integration**: Pulls from `robert-kratz/hostkit` repository

### Deployment Flow

1. GitHub Actions builds Docker image → TAR file
2. SCP uploads TAR to `/opt/domains/<domain>/deploy/`
3. `hostkit deploy <domain> <tar-file>` loads image and starts container
4. Maintains last 3 versions for rollback capability

### Error Handling Patterns

-   Always use `set -e` for fail-fast behavior
-   Consistent color-coded output functions: `print_success()`, `print_error()`, `print_warning()`
-   User confirmation via `ask_yes_no()` helper

## Project-Specific Conventions

### Bash Style

-   **Color constants**: Defined at script top (RED, GREEN, YELLOW, etc.)
-   **Function naming**: snake_case consistently used
-   **Error messages**: Always include usage examples
-   **Configuration**: All paths use absolute references from defined constants

### Port Management

-   **Port conflict detection**: `check_port_conflict()` prevents duplicate assignments
-   **Auto-assignment**: `get_next_available_port()` starts from 3000
-   **Internal binding**: Containers bound to `127.0.0.1:<port>` for security

### Nginx Integration

-   **Config generation**: Dynamic reverse proxy configs in `/etc/nginx/sites-available/`
-   **SSL automation**: Certbot integration with auto-renewal cron jobs
-   **Redirect handling**: Automatic HTTP→HTTPS and additional domain redirects

## Testing & Validation

### System Requirements

-   Ubuntu/Debian only (tested on Ubuntu 22.04)
-   Dependencies: Docker, Nginx, Certbot, jq, curl
-   Installation script (`install.sh`) handles dependency checks and system setup

### Container Status Checking

Use `get_container_status()` function which returns: `running`, `stopped`, or `not_found`

### File Structure Validation

Always check for required files before operations:

```bash
if [ ! -d "$WEB_ROOT/$domain" ]; then
    print_error "Domain $domain is not registered"
    exit 1
fi
```

## Key Files to Reference

-   `hostkit`: Main script with all helper functions and command routing
-   `modules/register.sh`: Complex domain registration with SSH key generation (703 lines)
-   `modules/deploy.sh`: Docker image deployment and version management
-   `modules/ssh-keys.sh`: Multi-key SSH management system
-   `modules/info.sh`: Detailed website information display
-   `modules/list.sh`: Website listing with SSL status and IDs
-   `modules/uninstall.sh`: Component-based uninstallation system
-   `completions/hostkit`: Bash completion with domain/ID/key support
-   `install.sh`: System setup and dependency installation
-   `SECURITY_ENHANCEMENTS.md`: Detailed security features documentation
-   `SSH_KEY_MANAGEMENT.md`: Multi-key SSH management guide
-   `INPUT_VALIDATION.md`: User input validation documentation
-   `UNINSTALL.md`: Uninstall guide
-   `VERSION`: Single line version file for update system
