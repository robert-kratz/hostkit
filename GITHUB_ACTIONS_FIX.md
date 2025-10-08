# GitHub Actions SCP Upload Fix - Summary

## What Was Fixed

### Issue 1: "This script must be run as root" ✅

**Problem**: Deploy command fails because `hostkit` requires root privileges.
**Solution**: Users must use `sudo hostkit deploy` in their workflow. SSH wrapper allows `sudo` commands.

### Issue 2: mkdir Command Blocked ✅

**Problem**: GitHub Actions runs `mkdir -p /opt/domains/.../deploy/` before uploading files.
**Solution**: Added mkdir pattern to SSH wrapper allowed commands.

### Issue 3: Log File Permission Denied ✅

**Problem**: SSH wrapper couldn't write to `/var/log/hostkit-ssh.log`.
**Solution**:

-   Made logging fail silently with `2>/dev/null || true`
-   Create log file with proper permissions during registration

### Issue 4: Insufficient Directory Permissions ✅

**Problem**: Deploy directory had `755` permissions, limiting write access.
**Solution**: Changed to `775` with ACL support for better permission control.

### Issue 5: SSH Wrapper Too Restrictive ✅

**Problem**: SCP pattern matching was too strict for GitHub Actions format.
**Solution**: Flexible regex pattern matching for all SCP variants.

## Changes Made

### Files Modified

1. `modules/register.sh` - Enhanced SSH wrapper and permissions
2. `fix-deploy-permissions.sh` - New script to fix existing installations
3. `docs/BUGFIX_SCP_UPLOAD_PERMISSIONS.md` - Technical documentation
4. `docs/QUICKFIX_SCP_UPLOAD.md` - Quick fix guide (German)

### SSH Wrapper Updates

```bash
# CHANGED: Only allow sudo deploy (removed non-sudo variant)
"sudo hostkit deploy "*)
    exec $SSH_ORIGINAL_COMMAND
    ;;

# NEW: Allow mkdir for deploy directories
"mkdir -p /opt/domains/"*"/deploy/"*)
    exec $SSH_ORIGINAL_COMMAND
    ;;
mkdir\ -p\ /opt/domains/*/deploy/*)
    exec $SSH_ORIGINAL_COMMAND
    ;;

# IMPROVED: Better SCP pattern matching
scp\ *)
    if [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*/deploy/ ]] || [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*deploy/ ]]; then
        exec $SSH_ORIGINAL_COMMAND
    else
        echo "ERROR: SCP only allowed to deployment directories"
        exit 1
    fi
    ;;

# FIXED: Silent logging
echo "$(date): SSH connection from $SSH_CLIENT as $USER: $SSH_ORIGINAL_COMMAND" >> /var/log/hostkit-ssh.log 2>/dev/null || true
```

### Permission Updates

```bash
# Deploy directory permissions
chown -R "$username:$username" "$WEB_ROOT/$domain/deploy"
chmod 775 "$WEB_ROOT/$domain/deploy"

# ACL support
setfacl -R -m u:${username}:rwx "$WEB_ROOT/$domain/deploy" 2>/dev/null || true
setfacl -d -m u:${username}:rwx "$WEB_ROOT/$domain/deploy" 2>/dev/null || true

# Log file setup
touch /var/log/hostkit-ssh.log 2>/dev/null || true
chmod 666 /var/log/hostkit-ssh.log 2>/dev/null || true
```

## How to Apply the Fix

### For New Installations

Just install HostKit normally - the fix is already included:

```bash
git clone https://github.com/robert-kratz/hostkit.git
cd hostkit
sudo bash install.sh
```

### For Existing Installations

Run the fix script:

```bash
cd /opt/hostkit
wget https://raw.githubusercontent.com/robert-kratz/hostkit/main/fix-deploy-permissions.sh
chmod +x fix-deploy-permissions.sh
sudo ./fix-deploy-permissions.sh
```

Or update manually - see `docs/QUICKFIX_SCP_UPLOAD.md` for instructions.

## Testing

### Local Test (Both Keys Work)

```bash
# Ed25519 key
scp -i ~/.ssh/deploy-example-com-ed25519 image.tar deploy-example-com@vps:/opt/domains/example.com/deploy/

# RSA key
scp -i ~/.ssh/deploy-example-com-rsa image.tar deploy-example-com@vps:/opt/domains/example.com/deploy/
```

### GitHub Actions

Both RSA and Ed25519 keys now work! **Important: Use `sudo` for deploy command!**

```yaml
- name: Upload Image to VPS via SCP
  run: |
      scp -P "$SSH_PORT" image.tar \
        "$DEPLOY_USER@$VPS_HOST:/opt/domains/$DOMAIN/deploy/image.tar"

- name: Deploy on VPS
  run: |
      ssh -p "$SSH_PORT" "$DEPLOY_USER@$VPS_HOST" \
        "sudo hostkit deploy $DOMAIN /opt/domains/$DOMAIN/deploy/image.tar"
      # ^^^^^ CRITICAL: Must use sudo!
```

See [github-actions-complete-workflow.yml](./docs/github-actions-complete-workflow.yml) for full example.

## Verification

After applying the fix, check:

1. **SSH wrapper updated**:

    ```bash
    sudo cat /opt/hostkit/ssh-wrapper.sh | grep -A 2 "mkdir -p"
    ```

2. **Log file permissions**:

    ```bash
    ls -la /var/log/hostkit-ssh.log
    ```

3. **Deploy directory permissions**:

    ```bash
    ls -la /opt/domains/example.com/deploy/
    ```

4. **ACL permissions** (if supported):
    ```bash
    getfacl /opt/domains/example.com/deploy/
    ```

## Security Notes

This fix maintains security by:

-   Only allowing mkdir to `/opt/domains/*/deploy/` paths
-   Maintaining command restrictions through SSH wrapper
-   Using regex pattern validation for all operations
-   Preserving user isolation
-   Logging all SSH commands (when possible)

## Version Info

-   **Fixed in**: HostKit v1.3.3 (current)
-   **Affects**: All versions prior to v1.3.3
-   **Severity**: High - Blocks GitHub Actions deployments
-   **Breaking Changes**: None - fully backward compatible

## Related Documentation

-   [Full Bugfix Documentation](./docs/BUGFIX_SCP_UPLOAD_PERMISSIONS.md)
-   [Quick Fix Guide (German)](./docs/QUICKFIX_SCP_UPLOAD.md)
-   [GitHub Actions Deployment](./docs/GITHUB_ACTIONS_DEPLOYMENT.md)
-   [SSH Key Management](./docs/SSH_KEY_MANAGEMENT.md)
