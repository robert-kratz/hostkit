#!/bin/bash

# list.sh - Website Overview
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

list_websites() {
    print_step "Registered Websites"
    echo ""
    
    # Find all domains (sorted)
    local domains=($(get_registered_domains))
    
    if [ ${#domains[@]} -eq 0 ]; then
        print_warning "No websites registered"
        echo ""
        echo "Register a new website with:"
        echo "  hostkit register"
        return
    fi
    
    # Table header with ID and SSL
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    printf "${WHITE}║${NC} %-3s ${WHITE}║${NC} %-23s ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-6s ${WHITE}║${NC} %-12s ${WHITE}║${NC} %-15s ${WHITE}║${NC} %-18s ${WHITE}║${NC}\n" "ID" "DOMAIN" "STATUS" "PORT" "SSL" "SSL EXPIRES" "VERSION"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    # List each website
    local id=0
    for domain in "${domains[@]}"; do
        local config=$(load_domain_config "$domain")
        local port=$(echo "$config" | jq -r '.port')
        local current_version=$(echo "$config" | jq -r '.current_version // "none"')
        local redirect_domains=$(echo "$config" | jq -r '.redirect_domains[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        
        # Determine status
        local container_name=$(get_container_name "$domain")
        local status=$(get_container_status "$domain")
        local status_text=""
        local status_color=""
        
        case "$status" in
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
        
        # Get SSL status
        local ssl_status=$(get_ssl_status "$domain")
        local ssl_days=$(get_ssl_days_until_expiry "$domain")
        local ssl_text=""
        local ssl_color=""
        local ssl_expires=""
        
        case "$ssl_status" in
            valid)
                ssl_text="✓ Valid"
                ssl_color="${GREEN}"
                ssl_expires="${ssl_days}d"
                ;;
            expiring)
                ssl_text="⚠ Expiring"
                ssl_color="${YELLOW}"
                ssl_expires="${ssl_days}d"
                ;;
            expired)
                ssl_text="✗ Expired"
                ssl_color="${RED}"
                ssl_expires="Expired"
                ;;
            missing)
                ssl_text="- None"
                ssl_color="${YELLOW}"
                ssl_expires="N/A"
                ;;
            error)
                ssl_text="? Error"
                ssl_color="${RED}"
                ssl_expires="Error"
                ;;
        esac
        
        # Shorten version if too long
        if [ ${#current_version} -gt 18 ]; then
            current_version="${current_version:0:15}..."
        fi
        
        # Shorten domain if too long
        local domain_display="$domain"
        if [ ${#domain_display} -gt 23 ]; then
            domain_display="${domain_display:0:20}..."
        fi
        
        printf "${WHITE}║${NC} ${CYAN}%-3s${NC} ${WHITE}║${NC} %-23s ${WHITE}║${NC} ${status_color}%-12s${NC} ${WHITE}║${NC} %-6s ${WHITE}║${NC} ${ssl_color}%-12s${NC} ${WHITE}║${NC} %-15s ${WHITE}║${NC} %-18s ${WHITE}║${NC}\n" \
            "$id" "$domain_display" "$status_text" "$port" "$ssl_text" "$ssl_expires" "$current_version"
        
        ((id++))
    done
    
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Total: ${#domains[@]} website(s)"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo "  Use either domain name or ID in commands:"
    echo "  hostkit info <domain|id>      - Show detailed website information"
    echo "  hostkit start <domain|id>     - Start website"
    echo "  hostkit stop <domain|id>      - Stop website"
    echo "  hostkit logs <domain|id>      - Show logs"
    echo ""
    echo -e "${WHITE}SSL Status Legend:${NC}"
    echo -e "  ${GREEN}✓ Valid${NC}      - Certificate is valid"
    echo -e "  ${YELLOW}⚠ Expiring${NC}   - Certificate expires in less than 7 days"
    echo -e "  ${RED}✗ Expired${NC}    - Certificate has expired"
    echo -e "  ${YELLOW}- None${NC}       - No certificate installed"
}