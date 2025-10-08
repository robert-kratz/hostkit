# Bugfix: SSL Certificate Detection & Nginx Reload

## Problem Description

Two issues were identified during domain registration:

1. **SSL Certificate not detected**: When Certbot creates a certificate with a suffix (e.g., `domain-0001`), HostKit doesn't find it
2. **Nginx not reloaded**: After creating a new site configuration, Nginx doesn't reload automatically

## Root Cause

### Issue 1: Certificate Detection

The `setup_nginx()` function only checks for exact domain name matches:

```bash
# OLD - Only checks exact match
if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
    cert_exists=true
fi
```

**Problem**: Certbot sometimes creates certificates with suffixes like `-0001` when:

-   A certificate with that name already exists (from previous attempts)
-   There are renewal issues
-   Manual certificate management was done

### Issue 2: Nginx Reload

The nginx reload was present but:

-   Silent failures weren't caught
-   No user feedback about reload status
-   Error messages weren't displayed properly

## Solution

### 1. Improved Certificate Detection

**New code** searches for certificates with any suffix:

```bash
# Find certificate directory (may have suffix like -0001)
local cert_dir=""
local cert_exists=false

if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
    cert_dir="$domain"
    cert_exists=true
else
    # Check for directories with suffixes (e.g., domain-0001)
    for dir in /etc/letsencrypt/live/${domain}* /etc/letsencrypt/live/${domain}-*; do
        if [ -f "$dir/fullchain.pem" ]; then
            cert_dir=$(basename "$dir")
            cert_exists=true
            break
        fi
    done
fi

if [ "$cert_exists" = true ]; then
    print_info "SSL certificate found at: /etc/letsencrypt/live/$cert_dir"
fi
```

Then use `$cert_dir` in Nginx config:

```bash
ssl_certificate /etc/letsencrypt/live/$cert_dir/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$cert_dir/privkey.pem;
```

### 2. Better Nginx Reload with Error Handling

```bash
# Test Nginx configuration
print_step "Testing Nginx configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    print_step "Reloading Nginx..."
    if systemctl reload nginx 2>&1; then
        print_success "Nginx configuration created and activated"
        if [ ${#redirect_domains[@]} -gt 0 ]; then
            print_info "Redirect domains configured: ${redirect_domains[*]} -> $domain"
        fi
    else
        print_error "Failed to reload Nginx"
        print_warning "Try manually: sudo systemctl reload nginx"
    fi
else
    print_error "Nginx configuration test failed:"
    nginx -t 2>&1
    print_warning "Configuration created but not activated"
    print_info "Fix the errors and run: sudo nginx -t && sudo systemctl reload nginx"
fi
```

### 3. HTTP/2 Syntax Update

Updated deprecated `listen 443 ssl http2` to modern syntax:

**Before:**

```nginx
listen 443 ssl http2;
listen [::]:443 ssl http2;
```

**After:**

```nginx
listen 443 ssl;
listen [::]:443 ssl;
http2 on;
```

## Files Modified

-   `modules/register.sh` - Lines 880-1056:
    -   Improved certificate detection with suffix support
    -   Better nginx reload error handling
    -   Updated HTTP/2 syntax
    -   Added user feedback for all operations

## Testing

### Test Certificate Detection

```bash
# Create a test certificate with suffix
sudo certbot certonly --nginx -d test.example.com
# Creates: /etc/letsencrypt/live/test.example.com-0001/

# Register domain
sudo hostkit register

# Should now detect and use the -0001 certificate
```

### Test Nginx Reload

```bash
# During registration, watch for:
✓ Testing Nginx configuration...
✓ Reloading Nginx...
✓ Nginx configuration created and activated
```

### Verify SSL Works

```bash
# After registration
curl -I https://your-domain.com
# Should return 200 OK with SSL
```

## For Existing Installations

If you already have a domain registered with certificate detection issues:

### Option 1: Re-register (Recommended)

```bash
# Remove and re-register
sudo hostkit remove your-domain.com
sudo hostkit register
```

### Option 2: Manual Nginx Config Update

```bash
# Find actual certificate directory
ls -la /etc/letsencrypt/live/ | grep your-domain

# Update nginx config
sudo nano /etc/nginx/sites-available/your-domain.com

# Change certificate paths from:
ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
# To (if certificate is in -0001 directory):
ssl_certificate /etc/letsencrypt/live/your-domain.com-0001/fullchain.pem;

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

## Version Info

-   **Fixed in**: HostKit v1.3.4 (current)
-   **Affects**: All versions prior to v1.3.4
-   **Breaking Changes**: None - fully backward compatible

## Related Issues

-   Nginx deprecated `listen ... http2` warnings
-   SSL certificate with suffixes not detected
-   Nginx not reloading after configuration changes
