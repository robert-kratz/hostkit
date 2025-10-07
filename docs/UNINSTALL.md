# HostKit Uninstallation Guide

## Overview

HostKit provides a comprehensive uninstallation system that allows you to selectively remove components based on your needs. You can choose to remove just the software package, specific components, or everything including data and configurations.

## Quick Start

```bash
hostkit uninstall
```

This will start the interactive uninstallation process with a menu of options.

## Uninstall Options

### Preset Options

#### 1. Minimal Uninstall

-   **What it removes**: Only the HostKit package and binaries
-   **What it keeps**: All websites, configurations, SSL certificates, Docker containers
-   **Use case**: Temporary removal or before manual reinstallation
-   **Command**: Choose `minimal` when prompted

#### 2. Standard Uninstall

-   **What it removes**: Package + Docker containers + Docker images
-   **What it keeps**: Website configurations, SSL certificates, deployment users
-   **Use case**: Clean up running services but keep configuration for later
-   **Command**: Choose `standard` when prompted

#### 3. Complete Uninstall

-   **What it removes**: Everything except SSL certificates
-   **What it keeps**: Only SSL certificates (to avoid Let's Encrypt rate limits)
-   **Use case**: Full cleanup while preserving expensive SSL certificates
-   **Command**: Choose `complete` when prompted

#### 4. Nuclear Uninstall

-   **What it removes**: Absolutely everything including SSL certificates
-   **What it keeps**: Nothing related to HostKit
-   **Use case**: Complete system cleanup, server decommissioning
-   **Command**: Choose `nuclear` when prompted
-   **⚠️ Warning**: SSL certificates will need time to regenerate due to rate limits

#### 5. Custom Uninstall

-   **What it removes**: Components you select individually
-   **Use case**: Precise control over what gets removed
-   **Command**: Choose `custom` when prompted

### Component Details

| Component      | Description                               | Impact of Removal                       |
| -------------- | ----------------------------------------- | --------------------------------------- |
| **Package**    | HostKit binaries and installation         | `hostkit` command unavailable       |
| **Websites**   | All registered website data and configs   | Complete loss of website configurations |
| **Containers** | All Docker containers managed by HostKit  | Websites stop running                   |
| **Images**     | All Docker images created by HostKit      | Need to rebuild/redeploy applications   |
| **Users**      | All deployment SSH users                  | GitHub Actions deployments will fail    |
| **Nginx**      | Nginx configurations created by HostKit   | Websites become unreachable             |
| **SSL**        | SSL certificates managed by Let's Encrypt | HTTPS will stop working                 |
| **Cron**       | Automated tasks (SSL renewal, etc.)       | SSL certificates won't auto-renew       |
| **Configs**    | HostKit configuration files               | Settings and preferences lost           |

## Safety Features

### Multi-Level Confirmation

1. **Component Selection**: Choose what to remove
2. **Summary Review**: See exactly what will be deleted
3. **Initial Confirmation**: Confirm the uninstall plan
4. **Final Confirmation**: Type "CONFIRM UNINSTALL" for destructive operations

### Attempt Limits

-   Domain confirmation has 3 attempts before cancellation
-   Invalid input allows retry without cancelling the process
-   Each confirmation step can be cancelled safely

### Preservation Options

The uninstaller is designed to preserve valuable components:

-   **SSL certificates**: Kept by default in most presets (due to rate limits)
-   **Configuration files**: Can be preserved for future reinstallation
-   **Website data**: Optionally preserved for backup purposes

## Usage Examples

### Example 1: Temporary Package Removal

```bash
hostkit uninstall
# Choose: minimal
# Confirm: Y
# Result: HostKit removed, all websites keep running
```

### Example 2: Server Cleanup (Keep SSL)

```bash
hostkit uninstall
# Choose: complete
# Confirm: Y
# Type: CONFIRM UNINSTALL
# Result: Everything removed except SSL certificates
```

### Example 3: Custom Selective Removal

```bash
hostkit uninstall
# Choose: custom
# Select: containers (Y), images (Y), package (N)
# Result: Stops all websites but keeps HostKit installed
```

### Example 4: Complete System Reset

```bash
hostkit uninstall
# Choose: nuclear
# Confirm: Y
# Type: CONFIRM UNINSTALL
# Result: Complete removal of everything
```

## What Happens During Uninstall

### Order of Operations

1. **Input validation and confirmation**
2. **Container shutdown** (graceful stop)
3. **Docker image removal**
4. **Website data cleanup**
5. **User account removal**
6. **Nginx configuration cleanup**
7. **SSL certificate removal** (if selected)
8. **Cron job cleanup**
9. **Configuration file removal**
10. **Package removal** (last step)

### Safety Checks

-   ✅ Nginx configuration validation before reload
-   ✅ SSH daemon reload after user removal
-   ✅ Graceful container shutdown before removal
-   ✅ File existence verification before deletion
-   ✅ Permission checks before system changes

## Recovery Options

### After Minimal Uninstall

```bash
# Reinstall HostKit
git clone https://github.com/robert-kratz/hostkit.git
cd hostkit
sudo bash install.sh
# All websites automatically detected and restored
```

### After Standard Uninstall

```bash
# Reinstall and redeploy
sudo bash install.sh
hostkit deploy example.com /path/to/backup.tar
```

### After Complete/Nuclear Uninstall

```bash
# Full setup required
sudo bash install.sh
hostkit register  # Reconfigure each website
# Redeploy all applications
# Regenerate SSL certificates
```

## Troubleshooting

### Common Issues

**"Permission denied" errors**

-   Run uninstall as root: `sudo hostkit uninstall`

**"Component not found" warnings**

-   Normal if components were manually removed
-   Uninstaller will skip missing components

**Nginx fails to reload**

-   Manual cleanup may be needed: `nginx -t && systemctl reload nginx`

**SSL certificates still present**

-   Manual removal: `certbot delete --cert-name domain.com`

### Manual Cleanup

If the uninstaller fails, manual cleanup locations:

```bash
# Package files
/opt/hostkit/
/usr/local/bin/hostkit
/etc/bash_completion.d/hostkit

# Website data
/opt/domains/

# Nginx configs
/etc/nginx/sites-available/*.conf
/etc/nginx/sites-enabled/*.conf

# User accounts
grep "^deploy-" /etc/passwd

# Cron jobs
crontab -l | grep "hostkit\|certbot"
```

## Best Practices

### Before Uninstalling

1. **Backup important data**

    ```bash
    tar -czf hostkit-backup.tar.gz /opt/domains/
    ```

2. **Document your setup**

    ```bash
    hostkit list > website-list.txt
    hostkit list-users > users-list.txt
    ```

3. **Export configurations**
    ```bash
    cp -r /opt/domains/ ~/hostkit-configs-backup/
    ```

### During Uninstall

1. **Read all confirmations carefully**
2. **Choose the least destructive option that meets your needs**
3. **Keep SSL certificates unless absolutely necessary to remove**
4. **Note any error messages for troubleshooting**

### After Uninstall

1. **Verify services are stopped** (if intended)

    ```bash
    docker ps
    systemctl status nginx
    ```

2. **Check for remaining files** (if complete removal intended)

    ```bash
    find /opt -name "*hostkit*" -o -name "*hostkit*"
    ```

3. **Update DNS records** (if websites permanently removed)

## Support

For uninstallation issues:

1. **Check logs**: Most operations are logged to system journal
2. **Manual cleanup**: Use the manual cleanup locations above
3. **Report bugs**: https://github.com/robert-kratz/hostkit/issues
4. **Community support**: Include your uninstall logs and error messages

## Security Notes

-   Uninstaller requires root privileges for system changes
-   User confirmations are required for all destructive operations
-   SSL certificate removal is restricted to prevent accidental data loss
-   All operations are logged for audit purposes
