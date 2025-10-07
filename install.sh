#!/bin/bash

# install.sh - HostKit Installation Script
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

INSTALL_DIR="/opt/hostkit"
BIN_DIR="/usr/local/bin"

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_step() {
    echo -e "${WHITE}$1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

check_os() {
    if [ ! -f /etc/os-release ]; then
        print_error "Cannot detect OS. This script requires Ubuntu or Debian."
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]]; then
        print_error "This script only supports Ubuntu and Debian."
        print_info "Detected: $PRETTY_NAME"
        exit 1
    fi
    
    print_success "OS check passed: $PRETTY_NAME"
}

install_dependencies() {
    print_step "Checking and installing dependencies..."
    
    # Update package list
    print_info "Updating package list..."
    apt-get update -qq
    
    # Remove conflicting docker-buildx-plugin if present
    if dpkg -l | grep -q "docker-buildx-plugin"; then
        print_info "Removing conflicting docker-buildx-plugin..."
        DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq docker-buildx-plugin 2>/dev/null || true
    fi
    
    local packages=("docker.io" "nginx" "certbot" "python3-certbot-nginx" "jq" "curl" "bc")
    local to_install=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            to_install+=("$package")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        print_info "Installing: ${to_install[*]}"
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${to_install[@]}"
        print_success "Dependencies installed"
    else
        print_success "All dependencies already installed"
    fi
    
    # Fix any broken packages from docker conflicts
    print_info "Fixing package configuration..."
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get install -f -y -qq 2>/dev/null || true
    
    # Enable and start Docker
    if ! systemctl is-active --quiet docker; then
        systemctl enable docker
        systemctl start docker
        print_success "Docker service started"
    fi
    
    # Enable and start Nginx
    if ! systemctl is-active --quiet nginx; then
        systemctl enable nginx
        systemctl start nginx
        print_success "Nginx service started"
    fi
}

create_directories() {
    print_step "Creating directory structure..."
    
    # Create main directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/modules"
    mkdir -p "$INSTALL_DIR/completions"
    mkdir -p "/opt/domains"
    mkdir -p "/var/log/hostkit"
    
    print_success "Directories created"
}

copy_files() {
    print_step "Copying HostKit files..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy main script
    if [ -f "$SCRIPT_DIR/hostkit" ]; then
        cp "$SCRIPT_DIR/hostkit" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/hostkit"
        print_success "Main script copied"
    else
        print_error "hostkit script not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Copy modules
    if [ -d "$SCRIPT_DIR/modules" ]; then
        cp -r "$SCRIPT_DIR/modules/"* "$INSTALL_DIR/modules/"
        chmod +x "$INSTALL_DIR/modules/"*.sh
        print_success "Modules copied"
    else
        print_warning "modules directory not found"
    fi
    
    # Copy bash completion
    if [ -f "$SCRIPT_DIR/completions/hostkit" ]; then
        cp "$SCRIPT_DIR/completions/hostkit" "$INSTALL_DIR/completions/"
        
        # Install bash completion
        if [ -d "/etc/bash_completion.d" ]; then
            ln -sf "$INSTALL_DIR/completions/hostkit" "/etc/bash_completion.d/hostkit"
            print_success "Bash completion installed"
        fi
    fi
    
    # Copy VERSION file
    if [ -f "$SCRIPT_DIR/VERSION" ]; then
        cp "$SCRIPT_DIR/VERSION" "$INSTALL_DIR/VERSION"
    else
        echo "1.2.0" > "$INSTALL_DIR/VERSION"
    fi
}

create_command() {
    print_step "Creating command-line tool..."
    
    # Create symlink
    ln -sf "$INSTALL_DIR/hostkit" "$BIN_DIR/hostkit"
    
    print_success "Command created: hostkit"
}

setup_ssl_renewal() {
    print_step "Setting up SSL certificate auto-renewal..."
    
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        print_success "Auto-renewal cron job added"
    else
        print_info "Auto-renewal cron job already exists"
    fi
}

create_config() {
    print_step "Creating configuration..."
    
    # Create global config
    cat > "$INSTALL_DIR/config.json" <<EOF
{
  "version": "1.3.0",
  "install_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "next_port": 3000,
  "domains": []
}
EOF
    
    print_success "Configuration created"
}

set_permissions() {
    print_step "Setting permissions..."
    
    # Set ownership
    chown -R root:root "$INSTALL_DIR"
    
    # Set directory permissions
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR/modules"
    chmod 755 "/opt/domains"
    chmod 755 "/var/log/hostkit"
    
    # Set file permissions
    chmod 644 "$INSTALL_DIR/config.json"
    chmod 755 "$INSTALL_DIR/hostkit"
    chmod 755 "$INSTALL_DIR/modules/"*.sh 2>/dev/null || true
    
    print_success "Permissions set"
}

print_completion_message() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║          HostKit installed successfully!                   ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Next steps:${NC}"
    echo -e "  1. Run ${CYAN}hostkit register${NC} to add your first website"
    echo -e "  2. Configure GitHub Actions for automated deployment"
    echo -e "  3. View all commands with ${CYAN}hostkit help${NC}"
    echo ""
    echo -e "${WHITE}Documentation:${NC}"
    echo -e "  • GitHub: ${CYAN}https://github.com/robert-kratz/hostkit${NC}"
    echo -e "  • Docs: ${CYAN}https://github.com/robert-kratz/hostkit/tree/main/docs${NC}"
    echo ""
    echo -e "${WHITE}Version:${NC} $(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "1.3.0")"
    echo ""
}

# Main installation process
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                            ║${NC}"
    echo -e "${CYAN}║                   HostKit Installer                        ║${NC}"
    echo -e "${CYAN}║                                                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    check_os
    install_dependencies
    create_directories
    copy_files
    create_command
    setup_ssl_renewal
    create_config
    set_permissions
    print_completion_message
}

# Run main function
main
