# HostKit v1.2.0 - Security Enhancement Summary

> **Copyright (c) 2025 Robert Julian Kratz**  
> **Repository:** https://github.com/robert-kratz/hostkit  
> **License:** MIT

## Overview

This update significantly enhances the security and usability of HostKit's SSH key management system, providing hardened RSA key generation, comprehensive user management, and easy key copying functionality.

## Major Enhancements

### 1. Hardened SSH Key Generation

-   **Dual Key Support**: Now generates both RSA 4096-bit and Ed25519 keys for maximum compatibility
-   **Enhanced Security**: RSA keys use 4096-bit encryption (up from default 2048-bit)
-   **GitHub Actions Compatible**: RSA keys ensure compatibility with older CI/CD systems
-   **Modern Security**: Ed25519 keys provide state-of-the-art cryptographic security

### 2. SSH Security Hardening

-   **Command Restriction**: SSH wrapper script (`/opt/hostkit/ssh-wrapper.sh`) limits users to deployment commands only
-   **Per-User SSH Config**: Individual SSH hardening rules in `/etc/ssh/sshd_config.d/`
-   **Password Lock**: All deployment users have password authentication disabled
-   **Connection Logging**: All SSH attempts logged to `/var/log/hostkit-ssh.log`

### 3. New User Management Commands

#### `hostkit list-users`

-   Lists all deployment users with their websites
-   Shows SSH key status (✓ Both keys, ✓ RSA only, ✓ Ed25519 only, ⚠ Partial, ✗ No keys)
-   Displays container status and website information
-   Color-coded status indicators

#### `hostkit show-keys <domain>`

-   Displays SSH keys with copy-paste ready commands
-   Shows both private and public keys
-   Provides `cat` commands to save keys locally
-   Includes usage instructions for GitHub Actions and manual connections

#### `hostkit regenerate-keys <domain>`

-   Safely regenerates SSH keys with backup
-   Creates new RSA 4096-bit and Ed25519 key pairs
-   Updates authorized_keys automatically
-   Displays new keys for copying

#### `hostkit user-info <username>`

-   Comprehensive user information display
-   SSH key analysis and file listing
-   Security status and permissions audit
-   Account status and configuration details

### 4. Enhanced Key Display

-   **Copy-Paste Ready**: All keys displayed with ready-to-use `cat` commands
-   **Local Setup Commands**: Complete commands to save keys locally with proper permissions
-   **Dual Format Support**: Both key types displayed for user choice
-   **Usage Examples**: GitHub Actions, manual SSH, and SCP examples provided

### 5. Security Improvements

-   **SSH Wrapper**: Restricts commands to deployment operations only
-   **Enhanced Permissions**: Stricter file and directory permissions
-   **Sudo Restrictions**: Limited sudo access to specific deployment commands
-   **Account Hardening**: Password-locked accounts with key-only authentication

## Command Reference

### New Commands

```bash
# List all users with SSH key status
hostkit list-users

# Show SSH keys for copying
hostkit show-keys example.com

# Regenerate SSH keys
hostkit regenerate-keys example.com

# Show detailed user information
hostkit user-info deploy-example-com
```

### Enhanced Registration

The `hostkit register` command now:

-   Generates both RSA 4096-bit and Ed25519 keys
-   Applies SSH hardening configuration
-   Creates command-restricted SSH wrapper
-   Displays keys with copy-paste commands
-   Provides comprehensive usage instructions

## Security Benefits

1. **Defense in Depth**: Multiple layers of security controls
2. **Principle of Least Privilege**: Users limited to essential commands only
3. **Key Rotation**: Easy regeneration of compromised keys
4. **Audit Trail**: Complete logging of SSH activities
5. **Compatibility**: Support for both modern and legacy systems

## Compatibility

-   **GitHub Actions**: Full support with RSA 4096-bit keys
-   **Modern Systems**: Ed25519 support for latest SSH implementations
-   **Legacy Systems**: RSA compatibility for older infrastructure
-   **CI/CD Systems**: Works with all major deployment platforms

## Migration from v1.1.0

Existing installations will continue to work with their current keys. To benefit from the enhanced security:

1. Update HostKit: `hostkit update`
2. Regenerate keys for enhanced security: `hostkit regenerate-keys <domain>`
3. Update GitHub Actions secrets with the new RSA key
4. Enjoy enhanced security and new management features

## Files Modified

-   `hostkit` - Added new command routing
-   `modules/register.sh` - Enhanced SSH key generation and security
-   `modules/users.sh` - New user management module
-   `install.sh` - Updated module installation
-   `README.md` - Updated documentation
-   `VERSION` - Updated to 1.2.0

This update provides a significant security enhancement while maintaining backward compatibility and ease of use.
