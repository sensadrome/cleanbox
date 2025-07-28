# Cleanbox

An intelligent email management tool that **learns from your existing organization patterns** to automatically clean your inbox. Unlike traditional spam filters that use heuristics, Cleanbox observes how you've already organized your emails into folders and applies those same patterns to new incoming messages.

## What Makes Cleanbox Different

**Traditional spam filters** use complex algorithms to detect spam based on email content, headers, and sender reputation. Cleanbox takes a different approach: it learns from **your actual behavior** by analyzing which senders you've already moved to folders, kept in your inbox, or marked as spam.

### Key Benefits:
- **Learns Your Preferences**: If you've moved emails from `newsletter@example.com` to a "Newsletters" folder, Cleanbox will automatically move future emails from that sender
- **No False Positives**: Since it's based on your existing organization, it won't incorrectly flag emails you actually want to see
- **Adapts Over Time**: As you organize more emails, Cleanbox becomes more accurate
- **Works Best with Existing Organization**: The more you've already organized your emails, the better Cleanbox performs

## Features

- **Pattern-Based Spam Detection**: Moves unwanted emails to junk/spam based on your existing organization patterns
- **Smart Inbox Cleaning**: Automatically moves new emails to appropriate folders based on learned sender patterns
- **Email Filing**: Reorganizes existing emails in the inbox based on sender patterns  
- **Unjunking**: Restores emails from junk/spam folders based on trusted sender patterns
- **List Management**: Handles newsletters, notifications, and marketing emails by moving them to designated folders
- **Whitelisting**: Keeps important emails in the inbox based on sender addresses and domains
- **Sent Email Analysis**: Analyzes your sent emails to understand who you correspond with and suggests whitelist candidates
- **Intelligent Caching**: Folder analysis is cached for performance
- **Multiple Authentication Methods**: Supports OAuth2 (Microsoft 365) and password-based authentication
- **Flexible Data Storage**: Centralized data directory for configuration, cache, and domain rules files

## Quick Start

### 1. Installation

```bash
# Clone the repository
git clone <repository-url>
cd cleanbox

# Install dependencies
bundle install

# Make the script executable
chmod +x cleanbox
```

### 2. Configuration

**Option A: Interactive Setup (Recommended)**
```bash
# Run the interactive setup wizard
./cleanbox setup
```

**Option B: Manual Configuration**
```bash
# Initialize configuration file
./cleanbox config init

# Edit the configuration file
nano ~/.cleanbox.yml
```

### 3. Run Cleanbox

```bash
# Clean new emails (default action)
./cleanbox

# File existing emails in inbox
./cleanbox file

# Show folder mappings
./cleanbox list

# Show all folders
./cleanbox folders

# Analyze sent emails vs folder patterns
./cleanbox sent-analysis collect
./cleanbox sent-analysis analyze
./cleanbox sent-analysis compare
```

## Data Directory

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

## Microsoft 365 / Entra Setup

Cleanbox supports OAuth2 authentication with Microsoft 365. Follow these steps to set up your application:

### 1. Register Application in Microsoft Entra

