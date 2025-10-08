#!/bin/bash

# fix-deploy-permissions.sh - Fix SCP upload permissions for existing domains
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run as root"
    exit 1
fi

# Check if HostKit is installed
if [ ! -d "/opt/hostkit" ]; then
    print_error "HostKit is not installed"
    exit 1
fi

if [ ! -d "/opt/domains" ]; then
    print_error "No domains directory found"
    exit 1
fi

echo -e "${WHITE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                    HostKit - Fix Deploy Permissions                           ║${NC}"
echo -e "${WHITE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "This script fixes SCP upload permissions for GitHub Actions deployments"
echo ""

# Count domains
domain_count=$(find /opt/domains -mindepth 1 -maxdepth 1 -type d | wc -l)

if [ "$domain_count" -eq 0 ]; then
    print_warning "No domains found"
    exit 0
fi

print_info "Found $domain_count domain(s) to process"
echo ""

# Process each domain
for domain_dir in /opt/domains/*; do
    if [ ! -d "$domain_dir" ]; then
        continue
    fi
    
    domain=$(basename "$domain_dir")
    config_file="$domain_dir/config.json"
    
    if [ ! -f "$config_file" ]; then
        print_warning "Skipping $domain (no config.json found)"
        continue
    fi
    
    print_step "Processing domain: $domain"
    
    # Get deploy username from config
    username=$(jq -r '.users[0].username // empty' "$config_file" 2>/dev/null)
    
    if [ -z "$username" ]; then
        print_warning "  No deploy user found in config - skipping"
        continue
    fi
    
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        print_warning "  User $username does not exist - skipping"
        continue
    fi
    
    # Check if deploy directory exists
    if [ ! -d "$domain_dir/deploy" ]; then
        print_warning "  Deploy directory does not exist - creating"
        mkdir -p "$domain_dir/deploy"
    fi
    
    # Fix ownership
    print_info "  Setting ownership: $username:$username"
    chown -R "$username:$username" "$domain_dir/deploy"
    
    # Fix permissions
    print_info "  Setting permissions: 775"
    chmod 775 "$domain_dir/deploy"
    
    # Set ACL permissions (if supported)
    if command -v setfacl &> /dev/null; then
        print_info "  Setting ACL permissions"
        setfacl -R -m u:${username}:rwx "$domain_dir/deploy" 2>/dev/null || print_warning "  ACL not supported on this filesystem"
        setfacl -d -m u:${username}:rwx "$domain_dir/deploy" 2>/dev/null || true
    else
        print_warning "  setfacl not available (ACL not supported)"
    fi
    
    print_success "  $domain permissions fixed"
    echo ""
done

# Update SSH wrapper
print_step "Updating SSH wrapper"

if [ -f "/opt/hostkit/ssh-wrapper.sh" ]; then
    print_info "Creating backup of current SSH wrapper"
    cp /opt/hostkit/ssh-wrapper.sh /opt/hostkit/ssh-wrapper.sh.backup
    
    cat > "/opt/hostkit/ssh-wrapper.sh" <<'EOF'
#!/bin/bash
# SSH Command Wrapper for Deployment Users
# Restricts commands to deployment-related operations only

# Log all connection attempts
echo "$(date): SSH connection from $SSH_CLIENT as $USER: $SSH_ORIGINAL_COMMAND" >> /var/log/hostkit-ssh.log

# If no command specified, deny interactive shell
if [ -z "$SSH_ORIGINAL_COMMAND" ]; then
    echo "ERROR: Interactive shell access not allowed"
    echo "This account is restricted to deployment operations only"
    exit 1
fi

# Allow only specific commands for deployment
case "$SSH_ORIGINAL_COMMAND" in
    # Allow deployment commands
    "sudo hostkit deploy "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    "hostkit deploy "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow Docker operations for deployment
    "sudo /opt/hostkit/deploy.sh "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow SCP file uploads to deployment directory (target mode)
    # This covers all SCP patterns from GitHub Actions and manual uploads
    scp\ *)
        # Check if it's a target mode upload (-t flag) to deploy directory
        if [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*/deploy/ ]] || [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*deploy/ ]]; then
            exec $SSH_ORIGINAL_COMMAND
        else
            echo "ERROR: SCP only allowed to deployment directories (/opt/domains/*/deploy/)"
            exit 1
        fi
        ;;
    # Allow rsync to deployment directory
    "rsync "*)
        if [[ "$SSH_ORIGINAL_COMMAND" == *"/deploy/"* ]]; then
            exec $SSH_ORIGINAL_COMMAND
        else
            echo "ERROR: rsync only allowed to deployment directories"
            exit 1
        fi
        ;;
    # Allow SFTP subsystem for file upload
    "internal-sftp")
        exec /usr/lib/openssh/sftp-server
        ;;
    # Allow sftp-server directly
    /usr/lib/openssh/sftp-server*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    /usr/libexec/openssh/sftp-server*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Reject all other commands
    *)
        echo "ERROR: Command not allowed: $SSH_ORIGINAL_COMMAND"
        echo "Allowed operations:"
        echo "  - File upload to deployment directory"
        echo "  - hostkit deploy commands"
        echo "  - Deployment-related Docker operations"
        exit 1
        ;;
esac
EOF
    
    chmod +x "/opt/hostkit/ssh-wrapper.sh"
    print_success "SSH wrapper updated"
else
    print_warning "SSH wrapper not found at /opt/hostkit/ssh-wrapper.sh"
fi

echo ""
echo -e "${WHITE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                            Fix Complete                                       ║${NC}"
echo -e "${WHITE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_success "All deploy permissions have been fixed"
print_info "You can now test GitHub Actions deployments"
echo ""
print_info "Test with: scp -i ~/.ssh/deploy-key image.tar deploy-user@server:/opt/domains/example.com/deploy/"
echo ""
