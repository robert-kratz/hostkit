#!/bin/bash

# ssl.sh - SSL Certificate Management
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

# Setup SSL certificate for a domain
ssl_setup_domain() {
    local domain_or_id="$1"
    
    # Resolve domain from ID if needed
    local domain=$(resolve_domain "$domain_or_id")
    if [ -z "$domain" ]; then
        print_error "Website not found: $domain_or_id"
        return 1
    fi
    
    local config_file="$WEB_ROOT/$domain/config.json"
    if [ ! -f "$config_file" ]; then
        print_error "Configuration not found for $domain"
        return 1
    fi
    
    # Load configuration
    local config=$(cat "$config_file")
    local all_domains=$(echo "$config" | jq -r '.all_domains[]' 2>/dev/null)
    local domains_array=()
    
    while IFS= read -r d; do
        [ -n "$d" ] && domains_array+=("$d")
    done <<< "$all_domains"
    
    echo ""
    echo -e "${WHITE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║          SSL Certificate Setup                            ║${NC}"
    echo -e "${WHITE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_info "Setting up SSL certificate for: $domain"
    
    if [ ${#domains_array[@]} -gt 1 ]; then
        echo -e "${CYAN}Additional domains: ${domains_array[@]:1}${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Prerequisites:${NC}"
    echo -e "  ${CYAN}✓${NC} Domain(s) must point to this server's IP"
    echo -e "  ${CYAN}✓${NC} Port 80 must be accessible"
    echo -e "  ${CYAN}✓${NC} Nginx must be running"
    echo ""
    echo -e "${YELLOW}Note: Let's Encrypt rate limit is 5 certificates per domain per week${NC}"
    echo ""
    
    if ! ask_yes_no "Continue with SSL setup?"; then
        print_warning "SSL setup cancelled"
        return 0
    fi
    
    # Check if certificate already exists
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        echo ""
        print_warning "SSL certificate already exists for $domain"
        
        # Show certificate info
        local expiry_date=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/cert.pem" 2>/dev/null | cut -d= -f2)
        if [ -n "$expiry_date" ]; then
            print_info "Current certificate expires: $expiry_date"
        fi
        
        echo ""
        if ask_yes_no "Do you want to renew/replace the certificate?"; then
            print_step "Renewing certificate..."
        else
            print_info "SSL setup cancelled"
            return 0
        fi
    fi
    
    # Build certbot command
    local certbot_cmd="certbot certonly --nginx"
    certbot_cmd="$certbot_cmd -d $domain"
    
    # Add additional domains
    for d in "${domains_array[@]:1}"; do
        certbot_cmd="$certbot_cmd -d $d"
    done
    
    certbot_cmd="$certbot_cmd --non-interactive --agree-tos"
    
    # Request email if not provided
    echo ""
    echo -ne "${CYAN}Email for Let's Encrypt notifications: ${NC}"
    read -r email
    
    if [ -z "$email" ]; then
        print_error "Email is required for Let's Encrypt"
        return 1
    fi
    
    # Validate email format
    if ! [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid email format"
        return 1
    fi
    
    certbot_cmd="$certbot_cmd --email $email"
    
    # Execute certbot
    echo ""
    print_step "Requesting SSL certificate from Let's Encrypt..."
    echo ""
    
    if eval "$certbot_cmd"; then
        print_success "SSL certificate obtained successfully!"
        
        # Update Nginx configuration to use SSL
        echo ""
        print_step "Updating Nginx configuration..."
        
        if update_nginx_ssl "$domain" "${domains_array[@]}"; then
            print_success "Nginx configuration updated"
            
            # Test and reload Nginx
            if nginx -t 2>/dev/null; then
                systemctl reload nginx
                print_success "Nginx reloaded"
            else
                print_error "Nginx configuration test failed"
                return 1
            fi
        else
            print_warning "Failed to update Nginx configuration"
        fi
        
        # Setup auto-renewal cron job
        setup_ssl_autorenewal
        
        echo ""
        print_success "SSL setup completed!"
        echo ""
        echo -e "${GREEN}Your website is now accessible via HTTPS:${NC}"
        echo -e "${CYAN}  https://$domain${NC}"
        
        if [ ${#domains_array[@]} -gt 1 ]; then
            for d in "${domains_array[@]:1}"; do
                echo -e "${CYAN}  https://$d${NC}"
            done
        fi
        
        echo ""
        print_info "Certificate will auto-renew before expiry"
        
    else
        print_error "Failed to obtain SSL certificate"
        echo ""
        echo -e "${YELLOW}Common issues:${NC}"
        echo -e "  ${CYAN}•${NC} Domain not pointing to this server"
        echo -e "  ${CYAN}•${NC} Port 80 not accessible (firewall?)"
        echo -e "  ${CYAN}•${NC} Nginx not running"
        echo -e "  ${CYAN}•${NC} Rate limit reached (5 certs/week per domain)"
        echo ""
        return 1
    fi
}

# Update Nginx configuration to enable SSL
update_nginx_ssl() {
    local domain="$1"
    shift
    local all_domains=("$domain" "$@")
    
    local nginx_config="$NGINX_SITES/$domain"
    
    if [ ! -f "$nginx_config" ]; then
        print_error "Nginx configuration not found: $nginx_config"
        return 1
    fi
    
    # Check if SSL is already configured
    if grep -q "listen 443 ssl" "$nginx_config"; then
        print_info "SSL already configured in Nginx"
        return 0
    fi
    
    # Load current config to get port
    local config_file="$WEB_ROOT/$domain/config.json"
    local port=$(jq -r '.port' "$config_file" 2>/dev/null)
    
    if [ -z "$port" ] || [ "$port" = "null" ]; then
        port="3000"
    fi
    
    # Create new Nginx config with SSL
    cat > "$nginx_config" <<EOF
# Nginx configuration for $domain
# Managed by HostKit
# Generated: $(date)

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $domain ${all_domains[@]:1};
    
    # ACME challenge for SSL renewal
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain ${all_domains[@]:1};
    
    # SSL Certificate
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$domain/chain.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logging
    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
    
    # Proxy to Docker container
    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
    
    # Enable site
    if [ ! -L "$NGINX_ENABLED/$domain" ]; then
        ln -s "$nginx_config" "$NGINX_ENABLED/$domain"
    fi
    
    return 0
}

# Setup auto-renewal cron job
setup_ssl_autorenewal() {
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "certbot renew"; then
        print_info "SSL auto-renewal already configured"
        return 0
    fi
    
    print_step "Setting up SSL auto-renewal..."
    
    # Add certbot renewal to crontab (runs twice daily)
    local current_cron=$(crontab -l 2>/dev/null || true)
    local new_cron="$current_cron"$'\n'"0 0,12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'"
    
    echo "$new_cron" | crontab -
    print_success "Auto-renewal configured (runs twice daily)"
}

# Renew SSL certificates
ssl_renew() {
    local domain_or_id="$1"
    
    echo ""
    echo -e "${WHITE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║          SSL Certificate Renewal                          ║${NC}"
    echo -e "${WHITE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -n "$domain_or_id" ]; then
        # Renew specific domain
        local domain=$(resolve_domain "$domain_or_id")
        if [ -z "$domain" ]; then
            print_error "Website not found: $domain_or_id"
            return 1
        fi
        
        print_step "Renewing certificate for $domain..."
        if certbot renew --cert-name "$domain" --force-renewal; then
            systemctl reload nginx
            print_success "Certificate renewed successfully"
        else
            print_error "Failed to renew certificate"
            return 1
        fi
    else
        # Renew all certificates
        print_step "Renewing all certificates..."
        if certbot renew; then
            systemctl reload nginx
            print_success "All certificates renewed"
        else
            print_error "Failed to renew certificates"
            return 1
        fi
    fi
}

# Show SSL certificate status
ssl_status() {
    local domain_or_id="$1"
    
    echo ""
    echo -e "${WHITE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║          SSL Certificate Status                           ║${NC}"
    echo -e "${WHITE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -n "$domain_or_id" ] && [ "$domain_or_id" != "all" ]; then
        # Show specific domain
        local domain=$(resolve_domain "$domain_or_id")
        if [ -z "$domain" ]; then
            print_error "Website not found: $domain_or_id"
            return 1
        fi
        
        show_domain_ssl_status "$domain"
    else
        # Show all domains
        local domains=($(get_registered_domains))
        
        if [ ${#domains[@]} -eq 0 ]; then
            print_warning "No websites registered"
            return 0
        fi
        
        for domain in "${domains[@]}"; do
            show_domain_ssl_status "$domain"
            echo ""
        done
    fi
}

# Show SSL status for a specific domain
show_domain_ssl_status() {
    local domain="$1"
    local cert_path="/etc/letsencrypt/live/$domain/cert.pem"
    
    echo -e "${WHITE}Domain: ${CYAN}$domain${NC}"
    
    if [ ! -f "$cert_path" ]; then
        echo -e "${YELLOW}  Status: No SSL certificate${NC}"
        echo -e "${CYAN}  Setup: hostkit ssl-setup $domain${NC}"
        return 0
    fi
    
    # Get certificate info
    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_path" 2>/dev/null | cut -d= -f2)
    local issuer=$(openssl x509 -issuer -noout -in "$cert_path" 2>/dev/null | sed 's/issuer=//')
    
    if [ -z "$expiry_date" ]; then
        echo -e "${RED}  Status: Error reading certificate${NC}"
        return 1
    fi
    
    # Calculate days until expiry
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    # Determine status color
    if [ $days_left -lt 0 ]; then
        echo -e "${RED}  Status: Expired${NC}"
        echo -e "${RED}  Expired: $((-days_left)) days ago${NC}"
    elif [ $days_left -lt 7 ]; then
        echo -e "${YELLOW}  Status: Expiring soon${NC}"
        echo -e "${YELLOW}  Days left: $days_left${NC}"
    else
        echo -e "${GREEN}  Status: Valid${NC}"
        echo -e "${GREEN}  Days left: $days_left${NC}"
    fi
    
    echo -e "${CYAN}  Expires: $expiry_date${NC}"
    echo -e "${CYAN}  Issuer: $issuer${NC}"
    
    # Show renewal command if needed
    if [ $days_left -lt 30 ]; then
        echo -e "${YELLOW}  Renew: hostkit ssl-renew $domain${NC}"
    fi
}
