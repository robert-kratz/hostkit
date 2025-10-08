#!/bin/bash

# deploy.sh - Website Deployment
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

# Check if TAR file contains docker-compose.yml
is_compose_archive() {
    local tar_file="$1"
    tar -tf "$tar_file" 2>/dev/null | grep -q "^docker-compose.yml$"
    return $?
}

# Extract docker-compose.yml from TAR
extract_compose_file() {
    local tar_file="$1"
    local dest_dir="$2"
    
    tar -xf "$tar_file" -C "$dest_dir" docker-compose.yml 2>/dev/null
    return $?
}

# Load all images from TAR (for compose stacks with multiple images)
load_all_images_from_tar() {
    local tar_file="$1"
    local temp_dir=$(mktemp -d)
    
    print_step "Extracting all images from archive..."
    
    # Extract TAR to temp directory
    tar -xf "$tar_file" -C "$temp_dir" 2>/dev/null || {
        print_error "Failed to extract archive"
        rm -rf "$temp_dir"
        return 1
    }
    
    # Find all .tar files (image files) in extracted content
    local image_files=($(find "$temp_dir" -name "*.tar" -type f))
    
    if [ ${#image_files[@]} -eq 0 ]; then
        print_warning "No Docker images found in archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    print_info "Found ${#image_files[@]} Docker image(s)"
    
    # Load each image
    for img_file in "${image_files[@]}"; do
        print_info "Loading image: $(basename "$img_file")"
        docker load -i "$img_file" || {
            print_warning "Failed to load $(basename "$img_file")"
        }
    done
    
    rm -rf "$temp_dir"
    return 0
}

# Deploy Docker Compose stack
deploy_compose_stack() {
    local domain="$1"
    local compose_file="$2"
    local version="$3"
    local config="$4"
    
    local compose_dir="$WEB_ROOT/$domain"
    local container_prefix="${domain//./-}"
    local configured_port=$(echo "$config" | jq -r '.port')
    
    # Copy compose file to domain directory
    cp "$compose_file" "$compose_dir/docker-compose.yml.tmp"
    
    # Process compose file: Override ports with configured port
    print_step "Processing docker-compose.yml..."
    print_info "Configured port: $configured_port"
    
    # Override host ports in docker-compose.yml with sed
    # This handles formats like:
    #   - "3000:3000"
    #   - "127.0.0.1:3000:3000"
    #   - 3000:3000
    
    sed -E "s/([\"']?)[0-9]+:([0-9]+)([\"']?)/\1${configured_port}:\2\3/g" \
        "$compose_dir/docker-compose.yml.tmp" > "$compose_dir/docker-compose.yml"
    
    # Show what changed
    local changes=$(grep -n "ports:" "$compose_dir/docker-compose.yml" -A 2 | grep -E "^\s*-\s*.*${configured_port}:" || true)
    if [ -n "$changes" ]; then
        print_success "Port mappings updated to use port $configured_port"
    else
        print_info "No port mappings found or already correct"
    fi
    
    # Remove temporary file
    rm -f "$compose_dir/docker-compose.yml.tmp"
    
    # Create versioned backup
    cp "$compose_dir/docker-compose.yml" "$compose_dir/docker-compose.${version}.yml"
    
    # Ensure .env file exists
    if [ ! -f "$compose_dir/.env" ]; then
        print_warning "No .env file found, creating template..."
        cat > "$compose_dir/.env" <<'ENVEOF'
# Environment Variables
PORT=3000
NODE_ENV=production
ENVEOF
        chmod 600 "$compose_dir/.env"
    fi
    
    print_step "Starting Docker Compose stack..."
    print_info "Using .env file: $compose_dir/.env"
    
    # Set environment variables for compose
    export COMPOSE_PROJECT_NAME="$container_prefix"
    export DOMAIN="$domain"
    
    # Start compose stack (docker-compose automatically reads .env from current directory)
    cd "$compose_dir"
    if docker-compose --env-file .env up -d 2>&1 | tee /tmp/compose-up.log; then
        print_success "Compose stack started"
        
        # Get list of services
        local services=($(docker-compose ps --services))
        print_info "Services: ${services[*]}"
        
        # Find main service (the one with exposed port)
        local main_service=""
        local exposed_port=""
        
        for service in "${services[@]}"; do
            # Check if service has port label or is first service
            local port_label=$(docker inspect "${container_prefix}_${service}_1" 2>/dev/null | \
                jq -r '.[0].Config.Labels["hostkit.port"] // empty')
            
            if [ -n "$port_label" ]; then
                main_service="$service"
                exposed_port="$port_label"
                break
            fi
        done
        
        # If no labeled service, use first service
        if [ -z "$main_service" ]; then
            main_service="${services[0]}"
            # Try to detect port from compose file
            exposed_port=$(grep -A 10 "^  $main_service:" "$compose_file" | \
                grep -oP "(?<=- \")[0-9]+(?=:)" | head -1)
        fi
        
        if [ -z "$exposed_port" ]; then
            # Use configured port from domain config
            exposed_port=$(echo "$config" | jq -r '.port')
        fi
        
        print_info "Main service: $main_service (port: $exposed_port)"
        
        # Update config with compose info
        local updated_config=$(echo "$config" | jq \
            --arg version "$version" \
            --arg main_service "$main_service" \
            --arg port "$exposed_port" \
            --argjson services "$(printf '%s\n' "${services[@]}" | jq -R . | jq -s .)" \
            '. + {
                type: "compose",
                current_version: $version,
                main_service: $main_service,
                port: ($port | tonumber),
                services: $services,
                compose_file: "docker-compose.yml"
            }')
        
        save_domain_config "$domain" "$updated_config"
        
        cd - > /dev/null
        return 0
    else
        print_error "Failed to start Compose stack"
        cat /tmp/compose-up.log
        cd - > /dev/null
        return 1
    fi
}

deploy_website() {
    local input="$1"
    local tar_file="$2"
    
    if [ -z "$input" ]; then
        print_error "Domain or ID missing"
        echo "Usage: hostkit deploy <domain|id> [tar-file]"
        echo ""
        echo "Examples:"
        echo "  hostkit deploy example.com"
        echo "  hostkit deploy 0 /path/to/image.tar"
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
    local port=$(echo "$config" | jq -r '.port')
    local username=$(echo "$config" | jq -r '.username')
    local memory_limit=$(echo "$config" | jq -r '.memory_limit // "512m"')
    local memory_reservation=$(echo "$config" | jq -r '.memory_reservation // "256m"')
    
    print_step "Deploying website: $domain"
    echo ""
    
    # Find TAR file
    if [ -z "$tar_file" ]; then
        # Search for latest TAR in deploy folder
        tar_file=$(find "$WEB_ROOT/$domain/deploy" -name "*.tar" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
        
        if [ -z "$tar_file" ]; then
            print_error "No TAR file found in $WEB_ROOT/$domain/deploy"
            print_info "Upload a TAR file to the deploy directory or specify a path"
            print_info "Example: scp image.tar user@server:/opt/domains/$domain/deploy/"
            return 1
        fi
        
        print_info "Using latest TAR: $(basename "$tar_file")"
    fi
    
    # Validate TAR file
    if [ ! -f "$tar_file" ]; then
        print_error "TAR file not found: $tar_file"
        return 1
    fi
    
    if [ ! -r "$tar_file" ]; then
        print_error "TAR file is not readable: $tar_file"
        return 1
    fi
    
    # Basic TAR validation
    if ! tar -tf "$tar_file" >/dev/null 2>&1; then
        print_error "Invalid or corrupted TAR file: $tar_file"
        return 1
    fi
    
    # Create version name (Timestamp)
    local version=$(date +%Y%m%d-%H%M%S)
    local image_name="${domain}-${version}"
    
    # Check if this is a Docker Compose archive
    if is_compose_archive "$tar_file"; then
        print_info "Detected Docker Compose configuration"
        
        # Create temporary directory for extraction
        local temp_dir=$(mktemp -d)
        
        # Extract compose file
        if ! extract_compose_file "$tar_file" "$temp_dir"; then
            print_error "Failed to extract docker-compose.yml"
            rm -rf "$temp_dir"
            return 1
        fi
        
        # Load all images from archive
        if ! load_all_images_from_tar "$tar_file"; then
            print_error "Failed to load images from archive"
            rm -rf "$temp_dir"
            return 1
        fi
        
        # Deploy compose stack
        if deploy_compose_stack "$domain" "$temp_dir/docker-compose.yml" "$version" "$config"; then
            # Save archive
            local image_dir="$WEB_ROOT/$domain/images"
            mkdir -p "$image_dir"
            mv "$tar_file" "$image_dir/${version}.tar"
            echo "$version" > "$image_dir/${version}.info"
            echo "compose" >> "$image_dir/${version}.info"
            
            rm -rf "$temp_dir"
            
            echo ""
            print_success "Compose deployment successful!"
            print_info "Version: $version"
            print_info "Stack: ${domain//./-}"
            print_info "URL: https://$domain"
            return 0
        else
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Standard single-container deployment
    print_step "Loading Docker image..."
    if docker load -i "$tar_file" 2>&1 | tee /tmp/docker-load.log; then
        print_success "Image loaded"
    else
        print_error "Error loading image"
        cat /tmp/docker-load.log
        return 1
    fi
    
    # Extrahiere Image-Namen aus docker load Output
    local loaded_image=$(grep "Loaded image" /tmp/docker-load.log | awk '{print $NF}' | head -1)
    
    if [ -z "$loaded_image" ]; then
        print_error "Could not determine image name"
        return 1
    fi
    
    print_info "Loaded image: $loaded_image"
    
    # Tag image with version
    docker tag "$loaded_image" "${domain}:${version}"
    docker tag "$loaded_image" "${domain}:latest"
    
    # Save image info
    local image_dir="$WEB_ROOT/$domain/images"
    mkdir -p "$image_dir"
    
    echo "$version" > "$image_dir/${version}.info"
    echo "$loaded_image" >> "$image_dir/${version}.info"
    
    # Stop old container
    local container_name="${domain//./-}"
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        print_step "Stopping old container..."
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
        print_success "Old container stopped"
    fi
    
    # Start new container
    print_step "Starting new container..."
    print_info "Memory limit: $memory_limit, reservation: $memory_reservation"
    
    docker run -d \
        --name "$container_name" \
        --restart unless-stopped \
        --memory="$memory_limit" \
        --memory-reservation="$memory_reservation" \
        -p "127.0.0.1:${port}:${port}" \
        -v "$WEB_ROOT/$domain/logs:/app/logs" \
        "${domain}:latest"
    
    if [ $? -eq 0 ]; then
        print_success "Container started"
        
        # Update config
        local updated_config=$(echo "$config" | jq ".current_version = \"$version\"")
        save_domain_config "$domain" "$updated_config"
        
        # Cleanup old images
        cleanup_old_images "$domain"
        
        # Move TAR file
        mv "$tar_file" "$image_dir/${version}.tar"
        
        echo ""
        print_success "Deployment successful!"
        print_info "Version: $version"
        print_info "Container: $container_name"
        print_info "URL: https://$domain"
    else
        print_error "Error starting container"
        docker logs "$container_name"
        return 1
    fi
}

cleanup_old_images() {
    local domain="$1"
    local image_dir="$WEB_ROOT/$domain/images"
    
    print_step "Cleaning up old images (keeping last 3)..."
    
    # List all versions
    local versions=($(ls -t "$image_dir"/*.info 2>/dev/null | head -n 10 | xargs -n1 basename | sed 's/.info$//'))
    
    if [ ${#versions[@]} -le 3 ]; then
        print_info "No cleanup needed (${#versions[@]} versions available)"
        return
    fi
    
    # Delete old versions (all except first 3)
    local deleted=0
    for ((i=3; i<${#versions[@]}; i++)); do
        local ver="${versions[$i]}"
        
        # Delete Docker image
        if docker image inspect "${domain}:${ver}" &>/dev/null; then
            docker rmi "${domain}:${ver}" 2>/dev/null || true
        fi
        
        # Delete TAR and info
        rm -f "$image_dir/${ver}.tar"
        rm -f "$image_dir/${ver}.info"
        
        ((deleted++))
    done
    
    if [ $deleted -gt 0 ]; then
        print_success "$deleted old version(s) deleted"
    fi
}