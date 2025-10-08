#!/bin/bash

# register.sh - Website Registration
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

# Transaction state tracking
declare -a TRANSACTION_STEPS=()
declare TRANSACTION_DOMAIN=""
declare TRANSACTION_USERNAME=""
declare TRANSACTION_ACTIVE=false

# Add a completed step to transaction
transaction_add_step() {
    local step="$1"
    TRANSACTION_STEPS+=("$step")
}

# Rollback all changes
transaction_rollback() {
    if [ "$TRANSACTION_ACTIVE" = false ]; then
        return 0
    fi
    
    echo ""
    print_warning "Rolling back changes..."
    
    # Rollback in reverse order
    for ((i=${#TRANSACTION_STEPS[@]}-1; i>=0; i--)); do
        local step="${TRANSACTION_STEPS[i]}"
        case "$step" in
            "domain_dir")
                if [ -d "$WEB_ROOT/$TRANSACTION_DOMAIN" ]; then
                    print_info "Removing domain directory: $WEB_ROOT/$TRANSACTION_DOMAIN"
                    rm -rf "$WEB_ROOT/$TRANSACTION_DOMAIN"
                fi
                ;;
            "config_saved")
                if [ -f "$WEB_ROOT/$TRANSACTION_DOMAIN/config.json" ]; then
                    print_info "Removing configuration file"
                    rm -f "$WEB_ROOT/$TRANSACTION_DOMAIN/config.json"
                fi
                ;;
            "user_created")
                if [ -n "$TRANSACTION_USERNAME" ] && id "$TRANSACTION_USERNAME" &>/dev/null; then
                    print_info "Removing user: $TRANSACTION_USERNAME"
                    userdel -r "$TRANSACTION_USERNAME" 2>/dev/null || true
                fi
                ;;
            "ssh_keys")
                if [ -d "/home/$TRANSACTION_USERNAME/.ssh" ]; then
                    print_info "Removing SSH keys"
                    rm -rf "/home/$TRANSACTION_USERNAME/.ssh"
                fi
                ;;
            "nginx_config")
                if [ -f "$NGINX_SITES/$TRANSACTION_DOMAIN" ]; then
                    print_info "Removing Nginx configuration"
                    rm -f "$NGINX_SITES/$TRANSACTION_DOMAIN"
                fi
                if [ -L "$NGINX_ENABLED/$TRANSACTION_DOMAIN" ]; then
                    rm -f "$NGINX_ENABLED/$TRANSACTION_DOMAIN"
                fi
                systemctl reload nginx 2>/dev/null || true
                ;;
            "ssl_cert")
                if [ -d "/etc/letsencrypt/live/$TRANSACTION_DOMAIN" ]; then
                    print_info "Removing SSL certificates"
                    certbot delete --cert-name "$TRANSACTION_DOMAIN" --non-interactive 2>/dev/null || true
                fi
                ;;
            "sshd_config")
                if [ -f "/etc/ssh/sshd_config.d/hostkit-$TRANSACTION_USERNAME.conf" ]; then
                    print_info "Removing SSH daemon configuration"
                    rm -f "/etc/ssh/sshd_config.d/hostkit-$TRANSACTION_USERNAME.conf"
                    systemctl reload sshd 2>/dev/null || true
                fi
                ;;
        esac
    done
    
    TRANSACTION_STEPS=()
    TRANSACTION_ACTIVE=false
    print_success "Rollback completed"
}

# Setup trap handlers for cleanup on exit
setup_transaction_trap() {
    trap 'transaction_rollback; exit 130' INT TERM
    TRANSACTION_ACTIVE=true
}

# Remove trap handlers
remove_transaction_trap() {
    trap - INT TERM
    TRANSACTION_ACTIVE=false
}

