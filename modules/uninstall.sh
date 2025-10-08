#!/bin/bash

# uninstall.sh - HostKit Uninstallation
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

# Capitalize first letter (compatible with bash 3.x)
capitalize() {
    local str="$1"
    echo "$(echo ${str:0:1} | tr '[:lower:]' '[:upper:]')${str:1}"
}

# Uninstall options structure
declare -A UNINSTALL_OPTIONS=(
    ["package"]="Remove HostKit package and binaries"
    ["websites"]="Remove all registered websites and their data"
    ["containers"]="Remove all Docker containers created by HostKit"
    ["images"]="Remove all Docker images created by HostKit"
    ["users"]="Remove all deployment users created by HostKit"
    ["nginx"]="Remove Nginx configurations created by HostKit"
    ["ssl"]="Remove SSL certificates managed by HostKit"
    ["cron"]="Remove cron jobs created by HostKit"
    ["configs"]="Remove all HostKit configuration files"
)

# Check what components are currently installed
check_installed_components() {
    local components=()
    
    # Check package installation
    if [ -d "$SCRIPT_DIR" ] && [ -f "$BIN_DIR/hostkit" ]; then
        components+=("package")
    fi
    
    # Check websites
    if [ -d "$WEB_ROOT" ] && [ "$(find "$WEB_ROOT" -maxdepth 1 -type d | wc -l)" -gt 1 ]; then
        components+=("websites")
    fi
    
    # Check containers
    if docker ps -a --format '{{.Names}}' | grep -E '^[a-z0-9.-]+-[a-z0-9.-]+$' >/dev/null 2>&1; then
        components+=("containers")
    fi
    
    # Check images
    if docker images --format '{{.Repository}}' | grep -E '^[a-z0-9.-]+\.[a-z0-9.-]+$' >/dev/null 2>&1; then
        components+=("images")
    fi
    
    # Check deployment users
    if getent passwd | grep -E '^deploy-' >/dev/null 2>&1; then
        components+=("users")
    fi
    
    # Check nginx configs
    if [ -d "$NGINX_SITES" ] && find "$NGINX_SITES" -name "*.conf" -exec grep -l "HostKit" {} \; 2>/dev/null | head -1 >/dev/null; then
        components+=("nginx")
    fi
    
    # Check SSL certificates
    if [ -d "/etc/letsencrypt/live" ] && [ "$(find /etc/letsencrypt/live -mindepth 1 -type d | wc -l)" -gt 0 ]; then
        components+=("ssl")
    fi
    
    # Check cron jobs
    if crontab -l 2>/dev/null | grep -q "certbot renew\|hostkit"; then
        components+=("cron")
    fi
    
    # Check config files
    if [ -f "$CONFIG_FILE" ] || [ -d "$WEB_ROOT" ]; then
        components+=("configs")
    fi
    
    printf '%s\n' "${components[@]}"
}

# Display component selection menu
show_uninstall_menu() {
    local installed_components=($@)
    
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           HOSTKIT UNINSTALLER                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}Select components to remove:${NC}"
    echo ""
    
    local option_keys=("package" "websites" "containers" "images" "users" "nginx" "ssl" "cron" "configs")
    local selected_options=()
    
    for key in "${option_keys[@]}"; do
        if [[ " ${installed_components[*]} " =~ " ${key} " ]]; then
            echo -e "  ${GREEN}[✓]${NC} $(capitalize "$key"): ${UNINSTALL_OPTIONS[$key]}"
        else
            echo -e "  ${YELLOW}[-]${NC} $(capitalize "$key"): ${UNINSTALL_OPTIONS[$key]} ${YELLOW}(not installed)${NC}"
        fi
    done
    
    echo ""
    echo -e "${WHITE}Available preset options:${NC}"
    echo -e "  ${CYAN}minimal${NC}  - Remove only the package (keep all data)"
    echo -e "  ${CYAN}standard${NC} - Remove package + containers + images (keep websites/configs)"
    echo -e "  ${CYAN}complete${NC} - Remove everything except SSL certificates"
    echo -e "  ${CYAN}nuclear${NC}  - Remove absolutely everything (including SSL certificates)"
    echo -e "  ${CYAN}custom${NC}   - Select individual components"
    echo ""
}

