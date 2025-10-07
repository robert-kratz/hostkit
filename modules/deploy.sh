#!/bin/bash

# deploy.sh - Website Deployment
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

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