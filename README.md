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
Cleanbox also uses a domain rules file for advanced domain-to-folder mapping. By default, it's located at `~/domain_rules.yml`, but you can specify a custom location using the `--data-dir` option. This file is automatically created during setup.

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
```

### Getting Started Safely

Since Cleanbox can be aggressive initially, here's a safe approach:

1. **First, organize your existing emails** into folders (Family, Work, Newsletters, etc.)
2. **Preview what Cleanbox would do**:
   ```bash
   ./cleanbox --pretend --verbose
   ```
3. **If the preview looks good, run it for real**:
   ```bash
   ./cleanbox
   ```
4. **Check your junk/spam folder** after the first run to make sure nothing important was moved there
5. **Continue organizing emails** - Cleanbox will become more accurate over time

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

**Unjunk emails from spam using inbox as reference:**
```bash
./cleanbox --unjunk Inbox
```

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