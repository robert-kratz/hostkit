#!/bin/bash

# ssh-keys.sh - SSH Key Management for Websites
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

# Directory structure:
# /opt/domains/<domain>/.ssh/keys/
#   ├── key-<name>.rsa (private key)
#   ├── key-<name>.rsa.pub (public key)
#   ├── key-<name>.ed25519 (private key)
#   └── key-<name>.ed25519.pub (public key)

# Get key directory for domain
get_key_directory() {
    local domain="$1"
    echo "$WEB_ROOT/$domain/.ssh/keys"
}

# Get authorized_keys file for domain
get_authorized_keys_file() {
    local domain="$1"
    local config=$(load_domain_config "$domain")
    local username=$(echo "$config" | jq -r '.username')
    
    if [ -z "$username" ]; then
        return 1
    fi
    
    local user_home=$(eval echo ~"$username")
    echo "$user_home/.ssh/authorized_keys"
}

# List all keys for a domain
list_domain_keys() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit list-keys <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit list-keys example.com"
        echo "  hostkit list-keys 0"
        return 1
    fi
    
    # Resolve domain from ID or name
    local domain
    domain=$(resolve_domain "$input")
    if [ $? -ne 0 ]; then
        print_error "Website not found: $input"
        print_info "Use 'hostkit list' to see all registered websites"
        return 1
    fi
    
    local key_dir=$(get_key_directory "$domain")
    
    print_step "SSH Keys for: $domain"
    echo ""
    
    if [ ! -d "$key_dir" ]; then
        print_warning "No keys directory found"
        print_info "Create a new key with: hostkit add-key $domain <key-name>"
        return 0
    fi
    
    # Find all key pairs
    local key_names=()
    while IFS= read -r pub_key; do
        local basename=$(basename "$pub_key")
        # Extract key name from filename (key-<name>.rsa.pub or key-<name>.ed25519.pub)
        local key_name=$(echo "$basename" | sed -E 's/key-(.+)\.(rsa|ed25519)\.pub/\1/')
        if [[ ! " ${key_names[@]} " =~ " ${key_name} " ]]; then
            key_names+=("$key_name")
        fi
    done < <(find "$key_dir" -name "key-*.pub" 2>/dev/null)
    
    if [ ${#key_names[@]} -eq 0 ]; then
        print_warning "No SSH keys found"
        print_info "Create a new key with: hostkit add-key $domain <key-name>"
        return 0
    fi
    
    # Display keys in table format
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${WHITE}║${NC} %-20s ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-22s ${WHITE}║${NC}\n" "KEY NAME" "RSA" "ED25519" "CREATED"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    for key_name in "${key_names[@]}"; do
        local rsa_exists="${RED}✗${NC}"
        local ed25519_exists="${RED}✗${NC}"
        local created="unknown"
        
        # Check RSA key
        if [ -f "$key_dir/key-$key_name.rsa" ]; then
            rsa_exists="${GREEN}✓${NC}"
            created=$(stat -f "%Sm" -t "%Y-%m-%d" "$key_dir/key-$key_name.rsa" 2>/dev/null || stat -c "%y" "$key_dir/key-$key_name.rsa" 2>/dev/null | cut -d' ' -f1)
        fi
        
        # Check Ed25519 key
        if [ -f "$key_dir/key-$key_name.ed25519" ]; then
            ed25519_exists="${GREEN}✓${NC}"
            if [ "$created" = "unknown" ]; then
                created=$(stat -f "%Sm" -t "%Y-%m-%d" "$key_dir/key-$key_name.ed25519" 2>/dev/null || stat -c "%y" "$key_dir/key-$key_name.ed25519" 2>/dev/null | cut -d' ' -f1)
            fi
        fi
        
        printf "${WHITE}║${NC} ${CYAN}%-20s${NC} ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-22s ${WHITE}║${NC}\n" \
            "$key_name" "$rsa_exists" "$ed25519_exists" "$created"
    done
    
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Total: ${#key_names[@]} key(s)"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  hostkit add-key $input <name>     - Create new SSH key"
    echo "  hostkit show-key $input <name>    - Display key content"
    echo "  hostkit remove-key $input <name>  - Remove SSH key"
}

# Add new SSH key
add_domain_key() {
    local input="$1"
    local key_name="$2"
    
    if [ -z "$input" ] || [ -z "$key_name" ]; then
        print_error "Domain/ID or key name missing"
        echo "Usage: hostkit add-key <domain|id> <key-name>"
        echo ""
        echo "Examples:"
        echo "  hostkit add-key example.com github-actions"
        echo "  hostkit add-key 0 deployment-key"
        return 1
    fi
    
    # Resolve domain from ID or name
    local domain
    domain=$(resolve_domain "$input")
    if [ $? -ne 0 ]; then
        print_error "Website not found: $input"
        print_info "Use 'hostkit list' to see all registered websites"
        return 1
    fi
    
    # Validate key name
    if [[ ! "$key_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid key name: $key_name"
        print_info "Key name must contain only letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    local key_dir=$(get_key_directory "$domain")
    local config=$(load_domain_config "$domain")
    local username=$(echo "$config" | jq -r '.username')
    
    # Create keys directory if it doesn't exist
    mkdir -p "$key_dir"
    chmod 700 "$key_dir"
    
    # Check if key already exists
    if [ -f "$key_dir/key-$key_name.rsa" ] || [ -f "$key_dir/key-$key_name.ed25519" ]; then
        print_error "Key with name '$key_name' already exists"
        print_info "Use a different name or remove the existing key first"
        return 1
    fi
    
    print_step "Creating SSH key pair: $key_name"
    echo ""
    
    # Generate RSA key
    print_info "Generating RSA 4096-bit key..."
    ssh-keygen -t rsa -b 4096 -f "$key_dir/key-$key_name.rsa" -N "" -C "hostkit-$domain-$key_name-rsa" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        chmod 600 "$key_dir/key-$key_name.rsa"
        chmod 644 "$key_dir/key-$key_name.rsa.pub"
        print_success "RSA key generated"
    else
        print_error "Failed to generate RSA key"
        return 1
    fi
    
    # Generate Ed25519 key
    print_info "Generating Ed25519 key..."
    ssh-keygen -t ed25519 -f "$key_dir/key-$key_name.ed25519" -N "" -C "hostkit-$domain-$key_name-ed25519" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        chmod 600 "$key_dir/key-$key_name.ed25519"
        chmod 644 "$key_dir/key-$key_name.ed25519.pub"
        print_success "Ed25519 key generated"
    else
        print_warning "Failed to generate Ed25519 key (continuing with RSA only)"
    fi
    
    # Add to authorized_keys
    print_step "Registering keys with user: $username"
    register_key_with_user "$domain" "$key_name"
    
    echo ""
    print_success "SSH key '$key_name' created successfully"
    echo ""
    print_info "View key content with:"
    echo "  hostkit show-key $domain $key_name"
}

# Register key with user's authorized_keys
register_key_with_user() {
    local domain="$1"
    local key_name="$2"
    
    local key_dir=$(get_key_directory "$domain")
    local auth_keys=$(get_authorized_keys_file "$domain")
    
    if [ -z "$auth_keys" ]; then
        print_error "Could not determine authorized_keys file"
        return 1
    fi
    
    local config=$(load_domain_config "$domain")
    local username=$(echo "$config" | jq -r '.username')
    local user_home=$(eval echo ~"$username")
    
    # Ensure .ssh directory exists for user
    mkdir -p "$user_home/.ssh"
    chown "$username:$username" "$user_home/.ssh"
    chmod 700 "$user_home/.ssh"
    
    # Touch authorized_keys if it doesn't exist
    touch "$auth_keys"
    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"
    
    # Add RSA public key
    if [ -f "$key_dir/key-$key_name.rsa.pub" ]; then
        local rsa_pub=$(cat "$key_dir/key-$key_name.rsa.pub")
        # Check if already exists
        if ! grep -Fq "$rsa_pub" "$auth_keys" 2>/dev/null; then
            echo "$rsa_pub" >> "$auth_keys"
            print_success "RSA public key registered"
        fi
    fi
    
    # Add Ed25519 public key
    if [ -f "$key_dir/key-$key_name.ed25519.pub" ]; then
        local ed_pub=$(cat "$key_dir/key-$key_name.ed25519.pub")
        # Check if already exists
        if ! grep -Fq "$ed_pub" "$auth_keys" 2>/dev/null; then
            echo "$ed_pub" >> "$auth_keys"
            print_success "Ed25519 public key registered"
        fi
    fi
    
    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"
}

# Unregister key from user's authorized_keys
unregister_key_from_user() {
    local domain="$1"
    local key_name="$2"
    
    local key_dir=$(get_key_directory "$domain")
    local auth_keys=$(get_authorized_keys_file "$domain")
    
    if [ -z "$auth_keys" ] || [ ! -f "$auth_keys" ]; then
        return 0
    fi
    
    local config=$(load_domain_config "$domain")
    local username=$(echo "$config" | jq -r '.username')
    
    # Remove RSA public key
    if [ -f "$key_dir/key-$key_name.rsa.pub" ]; then
        local rsa_pub=$(cat "$key_dir/key-$key_name.rsa.pub")
        sed -i.bak "\|$rsa_pub|d" "$auth_keys" 2>/dev/null
        print_success "RSA public key unregistered"
    fi
    
    # Remove Ed25519 public key
    if [ -f "$key_dir/key-$key_name.ed25519.pub" ]; then
        local ed_pub=$(cat "$key_dir/key-$key_name.ed25519.pub")
        sed -i.bak "\|$ed_pub|d" "$auth_keys" 2>/dev/null
        print_success "Ed25519 public key unregistered"
    fi
    
    # Clean up backup file
    rm -f "${auth_keys}.bak"
    
    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"
}

# Show key content
show_domain_key() {
    local input="$1"
    local key_name="$2"
    local key_type="${3:-all}"
    
    if [ -z "$input" ] || [ -z "$key_name" ]; then
        print_error "Domain/ID or key name missing"
        echo "Usage: hostkit show-key <domain|id> <key-name> [rsa|ed25519|all]"
        echo ""
        echo "Examples:"
        echo "  hostkit show-key example.com github-actions"
        echo "  hostkit show-key 0 deploy rsa"
        return 1
    fi
    
    # Resolve domain from ID or name
    local domain
    domain=$(resolve_domain "$input")
    if [ $? -ne 0 ]; then
        print_error "Website not found: $input"
        print_info "Use 'hostkit list' to see all registered websites"
        return 1
    fi
    
    local key_dir=$(get_key_directory "$domain")
    
    if [ ! -d "$key_dir" ]; then
        print_error "No keys found for: $domain"
        return 1
    fi
    
    # Check if key exists
    if [ ! -f "$key_dir/key-$key_name.rsa" ] && [ ! -f "$key_dir/key-$key_name.ed25519" ]; then
        print_error "Key '$key_name' not found"
        print_info "Use 'hostkit list-keys $domain' to see available keys"
        return 1
    fi
    
    print_step "SSH Key Content: $key_name (Domain: $domain)"
    echo ""
    
    # Show RSA key
    if [ "$key_type" = "all" ] || [ "$key_type" = "rsa" ]; then
        if [ -f "$key_dir/key-$key_name.rsa" ]; then
            echo -e "${WHITE}RSA Private Key:${NC}"
            echo -e "${YELLOW}cat << 'EOF' > ~/.ssh/hostkit-$domain-$key_name-rsa${NC}"
            cat "$key_dir/key-$key_name.rsa"
            echo -e "${YELLOW}EOF${NC}"
            echo -e "${YELLOW}chmod 600 ~/.ssh/hostkit-$domain-$key_name-rsa${NC}"
            echo ""
            
            echo -e "${WHITE}RSA Public Key:${NC}"
            cat "$key_dir/key-$key_name.rsa.pub"
            echo ""
            echo ""
        fi
    fi
    
    # Show Ed25519 key
    if [ "$key_type" = "all" ] || [ "$key_type" = "ed25519" ]; then
        if [ -f "$key_dir/key-$key_name.ed25519" ]; then
            echo -e "${WHITE}Ed25519 Private Key:${NC}"
            echo -e "${YELLOW}cat << 'EOF' > ~/.ssh/hostkit-$domain-$key_name-ed25519${NC}"
            cat "$key_dir/key-$key_name.ed25519"
            echo -e "${YELLOW}EOF${NC}"
            echo -e "${YELLOW}chmod 600 ~/.ssh/hostkit-$domain-$key_name-ed25519${NC}"
            echo ""
            
            echo -e "${WHITE}Ed25519 Public Key:${NC}"
            cat "$key_dir/key-$key_name.ed25519.pub"
            echo ""
            echo ""
        fi
    fi
    
    echo -e "${WHITE}GitHub Actions Secret Configuration:${NC}"
    echo "Add the following secrets to your GitHub repository:"
    echo ""
    echo -e "Secret name: ${CYAN}DEPLOY_SSH_KEY${NC}"
    echo -e "Secret value: Copy the ${YELLOW}Private Key${NC} content above"
    echo ""
}

# Remove SSH key
remove_domain_key() {
    local input="$1"
    local key_name="$2"
    
    if [ -z "$input" ] || [ -z "$key_name" ]; then
        print_error "Domain/ID or key name missing"
        echo "Usage: hostkit remove-key <domain|id> <key-name>"
        echo ""
        echo "Examples:"
        echo "  hostkit remove-key example.com github-actions"
        echo "  hostkit remove-key 0 old-key"
        return 1
    fi
    
    # Resolve domain from ID or name
    local domain
    domain=$(resolve_domain "$input")
    if [ $? -ne 0 ]; then
        print_error "Website not found: $input"
        print_info "Use 'hostkit list' to see all registered websites"
        return 1
    fi
    
    local key_dir=$(get_key_directory "$domain")
    
    if [ ! -d "$key_dir" ]; then
        print_error "No keys found for: $domain"
        return 1
    fi
    
    # Check if key exists
    if [ ! -f "$key_dir/key-$key_name.rsa" ] && [ ! -f "$key_dir/key-$key_name.ed25519" ]; then
        print_error "Key '$key_name' not found"
        print_info "Use 'hostkit list-keys $domain' to see available keys"
        return 1
    fi
    
    # Disable strict error handling for confirmation
    safe_mode_off
    
    echo ""
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "  WARNING: Key Removal"
    print_warning "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${WHITE}Domain:${NC} $domain"
    echo -e "${WHITE}Key Name:${NC} $key_name"
    echo ""
    print_info "This will:"
    echo "  - Delete private and public key files"
    echo "  - Remove key from authorized_keys"
    echo "  - Prevent authentication with this key"
    echo ""
    
    if ! ask_yes_no "Remove this SSH key?" "n"; then
        print_warning "Cancelled"
        safe_mode_on
        return 0
    fi
    
    # Re-enable strict error handling
    safe_mode_on
    
    print_step "Removing SSH key: $key_name"
    echo ""
    
    # Unregister from authorized_keys
    unregister_key_from_user "$domain" "$key_name"
    
    # Remove key files
    rm -f "$key_dir/key-$key_name.rsa" "$key_dir/key-$key_name.rsa.pub"
    rm -f "$key_dir/key-$key_name.ed25519" "$key_dir/key-$key_name.ed25519.pub"
    
    print_success "SSH key removed"
    echo ""
}