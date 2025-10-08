#!/bin/bash

# remove.sh - Website Removal
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

remove_website() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit remove <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit remove example.com"
        echo "  hostkit remove 0"
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
    
    # Disable strict error handling for user confirmation phase
    safe_mode_off
    
    local config=$(load_domain_config "$domain")
    local username=$(echo "$config" | jq -r '.username')
    
    echo ""
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "  WARNING: Website will be completely removed!"
    print_warning "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${WHITE}Domain:${NC} $domain"
    echo -e "${WHITE}User:${NC} $username"
    echo ""
    echo "The following will be deleted:"
    echo "  - Container and all Docker images"
    echo "  - All files in $WEB_ROOT/$domain"
    echo "  - Nginx configuration"
    echo "  - SSH user $username"
    echo ""
    print_info "SSL certificates will be PRESERVED to avoid rate limits"
    echo ""
    
    if ! ask_yes_no "Really continue?" "n"; then
        print_warning "Cancelled"
        exit 0
    fi
    
    # Domain confirmation with retry
    local confirmation=""
    local attempts=0
    while [ $attempts -lt 3 ]; do
        echo ""
        echo -ne "${RED}Enter the domain to confirm: ${NC}"
        read -r confirmation
        
        if [ "$confirmation" = "$domain" ]; then
            break
        fi
        
        ((attempts++))
        print_error "Confirmation failed. You entered: '$confirmation'"
        print_info "Please enter exactly: $domain"
        
        if [ $attempts -lt 3 ]; then
            print_warning "Attempt $attempts/3"
        else
            print_error "Too many failed attempts. Removal cancelled for safety."
            safe_mode_on
            return 1
        fi
    done
    
    # Re-enable strict error handling for system operations
    safe_mode_on
    
    echo ""
    print_step "Removing website: $domain"
    
    # Stop and remove container
    local container_name=$(get_container_name "$domain")
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        print_step "Removing container..."
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
        print_success "Container removed"
    fi
    
    # Remove all Docker images
    print_step "Removing Docker images..."
    local removed_images=0
    while IFS= read -r image; do
        docker rmi "$image" 2>/dev/null && ((removed_images++)) || true
    done < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${domain}:")
    
    if [ $removed_images -gt 0 ]; then
        print_success "$removed_images image(s) removed"
    fi
    
    # Remove Nginx configuration
    if [ -f "$NGINX_SITES/$domain" ]; then
        print_step "Removing Nginx configuration..."
        rm -f "$NGINX_ENABLED/$domain"
        rm -f "$NGINX_SITES/$domain"
        
        if nginx -t 2>/dev/null; then
            systemctl reload nginx
            print_success "Nginx configuration removed"
        else
            print_warning "Nginx error - please check manually"
        fi
    fi
    
    # SSL Certificate handling - PRESERVE by default
    if [ -d "/etc/letsencrypt/live/$domain" ]; then
        local days_left=$(days_until_expiry "$domain")
        echo ""
        print_info "SSL certificate found for $domain (expires in $days_left days)"
        print_warning "IMPORTANT: Certificates are preserved to avoid Let's Encrypt rate limits"
        print_info "Let's Encrypt allows only 5 certificates per domain per week"
        echo ""
        
        if ask_yes_no "Do you REALLY want to delete the SSL certificate? (NOT recommended)" "n"; then
            # Backup before deletion
            backup_certificate "$domain"
            
            print_step "Removing SSL certificate..."
            certbot delete --cert-name "$domain" --non-interactive 2>/dev/null || true
            print_success "SSL certificate removed (backup created)"
        else
            print_success "SSL certificate preserved"
            print_info "You can reuse this certificate when re-registering the domain"
        fi
    fi
    
    # Remove SSH user
    if id "$username" &>/dev/null; then
        if ask_yes_no "Remove SSH user '$username'?"; then
            print_step "Removing SSH user..."
            userdel -r "$username" 2>/dev/null || userdel "$username" 2>/dev/null || true
            rm -f "/etc/sudoers.d/$username" "/etc/sudoers.d/hostkit-$username"
            rm -f "/etc/ssh/sshd_config.d/$username.conf" "/etc/ssh/sshd_config.d/hostkit-$username.conf"
            systemctl reload sshd 2>/dev/null || true
            print_success "SSH user removed"
        fi
    fi
    
    # Remove website directory
    print_step "Removing website directory..."
    rm -rf "$WEB_ROOT/$domain"
    print_success "Directory removed"
    
    echo ""
    print_success "Website $domain has been removed"
    print_info "SSL certificates were preserved to avoid rate limit issues"
}