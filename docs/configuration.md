# Configuration

Cleanbox uses a YAML configuration file to manage your preferences and rules. This guide covers all configuration options and how to manage them effectively.

## Configuration File

By default, Cleanbox looks for configuration at `~/.cleanbox.yml`, but you can specify a custom location using the `--data-dir` option.

### Initialize Configuration

```bash
# Create a comprehensive template with detailed comments
./cleanbox config init
```

### Key Configuration Options

**Main Configuration (`~/.cleanbox.yml`)**:
```yaml
# Connection Settings
host: outlook.office365.com
username: your-email@example.com

# Authentication
auth_type: oauth2_microsoft  # or 'password'
# Sensitive credentials (client_id, client_secret, tenant_id, password) 
# are stored in .env file or environment variables

# Processing Options
whitelist_folders: ['Family', 'Work', 'Clients']  # Keep these senders in Inbox
list_folders: ['Newsletters', 'Notifications']    # Move these to folders
list_domain_map:                                 # Map domains to specific folders
  'facebook.com': 'Social'
  'github.com': 'Development'

# Retention Policy Settings
retention_policy: 'spammy'        # Options: spammy, hold, quarantine, paranoid
quarantine_folder: 'Quarantine'   # Folder for quarantined emails
hold_days: 7                      # Days to hold unknown emails in inbox

# Unjunk Options
unjunk: false
```

**Sensitive Credentials (`.env` file)**:
```bash
# OAuth2 Microsoft 365
CLEANBOX_CLIENT_ID=your-application-client-id
CLEANBOX_CLIENT_SECRET=your-client-secret
CLEANBOX_TENANT_ID=your-tenant-id

# Or for password authentication
CLEANBOX_PASSWORD=your-imap-password
```

## Configuration Management

### View Configuration

```bash
# Show current configuration
./cleanbox config show

# Show all configuration (including sensitive data)
./cleanbox config show --all

# Get specific configuration value
./cleanbox config get whitelist_folders
```

### Modify Configuration

```bash
# Set configuration value
./cleanbox config set whitelist_folders "['Family', 'Work']"

# Add to array configuration
./cleanbox config add whitelist_folders "Friends"

# Remove from array configuration
./cleanbox config remove whitelist_folders "Work"
```

### Configuration Examples

**Keep family and work emails in inbox, move newsletters to folders:**
```yaml
whitelist_folders: ['Family', 'Work']
list_folders: ['Newsletters', 'Notifications']
list_domain_map:
  'facebook.com': 'Social'
  'github.com': 'Development'
```

**Aggressive spam filtering (move unknown senders to junk):**
```yaml
whitelist_folders: ['Family', 'Work', 'Important']
list_folders: ['Newsletters', 'Notifications', 'Marketing']
# Unknown senders will be moved to junk/spam
```

**Conservative approach (keep more emails in inbox):**
```yaml
whitelist_folders: ['Family', 'Work', 'Friends', 'Important']
list_folders: ['Newsletters']  # Only move obvious newsletters
# Unknown senders stay in inbox
```

## Retention Policy System

The retention policy system controls how Cleanbox handles emails from unknown senders. This gives you fine-grained control over the aggressiveness of spam filtering.

### Available Policies

**`spammy` (Default)**: Treats legitimate-looking unknown emails as list emails
- Unknown senders with valid DKIM signatures are moved to your list folder
- Good for users who want to keep most legitimate emails
- Configuration: `retention_policy: 'spammy'`

**`hold`**: Keeps unknown emails in inbox for a configurable period
- Unknown emails are kept in the inbox for `hold_days` before being junked
- Allows you to review emails before they're automatically removed
- Configuration: `retention_policy: 'hold'` and `hold_days: 7`

**`quarantine`**: Files unknown emails to a designated folder for review
- Unknown emails are moved to a quarantine folder instead of being junked
- You can review and manually file emails you want to keep
- Configuration: `retention_policy: 'quarantine'` and `quarantine_folder: 'Quarantine'`

**`paranoid`**: Junks all unknown emails immediately
- The most aggressive approach - moves all unknown senders to junk/spam
- Good for users who prefer to manually whitelist senders they want
- Configuration: `retention_policy: 'paranoid'`

### Configuration Examples

**Balanced approach with hold policy:**
```yaml
retention_policy: 'hold'
hold_days: 14
quarantine_folder: 'Review'
```

**Conservative approach with quarantine:**
```yaml
retention_policy: 'quarantine'
quarantine_folder: 'Unknown Senders'
```

**Aggressive approach (original behavior):**
```yaml
retention_policy: 'paranoid'
```

## Domain Rules

Cleanbox uses a domain rules file for advanced domain-to-folder mapping. This file allows you to customize how related email domains are automatically filed together.

### Initialize Domain Rules

```bash
# Create a user-writable domain rules file
./cleanbox config init-domain-rules
```

This creates a customizable domain rules file at `~/.cleanbox/domain_rules.yml` (or `{data_dir}/domain_rules.yml` if using `--data-dir`).

