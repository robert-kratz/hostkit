# Registration Issues - Diagnosis and Fix

## Issues Reported

1. **bc command not found** error during memory allocation
2. **Additional domain input** not properly exiting when pressing Enter
3. **Memory selection display** showing unreadable garbled text
4. **Username prompt** getting concatenated with other text causing useradd errors
5. **jq parse error** with control characters in JSON

## Root Cause Analysis

### Primary Issue: Outdated Scripts on Server

The main problem is that your server is running **cached/outdated versions** of the HostKit scripts. The symptoms clearly show:

-   Missing "Step 2: Port Assignment" and "Step 3: User Setup" sections
-   Flow jumping directly from domain configuration to memory allocation
-   Old error messages referencing `bc` command (which has been removed from the codebase)
-   Different prompt text than what's in the current code

### Why This Happens

When you run `install.sh`, it copies scripts to `/opt/hostkit/`. If you later update the code in your development folder (e.g., `~/hostkit`), the changes **don't automatically propagate** to `/opt/hostkit/` on the server.

## Solution

### Option 1: Update HostKit on Server (Recommended)

Pull the latest changes and reinstall:

```bash
cd ~/hostkit  # or wherever you cloned the repo
git pull origin main
sudo ./install.sh
```

The installer will update all scripts in `/opt/hostkit/` with the latest versions.

### Option 2: Manual Script Update

If you only want to update specific modules without full reinstallation:

```bash
cd ~/hostkit
sudo cp modules/*.sh /opt/hostkit/modules/
sudo cp hostkit /opt/hostkit/hostkit
sudo chmod +x /opt/hostkit/hostkit
```

### Option 3: Force Reinstallation

For a clean start:

```bash
cd ~/hostkit
sudo hostkit uninstall  # Remove existing installation
git pull origin main
sudo ./install.sh
```

## Code Fixes Applied (v1.2.1)

Even though the main issue is cached scripts, the following improvements have been made:

### 1. Memory Module Color Definitions ✓

**File**: `modules/memory.sh`

Added color variable definitions at the top of the module to ensure proper display:

```bash
# Color definitions (in case module is sourced independently)
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    NC='\033[0m'
fi
```

**Why**: When modules are sourced, they may not have access to color variables defined in the main script.

### 2. BC Command Removal ✓

**Status**: Already removed in current version

The `bc` (basic calculator) dependency has been completely removed from the codebase. All arithmetic operations now use bash's built-in arithmetic `$(( ))`.

### 3. Input Validation Improvements ✓

**Status**: Already implemented in current version

-   Domain input with proper validation and retry logic
-   Port input with conflict detection
-   Username input with format validation
-   All inputs use proper stderr redirection (>&2) for prompts

## Verification Steps

After updating, verify the installation:

```bash
# Check version
sudo hostkit --version

# Should show v1.2.1 or higher

# Verify module files are updated
ls -la /opt/hostkit/modules/

# Check memory module has color definitions
head -20 /opt/hostkit/modules/memory.sh

# Test registration (you can cancel at any step)
sudo hostkit register
```

## Expected Registration Flow (v1.2.1)

When running `sudo hostkit register`, you should see:

```
╔═══════════════════════════════════════╗
║        HOSTKIT v1.2.1                 ║
║   VPS Website Management Tool         ║
╚═══════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: Domain Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Main domain: example.com

Do you want to add redirect domains? [Y/n]: Y
Additional domain (press Enter to finish): www.example.com
✓ Added: www.example.com
Additional domain (press Enter to finish): [PRESS ENTER]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2: Port Assignment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Internal container port (Enter for 3000): 3000

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 3: User Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deployment username (Enter for deploy-example-com):

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 4: Memory Allocation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Memory Configuration
Total System Memory: 2048MB
Reserved for OS: 512MB
Available for Containers: 1536MB

Suggested allocations:
  Small (512MB)  - Static websites, APIs
  Medium (1024MB) - Node.js, Python apps
  Large (2048MB)  - Java, databases

Memory limit in MB (e.g., 512): 512
✓ Memory Limit: 512MB
✓ Memory Reservation: 256MB
```

## Additional Notes

### About the "Additional Domain" Input

The input loop works as follows:

-   Type a domain and press Enter → adds the domain
-   Press Enter on empty input → exits the loop and continues to next step
-   Type invalid domain → shows error and prompts again

### About the Username Prompt

The username input function properly separates:

-   **stderr**: Prompts and error messages (appear on screen)
-   **stdout**: Only the final username value (captured by command substitution)

This prevents prompt text from being captured in variables.

### About Memory Display

The memory module now includes proper color definitions, so you should see:

-   Properly formatted headers
-   Colored text (cyan, white, green)
-   Clear progress bars (if shown)
-   No garbled characters or control sequences

## Troubleshooting

If issues persist after updating:

1. **Check if scripts are actually updated**:

    ```bash
    diff ~/hostkit/modules/memory.sh /opt/hostkit/modules/memory.sh
    ```

    Should show no differences.

2. **Verify no stale processes**:

    ```bash
    ps aux | grep hostkit
    ```

    Kill any stuck processes if found.

3. **Check system locale**:

    ```bash
    locale
    ```

    Error messages in German (like "Ungültiges Home-Verzeichnis") indicate German locale. This is fine, but ensure UTF-8 encoding: `LANG=de_DE.UTF-8`

4. **Test individual components**:
    ```bash
    # Test memory module
    source /opt/hostkit/modules/memory.sh
    get_total_memory
    ```

## Version History

-   **v1.2.0**: Previous version with potential caching issues
-   **v1.2.1**: Fixed memory module color definitions, improved documentation

## Contact

For persistent issues, check:

-   GitHub Issues: https://github.com/robert-kratz/hostkit/issues
-   Documentation: `/opt/hostkit/docs/`
