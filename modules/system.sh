#!/bin/bash

# system.sh - System Maintenance and Updates
# 
# Copyright (c) 2025 Robert Julian Kratz
# https://github.com/robert-kratz/hostkit
# 
# Licensed under the MIT License

# Update SSH wrapper to latest version
update_ssh_wrapper() {
    print_step "Updating SSH wrapper to latest version..."
    
    # Check if wrapper exists
    if [ ! -f "/opt/hostkit/ssh-wrapper.sh" ]; then
        print_warning "SSH wrapper not found - creating new one"
    fi
    
    # Create updated SSH wrapper
    cat > "/opt/hostkit/ssh-wrapper.sh" <<'EOF'
#!/bin/bash
# SSH Command Wrapper for Deployment Users
# Restricts commands to deployment-related operations only

# Log all connection attempts
echo "$(date): SSH connection from $SSH_CLIENT as $USER: $SSH_ORIGINAL_COMMAND" >> /var/log/hostkit-ssh.log

# If no command specified, deny interactive shell
if [ -z "$SSH_ORIGINAL_COMMAND" ]; then
    echo "ERROR: Interactive shell access not allowed"
    echo "This account is restricted to deployment operations only"
    exit 1
fi

# Allow only specific commands for deployment
case "$SSH_ORIGINAL_COMMAND" in
    # Allow deployment commands
    "sudo hostkit deploy "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    "hostkit deploy "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow Docker operations for deployment
    "sudo /opt/hostkit/deploy.sh "*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow SCP file uploads to deployment directory (target mode)
    scp\ -t\ */deploy/*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    scp\ -t\ /opt/domains/*/deploy/*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow SCP with various flags
    scp\ *\ -t\ */deploy/*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    scp\ *\ -t\ /opt/domains/*/deploy/*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Allow rsync to deployment directory
    "rsync "*)
        if [[ "$SSH_ORIGINAL_COMMAND" == *"/deploy/"* ]]; then
            exec $SSH_ORIGINAL_COMMAND
        else
            echo "ERROR: rsync only allowed to deployment directories"
            exit 1
        fi
        ;;
    # Allow SFTP subsystem for file upload
    "internal-sftp")
        exec /usr/lib/openssh/sftp-server
        ;;
    # Allow sftp-server directly
    /usr/lib/openssh/sftp-server*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    /usr/libexec/openssh/sftp-server*)
        exec $SSH_ORIGINAL_COMMAND
        ;;
    # Reject all other commands
    *)
        echo "ERROR: Command not allowed: $SSH_ORIGINAL_COMMAND"
        echo "Allowed operations:"
        echo "  - File upload to deployment directory"
        echo "  - hostkit deploy commands"
        echo "  - Deployment-related Docker operations"
        exit 1
        ;;
esac
EOF
    
    # Set permissions
    chmod +x "/opt/hostkit/ssh-wrapper.sh"
    
    # Ensure log file exists
    touch /var/log/hostkit-ssh.log
    chmod 644 /var/log/hostkit-ssh.log
    
    print_success "SSH wrapper updated successfully"
    
    # Reload SSH daemon
    if systemctl reload sshd 2>/dev/null; then
        print_success "SSH daemon reloaded"
    else
        print_warning "Could not reload SSH daemon - please run: systemctl reload sshd"
    fi
    
    echo ""
    print_info "The SSH wrapper now supports:"
    echo "  ✓ GitHub Actions SCP uploads"
    echo "  ✓ Modern SCP/SFTP protocols"
    echo "  ✓ Deployment commands via SSH"
    echo "  ✓ Enhanced security logging"
    echo ""
    print_info "All deployment users will automatically use the updated wrapper"
}

# Update SSH configurations for all existing users
update_ssh_configs() {
    print_step "Updating SSH configurations for deployment users..."
    
    local updated_count=0
    
    # Find all deployment users
    while IFS=: read -r username _ _ _ _ home _; do
        if [[ "$username" =~ ^deploy- ]]; then
            print_info "Updating config for: $username"
            
            # Update SSH config with new naming convention
            local old_config="/etc/ssh/sshd_config.d/${username}.conf"
            local new_config="/etc/ssh/sshd_config.d/hostkit-${username}.conf"
            
            # Remove old config if exists
            if [ -f "$old_config" ]; then
                rm -f "$old_config"
            fi
            
            # Create new config
            cat > "$new_config" <<EOF
# SSH hardening for deployment user $username
Match User $username
    # Disable password authentication for this user
    PasswordAuthentication no
    # Disable challenge-response authentication
    ChallengeResponseAuthentication no
    # Force public key authentication only
    AuthenticationMethods publickey
    # Restrict to specific commands only (allows SCP/SFTP via wrapper)
    ForceCommand /opt/hostkit/ssh-wrapper.sh
    # Disable port forwarding
    AllowTcpForwarding no
    AllowStreamLocalForwarding no
    # Disable tty allocation for scripts (allows SCP to work)
    PermitTTY no
    # Disable X11 forwarding
    X11Forwarding no
    # Set idle timeout (10 minutes)
    ClientAliveInterval 300
    ClientAliveCountMax 2
EOF
            
            # Update sudoers with new naming convention
            local old_sudoers="/etc/sudoers.d/${username}"
            local new_sudoers="/etc/sudoers.d/hostkit-${username}"
            
            if [ -f "$old_sudoers" ] && [ ! -f "$new_sudoers" ]; then
                # Migrate old sudoers file
                cp "$old_sudoers" "$new_sudoers"
                chmod 440 "$new_sudoers"
            fi
            
            ((updated_count++))
        fi
    done < <(getent passwd | grep "^deploy-")
    
    if [ $updated_count -gt 0 ]; then
        print_success "$updated_count user configurations updated"
        
        # Reload SSH daemon
        if systemctl reload sshd 2>/dev/null; then
            print_success "SSH daemon reloaded"
        else
            print_warning "Could not reload SSH daemon - please run: systemctl reload sshd"
        fi
    else
        print_info "No deployment users found"
    fi
}

# Run system diagnostics
system_diagnostics() {
    print_step "Running HostKit system diagnostics..."
    echo ""
    
    # Check SSH wrapper
    echo -e "${WHITE}═══ SSH Wrapper ═══${NC}"
    if [ -f "/opt/hostkit/ssh-wrapper.sh" ]; then
        echo -e "${GREEN}✓${NC} SSH wrapper exists: /opt/hostkit/ssh-wrapper.sh"
        if [ -x "/opt/hostkit/ssh-wrapper.sh" ]; then
            echo -e "${GREEN}✓${NC} SSH wrapper is executable"
        else
            echo -e "${RED}✗${NC} SSH wrapper is NOT executable"
            print_warning "Run: chmod +x /opt/hostkit/ssh-wrapper.sh"
        fi
        
        # Check for GitHub Actions SCP support
        if grep -q "scp.*-t.*deploy" "/opt/hostkit/ssh-wrapper.sh"; then
            echo -e "${GREEN}✓${NC} GitHub Actions SCP support detected"
        else
            echo -e "${YELLOW}⚠${NC} GitHub Actions SCP support NOT detected"
            print_warning "Run: hostkit system update-wrapper"
        fi
    else
        echo -e "${RED}✗${NC} SSH wrapper NOT found"
        print_warning "Run: hostkit system update-wrapper"
    fi
    echo ""
    
    # Check SSH log
    echo -e "${WHITE}═══ SSH Logging ═══${NC}"
    if [ -f "/var/log/hostkit-ssh.log" ]; then
        echo -e "${GREEN}✓${NC} SSH log exists: /var/log/hostkit-ssh.log"
        local log_lines=$(wc -l < /var/log/hostkit-ssh.log)
        echo -e "  ${CYAN}Log entries:${NC} $log_lines"
        if [ $log_lines -gt 0 ]; then
            echo -e "  ${CYAN}Recent activity:${NC}"
            tail -3 /var/log/hostkit-ssh.log | sed 's/^/    /'
        fi
    else
        echo -e "${YELLOW}⚠${NC} SSH log NOT found"
        print_info "Will be created on first SSH connection"
    fi
    echo ""
    
    # Check deployment users
    echo -e "${WHITE}═══ Deployment Users ═══${NC}"
    local user_count=0
    while IFS=: read -r username _ _ _ _ home _; do
        if [[ "$username" =~ ^deploy- ]]; then
            ((user_count++))
            echo -e "${GREEN}✓${NC} User: $username"
            
            # Check SSH config
            if [ -f "/etc/ssh/sshd_config.d/hostkit-${username}.conf" ]; then
                echo -e "  ${GREEN}✓${NC} SSH config: hostkit-${username}.conf (new format)"
            elif [ -f "/etc/ssh/sshd_config.d/${username}.conf" ]; then
                echo -e "  ${YELLOW}⚠${NC} SSH config: ${username}.conf (old format)"
                print_info "    Run: hostkit system update-configs"
            else
                echo -e "  ${RED}✗${NC} SSH config: NOT found"
            fi
            
            # Check sudoers
            if [ -f "/etc/sudoers.d/hostkit-${username}" ]; then
                echo -e "  ${GREEN}✓${NC} Sudoers: hostkit-${username} (new format)"
            elif [ -f "/etc/sudoers.d/${username}" ]; then
                echo -e "  ${YELLOW}⚠${NC} Sudoers: ${username} (old format)"
            else
                echo -e "  ${RED}✗${NC} Sudoers: NOT found"
            fi
            
            # Check SSH keys
            if [ -d "$home/.ssh" ]; then
                local key_count=$(find "$home/.ssh" -name "*.pub" 2>/dev/null | wc -l)
                echo -e "  ${GREEN}✓${NC} SSH keys: $key_count key(s) found"
            else
                echo -e "  ${RED}✗${NC} SSH keys: Directory not found"
            fi
        fi
    done < <(getent passwd | grep "^deploy-")
    
    if [ $user_count -eq 0 ]; then
        echo -e "${YELLOW}⚠${NC} No deployment users found"
        print_info "Create users with: hostkit users add <domain>"
    fi
    echo ""
    
    # Check websites
    echo -e "${WHITE}═══ Registered Websites ═══${NC}"
    if [ -d "$WEB_ROOT" ]; then
        local site_count=$(find "$WEB_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo -e "${GREEN}✓${NC} Websites registered: $site_count"
        
        # Check for websites without users
        for domain_dir in "$WEB_ROOT"/*; do
            if [ -d "$domain_dir" ] && [ -f "$domain_dir/config.json" ]; then
                local domain=$(basename "$domain_dir")
                local username=$(jq -r '.username // "none"' "$domain_dir/config.json" 2>/dev/null)
                
                if [ "$username" = "none" ] || [ "$username" = "null" ]; then
                    echo -e "  ${YELLOW}⚠${NC} $domain has no deployment user"
                    print_info "    Add user with: hostkit users add $domain"
                elif ! id "$username" &>/dev/null; then
                    echo -e "  ${RED}✗${NC} $domain user '$username' does not exist"
                fi
            fi
        done
    else
        echo -e "${RED}✗${NC} Website directory not found: $WEB_ROOT"
    fi
    echo ""
    
    # Summary
    echo -e "${WHITE}═══════════════════════════════════════${NC}"
    print_success "Diagnostics complete"
}

# System maintenance menu
system_menu() {
    local subcommand="${1:-help}"
    
    case "$subcommand" in
        update-wrapper)
            update_ssh_wrapper
            ;;
        update-configs)
            update_ssh_configs
            ;;
        diagnostics|check)
            system_diagnostics
            ;;
        help|--help|-h)
            echo "Usage: hostkit system <command>"
            echo ""
            echo "Available commands:"
            echo "  update-wrapper    Update SSH wrapper to latest version (fixes GitHub Actions SCP)"
            echo "  update-configs    Update SSH configs for all deployment users"
            echo "  diagnostics       Run system diagnostics and health check"
            echo "  help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  hostkit system update-wrapper   # Fix GitHub Actions SCP issues"
            echo "  hostkit system diagnostics      # Check system health"
            ;;
        *)
            print_error "Unknown system command: $subcommand"
            echo ""
            echo "Run 'hostkit system help' for available commands"
            exit 1
            ;;
    esac
}
