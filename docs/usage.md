# Usage

This guide covers how to use Cleanbox effectively, from basic commands to advanced usage patterns.

## Basic Commands

### Core Operations

```bash
# Clean new emails (default action)
./cleanbox

# File existing emails in inbox
./cleanbox file

# Show domain to folder mappings
./cleanbox list

# Show all folders
./cleanbox folders

# Unjunk emails from spam/junk based on inbox patterns
./cleanbox --unjunk Inbox

# File emails based on specific folders
./cleanbox file --file-from Family --file-from Work
```

### Setup and Configuration

```bash
# Interactive setup wizard (analyzes your email and configures Cleanbox)
./cleanbox setup

# Initialize configuration file
./cleanbox config init

# Show current configuration
./cleanbox config show

# Initialize domain rules file (for customization)
./cleanbox config init-domain-rules
```

### Sent Analysis

```bash
# Collect sent email data
./cleanbox sent-analysis collect

# Analyze collected data
./cleanbox sent-analysis analyze

# Compare sent recipients with folder patterns
./cleanbox sent-analysis compare
```

## Command Line Options

### General Options

```bash
# Verbose output
./cleanbox --verbose

# Dry run (show what would happen) - RECOMMENDED for first-time users
./cleanbox --pretend

# Process only recent emails
./cleanbox --since_months 1

# Use specific folders for filing
./cleanbox file --file-from Family --file-from Work

# Unjunk based on multiple folders
./cleanbox --unjunk Inbox --unjunk Family

# Use custom data directory for config, cache, and domain rules
./cleanbox --data-dir /path/to/data
```

### Logging Options

```bash
# Enable debug logging
./cleanbox --verbose --level debug

# Log to file
./cleanbox --log-file cleanbox.log

# Show brief output
./cleanbox --brief

# Show detailed output
./cleanbox --detailed
```

## Getting Started Safely

Since Cleanbox can be aggressive initially, here's a safe approach:

1. **First, organize your existing emails** into folders (Family, Work, Newsletters, etc.)
2. **Customize domain rules** (optional but recommended):
   ```bash
   ./cleanbox config init-domain-rules
   # Edit ~/.cleanbox/domain_rules.yml to add your company domains
   ```
3. **Preview what Cleanbox would do**:
   ```bash
   ./cleanbox --pretend --verbose
   ```
4. **If the preview looks good, run it for real**:
   ```bash
   ./cleanbox
   ```
5. **Check your junk/spam folder** after the first run to make sure nothing important was moved there
6. **Continue organizing emails** - Cleanbox will become more accurate over time

## Examples

### Basic Email Cleaning

**Keep family and work emails in inbox, move newsletters to folders:**
```yaml
# Configuration
whitelist_folders: ['Family', 'Work']
list_folders: ['Newsletters', 'Notifications']
list_domain_map:
  'facebook.com': 'Social'
  'github.com': 'Development'
```

**Run cleaning:**
```bash
./cleanbox --pretend  # Preview first
./cleanbox            # Run for real
```

### Filing Existing Emails

**File existing emails from inbox based on learned patterns:**
```bash
./cleanbox file
```

**File emails based on specific folders only:**
```bash
./cleanbox file --file-from Family --file-from Work
```

### Unjunking

**Unjunk emails from spam using inbox as reference:**
```bash
./cleanbox --unjunk Inbox
```

**Unjunk using multiple folders as reference:**
```bash
./cleanbox --unjunk Inbox --unjunk Family
```

### Sent Email Analysis

**Analyze sent emails to understand your communication patterns:**
```bash
# Collect data from your sent emails and folders
./cleanbox sent-analysis collect

# Analyze the collected data
./cleanbox sent-analysis analyze

# Compare sent recipients with folder senders
./cleanbox sent-analysis compare
```

### Configuration Management

**View and modify configuration:**
```bash
# Show current configuration
./cleanbox config show

# Get specific value
./cleanbox config get whitelist_folders

# Set configuration
./cleanbox config set whitelist_folders "['Family', 'Work']"

# Add to array
./cleanbox config add whitelist_folders "Friends"

# Remove from array
./cleanbox config remove whitelist_folders "Work"
```

## Advanced Usage Patterns

### Time-Based Processing

**Process only recent emails:**
```bash
# Process emails from last 3 months
./cleanbox --since_months 3

# Process emails from last 6 months
./cleanbox --since_months 6
```

### Folder-Specific Operations

**File emails from specific folders:**
```bash
# File emails based on Family and Work folders only
./cleanbox file --file-from Family --file-from Work

# File emails from all whitelist and list folders
./cleanbox file
```

**Unjunk based on multiple reference folders:**
```bash
# Use both Inbox and Family as reference for unjunking
./cleanbox --unjunk Inbox --unjunk Family
```

