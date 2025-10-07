#!/bin/bash

# register.sh - Website registration

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
    print_step "Starting website registration"
    echo ""
    
    # Main domain
    echo -ne "${CYAN}Main domain (e.g. example.com): ${NC}"
    read -r domain
    
    if [ -z "$domain" ]; then
        print_error "Domain cannot be empty"
        return 1
    fi
    
    # Check if domain already exists
    if [ -d "$WEB_ROOT/$domain" ]; then
        print_error "Domain $domain is already registered"
        return 1
    fi
    
    # Additional redirect domains
    local redirect_domains=()
    echo ""
    print_info "You can add additional domains that will redirect to the main domain"
    
    if ask_yes_no "Do you want to add redirect domains?"; then
        echo ""
        while true; do
            echo -ne "${CYAN}Additional domain (or Enter to finish): ${NC}"
            read -r additional_domain
            
            if [ -z "$additional_domain" ]; then
                break
            fi
            
            # Check if additional domain already exists
            if [ -d "$WEB_ROOT/$additional_domain" ]; then
                print_warning "Domain $additional_domain is already registered, skipping"
                continue
            fi
            
            redirect_domains+=("$additional_domain")
            print_success "Added: $additional_domain"
        done
    fi
    
    # Port with conflict detection
    local suggested_port=$(get_next_available_port 3000)
    echo ""
    echo -ne "${CYAN}Internal container port (suggested: $suggested_port): ${NC}"
    read -r port
    port=${port:-$suggested_port}
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        print_error "Port must be a number"
        return 1
    fi
    
    # Check for port conflicts
    if ! check_port_conflict "$port" "$domain"; then
        print_error "Port $port is already in use by another website"
        local next_port=$(get_next_available_port $((port + 1)))
        print_info "Next available port: $next_port"
        return 1
    fi
    
    # Username
    echo ""
    echo -ne "${CYAN}Deployment username (Enter for deploy-${domain//./-}): ${NC}"
    read -r username
    username=${username:-deploy-${domain//./-}}
    
    echo ""
    print_info "Registering website with the following configuration:"
    echo -e "  ${WHITE}Main domain:${NC} $domain"
    if [ ${#redirect_domains[@]} -gt 0 ]; then
        echo -e "  ${WHITE}Redirect domains:${NC} ${redirect_domains[*]}"
    fi
    echo -e "  ${WHITE}Port:${NC} $port"
    echo -e "  ${WHITE}Username:${NC} $username"
    echo ""
    
    if ! ask_yes_no "Continue?"; then
        print_warning "Registration cancelled"
        exit 0
    fi
    
    # Create directory structure
    echo ""
    print_step "Creating directory structure..."
    mkdir -p "$WEB_ROOT/$domain"/{deploy,images,logs}
    print_success "Directories created"
    
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
    "created": "$(date -Iseconds)",
    "current_version": null
}
EOF
    
    # Create SSH user
    if ask_yes_no "Create SSH user?"; then
        create_ssh_user "$domain" "$username"
    fi
    
    # Setup SSL certificates
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
    
    if [ -f "$private_key" ]; then
        print_warning "SSH keys already exist"
        if ask_yes_no "Regenerate SSH keys for better security?"; then
            rm -f "$private_key" "$public_key"
        else
            print_info "Using existing keys"
        fi
    fi
    
    if [ ! -f "$private_key" ]; then
        print_step "Generating hardened SSH key pair..."
        
        # Generate RSA key with 4096 bits and modern cipher for GitHub Actions compatibility
        # Also generate ed25519 as primary (more secure)
        ssh-keygen -t rsa -b 4096 -f "${private_key}-rsa" -N "" -C "deploy-rsa@$domain" >/dev/null 2>&1
        ssh-keygen -t ed25519 -f "$private_key" -N "" -C "deploy@$domain" >/dev/null 2>&1
        
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
    
    cat > "$ssh_config_dir/${username}.conf" <<EOF
# SSH hardening for deployment user $username
Match User $username
    # Disable password authentication for this user
    PasswordAuthentication no
    # Disable challenge-response authentication
    ChallengeResponseAuthentication no
    # Force public key authentication only
    AuthenticationMethods publickey
    # Restrict to specific commands only
    ForceCommand /opt/hostkit/ssh-wrapper.sh
    # Disable port forwarding
    AllowTcpForwarding no
    AllowStreamLocalForwarding no
    # Disable tty allocation for scripts
    PermitTTY no
    # Disable X11 forwarding
    X11Forwarding no
    # Set idle timeout (10 minutes)
    ClientAliveInterval 300
    ClientAliveCountMax 2
EOF
    
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
    chmod 755 "$WEB_ROOT/$domain/deploy"
    
    # Enhanced sudo permissions - only specific commands
    cat > "/etc/sudoers.d/$username" <<EOF
# Deployment permissions for $username
Defaults:$username !requiretty
$username ALL=(root) NOPASSWD: /opt/hostkit/deploy.sh $domain *
$username ALL=(root) NOPASSWD: /usr/bin/docker load
$username ALL=(root) NOPASSWD: /usr/bin/docker run *
$username ALL=(root) NOPASSWD: /usr/bin/docker stop *
$username ALL=(root) NOPASSWD: /usr/bin/docker rm *
$username ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx
EOF
    chmod 440 "/etc/sudoers.d/$username"
    
    # Create SSH wrapper script for command restriction
    create_ssh_wrapper "$username"
    
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

# Log all connection attempts
echo "$(date): SSH connection from $SSH_CLIENT as $USER: $SSH_ORIGINAL_COMMAND" >> /var/log/hostkit-ssh.log

# Allow only specific commands for deployment
case "$SSH_ORIGINAL_COMMAND" in
    # Allow deployment commands
    "hostkit deploy "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow Docker operations for deployment
    "sudo /opt/hostkit/deploy.sh "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow file upload to deployment directory
    "scp "*" "*/deploy/"*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow rsync to deployment directory
    "rsync "*)
        if [[ "$SSH_ORIGINAL_COMMAND" == *"/deploy/"* ]]; then
            exec $SSH_ORIGINAL_COMMAND
        else
            echo "ERROR: rsync only allowed to deployment directories"
            return 1
        fi
        ;;
    # Allow SFTP for file upload (restricted to home directory)
    "internal-sftp")
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
    
    local cert_exists=false
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        cert_exists=true
        print_info "SSL certificate found, creating HTTPS configuration"
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
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
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
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
EOF
        fi
        
        cat >> "$config_file" <<EOF
    server_name ${redirect_domains[*]};
EOF
        
        if [ "$cert_exists" = true ]; then
            cat >> "$config_file" <<EOF
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
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
    
    # Test Nginx configuration
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        print_success "Nginx configuration created and activated"
        if [ ${#redirect_domains[@]} -gt 0 ]; then
            print_info "Redirect domains configured: ${redirect_domains[*]} -> $domain"
        fi
    else
        print_error "Nginx configuration error"
        nginx -t
    fi
}