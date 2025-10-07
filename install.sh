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
WHITE='\033[1    print_success "Modules installed"

# Setup SSL certificate auto-renewal
print_step "Setting up SSL certificate auto-renewal..."
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    print_success "Auto-renewal cron job added"
else
    print_info "Auto-renewal cron job already exists"
fi

# Create command
print_step "Creating command-line tool..."'
NC='\033[0m'

INSTALL_DIR="/opt/hostkit"
BIN_DIR="/usr/local/bin"

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_step() {
    echo -e "${YELLOW}➜ $1${NC}"
}

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════╗"
echo "║   HOSTKIT Installation v1.2.0         ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (sudo ./install.sh)"
    exit 1
fi

print_step "Checking system requirements..."

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    echo ""
    echo "Install Docker with:"
    echo "  curl -fsSL https://get.docker.com | sh"
    exit 1
fi
print_success "Docker found"

# Check Nginx
if ! command -v nginx &> /dev/null; then
    print_info "Nginx not found, installing..."
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    print_success "Nginx installed"
else
    print_success "Nginx found"
fi

# Check jq
if ! command -v jq &> /dev/null; then
    print_info "jq not found, installing..."
    apt-get install -y jq
    print_success "jq installed"
else
    print_success "jq found"
fi

# Check curl
if ! command -v curl &> /dev/null; then
    print_info "curl not found, installing..."
    apt-get install -y curl
    print_success "curl installed"
else
    print_success "curl found"
fi

# Check unzip
if ! command -v unzip &> /dev/null; then
    print_info "unzip not found, installing..."
    apt-get install -y unzip
    print_success "unzip installed"
else
    print_success "unzip found"
fi

# Check certbot
if ! command -v certbot &> /dev/null; then
    print_info "Certbot not found, installing..."
    apt-get install -y certbot python3-certbot-nginx
    print_success "Certbot installed"
else
    print_success "Certbot found"
fi

echo ""
print_step "Installing HostKit..."

# Create directories
mkdir -p "$INSTALL_DIR/modules"
mkdir -p "/opt/domains"

# Copy main script
print_step "Copying main script..."
if [ -f "hostkit" ]; then
    cp hostkit "$INSTALL_DIR/hostkit.sh"
    print_success "Main script copied"
else
    print_error "hostkit script not found!"
    exit 1
fi

# Copy VERSION file
if [ -f "VERSION" ]; then
    cp VERSION "$INSTALL_DIR/VERSION"
    print_success "VERSION file copied"
else
    echo "1.1.0" > "$INSTALL_DIR/VERSION"
    print_info "VERSION file created"
fi

# Copy modules
print_step "Installing modules..."

# Copy all module files
if [ -d "modules" ]; then
    cp -r modules/* "$INSTALL_DIR/modules/"
    chmod +x "$INSTALL_DIR/modules"/*.sh
    print_success "Modules installed"
else
    # Fallback for individual files
    for module in register.sh deploy.sh control.sh list.sh versions.sh remove.sh users.sh; do
        if [ -f "$module" ]; then
            cp "$module" "$INSTALL_DIR/modules/"
            chmod +x "$INSTALL_DIR/modules/$module"
        fi
    done
    print_info "Modules installed (fallback method)"
fi

# Create command
print_step "Creating command-line tool..."
cp "$INSTALL_DIR/hostkit.sh" "$BIN_DIR/hostkit"
chmod +x "$BIN_DIR/hostkit"
chmod +x "$INSTALL_DIR/hostkit.sh"
chmod +x "$INSTALL_DIR/modules"/*.sh 2>/dev/null || true
print_success "Command 'hostkit' created"

# Install bash completion
print_step "Installing bash completion..."
if [ -f "completions/hostkit" ]; then
    # Install to system completion directory
    if [ -d "/etc/bash_completion.d" ]; then
        cp "completions/hostkit" "/etc/bash_completion.d/"
        print_success "Bash completion installed to /etc/bash_completion.d/"
    elif [ -d "/usr/share/bash-completion/completions" ]; then
        cp "completions/hostkit" "/usr/share/bash-completion/completions/"
        print_success "Bash completion installed to /usr/share/bash-completion/completions/"
    else
        # Fallback: install to user directory
        mkdir -p "$HOME/.bash_completion.d"
        cp "completions/hostkit" "$HOME/.bash_completion.d/"
        echo "source $HOME/.bash_completion.d/hostkit" >> "$HOME/.bashrc"
        print_success "Bash completion installed to $HOME/.bash_completion.d/"
    fi
else
    print_warning "Completion script not found"
fi

# Create Deploy Helper
cat > "$INSTALL_DIR/deploy.sh" << 'DEPLOY_HELPER_EOF'
#!/bin/bash
# Deploy Helper for SSH Deployment
DOMAIN="$1"
hostkit deploy "$DOMAIN"
DEPLOY_HELPER_EOF
chmod +x "$INSTALL_DIR/deploy.sh"

echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════╗"
echo "║   Installation successful! ✓          ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${WHITE}Next steps:${NC}"
echo ""
echo "1. Register your first website:"
echo -e "   ${CYAN}hostkit register${NC}"
echo ""
echo "2. List all websites:"
echo -e "   ${CYAN}hostkit list${NC}"
echo ""
echo "3. Deploy a website:"
echo -e "   ${CYAN}hostkit deploy <domain>${NC}"
echo ""
echo -e "${WHITE}Show help:${NC}"
echo -e "   ${CYAN}hostkit help${NC}"
echo ""
print_info "Installation completed in: $INSTALL_DIR"