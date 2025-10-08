# Quick Fix: GitHub Actions SCP Authentication Error

## Problem

```
ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain
```

## Root Cause

The SSH wrapper (`/opt/hostkit/ssh-wrapper.sh`) was created during initial user setup and **doesn't get updated automatically** when you pull new HostKit code. The old wrapper blocks modern SCP commands from GitHub Actions.

## ✅ Solution (Choose One)

### Option 1: Automatic Fix (Recommended)

**After pulling the latest HostKit code**, run this on your server:

```bash
# As root or with sudo
sudo hostkit system update-wrapper
```

This will:
- ✅ Update SSH wrapper to support GitHub Actions SCP
- ✅ Enable modern SCP/SFTP protocols
- ✅ Reload SSH daemon automatically
- ✅ Keep all existing users and configurations

### Option 2: Manual Fix

If the automatic command doesn't work yet (if you haven't installed the new version):

```bash
# 1. Edit the SSH wrapper
sudo nano /opt/hostkit/ssh-wrapper.sh

# 2. Replace the entire content with the new version (see below)

# 3. Make it executable
sudo chmod +x /opt/hostkit/ssh-wrapper.sh

# 4. Reload SSH
sudo systemctl reload sshd
```

**New SSH Wrapper Content:**

```bash
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
```

## Verification

### 1. Check if wrapper is updated:

```bash
sudo grep -q "scp.*-t.*deploy" /opt/hostkit/ssh-wrapper.sh && echo "✓ Updated" || echo "✗ Not updated"
```

### 2. Test SSH connection locally:

```bash
ssh -i ~/.ssh/deploy-key deploy-user@your-vps "echo test"
```

Expected output: `ERROR: Command not allowed: echo test` (this is correct - shell commands are blocked)

### 3. Test SCP upload:

```bash
echo "test" > test.tar
scp -i ~/.ssh/deploy-key test.tar deploy-user@your-vps:/opt/domains/example.com/deploy/
rm test.tar
```

Should succeed without errors.

### 4. Check logs:

```bash
sudo tail -f /var/log/hostkit-ssh.log
```

You should see logged SCP commands.

### 5. Run diagnostics:

```bash
sudo hostkit system diagnostics
```

This will show:
- ✅ SSH wrapper status
- ✅ GitHub Actions SCP support
- ✅ User configurations
- ✅ SSL certificates
- ⚠️ Any issues found

## Complete Update Steps

If you just pulled the latest code:

```bash
# 1. Navigate to HostKit directory
cd /opt/hostkit

# 2. Pull latest changes
sudo git pull

# 3. Update SSH wrapper (NEW!)
sudo hostkit system update-wrapper

# 4. Optional: Update all SSH configs
sudo hostkit system update-configs

# 5. Verify everything is working
sudo hostkit system diagnostics

# 6. Test with GitHub Actions
```

## Troubleshooting

### "hostkit: command not found"

The new `system` command isn't installed yet:

```bash
cd /opt/hostkit
sudo git pull
sudo bash install.sh  # Reinstall to update the binary
```

### "system: command not found" 

You're running an old HostKit version:

```bash
sudo hostkit version  # Check version
# If < v1.4.0, do manual fix (Option 2 above)
```

### Still getting authentication errors

1. **Verify SSH key is correct:**
   ```bash
   # On server, get the public key
   sudo cat /home/deploy-xxx/.ssh/deploy-xxx-rsa.pub
   
   # Compare with authorized_keys
   sudo cat /home/deploy-xxx/.ssh/authorized_keys
   ```

2. **Check SSH config:**
   ```bash
   sudo cat /etc/ssh/sshd_config.d/hostkit-deploy-*.conf
   ```

3. **Test with verbose logging:**
   ```bash
   ssh -vvv -i ~/.ssh/deploy-key deploy-user@your-vps
   ```

4. **Check server SSH logs:**
   ```bash
   sudo journalctl -u sshd -f
   ```

### SCP works but deploy fails

This is a different issue - check deployment logs:

```bash
sudo hostkit logs example.com
sudo docker logs example-com
```

## Prevention

After every HostKit update:

```bash
sudo hostkit system diagnostics
```

This will show you if anything needs updating.

## When to Use Each Command

| Command | When to Use |
|---------|-------------|
| `system update-wrapper` | GitHub Actions SCP fails |
| `system update-configs` | Migrating to new version |
| `system diagnostics` | After updates or when troubleshooting |

## Related Documentation

- `docs/GITHUB_ACTIONS_DEPLOYMENT.md` - Complete CI/CD setup guide
- `docs/BUGFIX_GITHUB_ACTIONS_SCP.md` - Technical details of the fix
- `docs/SSH_KEY_MANAGEMENT.md` - SSH key workflows

## Support

If the issue persists:

1. Run: `sudo hostkit system diagnostics > diagnostics.txt`
2. Check: `sudo tail -100 /var/log/hostkit-ssh.log > ssh.log`
3. Share both files in a GitHub issue

GitHub Issues: https://github.com/robert-kratz/hostkit/issues