### Domain Rules File Structure

```yaml
# Domain Rules for Cleanbox
# This file defines patterns for automatically filing related email domains

domain_patterns:
  # When Cleanbox finds emails from github.com, suggest these related domains
  github\.com:
    - githubusercontent.com
    - github.io
    - githubapp.com
  
  # Facebook domains
  facebook\.com:
    - facebookmail.com
    - fb.com
    - messenger.com

folder_patterns:
  # When Cleanbox has a folder named "github", suggest these domains
  ^github$:
    - githubusercontent.com
    - github.io
    - githubapp.com
  
  # Facebook folder
  ^facebook$:
    - facebookmail.com
    - fb.com
    - messenger.com
```

### Customization Examples

**Add your company domains:**
```yaml
domain_patterns:
  yourcompany\.com:
    - mail.yourcompany.com
    - notifications.yourcompany.com
    - alerts.yourcompany.com
```

**Add patterns for custom folders:**
```yaml
folder_patterns:
  ^work$:
    - yourcompany.com
    - work-related-domain.com
  ^personal$:
    - family-domain.com
    - personal-service.com
```

### File Resolution Priority

1. `{data_dir}/domain_rules.yml` (when using `--data-dir`)
2. `~/.cleanbox/domain_rules.yml` (user's home directory)
3. `config/domain_rules.yml` (default application file)

### Migration for Existing Users

If you're upgrading from an older version, run:
```bash
./cleanbox config init-domain-rules
```

This will create a customizable domain rules file while preserving all existing functionality.

## Data Directory Management

Cleanbox supports a centralized data directory for all its files (configuration, cache, domain rules). This is especially useful for containerized deployments or when you want to keep all Cleanbox data in a specific location.

### Using Data Directory

```bash
# Use a specific data directory
./cleanbox --data-dir /path/to/data

# This will store all files in /path/to/data:
# - /path/to/data/config.yml (instead of ~/.cleanbox.yml)
# - /path/to/data/cache/ (folder analysis cache)
# - /path/to/data/domain_rules.yml (domain mapping rules)
```

### File Locations

When using `--data-dir`, Cleanbox will look for files in this order:

1. **Configuration**: `{data_dir}/config.yml` → `~/.cleanbox.yml` → default
2. **Domain Rules**: `{data_dir}/domain_rules.yml` → `~/domain_rules.yml` → default
3. **Cache**: `{data_dir}/cache/` (always used when data_dir is specified)

### Container Deployment

For Docker or other containerized deployments:

```bash
# Mount a volume for persistent data
docker run -v /host/path/to/data:/app/data cleanbox --data-dir /app/data
```

## Advanced Configuration Options

### Processing Options

```yaml
# Time-based processing
sent_since_months: 24      # Analyze sent emails from last 24 months
valid_since_months: 12     # Consider emails valid from last 12 months
list_since_months: 12      # Analyze list folders from last 12 months

# Folder options
sent_folder: 'Sent Items'   # Custom sent folder name
list_folder: 'Lists'        # Default list folder name
junk_folder: 'Junk'         # Custom junk folder name

# Processing behavior
file_unread: false          # Only process unread messages
brief: false                # Show detailed output
detailed: false             # Show very detailed output
```

### Caching Options

```yaml
# Cache settings (advanced)
cache_enabled: true         # Enable/disable caching
cache_expiry_hours: 24     # Cache expiration time
```

### Logging Options

```yaml
# Logging configuration
log_level: info             # debug, info, warn, error
log_file: null              # Path to log file (null = stdout)
verbose: false              # Enable verbose output
```

## Configuration Validation

Cleanbox validates your configuration before running:

```bash
# Validate configuration
./cleanbox config validate

# Show validation errors
./cleanbox config validate --verbose
```

### Common Validation Issues

**Missing required fields:**
- `host` - IMAP server hostname
- `username` - Email username
- `auth_type` - Authentication method

**Invalid authentication type:**
- Must be one of: `oauth2_microsoft`, `oauth2_microsoft_user`, `oauth2_gmail`, `password`

**Missing credentials:**
- OAuth2 requires: `client_id`, `client_secret`, `tenant_id`
- Password auth requires: `password`

## Environment-Specific Configuration

### Development

```yaml
# Development configuration
host: localhost
username: test@example.com
auth_type: password
verbose: true
log_level: debug
```

### Production

```yaml
# Production configuration
host: outlook.office365.com
username: production@company.com
auth_type: oauth2_microsoft
verbose: false
log_level: info
```

### Testing

```yaml
# Testing configuration
host: test-imap.example.com
username: test@example.com
auth_type: password
pretend: true  # Don't actually move emails
```

## Next Steps

After configuring Cleanbox:

1. **[Usage](usage.md)** - Learn how to use Cleanbox effectively
2. **[Sent Analysis](sent-analysis.md)** - Understand your email communication patterns
3. **[Troubleshooting](troubleshooting.md)** - Common issues and solutions 