# HostKit User Input Validation & Error Handling

## Overview

HostKit v1.2.0+ includes comprehensive input validation and improved error handling to provide a better user experience and prevent system errors.

## New Features

### 1. Tab Completion

Tab completion is now available for all commands and arguments:

```bash
# Tab complete commands
hostkit <TAB>

# Tab complete domain names
hostkit start <TAB>

# Tab complete tar files for deployment
hostkit deploy example.com <TAB>
```

### 2. Input Validation

All user inputs are now validated with helpful error messages:

#### Domain Validation

-   Must contain only letters, numbers, dots, and hyphens
-   Cannot start or end with dots or hyphens
-   Cannot have consecutive dots or hyphens
-   Maximum length: 253 characters

#### Port Validation

-   Must be numeric
-   Range: 1024-65535 (avoiding system ports)
-   Automatic conflict detection

#### Username Validation

-   Must start with lowercase letter
-   Only lowercase letters, numbers, hyphens, underscores
-   Maximum length: 32 characters
-   Automatic conflict detection

### 3. Retry Logic

Instead of exiting on invalid input, users can retry:

```bash
# Example: Invalid domain input
Main domain (e.g. example.com): invalid..domain
✗ Invalid domain format. Use format like: example.com
Domain must:
  - Start and end with alphanumeric characters
  - Contain only letters, numbers, dots, and hyphens
  - Not have consecutive dots or hyphens
  - Be less than 254 characters
Main domain (e.g. example.com): example.com
✓ Valid domain
```

### 4. Enhanced Help System

Comprehensive help with examples:

```bash
hostkit help
```

Shows detailed information about:

-   Command usage patterns
-   Real-world examples
-   Configuration notes
-   Support information

### 5. Confirmation Safety

Multi-step confirmation for destructive operations:

```bash
hostkit remove example.com
# Shows detailed removal plan
# Requires domain name confirmation with retry attempts

hostkit uninstall
# Interactive component selection
# Multiple confirmation steps for destructive operations
```

### 6. Smart Uninstallation

Selective component removal with preset options:

```bash
hostkit uninstall
# Preset options:
# - minimal: Remove only package (keep all data)
# - standard: Remove package + containers + images
# - complete: Remove everything except SSL certificates
# - nuclear: Remove absolutely everything
# - custom: Select individual components
```

## Implementation Details

### Safe Mode Handling

The system uses controlled error handling:

-   User input phases: `set +e` (continue on errors)
-   System operations: `set -e` (fail fast on errors)

### Validation Functions

```bash
validate_domain()    # Domain format validation
validate_port()      # Port range and format validation
validate_username()  # Username format validation
validate_tar_file()  # TAR file existence and format
```

### Safe Input Functions

```bash
read_domain_input()    # Domain input with validation and retry
read_port_input()      # Port input with conflict detection
read_username_input()  # Username input with validation
```

## Error Types

### Input Validation Errors

-   Continue execution with retry prompts
-   Helpful error messages with format requirements
-   Suggestions for valid alternatives

### System Errors

-   Fail fast to prevent data corruption
-   Clear error messages with resolution steps
-   Return codes for scripting integration

### Configuration Errors

-   Validate before applying changes
-   Rollback on failure
-   Preserve existing configurations

## Best Practices

### For Users

1. Use tab completion to avoid typos
2. Pay attention to validation messages
3. Use suggested values when available
4. Read confirmation prompts carefully

### For Developers

1. All user inputs must use validation functions
2. Use safe_mode_off/on around user input sections
3. Return instead of exit in module functions
4. Provide helpful error messages with examples

## Migration Notes

### Breaking Changes

-   Module functions now return instead of exit
-   Input validation may reject previously accepted values
-   Confirmation dialogs have changed

### Backward Compatibility

-   All existing commands work the same way
-   Configuration files remain compatible
-   API behavior is preserved

## Testing

Test input validation with:

```bash
# Invalid domains
hostkit register
# Try: invalid..domain, -example.com, example-.com

# Invalid ports
# Try: 80, 99999, abc, -1000

# Invalid usernames
# Try: 123user, User-Name, user@domain
```

## Support

For issues with input validation:

1. Check the format requirements in error messages
2. Use tab completion to see available options
3. Refer to examples in help text
4. Report bugs at: https://github.com/robert-kratz/hostkit/issues
