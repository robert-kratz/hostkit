#!/bin/bash

# memory.sh - Memory Management Module
# Part of HostKit - VPS Website Management Tool

# Get total system memory in MB
get_total_memory() {
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((total_kb / 1024))
}

# Get available memory in MB
get_available_memory() {
    local available_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    echo $((available_kb / 1024))
}

# Get used memory by system in MB
get_system_memory_usage() {
    local total=$(get_total_memory)
    local available=$(get_available_memory)
    echo $((total - available))
}

# Calculate total allocated memory from all domains
get_total_allocated_memory() {
    local total_allocated=0
    
    if [ ! -d "$WEB_ROOT" ]; then
        echo "0"
        return
    fi
    
    for domain_dir in "$WEB_ROOT"/*; do
        if [ -d "$domain_dir" ] && [ -f "$domain_dir/config.json" ]; then
            local memory_limit=$(jq -r '.memory_limit // "0"' "$domain_dir/config.json")
            # Remove 'm' or 'M' suffix if present
            memory_limit=${memory_limit//[mM]/}
            total_allocated=$((total_allocated + memory_limit))
        fi
    done
    
    echo "$total_allocated"
}

# Get memory limit for a specific domain
get_domain_memory_limit() {
    local domain="$1"
    local config_file="$WEB_ROOT/$domain/config.json"
    
    if [ -f "$config_file" ]; then
        jq -r '.memory_limit // "512m"' "$config_file"
    else
        echo "512m"
    fi
}

# Get memory reservation for a specific domain
get_domain_memory_reservation() {
    local domain="$1"
    local config_file="$WEB_ROOT/$domain/config.json"
    
    if [ -f "$config_file" ]; then
        jq -r '.memory_reservation // "256m"' "$config_file"
    else
        echo "256m"
    fi
}

# Format memory size for display
format_memory() {
    local mem_mb="$1"
    
    if [ "$mem_mb" -ge 1024 ]; then
        local mem_gb=$(echo "scale=2; $mem_mb / 1024" | bc)
        echo "${mem_gb}GB"
    else
        echo "${mem_mb}MB"
    fi
}

# Display memory overview
show_memory_overview() {
    local total_mem=$(get_total_memory)
    local available_mem=$(get_available_memory)
    local system_used=$((total_mem - available_mem))
    local allocated=$(get_total_allocated_memory)
    
    # Reserve 20% for system (minimum 512MB, maximum 2GB)
    local system_reserve=$((total_mem / 5))
    [ "$system_reserve" -lt 512 ] && system_reserve=512
    [ "$system_reserve" -gt 2048 ] && system_reserve=2048
    
    local available_for_containers=$((total_mem - system_reserve))
    local remaining=$((available_for_containers - allocated))
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Memory Overview                               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Total System Memory:${NC}       $(format_memory $total_mem)"
    echo -e "  ${WHITE}Reserved for System:${NC}       $(format_memory $system_reserve)"
    echo -e "  ${WHITE}Available for Containers:${NC}  $(format_memory $available_for_containers)"
    echo ""
    echo -e "  ${YELLOW}Currently Allocated:${NC}       $(format_memory $allocated)"
    echo -e "  ${GREEN}Remaining Available:${NC}       $(format_memory $remaining)"
    echo ""
    
    # Show warning if over-allocated
    if [ "$remaining" -lt 0 ]; then
        echo -e "  ${RED}⚠ WARNING: Memory over-allocated by $(format_memory ${remaining#-})${NC}"
        echo ""
    fi
    
    # Show memory bar
    local allocated_percent=$((allocated * 100 / available_for_containers))
    [ "$allocated_percent" -gt 100 ] && allocated_percent=100
    
    local bar_length=40
    local filled=$((allocated_percent * bar_length / 100))
    local empty=$((bar_length - filled))
    
    local bar_color="$GREEN"
    [ "$allocated_percent" -gt 70 ] && bar_color="$YELLOW"
    [ "$allocated_percent" -gt 90 ] && bar_color="$RED"
    
    echo -n "  ["
    echo -n -e "${bar_color}"
    printf '%*s' "$filled" | tr ' ' '='
    echo -n -e "${NC}"
    printf '%*s' "$empty" | tr ' ' '-'
    echo "] ${allocated_percent}%"
    echo ""
}

# Validate memory input
validate_memory_input() {
    local memory="$1"
    
    # Remove any whitespace
    memory=$(echo "$memory" | tr -d '[:space:]')
    
    # Check if it matches valid pattern (number followed by optional m/M/g/G)
    if [[ ! "$memory" =~ ^[0-9]+[mMgG]?$ ]]; then
        return 1
    fi
    
    # Extract number
    local number=$(echo "$memory" | sed 's/[^0-9]//g')
    
    # Convert to MB for validation
    local mem_mb="$number"
    if [[ "$memory" =~ [gG]$ ]]; then
        mem_mb=$((number * 1024))
    fi
    
    # Check minimum (64MB)
    if [ "$mem_mb" -lt 64 ]; then
        return 1
    fi
    
    return 0
}

# Normalize memory value to MB with 'm' suffix
normalize_memory_value() {
    local memory="$1"
    
    # Remove any whitespace
    memory=$(echo "$memory" | tr -d '[:space:]')
    
    # Extract number
    local number=$(echo "$memory" | sed 's/[^0-9]//g')
    
    # Convert to MB
    local mem_mb="$number"
    if [[ "$memory" =~ [gG]$ ]]; then
        mem_mb=$((number * 1024))
    fi
    
    echo "${mem_mb}m"
}

# Interactive memory selection
select_memory_limit() {
    local domain="$1"
    local current_limit="$2"
    
    show_memory_overview
    
    echo -e "${WHITE}Select memory limit for ${CYAN}$domain${NC}"
    echo ""
    echo "  Memory limit is the maximum memory the container can use."
    echo "  The container will be terminated if it exceeds this limit."
    echo ""
    
    if [ -n "$current_limit" ]; then
        echo -e "  Current limit: ${YELLOW}$current_limit${NC}"
        echo ""
    fi
    
    echo "  Recommended allocations:"
    echo "    • Small site (static/minimal):  256m - 512m"
    echo "    • Medium site (Node.js/Python): 512m - 1g"
    echo "    • Large site (database/heavy):  1g - 2g"
    echo ""
    
    local memory_limit
    while true; do
        read -p "$(echo -e ${WHITE}Memory limit [e.g., 512m, 1g]:${NC} )" memory_limit
        
        if validate_memory_input "$memory_limit"; then
            memory_limit=$(normalize_memory_value "$memory_limit")
            
            # Extract MB value
            local limit_mb=$(echo "$memory_limit" | sed 's/[^0-9]//g')
            
            # Check if enough memory available
            local total_mem=$(get_total_memory)
            local system_reserve=$((total_mem / 5))
            [ "$system_reserve" -lt 512 ] && system_reserve=512
            [ "$system_reserve" -gt 2048 ] && system_reserve=2048
            local available_for_containers=$((total_mem - system_reserve))
            local current_allocated=$(get_total_allocated_memory)
            
            # If updating, subtract current limit from allocated
            if [ -n "$current_limit" ]; then
                local current_mb=$(echo "$current_limit" | sed 's/[^0-9]//g')
                current_allocated=$((current_allocated - current_mb))
            fi
            
            local remaining=$((available_for_containers - current_allocated))
            
            if [ "$limit_mb" -gt "$remaining" ]; then
                print_warning "Only $(format_memory $remaining) available. Please choose a lower value."
                echo ""
                continue
            fi
            
            break
        else
            print_error "Invalid memory format. Use format like: 256m, 512m, 1g, 2g (minimum 64m)"
            echo ""
        fi
    done
    
    # Calculate recommended reservation (50% of limit, minimum 64m)
    local limit_mb=$(echo "$memory_limit" | sed 's/[^0-9]//g')
    local reservation_mb=$((limit_mb / 2))
    [ "$reservation_mb" -lt 64 ] && reservation_mb=64
    local memory_reservation="${reservation_mb}m"
    
    echo ""
    echo -e "${GREEN}✓${NC} Memory limit set to ${CYAN}$memory_limit${NC}"
    echo -e "  Memory reservation (soft limit): ${CYAN}$memory_reservation${NC}"
    echo ""
    
    # Return both values separated by space
    echo "$memory_limit $memory_reservation"
}

# Set memory limits for a domain
set_domain_memory() {
    local domain="$1"
    local memory_limit="$2"
    local memory_reservation="$3"
    
    local config_file="$WEB_ROOT/$domain/config.json"
    
    if [ ! -f "$config_file" ]; then
        print_error "Domain $domain not found"
        return 1
    fi
    
    # Update config
    local tmp_file=$(mktemp)
    jq --arg limit "$memory_limit" \
       --arg reservation "$memory_reservation" \
       '.memory_limit = $limit | .memory_reservation = $reservation' \
       "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    
    print_success "Memory limits updated for $domain"
}

# Command: hostkit set-memory
cmd_set_memory() {
    local domain_or_id="$1"
    
    if [ -z "$domain_or_id" ]; then
        print_error "Usage: hostkit set-memory <domain|id>"
        exit 1
    fi
    
    # Resolve domain from ID if necessary
    local domain=$(resolve_domain_from_id "$domain_or_id")
    
    if [ ! -d "$WEB_ROOT/$domain" ]; then
        print_error "Website $domain_or_id not found"
        exit 1
    fi
    
    # Get current limits
    local current_limit=$(get_domain_memory_limit "$domain")
    
    # Interactive selection
    local memory_values=$(select_memory_limit "$domain" "$current_limit")
    local new_limit=$(echo "$memory_values" | awk '{print $1}')
    local new_reservation=$(echo "$memory_values" | awk '{print $2}')
    
    # Update configuration
    set_domain_memory "$domain" "$new_limit" "$new_reservation"
    
    # Check if container is running
    local container_name="${domain//./-}"
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo ""
        print_warning "Container is currently running"
        
        if ask_yes_no "Restart container to apply new memory limits?"; then
            print_step "Restarting container..."
            docker restart "$container_name" >/dev/null 2>&1
            print_success "Container restarted with new memory limits"
        else
            print_info "New memory limits will apply on next container start"
        fi
    fi
    
    echo ""
    print_success "Memory configuration updated successfully"
}

# Show memory stats for all domains
cmd_memory_stats() {
    show_memory_overview
    
    echo -e "${CYAN}Per-Website Allocation:${NC}"
    echo ""
    
    if [ ! -d "$WEB_ROOT" ] || [ -z "$(ls -A "$WEB_ROOT" 2>/dev/null)" ]; then
        print_info "No websites registered"
        return
    fi
    
    printf "  %-30s %-15s %-15s\n" "Domain" "Limit" "Reservation"
    printf "  %-30s %-15s %-15s\n" "$(printf '%.30s' "------------------------------")" "$(printf '%.15s' "---------------")" "$(printf '%.15s' "---------------")"
    
    for domain_dir in "$WEB_ROOT"/*; do
        if [ -d "$domain_dir" ] && [ -f "$domain_dir/config.json" ]; then
            local domain=$(basename "$domain_dir")
            local limit=$(get_domain_memory_limit "$domain")
            local reservation=$(get_domain_memory_reservation "$domain")
            
            printf "  %-30s %-15s %-15s\n" "$domain" "$limit" "$reservation"
        fi
    done
    
    echo ""
}