# Check if port is already in use by another website
check_port_conflict() {
    local port="$1"
    local current_domain="$2"
    
    if [ -d "$WEB_ROOT" ]; then
        for domain_dir in "$WEB_ROOT"/*; do
            if [ -d "$domain_dir" ] && [ -f "$domain_dir/config.json" ]; then
                local domain_name=$(basename "$domain_dir")
                # Skip check for the current domain (for updates)
                if [ "$domain_name" != "$current_domain" ]; then
                    local used_port=$(jq -r '.port' "$domain_dir/config.json" 2>/dev/null)
                    if [ "$used_port" = "$port" ]; then
                        return 1  # Conflict found
                    fi
                fi
            fi
        done
    fi
    return 0  # No conflict
}

# Get next available port starting from a base port
get_next_available_port() {
    local base_port=${1:-3000}
    local port=$base_port
    
    while ! check_port_conflict "$port" ""; do
        ((port++))
        if [ $port -gt 9999 ]; then
            print_error "No available ports found"
            return 1
        fi
    done
    
    echo $port
}

register_website() {
    # Initialize transaction system
    TRANSACTION_STEPS=()
    TRANSACTION_ACTIVE=false
    
    # Disable strict error handling for user input phase
    safe_mode_off
    
    print_step "Starting website registration"
    echo ""
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ This wizard will guide you through the registration process:     ║${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}║ 1. Domain Configuration - Your website's domain name             ║${NC}"
    echo -e "${CYAN}║ 2. Port Assignment - Internal Docker port mapping                ║${NC}"
    echo -e "${CYAN}║ 3. User Setup - Dedicated deployment user                        ║${NC}"
    echo -e "${CYAN}║ 4. Memory Allocation - Resource limits for your container        ║${NC}"
    echo -e "${CYAN}║ 5. SSL Certificate - Automatic HTTPS configuration               ║${NC}"
    echo -e "${CYAN}║ 6. SSH Keys - Secure deployment access                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Main domain with validation and retry
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Step 1: Domain Configuration${NC}"
    echo -e "${CYAN}Examples: example.com, subdomain.example.com${NC}"
    echo ""
    
    # Simple domain input - use plain prompts without colors
    local domain=""
    while [ -z "$domain" ]; do
        echo -n "Main domain: "
        read -r domain
        
        # Clean input: remove all whitespace, ANSI codes, and convert to lowercase
        domain=$(echo "$domain" | sed 's/\x1b\[[0-9;]*m//g' | tr -d ' \t\r\n' | tr '[:upper:]' '[:lower:]')
        
        if [ -z "$domain" ]; then
            echo -e "${RED}✗ Domain cannot be empty${NC}"
            continue
        fi
        
        if [ -d "$WEB_ROOT/$domain" ]; then
            echo -e "${RED}✗ Domain already registered${NC}"
            domain=""
            continue
        fi
        
        if ! validate_domain "$domain"; then
            echo -e "${RED}✗ Invalid domain format${NC}"
            domain=""
            continue
        fi
    done
    
    # Simple redirect domains
    local redirect_domains=()
    echo ""
    if ask_yes_no "Add redirect domains? (e.g., www.$domain)"; then
        echo -e "${CYAN}ℹ Enter domains one by one, then press Enter on empty line to continue${NC}"
        while true; do
            echo -n "Redirect domain: "
            read -r additional_domain
            
            # Clean input: remove ANSI codes, trim whitespace, convert to lowercase
            additional_domain=$(echo "$additional_domain" | sed 's/\x1b\[[0-9;]*m//g' | xargs 2>/dev/null | tr '[:upper:]' '[:lower:]')
            
            # Empty input = done adding domains
            if [ -z "$additional_domain" ] || [ "$additional_domain" = "" ]; then
                if [ ${#redirect_domains[@]} -gt 0 ]; then
                    echo -e "${GREEN}✓ Added ${#redirect_domains[@]} redirect domain(s)${NC}"
                fi
                break
            fi
            
            if validate_domain "$additional_domain" && [ ! -d "$WEB_ROOT/$additional_domain" ]; then
                redirect_domains+=("$additional_domain")
                echo -e "${GREEN}  ✓ Added: $additional_domain${NC}"
            else
                echo -e "${YELLOW}  ⚠ Skipped (invalid or already exists)${NC}"
            fi
        done
    fi
    
    # Simple port input
    local suggested_port=$(get_next_available_port 3000)
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Step 2: Port Assignment${NC}"
    echo ""
    
    local port=""
    while [ -z "$port" ]; do
        echo -n "Internal container port [$suggested_port]: "
        read -r port
        port=${port:-$suggested_port}
        
        # Clean input: remove non-digits
        port=$(echo "$port" | tr -cd '0-9')
        
        if [ -z "$port" ]; then
            port=$suggested_port
        fi
        
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
            echo -e "${RED}✗ Port must be between 1024-65535${NC}"
            port=""
            continue
        fi
        
        if ! check_port_conflict "$port" ""; then
            echo -e "${RED}✗ Port already in use${NC}"
            suggested_port=$(get_next_available_port $((port + 1)))
            echo -e "${CYAN}ℹ Next available: $suggested_port${NC}"
            port=""
        fi
    done
    
    # Optional username input
    local suggested_username="deploy-${domain//./-}"
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Step 3: User Setup (Optional)${NC}"
    echo -e "${CYAN}You can create an SSH user now or skip and do it later${NC}"
    echo -e "${CYAN}Use 'hostkit users add <domain>' to add users later${NC}"
    echo ""
    
    local username=""
    local skip_user=false
    
    if ask_yes_no "Create deployment user now?"; then
        while [ -z "$username" ]; do
            echo -n "Deployment username [$suggested_username]: "
            read -r username
            username=${username:-$suggested_username}
            
            # Clean input: remove ANSI codes, whitespace, convert to lowercase
            username=$(echo "$username" | sed 's/\x1b\[[0-9;]*m//g' | tr -d ' \t\r\n' | tr '[:upper:]' '[:lower:]')
            
            if ! validate_username "$username"; then
                echo -e "${RED}✗ Invalid username (lowercase letters, numbers, hyphens only)${NC}"
                username=""
                continue
            fi
            
            if id "$username" &>/dev/null; then
                echo -e "${RED}✗ User already exists${NC}"
                username=""
            fi
        done
    else
        skip_user=true
        username="none"
        echo -e "${YELLOW}ℹ User creation skipped - you can add users later${NC}"
    fi
    
    # Simple memory allocation
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Step 4: Memory Allocation${NC}"
    echo -e "${CYAN}Common: 512MB (small), 1024MB (medium), 2048MB (large)${NC}"
    echo ""
    
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    local system_reserve=$((total_mem / 5))
    [ "$system_reserve" -lt 512 ] && system_reserve=512
    [ "$system_reserve" -gt 2048 ] && system_reserve=2048
    local available=$((total_mem - system_reserve))
    
    echo -e "${CYAN}System memory: ${total_mem}MB | Available: ${available}MB${NC}"
    echo ""
    
    local memory_limit=""
    while [ -z "$memory_limit" ]; do
        echo -n "Memory limit in MB [512]: "
        read -r memory_limit
        memory_limit=${memory_limit:-512}
        
        # Clean input: only keep digits
        memory_limit=$(echo "$memory_limit" | tr -cd '0-9')
        
        if [ -z "$memory_limit" ]; then
            memory_limit=512
        fi
        
        if ! [[ "$memory_limit" =~ ^[0-9]+$ ]] || [ "$memory_limit" -lt 128 ]; then
            echo -e "${RED}✗ Minimum 128MB required${NC}"
            memory_limit=""
            continue
        fi
        
        if [ "$memory_limit" -gt "$available" ]; then
            echo -e "${RED}✗ Exceeds available memory (${available}MB)${NC}"
            memory_limit=""
        fi
    done
    
    local memory_reservation=$((memory_limit / 2))
    memory_limit="${memory_limit}m"
    memory_reservation="${memory_reservation}m"
    
    echo -e "${GREEN}✓ Memory limit: $memory_limit (reservation: $memory_reservation)${NC}"
    
    # Summary
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Configuration Summary${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Domain:   ${CYAN}$domain${NC}"
    if [ ${#redirect_domains[@]} -gt 0 ]; then
        echo -e "  Redirects: ${CYAN}${redirect_domains[*]}${NC}"
    fi
    echo -e "  Port:     ${CYAN}$port${NC}"
    if [ "$skip_user" = true ]; then
        echo -e "  User:     ${YELLOW}(skipped - add later)${NC}"
    else
        echo -e "  User:     ${CYAN}$username${NC}"
    fi
    echo -e "  Memory:   ${CYAN}$memory_limit${NC}"
    echo ""
    
    if ! ask_yes_no "Proceed with registration?"; then
        print_warning "Registration cancelled"
        safe_mode_on
        return 1
    fi
    
    # Setup transaction tracking and trap handlers
    TRANSACTION_DOMAIN="$domain"
    TRANSACTION_USERNAME="$username"
    setup_transaction_trap
    
    # Re-enable strict error handling for system operations
    safe_mode_on
    
    # Create directory structure
    echo ""
    print_step "Creating directory structure..."
    mkdir -p "$WEB_ROOT/$domain"/{deploy,images,logs}
    transaction_add_step "domain_dir"
    print_success "Directories created"
    
    # Create .env template file
    print_step "Creating environment file template..."
    cat > "$WEB_ROOT/$domain/.env" <<'ENVEOF'
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
ENVEOF
    
    # Set appropriate permissions
    chmod 600 "$WEB_ROOT/$domain/.env"
    print_success ".env file created at $WEB_ROOT/$domain/.env"
    print_info "Edit this file to configure your application's environment variables"
    
    # Create configuration
    local all_domains=("$domain")
    all_domains+=("${redirect_domains[@]}")
    
    # Convert array to JSON
    local domains_json=$(printf '%s\n' "${all_domains[@]}" | jq -R . | jq -s .)
    
    cat > "$WEB_ROOT/$domain/config.json" <<EOF
{
    "domain": "$domain",
    "redirect_domains": $(printf '%s\n' "${redirect_domains[@]}" | jq -R . | jq -s .),
    "all_domains": $domains_json,
    "port": $port,
    "username": "$username",
    "memory_limit": "$memory_limit",
    "memory_reservation": "$memory_reservation",
    "created": "$(date -Iseconds)",
    "current_version": null
}
EOF
    transaction_add_step "config_saved"
    
    # Create SSH user (only if not skipped)
    if [ "$skip_user" = false ]; then
        echo ""
        echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}Step 5: SSH User Setup${NC}"
        echo -e "${CYAN}Creates a dedicated user with SSH keys for secure deployments${NC}"
        echo ""
        
        if ask_yes_no "Create SSH user and keys now?"; then
            create_ssh_user "$domain" "$username"
        else
            echo -e "${YELLOW}ℹ SSH user creation skipped - you can add users later with:${NC}"
            echo -e "${CYAN}  hostkit users add $domain${NC}"
        fi
    else
        echo ""
        echo -e "${YELLOW}ℹ SSH user setup skipped (no user created)${NC}"
    fi
    
    # Setup SSL certificates
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Step 6: SSL Certificate${NC}"
    echo -e "${CYAN}Automatically request Let's Encrypt SSL certificate for HTTPS${NC}"
    echo -e "${CYAN}Your domain must already point to this server's IP address${NC}"
    echo -e "${CYAN}Rate limit: 5 certificates per domain per week${NC}"
    echo ""
    
    if ask_yes_no "Setup SSL certificates with Certbot?"; then
        setup_certbot "$domain" "${all_domains[@]}"
    fi
    
    # Setup Nginx
    if ask_yes_no "Create Nginx configuration?"; then
        setup_nginx "$domain" "$port" "${all_domains[@]}"
    fi
    
    echo ""
    print_success "Website $domain successfully registered!"
    print_info "Deployment directory: $WEB_ROOT/$domain/deploy"
    if [ ${#redirect_domains[@]} -gt 0 ]; then
        print_info "Redirect domains: ${redirect_domains[*]} -> $domain"
    fi
    
    # Show next steps if user was skipped
    if [ "$skip_user" = true ]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}Next Steps:${NC}"
        echo -e "${CYAN}  1. Create deployment user:${NC}"
        echo -e "     hostkit users add $domain"
        echo -e "${CYAN}  2. Deploy your application:${NC}"
        echo -e "     hostkit deploy $domain /path/to/your-app.tar"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    # Transaction completed successfully - remove trap handlers
    remove_transaction_trap
    print_success "Registration completed successfully - all changes committed"
}

create_ssh_user() {
    local domain="$1"
    local username="$2"
    
    print_step "Creating SSH user $username..."
    
    # Create user with additional security settings
    if id "$username" &>/dev/null; then
        print_warning "User $username already exists"
    else
        # Create user with restricted shell and no login password
        useradd -m -s /bin/bash -d "/home/$username" -U "$username"
        # Lock the password to prevent password-based login
        passwd -l "$username" >/dev/null 2>&1
        # Set account expiry to never
        chage -E -1 "$username" >/dev/null 2>&1
        transaction_add_step "user_created"
        print_success "User created with hardened settings"
    fi
    
    # Create .ssh directory with strict permissions
    local ssh_dir="/home/$username/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Generate SSH key pair with enhanced security
    local key_name="deploy-${domain//./-}"
    local private_key="$ssh_dir/$key_name"
    local public_key="$ssh_dir/${key_name}.pub"
    
    if [ -f "$private_key" ] || [ -f "${private_key}-rsa" ]; then
        print_warning "SSH keys already exist"
        if ask_yes_no "Regenerate SSH keys for better security?"; then
            # Remove both Ed25519 and RSA keys
            rm -f "$private_key" "$public_key"
            rm -f "${private_key}-rsa" "${public_key}-rsa"
        else
            print_info "Using existing keys"
        fi
    fi
    
    if [ ! -f "$private_key" ] || [ ! -f "${private_key}-rsa" ]; then
        print_step "Generating hardened SSH key pair..."
        
        # Ensure old keys are completely removed before generating new ones
        rm -f "$private_key" "$public_key" "${private_key}-rsa" "${public_key}-rsa"
        
        # Generate RSA key with 4096 bits and modern cipher for GitHub Actions compatibility
        # Also generate ed25519 as primary (more secure)
        # Using -y to force overwrite without prompting (though we already deleted)
        ssh-keygen -t rsa -b 4096 -f "${private_key}-rsa" -N "" -C "deploy-rsa@$domain" -q >/dev/null 2>&1
        ssh-keygen -t ed25519 -f "$private_key" -N "" -C "deploy@$domain" -q >/dev/null 2>&1
        
        transaction_add_step "ssh_keys"
        print_success "SSH keys generated (both RSA 4096-bit and Ed25519)"
        print_info "RSA key: ${private_key}-rsa (GitHub Actions compatible)"
        print_info "Ed25519 key: $private_key (recommended for modern systems)"
    fi
    
    # Setup authorized keys with both key types
    > "$ssh_dir/authorized_keys"  # Clear existing keys
    if [ -f "$public_key" ]; then
        cat "$public_key" >> "$ssh_dir/authorized_keys"
    fi
    if [ -f "${public_key}-rsa" ]; then
        cat "${public_key}-rsa" >> "$ssh_dir/authorized_keys"
    fi
    
    # Harden SSH configuration for this user
    local ssh_config_dir="/etc/ssh/sshd_config.d"
    mkdir -p "$ssh_config_dir"
    
    cat > "$ssh_config_dir/hostkit-${username}.conf" <<EOF
# SSH hardening for deployment user $username
Match User $username
    # Disable password authentication for this user
    PasswordAuthentication no
    # Disable challenge-response authentication
    ChallengeResponseAuthentication no
    # Force public key authentication only
    AuthenticationMethods publickey
    # Restrict to specific commands only (allows SCP/SFTP via wrapper)
    ForceCommand /opt/hostkit/ssh-wrapper.sh
    # Disable port forwarding
    AllowTcpForwarding no
    AllowStreamLocalForwarding no
    # Disable tty allocation for scripts (allows SCP to work)
    PermitTTY no
    # Disable X11 forwarding
    X11Forwarding no
    # Set idle timeout (10 minutes)
    ClientAliveInterval 300
    ClientAliveCountMax 2
EOF
    transaction_add_step "sshd_config"
    
    # Set strict permissions
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chmod 600 "$private_key" 2>/dev/null || true
    chmod 600 "${private_key}-rsa" 2>/dev/null || true  
    chmod 644 "$public_key" 2>/dev/null || true
    chmod 644 "${public_key}-rsa" 2>/dev/null || true
    chown -R "$username:$username" "$ssh_dir"
    
    # Grant access to deployment folder with proper permissions
    chown -R "$username:$username" "$WEB_ROOT/$domain/deploy"
    chmod 775 "$WEB_ROOT/$domain/deploy"
    # Ensure user can write files in deploy directory
    setfacl -R -m u:${username}:rwx "$WEB_ROOT/$domain/deploy" 2>/dev/null || true
    setfacl -d -m u:${username}:rwx "$WEB_ROOT/$domain/deploy" 2>/dev/null || true
    
    # Enhanced sudo permissions - only specific commands
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
    
    # Create SSH wrapper script for command restriction
    create_ssh_wrapper "$username"
    
    # Create and setup SSH log file with proper permissions
    touch /var/log/hostkit-ssh.log 2>/dev/null || true
    chmod 666 /var/log/hostkit-ssh.log 2>/dev/null || true
    
    # Restart SSH service to apply configuration
    systemctl reload sshd 2>/dev/null || print_warning "Could not reload SSH service"
    
    echo ""
    print_success "SSH user configured with enhanced security"
    
    # Display both keys for copying
    display_ssh_keys_for_copying "$username" "$private_key" "$domain"
}

# Create SSH wrapper script for command restriction
create_ssh_wrapper() {
    local username="$1"
    
    cat > "/opt/hostkit/ssh-wrapper.sh" <<'EOF'
#!/bin/bash
# SSH Command Wrapper for Deployment Users
# Restricts commands to deployment-related operations only

# Log all connection attempts (ignore errors if log file not writable)
echo "$(date): SSH connection from $SSH_CLIENT as $USER: $SSH_ORIGINAL_COMMAND" >> /var/log/hostkit-ssh.log 2>/dev/null || true

# If no command specified, deny interactive shell
if [ -z "$SSH_ORIGINAL_COMMAND" ]; then
    echo "ERROR: Interactive shell access not allowed"
    echo "This account is restricted to deployment operations only"
    exit 1
fi

# Allow only specific commands for deployment
case "$SSH_ORIGINAL_COMMAND" in
    # Allow deployment commands (must use sudo)
    "sudo hostkit deploy "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow Docker operations for deployment
    "sudo /opt/hostkit/deploy.sh "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow mkdir for deployment directory (required by GitHub Actions SCP)
    "mkdir -p /opt/domains/"*"/deploy/"*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    mkdir\ -p\ /opt/domains/*/deploy/*)
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
        return 1
        ;;
esac
EOF
    
    chmod +x "/opt/hostkit/ssh-wrapper.sh"
    
    # Create log file with proper permissions
    touch /var/log/hostkit-ssh.log
    chmod 644 /var/log/hostkit-ssh.log
}

# Display SSH keys with copy-paste ready format
display_ssh_keys_for_copying() {
    local username="$1"
    local private_key="$2"
    local domain="$3"
    
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                          SSH KEYS FOR DEPLOYMENT                               ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    print_info "Two key types generated for maximum compatibility:"
    echo -e "  ${GREEN}1. Ed25519${NC} - Recommended for modern systems (smaller, faster, more secure)"
    echo -e "  ${GREEN}2. RSA 4096-bit${NC} - Compatible with older systems and GitHub Actions"
    echo ""
    
    # Ed25519 Private Key
    if [ -f "$private_key" ]; then
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                          Ed25519 PRIVATE KEY                                  ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}Copy this command to save the Ed25519 private key locally:${NC}"
        echo ""
        echo -e "${GREEN}cat > ~/.ssh/deploy-${domain//./-}-ed25519 << 'EOF'${NC}"
        cat "$private_key"
        echo -e "${GREEN}EOF${NC}"
        echo -e "${GREEN}chmod 600 ~/.ssh/deploy-${domain//./-}-ed25519${NC}"
        echo ""
    fi
    
    # RSA Private Key
    if [ -f "${private_key}-rsa" ]; then
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                          RSA 4096 PRIVATE KEY                                 ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}Copy this command to save the RSA private key locally (GitHub Actions):${NC}"
        echo ""
        echo -e "${GREEN}cat > ~/.ssh/deploy-${domain//./-}-rsa << 'EOF'${NC}"
        cat "${private_key}-rsa"
        echo -e "${GREEN}EOF${NC}"
        echo -e "${GREEN}chmod 600 ~/.ssh/deploy-${domain//./-}-rsa${NC}"
        echo ""
    fi
    
    # Ed25519 Public Key
    if [ -f "${private_key}.pub" ]; then
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                          Ed25519 PUBLIC KEY                                   ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}Copy this command to save the Ed25519 public key locally:${NC}"
        echo ""
        echo -e "${GREEN}cat > ~/.ssh/deploy-${domain//./-}-ed25519.pub << 'EOF'${NC}"
        cat "${private_key}.pub"
        echo -e "${GREEN}EOF${NC}"
        echo ""
    fi
    
    # RSA Public Key
    if [ -f "${private_key}-rsa.pub" ]; then
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                          RSA 4096 PUBLIC KEY                                  ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}Copy this command to save the RSA public key locally:${NC}"
        echo ""
        echo -e "${GREEN}cat > ~/.ssh/deploy-${domain//./-}-rsa.pub << 'EOF'${NC}"
        cat "${private_key}-rsa.pub"
        echo -e "${GREEN}EOF${NC}"
        echo ""
    fi
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                             USAGE INSTRUCTIONS                                 ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}For GitHub Actions, add this as a repository secret:${NC}"
    echo -e "  Secret name: ${CYAN}DEPLOY_SSH_KEY${NC}"
    echo -e "  Secret value: ${CYAN}Contents of the RSA private key${NC}"
    echo ""
    echo -e "${WHITE}For manual SSH connection:${NC}"
    echo -e "  ${CYAN}ssh -i ~/.ssh/deploy-${domain//./-}-ed25519 $username@your-server${NC}"
    echo -e "  ${CYAN}ssh -i ~/.ssh/deploy-${domain//./-}-rsa $username@your-server${NC}"
    echo ""
    echo -e "${WHITE}For SCP file upload:${NC}"
    echo -e "  ${CYAN}scp -i ~/.ssh/deploy-${domain//./-}-ed25519 image.tar $username@your-server:~/deploy/${NC}"
    echo ""
    print_warning "Save these keys securely! They will not be shown again."
    print_info "Keys are also stored on the server at: /home/$username/.ssh/"
    echo ""
    echo -e "${RED}Press Enter to continue (keys will be cleared from screen)...${NC}"
    read -r
    clear
    print_success "SSH keys generated and displayed. User is ready for deployment!"
}

setup_certbot() {
    local domain="$1"
    shift
    local all_domains=("$@")
    
    print_step "Setting up SSL certificates..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        print_warning "Certbot not installed. Installing certbot..."
        apt-get update && apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Check if certificate already exists and covers all domains
    if check_certificate_exists "$domain"; then
        local days_left=$(days_until_expiry "$domain")
        print_info "Existing certificate found for $domain"
        print_info "Certificate expires in $days_left days"
        
        if check_certificate_covers_domains "$domain" "${all_domains[@]}"; then
            if [ $days_left -gt 30 ]; then
                print_success "Existing certificate covers all domains and is valid for $days_left days"
                print_info "Skipping certificate request to avoid rate limits"
                return 0
            else
                print_warning "Certificate expires in $days_left days, will renew"
            fi
        else
            print_warning "Existing certificate doesn't cover all required domains"
            print_info "Required domains: ${all_domains[*]}"
            
            # Backup existing certificate before requesting new one
            backup_certificate "$domain"
        fi
    fi
    
    # Create certificates for all domains
    local domain_args=""
    for d in "${all_domains[@]}"; do
        domain_args="$domain_args -d $d"
    done
    
    local domains_list=$(IFS=", "; echo "${all_domains[*]}")
    
    # Check if we're close to rate limits (basic protection)
    local recent_certs=$(find /etc/letsencrypt/live -name "cert.pem" -newer /etc/letsencrypt/live -mtime -7 2>/dev/null | wc -l)
    if [ $recent_certs -gt 3 ]; then
        print_warning "Multiple certificates issued recently. Let's Encrypt has rate limits."
        if ! ask_yes_no "Continue with certificate request? (Rate limit: 5 certs per domain per week)"; then
            print_info "Certificate request skipped"
            return 1
        fi
    fi
    
    print_step "Requesting certificates for: $domains_list"
    
    if certbot certonly --nginx $domain_args --non-interactive --agree-tos --email "admin@$domain" --expand; then
        transaction_add_step "ssl_cert"
        print_success "SSL certificates successfully created/updated"
        
        # Verify the new certificate covers all domains
        if check_certificate_covers_domains "$domain" "${all_domains[@]}"; then
            print_success "Certificate verified to cover all domains"
        else
            print_warning "Certificate may not cover all domains - manual verification recommended"
        fi
    else
        local exit_code=$?
        print_error "Error creating certificates (exit code: $exit_code)"
        
        if [ $exit_code -eq 1 ]; then
            print_warning "This might be a rate limit issue with Let's Encrypt"
            print_info "Let's Encrypt allows 5 certificates per registered domain per week"
            print_info "You can check your rate limit status at: https://crt.sh/?q=$domain"
        fi
        
        print_info "You can try again later or request manually with:"
        print_info "certbot certonly --nginx $domain_args"
        return 1
    fi
}

setup_nginx() {
    local domain="$1"
    local port="$2"
    shift 2
    local all_domains=("$@")
    local redirect_domains=("${all_domains[@]:1}")  # All domains except the first (main domain)
    
    print_step "Creating Nginx configuration..."
    
    # Find certificate directory (may have suffix like -0001)
    local cert_dir=""
    local cert_exists=false
    
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        cert_dir="$domain"
        cert_exists=true
    else
        # Check for directories with suffixes (e.g., domain-0001)
        for dir in /etc/letsencrypt/live/${domain}* /etc/letsencrypt/live/${domain}-*; do
            if [ -f "$dir/fullchain.pem" ]; then
                cert_dir=$(basename "$dir")
                cert_exists=true
                break
            fi
        done
    fi
    
    if [ "$cert_exists" = true ]; then
        print_info "SSL certificate found at: /etc/letsencrypt/live/$cert_dir"
    else
        print_warning "No SSL certificate found, creating HTTP configuration"
    fi
    
    local config_file="$NGINX_SITES/$domain"
    
    # Create server names list for main domain
    local server_names="${all_domains[*]}"
    
    cat > "$config_file" <<EOF
# Nginx configuration for $domain
# Generated on $(date)

upstream ${domain//./_}_backend {
    server 127.0.0.1:$port;
}

# Main domain configuration
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

EOF

    if [ "$cert_exists" = true ]; then
        cat >> "$config_file" <<EOF
    # SSL redirect
    return 301 https://$domain\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name $domain;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$cert_dir/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$cert_dir/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

EOF
    fi

    cat >> "$config_file" <<EOF
    # Logging
    access_log $WEB_ROOT/$domain/logs/access.log;
    error_log $WEB_ROOT/$domain/logs/error.log;

    # Proxy settings
    location / {
        proxy_pass http://${domain//./_}_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Client Body Size
    client_max_body_size 50M;
}

EOF

    # Add redirect configurations for additional domains
    if [ ${#redirect_domains[@]} -gt 0 ]; then
        cat >> "$config_file" <<EOF
# Redirect domains to main domain
server {
    listen 80;
    listen [::]:80;
EOF
        
        if [ "$cert_exists" = true ]; then
            cat >> "$config_file" <<EOF
    server_name ${redirect_domains[*]};
    return 301 https://$domain\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
EOF
        fi
        
        cat >> "$config_file" <<EOF
    server_name ${redirect_domains[*]};
EOF
        
        if [ "$cert_exists" = true ]; then
            cat >> "$config_file" <<EOF
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$cert_dir/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$cert_dir/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
EOF
        fi
        
        local redirect_target
        if [ "$cert_exists" = true ]; then
            redirect_target="https://$domain"
        else
            redirect_target="http://$domain"
        fi
        
        cat >> "$config_file" <<EOF
    
    return 301 $redirect_target\$request_uri;
}
EOF
    fi

    # Enable site
    ln -sf "$config_file" "$NGINX_ENABLED/$domain"
    transaction_add_step "nginx_config"
    
    # Test Nginx configuration
    print_step "Testing Nginx configuration..."
    if nginx -t 2>&1 | grep -q "successful"; then
        print_step "Reloading Nginx..."
        if systemctl reload nginx 2>&1; then
            print_success "Nginx configuration created and activated"
            if [ ${#redirect_domains[@]} -gt 0 ]; then
                print_info "Redirect domains configured: ${redirect_domains[*]} -> $domain"
            fi
        else
            print_error "Failed to reload Nginx"
            print_warning "Try manually: sudo systemctl reload nginx"
        fi
    else
        print_error "Nginx configuration test failed:"
        nginx -t 2>&1
        print_warning "Configuration created but not activated"
        print_info "Fix the errors and run: sudo nginx -t && sudo systemctl reload nginx"
    fi
}