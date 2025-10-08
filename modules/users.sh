#!/bin/bash

# users.sh - User Management and Key Status
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

list_users_with_keys() {
    print_step "User Accounts and SSH Key Status"
    echo ""
    
    # Find all domains and their users
    local users_data=()
    if [ -d "$WEB_ROOT" ]; then
        while IFS= read -r dir; do
            if [ -f "$dir/config.json" ]; then
                local domain=$(basename "$dir")
                local config=$(cat "$dir/config.json")
                local username=$(echo "$config" | jq -r '.username // "unknown"')
                local port=$(echo "$config" | jq -r '.port // "unknown"')
                local created=$(echo "$config" | jq -r '.created // "unknown"')
                
                # Get container status
                local container_status=$(get_container_status "$domain")
                
                # Check SSH key status
                local key_status=$(check_user_ssh_keys "$username")
                
                users_data+=("$domain|$username|$port|$container_status|$key_status|$created")
            fi
        done < <(find "$WEB_ROOT" -maxdepth 1 -type d)
    fi
    
    if [ ${#users_data[@]} -eq 0 ]; then
        print_warning "No users found"
        echo ""
        echo "Register a new website with:"
        echo "  hostkit register"
        return
    fi
    
    # Sort by domain name
    IFS=$'\n' users_data=($(sort <<<"${users_data[*]}"))
    unset IFS
    
    # Table header
    echo -e "${WHITE}╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${WHITE}║${NC} %-25s ${WHITE}║${NC} %-20s ${WHITE}║${NC} %-6s ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-25s ${WHITE}║${NC} %-20s ${WHITE}║${NC}\n" "DOMAIN" "USERNAME" "PORT" "STATUS" "SSH KEY STATUS" "CREATED"
    echo -e "${WHITE}╠═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # List each user
    for user_data in "${users_data[@]}"; do
        IFS='|' read -r domain username port container_status key_status created <<< "$user_data"
        
        # Format container status with colors
        local status_text=""
        local status_color=""
        
        case "$container_status" in
            running)
                status_text="●  running"
                status_color="${GREEN}"
                ;;
            stopped)
                status_text="○  stopped"
                status_color="${YELLOW}"
                ;;
            not_found)
                status_text="✗  no container"
                status_color="${RED}"
                ;;
        esac
        
        # Format key status with colors
        local key_color=""
        case "$key_status" in
            *"✓"*)
                key_color="${GREEN}"
                ;;
            *"⚠"*)
                key_color="${YELLOW}"
                ;;
            *"✗"*)
                key_color="${RED}"
                ;;
        esac
        
        # Format created date
        local created_display="$created"
        if [ ${#created_display} -gt 20 ]; then
            created_display="${created_display:0:10}"
        fi
        
        printf "${WHITE}║${NC} %-25s ${WHITE}║${NC} %-20s ${WHITE}║${NC} %-6s ${WHITE}║${NC} ${status_color}%-12s${NC} ${WHITE}║${NC} ${key_color}%-25s${NC} ${WHITE}║${NC} %-20s ${WHITE}║${NC}\n" \
            "$domain" "$username" "$port" "$status_text" "$key_status" "$created_display"
    done
    
    echo -e "${WHITE}╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Total: ${#users_data[@]} user(s)"
    echo ""
    echo -e "${CYAN}Key Status Legend:${NC}"
    echo -e "  ${GREEN}✓ Both keys present${NC} - Both RSA and Ed25519 keys found"
    echo -e "  ${GREEN}✓ RSA only${NC} - Only RSA key found"
    echo -e "  ${GREEN}✓ Ed25519 only${NC} - Only Ed25519 key found"
    echo -e "  ${YELLOW}⚠ Partial keys${NC} - Some key files missing"
    echo -e "  ${RED}✗ No keys${NC} - No SSH keys found"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  hostkit show-keys <domain>      - Display keys for copying"
    echo "  hostkit regenerate-keys <domain> - Regenerate SSH keys"
    echo "  hostkit user-info <username>    - Show detailed user information"
}

# Check SSH key status for a user
check_user_ssh_keys() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "✗ User not found"
        return
    fi
    
    local ssh_dir="/home/$username/.ssh"
    local has_rsa=false
    local has_ed25519=false
    local has_auth_keys=false
    
    # Check for RSA keys
    if [ -f "$ssh_dir"/*-rsa ] && [ -f "$ssh_dir"/*-rsa.pub ]; then
        has_rsa=true
    fi
    
    # Check for Ed25519 keys (excluding RSA files)
    for key_file in "$ssh_dir"/*; do
        if [ -f "$key_file" ] && [[ "$key_file" != *"-rsa"* ]] && [[ "$key_file" != *".pub" ]]; then
            if ssh-keygen -l -f "$key_file" 2>/dev/null | grep -q "ED25519"; then
                has_ed25519=true
                break
            fi
        fi
    done
    
    # Check authorized_keys
    if [ -f "$ssh_dir/authorized_keys" ] && [ -s "$ssh_dir/authorized_keys" ]; then
        has_auth_keys=true
    fi
    
    # Determine status
    if [ "$has_rsa" = true ] && [ "$has_ed25519" = true ] && [ "$has_auth_keys" = true ]; then
        echo "✓ Both keys present"
    elif [ "$has_rsa" = true ] && [ "$has_auth_keys" = true ]; then
        echo "✓ RSA only"
    elif [ "$has_ed25519" = true ] && [ "$has_auth_keys" = true ]; then
        echo "✓ Ed25519 only"
    elif [ "$has_rsa" = true ] || [ "$has_ed25519" = true ]; then
        echo "⚠ Partial keys"
    else
        echo "✗ No keys"
    fi
}

# Show SSH keys for a specific domain/user
show_user_keys() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit show-keys <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit show-keys example.com"
        echo "  hostkit show-keys 0"
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
    
    local config=$(load_domain_config "$domain")
    local username=$(echo "$config" | jq -r '.username')
    
    if ! id "$username" &>/dev/null; then
        print_error "User $username not found"
        return 1
    fi
    
    local ssh_dir="/home/$username/.ssh"
    
    # Find the key files
    local private_key=""
    local rsa_key=""
    
    # Find Ed25519 key
    for key_file in "$ssh_dir"/*; do
        if [ -f "$key_file" ] && [[ "$key_file" != *"-rsa"* ]] && [[ "$key_file" != *".pub" ]]; then
            if ssh-keygen -l -f "$key_file" 2>/dev/null | grep -q "ED25519"; then
                private_key="$key_file"
                break
            fi
        fi
    done
    
    # Find RSA key
    for key_file in "$ssh_dir"/*-rsa; do
        if [ -f "$key_file" ]; then
            rsa_key="$key_file"
            break
        fi
    done
    
    if [ -z "$private_key" ] && [ -z "$rsa_key" ]; then
        print_error "No SSH keys found for user $username"
        print_info "Generate new keys with: hostkit regenerate-keys $domain"
        return 1
    fi
    
    print_step "SSH Keys for $domain (user: $username)"
    
    # Display keys using the same function as registration
    if [ -n "$private_key" ] || [ -n "$rsa_key" ]; then
        # Use the first available key path for the display function
        local display_key="${private_key:-$rsa_key}"
        display_ssh_keys_for_copying "$username" "$display_key" "$domain"
    fi
}

# Regenerate SSH keys for a domain
regenerate_user_keys() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit regenerate-keys <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit regenerate-keys example.com"
        echo "  hostkit regenerate-keys 0"
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
    
    local config=$(load_domain_config "$domain")
    local username=$(echo "$config" | jq -r '.username')
    
    if ! id "$username" &>/dev/null; then
        print_error "User $username not found"
        return 1
    fi
    
    echo ""
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "  WARNING: This will regenerate SSH keys!"
    print_warning "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${WHITE}Domain:${NC} $domain"
    echo -e "${WHITE}User:${NC} $username"
    echo ""
    print_warning "This will:"
    echo "  - Generate new RSA 4096-bit and Ed25519 keys"
    echo "  - Replace existing keys"
    echo "  - Invalidate current GitHub Actions secrets"
    echo "  - Require updating deployment configurations"
    echo ""
    
    if ! ask_yes_no "Continue with key regeneration?" "n"; then
        print_warning "Key regeneration cancelled"
        exit 0
    fi
    
    print_step "Regenerating SSH keys for $username..."
    
    local ssh_dir="/home/$username/.ssh"
    
    # Backup existing keys
    local backup_dir="$ssh_dir/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    if ls "$ssh_dir"/* >/dev/null 2>&1; then
        cp "$ssh_dir"/* "$backup_dir/" 2>/dev/null || true
        print_info "Existing keys backed up to: $backup_dir"
    fi
    
    # Clear existing keys
    rm -f "$ssh_dir"/deploy-* "$ssh_dir"/*.pub "$ssh_dir"/authorized_keys
    
    # Generate new keys
    local key_name="deploy-${domain//./-}"
    local private_key="$ssh_dir/$key_name"
    
    print_step "Generating new SSH key pair..."
    
    # Generate both key types
    ssh-keygen -t rsa -b 4096 -f "${private_key}-rsa" -N "" -C "deploy-rsa@$domain" >/dev/null 2>&1
    ssh-keygen -t ed25519 -f "$private_key" -N "" -C "deploy@$domain" >/dev/null 2>&1
    
    print_success "New SSH keys generated"
    
    # Setup authorized keys
    > "$ssh_dir/authorized_keys"
    cat "$private_key.pub" >> "$ssh_dir/authorized_keys"
    cat "${private_key}-rsa.pub" >> "$ssh_dir/authorized_keys"
    
    # Set permissions
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chmod 600 "$private_key" "${private_key}-rsa"
    chmod 644 "$private_key.pub" "${private_key}-rsa.pub"
    chown -R "$username:$username" "$ssh_dir"
    
    print_success "SSH keys regenerated successfully"
    
    # Display new keys
    display_ssh_keys_for_copying "$username" "$private_key" "$domain"
}

# Show detailed user information
show_user_info() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Username missing"
        echo "Usage: hostkit user-info <username>"
        return 1
    fi
    
    if ! id "$username" &>/dev/null; then
        print_error "User $username not found"
        return 1
    fi
    
    # Find domain for this user
    local domain=""
    if [ -d "$WEB_ROOT" ]; then
        while IFS= read -r dir; do
            if [ -f "$dir/config.json" ]; then
                local config=$(cat "$dir/config.json")
                local config_username=$(echo "$config" | jq -r '.username // ""')
                if [ "$config_username" = "$username" ]; then
                    domain=$(basename "$dir")
                    break
                fi
            fi
        done < <(find "$WEB_ROOT" -maxdepth 1 -type d)
    fi
    
    print_step "Detailed User Information: $username"
    echo ""
    
    # Basic user info
    local user_info=$(getent passwd "$username")
    local user_home=$(echo "$user_info" | cut -d: -f6)
    local user_shell=$(echo "$user_info" | cut -d: -f7)
    local user_uid=$(echo "$user_info" | cut -d: -f3)
    local user_gid=$(echo "$user_info" | cut -d: -f4)
    
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    USER DETAILS                           ${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Username:${NC} $username"
    echo -e "${CYAN}Domain:${NC} ${domain:-"Not found"}"
    echo -e "${CYAN}Home Directory:${NC} $user_home"
    echo -e "${CYAN}Shell:${NC} $user_shell"
    echo -e "${CYAN}UID:${NC} $user_uid"
    echo -e "${CYAN}GID:${NC} $user_gid"
    
    # SSH key information
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    SSH KEY STATUS                         ${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    
    local ssh_dir="$user_home/.ssh"
    local key_status=$(check_user_ssh_keys "$username")
    echo -e "${CYAN}Key Status:${NC} $key_status"
    
    if [ -d "$ssh_dir" ]; then
        echo -e "${CYAN}SSH Directory:${NC} $ssh_dir"
        echo -e "${CYAN}Directory Permissions:${NC} $(stat -c %a "$ssh_dir" 2>/dev/null || echo "N/A")"
        
        if [ -f "$ssh_dir/authorized_keys" ]; then
            local key_count=$(wc -l < "$ssh_dir/authorized_keys" 2>/dev/null || echo "0")
            echo -e "${CYAN}Authorized Keys:${NC} $key_count key(s)"
        else
            echo -e "${CYAN}Authorized Keys:${NC} Not found"
        fi
        
        # List key files
        echo -e "${CYAN}Key Files:${NC}"
        if ls "$ssh_dir"/* >/dev/null 2>&1; then
            for key_file in "$ssh_dir"/*; do
                if [ -f "$key_file" ] && [[ "$key_file" != *".pub" ]]; then
                    local key_type=$(ssh-keygen -l -f "$key_file" 2>/dev/null | awk '{print $4}' || echo "Unknown")
                    local key_bits=$(ssh-keygen -l -f "$key_file" 2>/dev/null | awk '{print $1}' || echo "Unknown")
                    echo "  - $(basename "$key_file"): $key_type ($key_bits bits)"
                fi
            done
        else
            echo "  - No private key files found"
        fi
    else
        echo -e "${CYAN}SSH Directory:${NC} Not found"
    fi
    
    # Domain information if found
    if [ -n "$domain" ]; then
        echo ""
        echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                   DOMAIN INFORMATION                      ${NC}"
        echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
        
        local config=$(load_domain_config "$domain")
        local port=$(echo "$config" | jq -r '.port // "unknown"')
        local created=$(echo "$config" | jq -r '.created // "unknown"')
        local current_version=$(echo "$config" | jq -r '.current_version // "none"')
        local container_status=$(get_container_status "$domain")
        
        echo -e "${CYAN}Domain:${NC} $domain"
        echo -e "${CYAN}Port:${NC} $port"
        echo -e "${CYAN}Created:${NC} $created"
        echo -e "${CYAN}Current Version:${NC} $current_version"
        echo -e "${CYAN}Container Status:${NC} $container_status"
    fi
    
    # Permissions and security
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                  SECURITY & PERMISSIONS                   ${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    
    # Check sudo permissions (try both old and new naming)
    local sudoers_file=""
    if [ -f "/etc/sudoers.d/hostkit-$username" ]; then
        sudoers_file="/etc/sudoers.d/hostkit-$username"
    elif [ -f "/etc/sudoers.d/$username" ]; then
        sudoers_file="/etc/sudoers.d/$username"
    fi
    
    if [ -n "$sudoers_file" ]; then
        echo -e "${CYAN}Sudo Rules:${NC} Found ($sudoers_file)"
        echo "  $(grep -v '^#' "$sudoers_file" | head -3 | sed 's/^/  /')"
    else
        echo -e "${CYAN}Sudo Rules:${NC} Not found"
    fi
    
    # Check SSH config (try both old and new naming)
    local ssh_config=""
    if [ -f "/etc/ssh/sshd_config.d/hostkit-$username.conf" ]; then
        ssh_config="/etc/ssh/sshd_config.d/hostkit-$username.conf"
    elif [ -f "/etc/ssh/sshd_config.d/$username.conf" ]; then
        ssh_config="/etc/ssh/sshd_config.d/$username.conf"
    fi
    
    if [ -n "$ssh_config" ]; then
        echo -e "${CYAN}SSH Restrictions:${NC} Found ($ssh_config)"
    else
        echo -e "${CYAN}SSH Restrictions:${NC} Not found"
    fi
    
    # Check account status
    local passwd_status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
    case "$passwd_status" in
        "L")
            echo -e "${CYAN}Account Status:${NC} ${GREEN}Locked (password disabled)${NC}"
            ;;
        "P")
            echo -e "${CYAN}Account Status:${NC} ${YELLOW}Password enabled${NC}"
            ;;
        *)
            echo -e "${CYAN}Account Status:${NC} $passwd_status"
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}Available Commands:${NC}"
    if [ -n "$domain" ]; then
        echo "  hostkit show-keys $domain       - Show SSH keys"
        echo "  hostkit regenerate-keys $domain - Regenerate SSH keys"
    fi
    echo "  hostkit list-users              - List all users"
}