#!/bin/bash

# fix-sudo-permissions.sh - Fix sudo permissions for existing deploy users
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
echo -e "${WHITE}║                    HostKit - Fix Sudo Permissions                             ║${NC}"
echo -e "${WHITE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "This script fixes sudo permissions for deploy users to work without TTY"
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
    
    # Update sudoers file
    print_info "  Updating sudoers for: $username"
    
    cat > "/etc/sudoers.d/hostkit-$username" <<EOF
# Deployment permissions for $username
Defaults:$username !requiretty
Defaults:$username !authenticate
$username ALL=(root) NOPASSWD: /usr/bin/hostkit deploy $domain *
$username ALL=(root) NOPASSWD: /usr/local/bin/hostkit deploy $domain *
$username ALL=(root) NOPASSWD: /opt/hostkit/hostkit deploy $domain *
$username ALL=(root) NOPASSWD: /usr/bin/hostkit deploy *
$username ALL=(root) NOPASSWD: /usr/local/bin/hostkit deploy *
$username ALL=(root) NOPASSWD: /opt/hostkit/hostkit deploy *
$username ALL=(root) NOPASSWD: /usr/bin/docker load
$username ALL=(root) NOPASSWD: /usr/bin/docker run *
$username ALL=(root) NOPASSWD: /usr/bin/docker stop *
$username ALL=(root) NOPASSWD: /usr/bin/docker rm *
$username ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx
EOF
    
    chmod 440 "/etc/sudoers.d/hostkit-$username"
    
    # Verify sudoers syntax
    if ! visudo -c -f "/etc/sudoers.d/hostkit-$username" >/dev/null 2>&1; then
        print_error "  Sudoers syntax error! Removing file."
        rm -f "/etc/sudoers.d/hostkit-$username"
        continue
    fi
    
    print_success "  $domain sudoers updated"
    echo ""
done

echo ""
echo -e "${WHITE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║                            Fix Complete                                       ║${NC}"
echo -e "${WHITE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_success "All sudo permissions have been fixed"
echo ""
print_info "Test with: sudo -u <deploy-user> sudo hostkit deploy <domain> <tar-file>"
echo ""
