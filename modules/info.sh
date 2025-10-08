#!/bin/bash

# info.sh - Website Detailed Information
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

show_website_info() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit info <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit info example.com"
        echo "  hostkit info 0"
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
    
    # Load configuration
    local config=$(load_domain_config "$domain")
    if [ -z "$config" ] || [ "$config" = "{}" ]; then
        print_error "Failed to load configuration for: $domain"
        return 1
    fi
    
    # Get website ID
    local website_id=$(get_domain_id "$domain")
    
    # Extract config values
    local port=$(echo "$config" | jq -r '.port')
    local username=$(echo "$config" | jq -r '.username')
    local current_version=$(echo "$config" | jq -r '.current_version // "none"')
    local created=$(echo "$config" | jq -r '.created // "unknown"')
    local redirect_domains=$(echo "$config" | jq -r '.redirect_domains[]?' 2>/dev/null)
    
    # Get container information
    local container_name=$(get_container_name "$domain")
    local container_status=$(get_container_status "$domain")
    local container_id=""
    local container_image=""
    local container_uptime=""
    
    if [ "$container_status" = "running" ] || [ "$container_status" = "stopped" ]; then
        container_id=$(docker ps -a --filter "name=^${container_name}$" --format "{{.ID}}" 2>/dev/null)
        container_image=$(docker ps -a --filter "name=^${container_name}$" --format "{{.Image}}" 2>/dev/null)
        if [ "$container_status" = "running" ]; then
            container_uptime=$(docker ps --filter "name=^${container_name}$" --format "{{.Status}}" 2>/dev/null)
        fi
    fi
    
    # Get SSL information
    local ssl_status=$(get_ssl_status "$domain")
    local ssl_days=$(get_ssl_days_until_expiry "$domain")
    local ssl_issuer=""
    local ssl_expiry_date=""
    
    if [ -f "/etc/letsencrypt/live/$domain/cert.pem" ]; then
        ssl_issuer=$(openssl x509 -issuer -noout -in "/etc/letsencrypt/live/$domain/cert.pem" 2>/dev/null | sed 's/issuer=//')
        ssl_expiry_date=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/cert.pem" 2>/dev/null | cut -d= -f2)
    fi
    
    # Get version history
    local image_dir="$WEB_ROOT/$domain/images"
    local version_count=0
    if [ -d "$image_dir" ]; then
        version_count=$(find "$image_dir" -name "*.info" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    # Get disk usage
    local disk_usage="unknown"
    if [ -d "$WEB_ROOT/$domain" ]; then
        disk_usage=$(du -sh "$WEB_ROOT/$domain" 2>/dev/null | cut -f1)
    fi
    
    # Display information
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        WEBSITE INFORMATION                                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${WHITE}GENERAL INFORMATION${NC}"
    echo -e "  ${CYAN}ID:${NC}                  $website_id"
    echo -e "  ${CYAN}Domain:${NC}              $domain"
    echo -e "  ${CYAN}Port:${NC}                $port"
    echo -e "  ${CYAN}Created:${NC}             $created"
    echo -e "  ${CYAN}Disk Usage:${NC}          $disk_usage"
    
    if [ -n "$redirect_domains" ]; then
        echo -e "  ${CYAN}Redirect Domains:${NC}"
        while IFS= read -r redirect; do
            echo -e "    - $redirect"
        done <<< "$redirect_domains"
    fi
    
    # Check deployment type
    local deployment_type=$(echo "$config" | jq -r '.type // "single"')
    
    echo ""
    echo -e "${WHITE}DEPLOYMENT TYPE${NC}"
    if [ "$deployment_type" = "compose" ]; then
        echo -e "  ${CYAN}Type:${NC}                ${BLUE}Docker Compose${NC}"
        
        # Show services
        local services=$(echo "$config" | jq -r '.services[]?' 2>/dev/null)
        if [ -n "$services" ]; then
            echo -e "  ${CYAN}Services:${NC}"
            while IFS= read -r service; do
                local service_container="${container_name}_${service}_1"
                local service_status="not running"
                if docker ps --format '{{.Names}}' | grep -q "^${service_container}$"; then
                    service_status="${GREEN}running${NC}"
                elif docker ps -a --format '{{.Names}}' | grep -q "^${service_container}$"; then
                    service_status="${YELLOW}stopped${NC}"
                else
                    service_status="${RED}not found${NC}"
                fi
                echo -e "    - ${service} (${service_status})"
            done <<< "$services"
        fi
        
        local main_service=$(echo "$config" | jq -r '.main_service // "unknown"')
        echo -e "  ${CYAN}Main Service:${NC}        $main_service"
    else
        echo -e "  ${CYAN}Type:${NC}                ${BLUE}Single Container${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}CONTAINER STATUS${NC}"
    case "$container_status" in
        running)
            echo -e "  ${CYAN}Status:${NC}              ${GREEN}●${NC} Running"
            if [ "$deployment_type" != "compose" ]; then
                echo -e "  ${CYAN}Container ID:${NC}        $container_id"
                echo -e "  ${CYAN}Image:${NC}               $container_image"
                echo -e "  ${CYAN}Uptime:${NC}              $container_uptime"
                
                # Show memory usage if container is running
                local mem_usage=$(docker stats "$container_name" --no-stream --format "{{.MemUsage}}" 2>/dev/null)
                if [ -n "$mem_usage" ]; then
                    echo -e "  ${CYAN}Memory Usage:${NC}        $mem_usage"
                fi
            fi
            ;;
        partial)
            echo -e "  ${CYAN}Status:${NC}              ${YELLOW}⚠${NC} Partially Running"
            echo -e "  ${YELLOW}Some services are not running${NC}"
            ;;
        stopped)
            echo -e "  ${CYAN}Status:${NC}              ${YELLOW}○${NC} Stopped"
            if [ "$deployment_type" != "compose" ]; then
                echo -e "  ${CYAN}Container ID:${NC}        $container_id"
                echo -e "  ${CYAN}Image:${NC}               $container_image"
            fi
            ;;
        not_found)
            echo -e "  ${CYAN}Status:${NC}              ${RED}✗${NC} No deployment"
            echo -e "  ${YELLOW}Run 'hostkit deploy $domain' to create deployment${NC}"
            ;;
    esac
    
    # Show memory limits (only for single container)
    if [ "$deployment_type" != "compose" ]; then
        local memory_limit=$(echo "$config" | jq -r '.memory_limit // "512m"')
        local memory_reservation=$(echo "$config" | jq -r '.memory_reservation // "256m"')
        echo -e "  ${CYAN}Memory Limit:${NC}        $memory_limit"
        echo -e "  ${CYAN}Memory Reservation:${NC}  $memory_reservation"
    fi
    
    echo ""
    echo -e "${WHITE}SSL CERTIFICATE${NC}"
    case "$ssl_status" in
        valid)
            echo -e "  ${CYAN}Status:${NC}              ${GREEN}✓${NC} Valid"
            echo -e "  ${CYAN}Expires in:${NC}          ${GREEN}${ssl_days} days${NC}"
            ;;
        expiring)
            echo -e "  ${CYAN}Status:${NC}              ${YELLOW}⚠${NC} Expiring Soon"
            echo -e "  ${CYAN}Expires in:${NC}          ${YELLOW}${ssl_days} days${NC}"
            ;;
        expired)
            echo -e "  ${CYAN}Status:${NC}              ${RED}✗${NC} Expired"
            echo -e "  ${CYAN}Expired:${NC}             ${RED}${ssl_days} days ago${NC}"
            ;;
        missing)
            echo -e "  ${CYAN}Status:${NC}              ${YELLOW}-${NC} No Certificate"
            echo -e "  ${YELLOW}Run 'hostkit ssl-renew $domain' to obtain certificate${NC}"
            ;;
        error)
            echo -e "  ${CYAN}Status:${NC}              ${RED}?${NC} Error reading certificate"
            ;;
    esac
    
    if [ -n "$ssl_expiry_date" ]; then
        echo -e "  ${CYAN}Expiry Date:${NC}         $ssl_expiry_date"
    fi
    if [ -n "$ssl_issuer" ]; then
        echo -e "  ${CYAN}Issuer:${NC}              $ssl_issuer"
    fi
    
    echo ""
    echo -e "${WHITE}DEPLOYMENT${NC}"
    echo -e "  ${CYAN}Username:${NC}            $username"
    echo -e "  ${CYAN}Current Version:${NC}     $current_version"
    echo -e "  ${CYAN}Version History:${NC}     $version_count version(s) available"
    
    # Show SSH key status (default keys)
    local ssh_key_rsa="$WEB_ROOT/$domain/.ssh/id_rsa"
    local ssh_key_ed25519="$WEB_ROOT/$domain/.ssh/id_ed25519"
    echo ""
    echo -e "${WHITE}SSH KEYS (Default)${NC}"
    if [ -f "$ssh_key_rsa" ]; then
        local key_size=$(ssh-keygen -lf "$ssh_key_rsa" 2>/dev/null | awk '{print $1}')
        echo -e "  ${CYAN}RSA Key:${NC}             ${GREEN}✓${NC} Present ($key_size bit)"
    else
        echo -e "  ${CYAN}RSA Key:${NC}             ${RED}✗${NC} Missing"
    fi
    
    if [ -f "$ssh_key_ed25519" ]; then
        echo -e "  ${CYAN}Ed25519 Key:${NC}         ${GREEN}✓${NC} Present"
    else
        echo -e "  ${CYAN}Ed25519 Key:${NC}         ${RED}✗${NC} Missing"
    fi
    
    # Show additional SSH keys
    local key_dir="$WEB_ROOT/$domain/.ssh/keys"
    if [ -d "$key_dir" ]; then
        local key_names=()
        while IFS= read -r pub_key; do
            local basename=$(basename "$pub_key")
            local key_name=$(echo "$basename" | sed -E 's/key-(.+)\.(rsa|ed25519)\.pub/\1/')
            if [[ ! " ${key_names[@]} " =~ " ${key_name} " ]]; then
                key_names+=("$key_name")
            fi
        done < <(find "$key_dir" -name "key-*.pub" 2>/dev/null)
        
        if [ ${#key_names[@]} -gt 0 ]; then
            echo ""
            echo -e "${WHITE}SSH KEYS (Additional)${NC}"
            echo -e "  ${CYAN}Total Keys:${NC}          ${#key_names[@]} key(s)"
            
            for key_name in "${key_names[@]}"; do
                local rsa_exists="${RED}✗${NC}"
                local ed25519_exists="${RED}✗${NC}"
                
                if [ -f "$key_dir/key-$key_name.rsa" ]; then
                    rsa_exists="${GREEN}✓${NC}"
                fi
                if [ -f "$key_dir/key-$key_name.ed25519" ]; then
                    ed25519_exists="${GREEN}✓${NC}"
                fi
                
                echo -e "  ${CYAN}• $key_name:${NC}           RSA: $rsa_exists  Ed25519: $ed25519_exists"
            done
            
            echo ""
            echo -e "  ${YELLOW}Use 'hostkit list-keys $website_id' for more details${NC}"
        else
            echo ""
            echo -e "  ${YELLOW}No additional keys. Use 'hostkit add-key $website_id <name>' to create.${NC}"
        fi
    else
        echo ""
        echo -e "  ${YELLOW}No additional keys. Use 'hostkit add-key $website_id <name>' to create.${NC}"
    fi
    
    # Show Nginx config status
    echo ""
    echo -e "${WHITE}CONFIGURATION${NC}"
    if [ -f "$NGINX_SITES/$domain.conf" ]; then
        echo -e "  ${CYAN}Nginx Config:${NC}        ${GREEN}✓${NC} Active"
        echo -e "  ${CYAN}Config File:${NC}         $NGINX_SITES/$domain.conf"
    else
        echo -e "  ${CYAN}Nginx Config:${NC}        ${RED}✗${NC} Missing"
    fi
    
    if [ -f "$WEB_ROOT/$domain/config.json" ]; then
        echo -e "  ${CYAN}Domain Config:${NC}       ${GREEN}✓${NC} Present"
        echo -e "  ${CYAN}Config File:${NC}         $WEB_ROOT/$domain/config.json"
    fi
    
    # Show available versions
    if [ $version_count -gt 0 ]; then
        echo ""
        echo -e "${WHITE}AVAILABLE VERSIONS${NC}"
        local version_files=($(find "$image_dir" -name "*.info" -type f 2>/dev/null | sort -r | head -5))
        for version_file in "${version_files[@]}"; do
            local version=$(basename "$version_file" .info)
            local is_current=""
            if [ "$version" = "$current_version" ]; then
                is_current="${GREEN}(current)${NC}"
            fi
            echo -e "  - $version $is_current"
        done
        if [ $version_count -gt 5 ]; then
            echo -e "  ${YELLOW}... and $((version_count - 5)) more${NC}"
        fi
    fi
    
    # Show quick actions
    echo ""
    echo -e "${WHITE}QUICK ACTIONS${NC}"
    case "$container_status" in
        running)
            echo -e "  ${CYAN}hostkit stop $website_id${NC}       - Stop container"
            echo -e "  ${CYAN}hostkit restart $website_id${NC}    - Restart container"
            echo -e "  ${CYAN}hostkit logs $website_id${NC}       - View logs"
            ;;
        stopped)
            echo -e "  ${CYAN}hostkit start $website_id${NC}      - Start container"
            echo -e "  ${CYAN}hostkit logs $website_id${NC}       - View logs"
            ;;
        not_found)
            echo -e "  ${CYAN}hostkit deploy $website_id${NC}     - Deploy container"
            ;;
    esac
    
    if [ "$ssl_status" = "expiring" ] || [ "$ssl_status" = "expired" ] || [ "$ssl_status" = "missing" ]; then
        echo -e "  ${CYAN}hostkit ssl-renew $website_id${NC}  - Renew SSL certificate"
    fi
    
    echo -e "  ${CYAN}hostkit versions $website_id${NC}    - Show all versions"
    echo -e "  ${CYAN}hostkit remove $website_id${NC}      - Remove website"
    
    echo ""
}