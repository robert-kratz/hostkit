# GitHub Actions SCP Support Fix

## Problem

GitHub Actions deployment with `appleboy/scp-action` was failing with:

```
ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain
```

## Root Cause

The SSH wrapper script (`/opt/hostkit/ssh-wrapper.sh`) was blocking SCP commands from GitHub Actions because:

1. The SCP command pattern didn't match the restrictive regex
2. The wrapper didn't handle modern SCP protocol formats
3. Missing support for various SCP flag combinations

## Changes Made

### 1. Enhanced SSH Wrapper (`modules/register.sh`)

**Added support for:**

-   Modern SCP target mode: `scp -t /opt/domains/*/deploy/*`
-   SCP with various flags: `scp * -t /opt/domains/*/deploy/*`
-   SFTP server direct execution
-   Better logging for troubleshooting
-   Explicit denial of interactive shells

**New allowed command patterns:**

```bash
scp -t */deploy/*                          # Basic target mode
scp -t /opt/domains/*/deploy/*             # Absolute path
scp * -t */deploy/*                        # With flags
/usr/lib/openssh/sftp-server*              # SFTP subsystem
```

### 2. Consistent File Naming

Updated configuration files to use consistent `hostkit-` prefix:

**Before:**

-   `/etc/ssh/sshd_config.d/<username>.conf`
-   `/etc/sudoers.d/<username>`

**After:**

-   `/etc/ssh/sshd_config.d/hostkit-<username>.conf`
-   `/etc/sudoers.d/hostkit-<username>`

### 3. Backward Compatibility

Updated modules to support both old and new naming conventions:

-   `modules/users.sh` - User info display
-   `modules/remove.sh` - Website removal
-   `modules/uninstall.sh` - Full uninstall

These modules now check for both file naming patterns.

### 4. Improved Sudoers Configuration

Added explicit hostkit binary paths to sudoers:

```bash
$username ALL=(root) NOPASSWD: /usr/bin/hostkit deploy $domain *
$username ALL=(root) NOPASSWD: /opt/hostkit/hostkit deploy $domain *
```

### 5. Documentation

Created comprehensive guide: `docs/GITHUB_ACTIONS_DEPLOYMENT.md`

**Covers:**

-   SSH key setup (RSA vs Ed25519)
-   GitHub Secrets configuration
-   Example workflow files
-   Environment variable handling (.env files)
-   Security best practices
-   Troubleshooting common issues
-   Advanced deployment patterns

## Testing

### Verify SSH Wrapper

```bash
# Check wrapper exists and is executable
ls -la /opt/hostkit/ssh-wrapper.sh

# Check SSH config
cat /etc/ssh/sshd_config.d/hostkit-deploy-*.conf

# Test SCP locally
scp -i ~/.ssh/deploy-key test.tar deploy-user@vps:/opt/domains/example.com/deploy/
```

### Monitor Logs

```bash
# Watch SSH wrapper activity
sudo tail -f /var/log/hostkit-ssh.log

# Check SSH authentication
sudo journalctl -u sshd -f
```

## Migration for Existing Installations

For existing HostKit installations, run these commands to update configurations:

```bash
# Update SSH wrapper
sudo cp /opt/hostkit/modules/register.sh /tmp/register.sh.new
sudo bash /tmp/register.sh.new  # Extract create_ssh_wrapper function

# Reload SSH daemon
sudo systemctl reload sshd

# Verify
sudo hostkit users list <domain>
```

## Security Considerations

### What's Allowed

✅ File uploads to `/opt/domains/*/deploy/` via SCP/SFTP  
✅ Running `hostkit deploy` commands via sudo  
✅ Rsync to deploy directories  
✅ Docker operations for deployment

### What's Blocked

❌ Interactive shell access  
❌ File uploads outside deploy directories  
❌ Arbitrary command execution  
❌ Password-based authentication  
❌ Port forwarding  
❌ X11 forwarding

### Enhanced Logging

All SSH connection attempts are logged to `/var/log/hostkit-ssh.log`:

```
2025-10-08 10:30:15: SSH connection from 192.168.1.100 as deploy-example-com: scp -t /opt/domains/example.com/deploy/
```

## GitHub Actions Integration

### Recommended Workflow

```yaml
- name: Upload Image to VPS
  uses: appleboy/scp-action@v0.1.7
  with:
      host: ${{ secrets.VPS_HOST }}
      username: ${{ secrets.DEPLOY_USER }}
      key: ${{ secrets.DEPLOY_SSH_KEY }} # Use RSA key
      port: ${{ secrets.VPS_PORT || 22 }}
      source: "image.tar"
      target: "/opt/domains/${{ secrets.DOMAIN }}/deploy/"
```

### Required Secrets

| Secret           | Description                      |
| ---------------- | -------------------------------- |
| `DEPLOY_SSH_KEY` | RSA private key (full content)   |
| `DEPLOY_USER`    | Username from `hostkit register` |
| `DOMAIN`         | Registered domain name           |
| `VPS_HOST`       | Server IP or hostname            |
| `VPS_PORT`       | SSH port (default: 22)           |

## Breaking Changes

None. All changes are backward compatible:

-   Old configuration files are still recognized
-   Existing SSH keys continue to work
-   No database schema changes
-   No API changes

## Future Improvements

1. **Automatic .env file mounting**: Deploy module should automatically use `.env` if present
2. **Key rotation command**: `hostkit ssh-keys rotate <domain>`
3. **Deployment hooks**: Pre/post-deployment scripts
4. **Blue-green deployments**: Zero-downtime deployments
5. **Health check integration**: Automatic rollback on failure

## Related Documentation

-   `docs/GITHUB_ACTIONS_DEPLOYMENT.md` - Complete deployment guide
-   `docs/SSH_KEY_MANAGEMENT.md` - SSH key workflows
-   `docs/SECURITY_ENHANCEMENTS.md` - Security features
-   `SECURITY_ENHANCEMENTS.md` - Original security docs

## Version

This fix is included in HostKit v1.x.x and later.

Check your version: `hostkit --version`