### Data Directory Usage

**Use custom data directory:**
```bash
# Store all data in /path/to/data
./cleanbox --data-dir /path/to/data

# This affects:
# - Configuration: /path/to/data/config.yml
# - Cache: /path/to/data/cache/
# - Domain rules: /path/to/data/domain_rules.yml
```

### Container Deployment

**Docker deployment with persistent data:**
```bash
# Mount volume for persistent data
docker run -v /host/path/to/data:/app/data cleanbox --data-dir /app/data

# With environment variables
docker run -e CLEANBOX_CLIENT_ID=secret \
           -e CLEANBOX_CLIENT_SECRET=secret \
           -v /host/path/to/data:/app/data \
           cleanbox --data-dir /app/data
```

## Use Cases

### Personal Email Management

**Scenario**: You want to keep family and work emails in your inbox, but move newsletters and social media notifications to folders.

**Configuration:**
```yaml
whitelist_folders: ['Family', 'Work', 'Important']
list_folders: ['Newsletters', 'Social', 'Notifications']
list_domain_map:
  'facebook.com': 'Social'
  'twitter.com': 'Social'
  'linkedin.com': 'Work'
```

**Usage:**
```bash
# Set up configuration
./cleanbox config set whitelist_folders "['Family', 'Work', 'Important']"
./cleanbox config set list_folders "['Newsletters', 'Social', 'Notifications']"

# Preview what will happen
./cleanbox --pretend --verbose

# Run cleaning
./cleanbox
```

### Business Email Organization

**Scenario**: You want to organize work emails by client and project, while keeping important communications in your inbox.

**Configuration:**
```yaml
whitelist_folders: ['Important', 'Urgent', 'Management']
list_folders: ['Client A', 'Client B', 'Project X', 'Project Y']
list_domain_map:
  'clienta.com': 'Client A'
  'clientb.com': 'Client B'
  'projectx.com': 'Project X'
```

**Usage:**
```bash
# File existing emails into appropriate folders
./cleanbox file

# Clean new incoming emails
./cleanbox
```

### Newsletter and Marketing Management

**Scenario**: You want to automatically file newsletters and marketing emails while keeping important communications in your inbox.

**Configuration:**
```yaml
whitelist_folders: ['Family', 'Work', 'Important']
list_folders: ['Newsletters', 'Marketing', 'Promotions']
list_domain_map:
  'newsletter.com': 'Newsletters'
  'marketing.com': 'Marketing'
  'promo.com': 'Promotions'
```

**Usage:**
```bash
# Preview newsletter filing
./cleanbox --pretend --verbose

# Run automatic filing
./cleanbox
```

## Monitoring and Maintenance

### Regular Tasks

**Daily:**
```bash
# Clean new emails
./cleanbox
```

**Weekly:**
```bash
# Check for any misclassified emails
./cleanbox --unjunk Inbox

# Update sent analysis
./cleanbox sent-analysis collect
./cleanbox sent-analysis analyze
```

**Monthly:**
```bash
# Review and update configuration
./cleanbox config show

# Update domain rules if needed
nano ~/.cleanbox/domain_rules.yml
```

### Performance Optimization

**Use caching effectively:**
```bash
# Cache is automatically used for folder analysis
# Subsequent runs will be faster
./cleanbox
```

**Monitor cache size:**
```bash
# Check cache directory size
du -sh ~/.cleanbox/cache/
```

## Troubleshooting Usage

### Common Issues

**"Cleanbox moved important emails to spam"**
- This is normal behavior initially - Cleanbox learns from your existing organization
- Use `--pretend` flag to preview actions before applying them
- Organize more emails into appropriate folders to improve accuracy
- Check your junk/spam folder regularly and move important emails back to inbox
- Consider adding important senders to `whitelist_folders` configuration

**"Domain rules not working"**
- Ensure you've created a domain rules file: `./cleanbox config init-domain-rules`
- Check that your domain rules file is in the correct location
- Verify the YAML syntax in your domain rules file
- Use `--verbose` flag to see which domain rules file is being loaded

**"Configuration not being applied"**
- Check configuration with: `./cleanbox config show`
- Validate configuration: `./cleanbox config validate`
- Ensure you're using the correct data directory if specified

### Debug Mode

```bash
# Enable debug logging
./cleanbox --verbose --level debug

# Log to file for analysis
./cleanbox --log-file cleanbox.log --verbose --level debug
```

## Next Steps

After learning the basics:

1. **[Sent Analysis](sent-analysis.md)** - Understand your email communication patterns
2. **[Configuration](configuration.md)** - Advanced configuration options
3. **[Troubleshooting](troubleshooting.md)** - Common issues and solutions 