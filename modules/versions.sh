#!/bin/bash

# versions.sh - Version Management
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

show_versions() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit versions <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit versions example.com"
        echo "  hostkit versions 0"
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
    
    local image_dir="$WEB_ROOT/$domain/images"
    local config=$(load_domain_config "$domain")
    local current_version=$(echo "$config" | jq -r '.current_version // "none"')
    
    print_step "Available versions for: $domain"
    echo ""
    
    # List all versions
    local versions=()
    if [ -d "$image_dir" ]; then
        while IFS= read -r info_file; do
            if [ -f "$info_file" ]; then
                local ver=$(basename "$info_file" .info)
                versions+=("$ver")
            fi
        done < <(find "$image_dir" -name "*.info" -type f | sort -r)
    fi
    
    if [ ${#versions[@]} -eq 0 ]; then
        print_warning "No versions found"
        echo ""
        echo "Deploy a new version with:"
        echo "  hostkit deploy $domain"
        return
    fi
    
    # Table header
    echo -e "${WHITE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    printf "${WHITE}║${NC} %-3s ${WHITE}║${NC} %-20s ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-20s ${WHITE}║${NC}\n" "#" "VERSION" "STATUS" "CREATED"
    echo -e "${WHITE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    
    local idx=1
    for ver in "${versions[@]}"; do
        local status_text=""
        local status_color="${NC}"
        
        if [ "$ver" = "$current_version" ]; then
            status_text="● active"
            status_color="${GREEN}"
        else
            # Check if image exists
            if docker image inspect "${domain}:${ver}" &>/dev/null; then
                status_text="○ available"
                status_color="${CYAN}"
            else
                status_text="✗ deleted"
                status_color="${RED}"
            fi
        fi
        
        # Extract date from version
        local date_part="${ver:0:8}"
        local time_part="${ver:9:6}"
        local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
        local formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
        local formatted="${formatted_date} ${formatted_time}"
        
        printf "${WHITE}║${NC} %-3s ${WHITE}║${NC} %-20s ${WHITE}║${NC} ${status_color}%-12s${NC} ${WHITE}║${NC} %-20s ${WHITE}║${NC}\n" \
            "$idx" "$ver" "$status_text" "$formatted"
        
        ((idx++))
    done
    
    echo -e "${WHITE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Total: ${#versions[@]} version(s)"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  hostkit switch $domain <version>  - Switch to version"
    echo "  hostkit deploy $domain            - Deploy new version"
}

switch_version() {
    local input="$1"
    local target_version="$2"
    
    if [ -z "$input" ] || [ -z "$target_version" ]; then
        print_error "Domain/ID or version missing"
        echo "Usage: hostkit switch <domain|id> <version>"
        echo ""
        echo "Examples:"
        echo "  hostkit switch example.com 20231201-120000"
        echo "  hostkit switch 0 20231201-120000"
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
    local port=$(echo "$config" | jq -r '.port')
    local current_version=$(echo "$config" | jq -r '.current_version // "none"')
    local deployment_type=$(echo "$config" | jq -r '.type // "single"')
    
    print_step "Switching version for: $domain"
    echo ""
    
    # Check if this is a compose deployment
    if [ "$deployment_type" = "compose" ]; then
        local image_dir="$WEB_ROOT/$domain/images"
        local compose_backup="$WEB_ROOT/$domain/docker-compose.${target_version}.yml"
        
        if [ ! -f "$compose_backup" ]; then
            print_error "Compose file for version $target_version not found"
            return 1
        fi
        
        if [ "$target_version" = "$current_version" ]; then
            print_warning "Version $target_version is already active"
            exit 0
        fi
        
        print_info "Current: $current_version"
        print_info "New: $target_version"
        echo ""
        
        if ! ask_yes_no "Switch compose stack version?"; then
            print_warning "Aborted"
            exit 0
        fi
        
        # Stop current compose stack
        local container_name=$(get_container_name "$domain")
        cd "$WEB_ROOT/$domain"
        export COMPOSE_PROJECT_NAME="$container_name"
        
        print_step "Stopping current compose stack..."
        docker-compose down
        print_success "Stack stopped"
        
        # Restore compose file from backup
        cp "$compose_backup" "$WEB_ROOT/$domain/docker-compose.yml"
        
        # Load images for this version
        local version_tar="$image_dir/${target_version}.tar"
        if [ -f "$version_tar" ]; then
            print_step "Loading images for version $target_version..."
            load_all_images_from_tar "$version_tar"
        fi
        
        # Start with new version
        print_step "Starting compose stack with version $target_version..."
        docker-compose --env-file .env up -d
        
        if [ $? -eq 0 ]; then
            print_success "Compose stack started"
            
            # Update config
            local updated_config=$(echo "$config" | jq ".current_version = \"$target_version\"")
            save_domain_config "$domain" "$updated_config"
            
            cd - > /dev/null
            
            echo ""
            print_success "Version switched successfully!"
            print_info "Version: $target_version"
            print_info "Stack: $container_name"
        else
            print_error "Error starting compose stack"
            cd - > /dev/null
            return 1
        fi
    else
        # Standard single container version switch
        # Check if version exists
        if ! docker image inspect "${domain}:${target_version}" &>/dev/null; then
            print_error "Version $target_version not found or image was deleted"
            return 1
        fi
        
        if [ "$target_version" = "$current_version" ]; then
            print_warning "Version $target_version is already active"
            exit 0
        fi
        
        print_info "Current: $current_version"
        print_info "New: $target_version"
        echo ""
        
        if ! ask_yes_no "Switch version?"; then
            print_warning "Aborted"
            exit 0
        fi
        
        # Stop old container
        local container_name=$(get_container_name "$domain")
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            print_step "Stopping current container..."
            docker stop "$container_name" 2>/dev/null || true
            docker rm "$container_name" 2>/dev/null || true
            print_success "Container stopped"
        fi
        
        # Tag new version as latest
        docker tag "${domain}:${target_version}" "${domain}:latest"
        
        # Start container with new version
        print_step "Starting container with version $target_version..."
        
        docker run -d \
            --name "$container_name" \
            --restart unless-stopped \
            -p "127.0.0.1:${port}:${port}" \
            -v "$WEB_ROOT/$domain/logs:/app/logs" \
            "${domain}:${target_version}"
        
        if [ $? -eq 0 ]; then
            print_success "Container started"
            
            # Update config
            local updated_config=$(echo "$config" | jq ".current_version = \"$target_version\"")
            save_domain_config "$domain" "$updated_config"
            
            echo ""
            print_success "Version switched successfully!"
            print_info "Version: $target_version"
            print_info "Container: $container_name"
        else
            print_error "Error starting container"
            docker logs "$container_name"
            return 1
        fi
    fi
}