# Get user selection
get_uninstall_selection() {
    local installed_components=($@)
    local selection=""
    
    while true; do
        echo -ne "${CYAN}Choose uninstall option [minimal/standard/complete/nuclear/custom]: ${NC}"
        read -r selection
        
        case "$selection" in
            minimal)
                echo "package"
                return 0
                ;;
            standard)
                echo "package containers images"
                return 0
                ;;
            complete)
                echo "package websites containers images users nginx cron configs"
                return 0
                ;;
            nuclear)
                echo "package websites containers images users nginx ssl cron configs"
                return 0
                ;;
            custom)
                get_custom_selection "${installed_components[@]}"
                return 0
                ;;
            "")
                print_error "Please make a selection"
                continue
                ;;
            *)
                print_error "Invalid option: $selection"
                print_info "Please choose: minimal, standard, complete, nuclear, or custom"
                continue
                ;;
        esac
    done
}

# Get custom component selection
get_custom_selection() {
    local installed_components=($@)
    local selected=()
    local option_keys=("package" "websites" "containers" "images" "users" "nginx" "ssl" "cron" "configs")
    
    echo ""
    echo -e "${WHITE}Custom selection - choose components to remove:${NC}"
    echo ""
    
    for key in "${option_keys[@]}"; do
        if [[ " ${installed_components[*]} " =~ " ${key} " ]]; then
            if ask_yes_no "Remove ${key}: ${UNINSTALL_OPTIONS[$key]}?" "n"; then
                selected+=("$key")
            fi
        fi
    done
    
    if [ ${#selected[@]} -eq 0 ]; then
        print_warning "No components selected for removal"
        return 1
    fi
    
    printf '%s ' "${selected[@]}"
    return 0
}

# Show uninstall summary
show_uninstall_summary() {
    local components=($@)
    
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                  UNINSTALL SUMMARY${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}The following components will be removed:${NC}"
    echo ""
    
    for component in "${components[@]}"; do
        echo -e "  ${RED}✗${NC} $(capitalize "$component"): ${UNINSTALL_OPTIONS[$component]}"
    done
    
    echo ""
    echo -e "${RED}⚠  WARNING: This action cannot be undone!${NC}"
    echo ""
}

# Remove HostKit package
remove_package() {
    print_step "Removing HostKit package..."
    
    # Remove binary
    if [ -f "$BIN_DIR/hostkit" ]; then
        rm -f "$BIN_DIR/hostkit"
        print_success "Binary removed"
    fi
    
    # Remove installation directory
    if [ -d "$SCRIPT_DIR" ]; then
        rm -rf "$SCRIPT_DIR"
        print_success "Installation directory removed"
    fi
    
    # Remove bash completion
    local completion_files=(
        "/etc/bash_completion.d/hostkit"
        "/usr/share/bash-completion/completions/hostkit"
        "$HOME/.bash_completion.d/hostkit"
    )
    
    for comp_file in "${completion_files[@]}"; do
        if [ -f "$comp_file" ]; then
            rm -f "$comp_file"
            print_success "Bash completion removed: $comp_file"
        fi
    done
    
    # Remove from .bashrc if added
    if [ -f "$HOME/.bashrc" ] && grep -q "hostkit" "$HOME/.bashrc"; then
        sed -i '/hostkit/d' "$HOME/.bashrc"
        print_success "Removed from .bashrc"
    fi
}

# Remove all websites and their data
remove_websites() {
    print_step "Removing websites and their data..."
    
    if [ ! -d "$WEB_ROOT" ]; then
        print_info "No websites directory found"
        return 0
    fi
    
    local removed_count=0
    while IFS= read -r domain_dir; do
        if [ -d "$domain_dir" ] && [ -f "$domain_dir/config.json" ]; then
            local domain=$(basename "$domain_dir")
            print_info "Removing website: $domain"
            rm -rf "$domain_dir"
            ((removed_count++))
        fi
    done < <(find "$WEB_ROOT" -maxdepth 1 -type d)
    
    # Remove root directory if empty
    if [ -d "$WEB_ROOT" ] && [ "$(find "$WEB_ROOT" -mindepth 1 | wc -l)" -eq 0 ]; then
        rmdir "$WEB_ROOT"
        print_success "Websites directory removed"
    fi
    
    print_success "$removed_count websites removed"
}

# Remove Docker containers
remove_containers() {
    print_step "Removing Docker containers..."
    
    local removed_count=0
    while IFS= read -r container; do
        if [ -n "$container" ]; then
            print_info "Stopping and removing container: $container"
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
            ((removed_count++))
        fi
    done < <(docker ps -a --format '{{.Names}}' | grep -E '^[a-z0-9.-]+-[a-z0-9.-]+$')
    
    print_success "$removed_count containers removed"
}

# Remove Docker images
remove_images() {
    print_step "Removing Docker images..."
    
    local removed_count=0
    while IFS= read -r image; do
        if [ -n "$image" ]; then
            print_info "Removing image: $image"
            docker rmi "$image" 2>/dev/null || true
            ((removed_count++))
        fi
    done < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^[a-z0-9.-]+\.[a-z0-9.-]+:')
    
    print_success "$removed_count images removed"
}

# Remove deployment users
remove_users() {
    print_step "Removing deployment users..."
    
    local removed_count=0
    while IFS= read -r user_info; do
        local username=$(echo "$user_info" | cut -d: -f1)
        if [[ "$username" =~ ^deploy- ]]; then
            print_info "Removing user: $username"
            
            # Remove user and home directory
            userdel -r "$username" 2>/dev/null || true
            
            # Remove SSH config (try both old and new naming)
            rm -f "/etc/ssh/sshd_config.d/${username}.conf"
            rm -f "/etc/ssh/sshd_config.d/hostkit-${username}.conf"
            
            # Remove sudoers file (try both old and new naming)
            rm -f "/etc/sudoers.d/$username"
            rm -f "/etc/sudoers.d/hostkit-$username"
            
            ((removed_count++))
        fi
    done < <(getent passwd | grep "^deploy-")
    
    # Reload SSH daemon if users were removed
    if [ $removed_count -gt 0 ]; then
        systemctl reload sshd 2>/dev/null || true
        print_success "$removed_count deployment users removed"
    else
        print_info "No deployment users found"
    fi
}

# Remove Nginx configurations
remove_nginx() {
    print_step "Removing Nginx configurations..."
    
    local removed_count=0
    
    # Find and remove HostKit configs
    while IFS= read -r config_file; do
        if [ -f "$config_file" ] && grep -q "HostKit" "$config_file" 2>/dev/null; then
            local domain=$(basename "$config_file" .conf)
            print_info "Removing Nginx config: $domain"
            
            # Remove from sites-enabled
            if [ -L "$NGINX_ENABLED/$domain.conf" ]; then
                rm -f "$NGINX_ENABLED/$domain.conf"
            fi
            
            # Remove from sites-available
            rm -f "$config_file"
            ((removed_count++))
        fi
    done < <(find "$NGINX_SITES" -name "*.conf" 2>/dev/null)
    
    # Test and reload Nginx
    if [ $removed_count -gt 0 ]; then
        if nginx -t 2>/dev/null; then
            systemctl reload nginx 2>/dev/null || true
            print_success "$removed_count Nginx configurations removed"
        else
            print_warning "Nginx configuration test failed - please check manually"
        fi
    else
        print_info "No HostKit Nginx configurations found"
    fi
}

# Remove SSL certificates
remove_ssl() {
    print_step "Removing SSL certificates..."
    
    if [ ! -d "/etc/letsencrypt/live" ]; then
        print_info "No SSL certificates found"
        return 0
    fi
    
    local removed_count=0
    while IFS= read -r cert_dir; do
        if [ -d "$cert_dir" ]; then
            local domain=$(basename "$cert_dir")
            print_info "Removing SSL certificate: $domain"
            certbot delete --cert-name "$domain" --non-interactive 2>/dev/null || true
            ((removed_count++))
        fi
    done < <(find /etc/letsencrypt/live -mindepth 1 -maxdepth 1 -type d)
    
    print_success "$removed_count SSL certificates removed"
}

# Remove cron jobs
remove_cron() {
    print_step "Removing cron jobs..."
    
    local current_cron=$(crontab -l 2>/dev/null || true)
    local new_cron=""
    
    if [ -n "$current_cron" ]; then
        # Remove HostKit related cron jobs
        new_cron=$(echo "$current_cron" | grep -v "certbot renew\|hostkit")
        
        if [ "$current_cron" != "$new_cron" ]; then
            if [ -n "$new_cron" ]; then
                echo "$new_cron" | crontab -
            else
                crontab -r 2>/dev/null || true
            fi
            print_success "HostKit cron jobs removed"
        else
            print_info "No HostKit cron jobs found"
        fi
    else
        print_info "No cron jobs found"
    fi
}

# Remove configuration files
remove_configs() {
    print_step "Removing configuration files..."
    
    local removed_count=0
    local config_files=(
        "$CONFIG_FILE"
        "$VERSION_FILE"
        "$VERSION_CHECK_FILE"
    )
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            rm -f "$config_file"
            ((removed_count++))
        fi
    done
    
    print_success "$removed_count configuration files removed"
}

# Main uninstall function
uninstall_hostkit() {
    # Disable strict error handling for user input
    safe_mode_off
    
    print_step "Checking installed components..."
    local installed_components=($(check_installed_components))
    
    if [ ${#installed_components[@]} -eq 0 ]; then
        print_warning "No HostKit components found to uninstall"
        safe_mode_on
        return 0
    fi
    
    show_uninstall_menu "${installed_components[@]}"
    
    local selected_components
    selected_components=$(get_uninstall_selection "${installed_components[@]}")
    if [ $? -ne 0 ]; then
        print_warning "Uninstall cancelled"
        safe_mode_on
        return 0
    fi
    
    local components=($selected_components)
    show_uninstall_summary "${components[@]}"
    
    if ! ask_yes_no "Proceed with uninstallation?" "n"; then
        print_warning "Uninstall cancelled"
        safe_mode_on
        return 0
    fi
    
    # Final confirmation for destructive operations
    if [[ " ${components[*]} " =~ " websites " ]] || [[ " ${components[*]} " =~ " ssl " ]]; then
        echo ""
        echo -ne "${RED}Type 'CONFIRM UNINSTALL' to proceed: ${NC}"
        read -r final_confirmation
        
        if [ "$final_confirmation" != "CONFIRM UNINSTALL" ]; then
            print_error "Final confirmation failed. Uninstall cancelled."
            safe_mode_on
            return 1
        fi
    fi
    
    # Re-enable strict error handling for system operations
    safe_mode_on
    
    echo ""
    print_step "Starting uninstallation..."
    echo ""
    
    # Execute removal in proper order
    for component in "${components[@]}"; do
        case "$component" in
            containers) remove_containers ;;
            images) remove_images ;;
            websites) remove_websites ;;
            users) remove_users ;;
            nginx) remove_nginx ;;
            ssl) remove_ssl ;;
            cron) remove_cron ;;
            configs) remove_configs ;;
            package) remove_package ;;
        esac
        echo ""
    done
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         UNINSTALLATION COMPLETE                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}Selected components have been successfully removed.${NC}"
    echo ""
    
    if [[ " ${components[*]} " =~ " package " ]]; then
        echo -e "${WHITE}HostKit has been uninstalled from this system.${NC}"
        echo -e "${WHITE}Thank you for using HostKit!${NC}"
    else
        echo -e "${WHITE}HostKit package remains installed.${NC}"
        echo -e "${WHITE}Run 'hostkit help' to see available commands.${NC}"
    fi
    
    echo ""
}