1. Go to [Microsoft Entra Admin Center](https://entra.microsoft.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **New registration**
4. Fill in the details:
   - **Name**: `Cleanbox Email Manager` (or your preferred name)
   - **Supported account types**: Choose based on your needs:
     - `Accounts in this organizational directory only` (single tenant)
     - `Accounts in any organizational directory` (multi-tenant)
   - **Redirect URI**: Leave blank for now
5. Click **Register**

### 2. Configure API Permissions

1. In your new app registration, go to **API permissions**
2. Click **Add a permission**
3. Select **Microsoft Graph**
4. Choose **Application permissions** (not Delegated)
5. Search for and select these permissions:
   - `IMAP.AccessAsUser.All` - Full access to user mailboxes via IMAP
   - `Mail.Read` - Read user mail
   - `Mail.ReadWrite` - Read and write user mail
6. Click **Add permissions**
7. Click **Grant admin consent** (requires admin privileges)

### 3. Create Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Add a description (e.g., "Cleanbox OAuth2 Secret")
4. Choose expiration period
5. Click **Add**
6. **Important**: Copy the secret value immediately - you won't be able to see it again!

### 4. Get Application Details

1. Go to **Overview** to find:
   - **Application (client) ID** - This is your `client_id`
   - **Directory (tenant) ID** - This is your `tenant_id`
2. Use the client secret you created in step 3

### 5. Configure Cleanbox

**Option A: Interactive Setup (Recommended)**
```bash
./cleanbox setup
```
This will analyze your email structure and create both configuration files automatically.

**Option B: Manual Configuration**

The setup wizard will create two files:

1. **`~/.cleanbox.yml`** - Main configuration (non-sensitive settings):
```yaml
host: outlook.office365.com
username: your-email@yourdomain.com
auth_type: oauth2_microsoft
# Sensitive credentials are stored in .env file
```

2. **`.env`** - Sensitive credentials (automatically created):
```bash
CLEANBOX_CLIENT_ID=your-application-client-id
CLEANBOX_CLIENT_SECRET=your-client-secret
CLEANBOX_TENANT_ID=your-tenant-id
```

**Security Note**: The `.env` file is automatically added to `.gitignore` to prevent accidental commits of sensitive data.

**Option C: Environment Variables**
You can also set credentials as environment variables:
```bash
export CLEANBOX_CLIENT_ID="your-application-client-id"
export CLEANBOX_CLIENT_SECRET="your-client-secret"
export CLEANBOX_TENANT_ID="your-tenant-id"
```

## Configuration

Cleanbox uses a YAML configuration file. By default, it's located at `~/.cleanbox.yml`, but you can specify a custom location using the `--data-dir` option. Run `./cleanbox config init` to create a comprehensive template with detailed comments.

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

# Unjunk Options
unjunk: false
unjunk_folders: ['Inbox']  # Use these folders as reference for unjunking
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

**Domain Rules File**:
Cleanbox uses a domain rules file for advanced domain-to-folder mapping. This file allows you to customize how related email domains are automatically filed together. By default, it's located at `~/.cleanbox/domain_rules.yml`, but you can specify a custom location using the `--data-dir` option.

### Domain Rules Customization

Domain rules help Cleanbox understand relationships between email domains. For example, if you have emails from `github.com` in a "Development" folder, Cleanbox can automatically file emails from related domains like `githubusercontent.com` and `github.io` to the same folder.

**Initialize Domain Rules**:
```bash
# Create a user-writable domain rules file
./cleanbox config init-domain-rules
```

This creates a customizable domain rules file at `~/.cleanbox/domain_rules.yml` (or `{data_dir}/domain_rules.yml` if using `--data-dir`).

**Domain Rules File Structure**:
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

**Customization Examples**:

Add your company domains:
```yaml
domain_patterns:
  yourcompany\.com:
    - mail.yourcompany.com
    - notifications.yourcompany.com
    - alerts.yourcompany.com
```

Add patterns for custom folders:
```yaml
folder_patterns:
  ^work$:
    - yourcompany.com
    - work-related-domain.com
  ^personal$:
    - family-domain.com
    - personal-service.com
```

**File Resolution Priority**:
1. `{data_dir}/domain_rules.yml` (when using `--data-dir`)
2. `~/.cleanbox/domain_rules.yml` (user's home directory)
3. `config/domain_rules.yml` (default application file)

**Migration for Existing Users**:
If you're upgrading from an older version, run:
```bash
./cleanbox config init-domain-rules
```
This will create a customizable domain rules file while preserving all existing functionality.

### Configuration Management

```bash
# Show current configuration
./cleanbox config show

# Get specific configuration value
./cleanbox config get whitelist_folders

# Set configuration value
./cleanbox config set whitelist_folders "['Family', 'Work']"

# Add to array configuration
./cleanbox config add whitelist_folders "Friends"

# Remove from array configuration
./cleanbox config remove whitelist_folders "Work"

# Initialize domain rules file (for customization)
./cleanbox config init-domain-rules
```

## Usage

### Basic Commands

```bash
# Interactive setup wizard (analyzes your email and configures Cleanbox)
./cleanbox setup

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

### Command Line Options

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

# Sent analysis commands
./cleanbox sent-analysis collect    # Collect sent email data
./cleanbox sent-analysis analyze    # Analyze collected data
./cleanbox sent-analysis compare    # Compare sent vs folder patterns
```

### Getting Started Safely

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

### Examples

**Keep family and work emails in inbox, move newsletters to folders:**
```yaml
whitelist_folders: ['Family', 'Work']
list_folders: ['Newsletters', 'Notifications']
list_domain_map:
  'facebook.com': 'Social'
  'github.com': 'Development'
```

**File existing emails from inbox based on learned patterns:**
```bash
./cleanbox file
```

**Analyze sent emails to understand your communication patterns:**
```bash
# Collect data from your sent emails and folders
./cleanbox sent-analysis collect

# Analyze the collected data
./cleanbox sent-analysis analyze

# Compare sent recipients with folder senders
./cleanbox sent-analysis compare
```

**Unjunk emails from spam using inbox as reference:**
```bash
./cleanbox --unjunk Inbox
```

## Sent Email Analysis

Cleanbox includes a powerful sent email analysis feature that helps you understand your communication patterns and optimize your whitelist configuration.

### What It Does

The sent-analysis feature:
- **Analyzes your sent emails** to identify who you correspond with most frequently
- **Compares sent recipients** with folder senders to find potential whitelist candidates
- **Suggests folder categorization** based on overlap between sent emails and folder contents
- **Provides detailed statistics** about your email communication patterns

### Commands

```bash
# Collect data from your sent emails and all folders
./cleanbox sent-analysis collect

# Analyze the collected data and show statistics
./cleanbox sent-analysis analyze

# Compare sent recipients with folder senders and show recommendations
./cleanbox sent-analysis compare

# Show help for sent-analysis commands
./cleanbox sent-analysis help
```

### Data Collection

The `collect` command:
- Analyzes up to 1000 of your most recent sent emails
- Examines up to 200 messages from each folder
- Saves detailed data to JSON and CSV files for analysis
- Uses progress meters to show collection progress

### Analysis Output

The `analyze` command shows:
- **Top recipients** from your sent emails
- **Folder categorization** (whitelist vs list folders)
- **Message counts** and sender statistics for each folder

The `compare` command shows:
- **Overlap analysis** between sent recipients and folder senders
- **Folder rankings** by overlap percentage
- **Recommendations** for whitelist vs list categorization
- **Summary statistics** for whitelist vs list folders

### Data Directory Support

Sent analysis data is saved to the same data directory as other Cleanbox files:
- **With `--data-dir`**: Files saved to specified directory
- **Without `--data-dir`**: Files saved to current working directory
- **From config**: Uses `data_dir` setting from `~/.cleanbox.yml`

### Example Output

```bash
$ ./cleanbox sent-analysis compare

📊 SENT vs FOLDER COMPARISON
============================================================
Folders ranked by overlap with sent recipients:

1. Family (whitelist)
   Overlap: 9/9 (100.0%)
   Overlapping emails: family@example.com, mom@example.com

2. Work (whitelist)
   Overlap: 4/16 (25.0%)
   Overlapping emails: colleague@company.com, client@client.com

SUMMARY STATISTICS
==============================
Whitelist folders average overlap: 49.24%
List folders average overlap: 6.37%

RECOMMENDATIONS
====================
Folders with high overlap (>50%) - consider whitelist:
  - Family (100.0%)
  - Friends (75.0%)

Folders with low overlap (<10%) - consider list:
  - Newsletters (5.0%)
  - Shopping (2.0%)
```

### Use Cases

**Optimizing Whitelist Configuration:**
- Use sent analysis to identify people you frequently email
- Add high-overlap folders to your whitelist configuration
- Remove low-overlap folders from whitelist

**Understanding Communication Patterns:**
- See who you correspond with most frequently
- Identify which folders contain people you actually communicate with
- Find potential whitelist candidates you might have missed

**Data-Driven Folder Organization:**
- Use overlap analysis to decide how to categorize folders
- Move high-overlap folders to whitelist
- Move low-overlap folders to list categories

**Unjunk emails using multiple folders as reference:**
```bash
./cleanbox --unjunk Inbox --unjunk Family
```

## How It Works

### Learning Phase
Cleanbox analyzes your existing email organization to understand your preferences:

1. **Whitelist Analysis**: Examines folders you've designated as important (like "Family", "Work", "Clients") to learn which senders should stay in your inbox
2. **List Detection**: Identifies newsletters, notifications, and marketing emails by analyzing folders like "Newsletters", "Notifications", etc.
3. **Pattern Recognition**: Learns domain patterns (e.g., if you've moved emails from `facebook.com` to a "Social" folder, it will do the same for future emails)
4. **Domain Rules**: Uses customizable domain rules to understand relationships between email domains and suggest related domains for automatic filing

### Processing Phase
New emails are automatically processed based on learned patterns:

- **Whitelisted Senders**: Emails from senders found in your important folders stay in the inbox
- **List Senders**: Emails from senders found in list folders get moved to appropriate folders
- **Unknown Senders**: Emails from unknown senders get moved to junk/spam (this is where the "aggressive" behavior you mentioned comes from)

### Important Notes
- **Works Best with Existing Organization**: Cleanbox is most effective when you've already started organizing your emails into folders
- **Can Be Aggressive Initially**: Until you've organized enough emails, Cleanbox may move legitimate emails to spam. Use the `--pretend` flag to preview actions before applying them
- **Improves Over Time**: As you organize more emails, Cleanbox becomes more accurate and less aggressive
- **Caching**: Folder analysis is cached for performance, so subsequent runs are faster

## Troubleshooting

### Common Issues

**"Authentication failed"**
- Check your OAuth2 credentials (client_id, client_secret, tenant_id)
- Ensure admin consent was granted for API permissions
- Verify your username matches the registered application

**"Folder not found"**
- Check folder names in your configuration
- Ensure folders exist in your email account
- Use `./cleanbox folders` to see available folders

**"Permission denied"**
- Ensure IMAP is enabled in your email account
- Check that your OAuth2 app has the correct permissions
- Verify admin consent was granted

**"Cleanbox moved important emails to spam"**
- This is normal behavior initially - Cleanbox learns from your existing organization
- Use `--pretend` flag to preview actions before applying them
- Organize more emails into appropriate folders to improve accuracy
- Check your junk/spam folder regularly and move important emails back to inbox
- Consider adding important senders to `whitelist_folders` configuration

**"Domain rules not working"**
- Ensure you've created a domain rules file: `./cleanbox config init-domain-rules`
- Check that your domain rules file is in the correct location (see file resolution priority)
- Verify the YAML syntax in your domain rules file
- Use `--verbose` flag to see which domain rules file is being loaded

### Debug Mode

```bash
# Enable debug logging
./cleanbox --verbose --level debug

# Log to file
./cleanbox --log-file cleanbox.log
```

## Security

- **OAuth2 Credentials**: Store client secrets securely (environment variables or secrets management)
- **Configuration File**: Keep `~/.cleanbox.yml` secure (chmod 600)
- **Logs**: Be aware that logs may contain email addresses and metadata

## Development

### Prerequisites

- Ruby 2.6+
- Bundler

### Setup

```bash
bundle install
```

### Running Tests

```bash
# Add tests when implemented
```

### Project Structure

```
lib/
├── cli/                    # Command-line interface
│   ├── cleanbox_cli.rb    # Main CLI orchestrator
│   ├── config_manager.rb  # Configuration management
│   ├── cli_parser.rb      # Command-line argument parsing
│   ├── validator.rb       # Configuration validation
│   └── secrets_manager.rb # Secure credential management
├── auth/                   # Authentication
│   └── authentication_manager.rb
├── cleanbox.rb            # Core business logic
├── message.rb             # Individual message processing
├── folder_checker.rb      # Folder analysis with caching
├── connection.rb          # IMAP connection management
└── microsoft_365_application_token.rb
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

[Add your license information here]

## Support

For issues and questions:
- Check the troubleshooting section above
- Review the configuration examples
- Open an issue on GitHub

---

**Note**: Cleanbox is designed to work with IMAP email servers. Gmail support is planned but requires additional implementation for label-based organization vs traditional folder-based organization. 