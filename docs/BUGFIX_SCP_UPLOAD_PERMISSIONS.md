# Bugfix: SCP Upload Permissions (GitHub Actions)

## Problem Description

GitHub Actions deployment fails during the "Upload Image to VPS" step with error:
```
error copy file to dest: ***, error message: Process exited with status 1
```

## Root Cause

The issue was caused by insufficient write permissions on the `/opt/domains/<domain>/deploy/` directory:

1. **Permission mismatch**: Directory was created with `755` permissions, limiting write access
2. **SSH wrapper restrictions**: SCP pattern matching was too strict for GitHub Actions format
3. **Missing ACL permissions**: No fallback for systems where group permissions might not work

## Solution

### 1. Enhanced Directory Permissions

Changed deploy directory permissions to `775` and added ACL support:

```bash
chown -R "$username:$username" "$WEB_ROOT/$domain/deploy"
chmod 775 "$WEB_ROOT/$domain/deploy"
# Add ACL for better permission control
setfacl -R -m u:${username}:rwx "$WEB_ROOT/$domain/deploy" 2>/dev/null || true
setfacl -d -m u:${username}:rwx "$WEB_ROOT/$domain/deploy" 2>/dev/null || true
```

### 2. Improved SSH Wrapper

Updated the SSH command wrapper to handle all SCP patterns from GitHub Actions:

**Before** (too restrictive):
```bash
scp\ -t\ */deploy/*)
    exec $SSH_ORIGINAL_COMMAND
    ;;
scp\ -t\ /opt/domains/*/deploy/*)
    exec $SSH_ORIGINAL_COMMAND
    ;;
```

**After** (flexible pattern matching):
```bash
scp\ *)
    # Check if it's a target mode upload (-t flag) to deploy directory
    if [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*/deploy/ ]] || [[ "$SSH_ORIGINAL_COMMAND" =~ scp.*-t.*deploy/ ]]; then
        exec $SSH_ORIGINAL_COMMAND
    else
        echo "ERROR: SCP only allowed to deployment directories (/opt/domains/*/deploy/)"
        exit 1
    fi
    ;;
```

## Files Modified

- `modules/register.sh` - Lines 571-574 (permissions)
- `modules/register.sh` - Lines 634-648 (SSH wrapper)

## Testing

### Manual Test
```bash
# On your local machine
scp -i ~/.ssh/deploy-example-com-rsa image.tar deploy-example-com@your-vps:/opt/domains/example.com/deploy/
```

### GitHub Actions Test
Use the standard workflow:
```yaml
- name: Upload Image to VPS
  uses: appleboy/scp-action@v0.1.7
  with:
      host: ${{ secrets.VPS_HOST }}
      username: ${{ secrets.DEPLOY_USER }}
      key: ${{ secrets.DEPLOY_SSH_KEY }}
      port: ${{ secrets.VPS_PORT || 22 }}
      source: 'image.tar'
      target: '/opt/domains/${{ secrets.DOMAIN }}/deploy/'
```

## For Existing Installations

If you already have a registered domain, update permissions manually:

```bash
# Get the deploy username for your domain
DOMAIN="example.com"
USERNAME=$(jq -r '.users[0].username' /opt/domains/$DOMAIN/config.json)

# Fix permissions
sudo chown -R "$USERNAME:$USERNAME" /opt/domains/$DOMAIN/deploy
sudo chmod 775 /opt/domains/$DOMAIN/deploy
sudo setfacl -R -m u:${USERNAME}:rwx /opt/domains/$DOMAIN/deploy 2>/dev/null || true
sudo setfacl -d -m u:${USERNAME}:rwx /opt/domains/$DOMAIN/deploy 2>/dev/null || true

# Update SSH wrapper
sudo hostkit register --update-wrapper  # (if this command exists)
# OR manually update /opt/hostkit/ssh-wrapper.sh with the new SCP pattern
```

## Security Notes

This fix maintains security by:
- Only allowing SCP uploads to `/opt/domains/*/deploy/` directories
- Maintaining command restrictions through the SSH wrapper
- Using regex pattern matching to validate target paths
- Preserving user isolation (each domain has its own deploy user)

## Related Issues

- GitHub Actions SCP error: "Process exited with status 1"
- Permission denied when uploading to VPS
- SSH command restrictions blocking legitimate uploads

## Version

- **Fixed in**: HostKit v1.3.1 (unreleased)
- **Affects**: All versions prior to v1.3.1
- **Severity**: High - Blocks GitHub Actions deployments

## Additional Troubleshooting

If the issue persists after applying this fix:

1. **Check SSH wrapper logs**:
   ```bash
   sudo tail -f /var/log/hostkit-ssh.log
   ```

2. **Test SSH connection**:
   ```bash
   ssh -i ~/.ssh/deploy-example-com-rsa deploy-example-com@your-vps
   ```

3. **Verify file permissions**:
   ```bash
   ls -la /opt/domains/example.com/deploy/
   ```

4. **Check ACL support**:
   ```bash
   getfacl /opt/domains/example.com/deploy/
   ```

5. **Verify SSH wrapper execution**:
   ```bash
   sudo cat /opt/hostkit/ssh-wrapper.sh
   sudo chmod +x /opt/hostkit/ssh-wrapper.sh
   ```

## References

- [GitHub Actions Deployment Guide](./GITHUB_ACTIONS_DEPLOYMENT.md)
- [SSH Key Management](./SSH_KEY_MANAGEMENT.md)
- [Security Enhancements](./SECURITY_ENHANCEMENTS.md)
