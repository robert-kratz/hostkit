#!/bin/bash

# memory.sh - Simplified Memory Management Module
# Part of HostKit - VPS Website Management Tool

# Get total system memory in MB
get_total_memory() {
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((total_kb / 1024))
}

# Simple memory selection without fancy display
select_memory_limit() {
    local domain="$1"
    local current_limit="$2"
    
    local total_mem=$(get_total_memory)
    
    # Calculate system reserve (20%, min 512MB, max 2GB)
    local system_reserve=$((total_mem / 5))
    [ "$system_reserve" -lt 512 ] && system_reserve=512
    [ "$system_reserve" -gt 2048 ] && system_reserve=2048
    
    local available_for_containers=$((total_mem - system_reserve))
    
    echo "" >&2
    echo -e "${WHITE}Memory Configuration${NC}" >&2
    echo -e "${CYAN}Total System Memory: ${total_mem}MB${NC}" >&2
    echo -e "${CYAN}Reserved for OS: ${system_reserve}MB${NC}" >&2
    echo -e "${CYAN}Available for Containers: ${available_for_containers}MB${NC}" >&2
    echo "" >&2
    echo -e "${WHITE}Suggested allocations:${NC}" >&2
    echo -e "  ${CYAN}Small (512MB)  - Static websites, APIs${NC}" >&2
    echo -e "  ${CYAN}Medium (1024MB) - Node.js, Python apps${NC}" >&2
    echo -e "  ${CYAN}Large (2048MB)  - Java, databases${NC}" >&2
    echo "" >&2
    
    local memory_limit=""
    while true; do
        echo -ne "${CYAN}Memory limit in MB (e.g., 512): ${NC}" >&2
        read -r memory_limit
        
        # Remove any 'm' or 'MB' suffix
        memory_limit=$(echo "$memory_limit" | sed 's/[mMbB]//g')
        
        # Check if numeric
        if ! [[ "$memory_limit" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}✗ Please enter a number${NC}" >&2
            continue
        fi
        
        # Check if within available range
        if [ "$memory_limit" -lt 128 ]; then
            echo -e "${RED}✗ Memory limit too low (minimum 128MB)${NC}" >&2
            continue
        fi
        
        if [ "$memory_limit" -gt "$available_for_containers" ]; then
            echo -e "${RED}✗ Memory limit exceeds available memory (${available_for_containers}MB)${NC}" >&2
            continue
        fi
        
        break
    done
    
    # Calculate reservation (50% of limit)
    local memory_reservation=$((memory_limit / 2))
    
    echo -e "${GREEN}✓ Memory Limit: ${memory_limit}MB${NC}" >&2
    echo -e "${GREEN}✓ Memory Reservation: ${memory_reservation}MB${NC}" >&2
    echo "" >&2
    
    # Output format: "limit reservation" (space-separated)
    echo "${memory_limit}m ${memory_reservation}m"
}

# Show memory stats command
cmd_memory_stats() {
    local total_mem=$(get_total_memory)
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              System Memory Overview                       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Total System Memory:${NC} ${total_mem}MB"
    echo ""
    
    if [ ! -d "$WEB_ROOT" ]; then
        echo -e "${YELLOW}No websites registered yet${NC}"
        return
    fi
    
    echo -e "${WHITE}Website Memory Allocations:${NC}"
    echo ""
    
    local total_allocated=0
    for domain_dir in "$WEB_ROOT"/*; do
        if [ -d "$domain_dir" ] && [ -f "$domain_dir/config.json" ]; then
            local domain=$(basename "$domain_dir")
            local memory_limit=$(jq -r '.memory_limit // "0m"' "$domain_dir/config.json")
            local memory_mb=$(echo "$memory_limit" | sed 's/[mMgG]//g')
            
            echo -e "  ${CYAN}${domain}${NC}: ${memory_limit}"
            total_allocated=$((total_allocated + memory_mb))
        fi
    done
    
    echo ""
    echo -e "${WHITE}Total Allocated:${NC} ${total_allocated}MB"
    echo -e "${WHITE}Available:${NC} $((total_mem - total_allocated))MB"
    echo ""
}

# Set memory for existing website
cmd_set_memory() {
    local domain_or_id="$1"
    
    # Resolve domain from ID if needed
    local domain=$(resolve_domain_from_id "$domain_or_id")
    if [ -z "$domain" ]; then
        print_error "Website not found: $domain_or_id"
        return 1
    fi
    
    local config_file="$WEB_ROOT/$domain/config.json"
    if [ ! -f "$config_file" ]; then
        print_error "Configuration not found for $domain"
        return 1
    fi
    
    # Get current values
    local current_limit=$(jq -r '.memory_limit // "512m"' "$config_file")
    
    echo ""
    echo -e "${WHITE}Current memory limit:${NC} $current_limit"
    
    # Get new values
    local memory_values=$(select_memory_limit "$domain" "$current_limit")
    local new_limit=$(echo "$memory_values" | awk '{print $1}')
    local new_reservation=$(echo "$memory_values" | awk '{print $2}')
    
    # Update config
    local tmp_config=$(mktemp)
    jq ".memory_limit = \"$new_limit\" | .memory_reservation = \"$new_reservation\"" "$config_file" > "$tmp_config"
    mv "$tmp_config" "$config_file"
    
    print_success "Memory limits updated for $domain"
    
    # Check if container is running
    local container_name="${domain//./-}"
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo ""
        if ask_yes_no "Container is running. Restart to apply new limits?"; then
            print_info "Restarting container..."
            docker restart "$container_name" >/dev/null
            print_success "Container restarted with new memory limits"
        else
            print_warning "New limits will apply on next container start"
        fi
    fi
}
