#!/bin/bash

# control.sh - Container Control
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

get_container_name() {
    local domain="$1"
    echo "${domain//./-}"
}

is_compose_deployment() {
    local domain="$1"
    local config=$(load_domain_config "$domain")
    local deployment_type=$(echo "$config" | jq -r '.type // "single"')
    [ "$deployment_type" = "compose" ]
}

get_container_status() {
    local domain="$1"
    local container_name=$(get_container_name "$domain")
    
    # Check if this is a compose deployment
    if is_compose_deployment "$domain"; then
        # Check compose stack status
        cd "$WEB_ROOT/$domain" 2>/dev/null || return 1
        local running_services=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        local total_services=$(docker-compose ps --services 2>/dev/null | wc -l)
        cd - > /dev/null
        
        if [ "$running_services" -gt 0 ] && [ "$running_services" -eq "$total_services" ]; then
            echo "running"
        elif [ "$running_services" -gt 0 ]; then
            echo "partial"
        elif [ "$total_services" -gt 0 ]; then
            echo "stopped"
        else
            echo "not_found"
        fi
    else
        # Standard single container check
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo "running"
        elif docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo "stopped"
        else
            echo "not_found"
        fi
    fi
}

start_website() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit start <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit start example.com"
        echo "  hostkit start 0"
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
    
    local container_name=$(get_container_name "$domain")
    local status=$(get_container_status "$domain")
    
    print_step "Starting website: $domain"
    echo ""
    
    # Check if this is a compose deployment
    if is_compose_deployment "$domain"; then
        case "$status" in
            running)
                print_warning "Compose stack is already running"
                ;;
            partial|stopped)
                cd "$WEB_ROOT/$domain"
                export COMPOSE_PROJECT_NAME="$container_name"
                docker-compose --env-file .env up -d
                if [ $? -eq 0 ]; then
                    print_success "Compose stack started"
                else
                    print_error "Error starting compose stack"
                    cd - > /dev/null
                    return 1
                fi
                cd - > /dev/null
                ;;
            not_found)
                print_error "No compose stack found. Please deploy first."
                return 1
                ;;
        esac
    else
        # Standard single container
        case "$status" in
            running)
                print_warning "Container is already running"
                ;;
            stopped)
                docker start "$container_name"
                if [ $? -eq 0 ]; then
                    print_success "Container started"
                else
                    print_error "Error starting container"
                    return 1
                fi
                ;;
            not_found)
                print_error "No container found. Please deploy first."
                return 1
                ;;
        esac
    fi
}

stop_website() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit stop <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit stop example.com"
        echo "  hostkit stop 0"
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
    
    local container_name=$(get_container_name "$domain")
    local status=$(get_container_status "$domain")
    
    print_step "Stopping website: $domain"
    echo ""
    
    # Check if this is a compose deployment
    if is_compose_deployment "$domain"; then
        if [ "$status" = "not_found" ]; then
            print_error "No compose stack found"
            return 1
        elif [ "$status" = "stopped" ]; then
            print_warning "Compose stack is already stopped"
        else
            cd "$WEB_ROOT/$domain"
            export COMPOSE_PROJECT_NAME="$container_name"
            docker-compose stop
            if [ $? -eq 0 ]; then
                print_success "Compose stack stopped"
            else
                print_error "Error stopping compose stack"
                cd - > /dev/null
                return 1
            fi
            cd - > /dev/null
        fi
    else
        # Standard single container
        if [ "$status" = "not_found" ]; then
            print_error "No container found"
            return 1
        elif [ "$status" = "stopped" ]; then
            print_warning "Container is already stopped"
        else
            docker stop "$container_name"
            if [ $? -eq 0 ]; then
                print_success "Container stopped"
            else
                print_error "Error stopping container"
                return 1
            fi
        fi
    fi
}

restart_website() {
    local input="$1"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit restart <domain|id>"
        echo ""
        echo "Examples:"
        echo "  hostkit restart example.com"
        echo "  hostkit restart 0"
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
    
    local container_name=$(get_container_name "$domain")
    local status=$(get_container_status "$domain")
    
    print_step "Restarting website: $domain"
    echo ""
    
    if [ "$status" = "not_found" ]; then
        print_error "No deployment found. Please deploy first."
        return 1
    fi
    
    # Check if this is a compose deployment
    if is_compose_deployment "$domain"; then
        cd "$WEB_ROOT/$domain"
        export COMPOSE_PROJECT_NAME="$container_name"
        docker-compose --env-file .env restart
        if [ $? -eq 0 ]; then
            print_success "Compose stack restarted"
        else
            print_error "Error restarting compose stack"
            cd - > /dev/null
            return 1
        fi
        cd - > /dev/null
    else
        # Standard single container
        docker restart "$container_name"
        if [ $? -eq 0 ]; then
            print_success "Container restarted"
        else
            print_error "Error restarting container"
            return 1
        fi
    fi
}

show_logs() {
    local input="$1"
    local lines="${2:-50}"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit logs <domain|id> [number-of-lines]"
        echo ""
        echo "Examples:"
        echo "  hostkit logs example.com"
        echo "  hostkit logs 0 100"
        echo "  hostkit logs 0 -f"
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
    
    local container_name=$(get_container_name "$domain")
    local status=$(get_container_status "$domain")
    
    if [ "$status" = "not_found" ]; then
        print_error "No deployment found"
        return 1
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Logs for $domain (last $lines lines)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if this is a compose deployment
    if is_compose_deployment "$domain"; then
        cd "$WEB_ROOT/$domain"
        export COMPOSE_PROJECT_NAME="$container_name"
        docker-compose logs --tail "$lines" -f
        cd - > /dev/null
    else
        # Standard single container
        docker logs --tail "$lines" -f "$container_name"
    fi
}