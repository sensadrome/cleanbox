# Cleanbox

An intelligent email management tool that **learns from your existing organization patterns** to automatically clean your inbox. Unlike traditional spam filters that use heuristics, Cleanbox observes how you've already organized your emails into folders and applies those same patterns to new incoming messages.

## What Makes Cleanbox Different

**Traditional spam filters** use complex algorithms to detect spam based on email content, headers, and sender reputation. Cleanbox takes a different approach: it learns from **your actual behavior** by analyzing which senders you've already moved to folders, kept in your inbox, or marked as spam.

### Key Benefits:
- **Learns Your Preferences**: If you've moved emails from `newsletter@example.com` to a "Newsletters" folder, Cleanbox will automatically move future emails from that sender
- **No False Positives**: Since it's based on your existing organization, it won't incorrectly flag emails you actually want to see
- **Adapts Over Time**: As you organize more emails, Cleanbox becomes more accurate
- **Works Best with Existing Organization**: The more you've already organized your emails, the better Cleanbox performs

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

### 2. Setup

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
# Clean new emails
./cleanbox clean

# File existing emails in inbox
./cleanbox file

# Show folder mappings
./cleanbox list

# Show all folders
./cleanbox folders

# Manage authentication
./cleanbox auth setup    # Set up authentication
./cleanbox auth test     # Test authentication
./cleanbox auth show     # Show auth status
./cleanbox auth reset    # Reset authentication

# Show help (default when no arguments provided)
./cleanbox
```

### 4. Interactive Console (NEW!)

For development, testing, and exploration, use the interactive console:

```bash
# Console (tries Pry first, falls back to IRB)
./bin/console

# With custom config file
./bin/console -c /path/to/config.yml

# Or start irb/pry manually and load the console
irb
require_relative 'lib/console'
CleanboxConsole.help
```

The console provides a REPL interface for exploring your email structure, testing configurations, and performing one-off operations. See [Console Documentation](docs/console.md) for details.

## Documentation

📚 **Complete documentation is available in the [docs/](docs/) directory:**

- **[🚀 Installation](docs/installation.md)** - Prerequisites and installation steps
- **[🔐 Authentication](docs/authentication.md)** - Microsoft 365 OAuth2 and standard IMAP setup
- **[⚙️ Configuration](docs/configuration.md)** - Configuration files, domain rules, and data directory management
- **[📋 Usage](docs/usage.md)** - Commands, examples, and advanced usage patterns
- **[📊 Sent Analysis](docs/sent-analysis.md)** - Understanding your email communication patterns
- **[🖥️ Console](docs/console.md)** - Interactive REPL interface for development and testing
- **[🔧 Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[👨‍💻 Development](docs/development.md)** - Contributing and development setup

## Features

- **Pattern-Based Spam Detection**: Moves unwanted emails to junk/spam based on your existing organization patterns
- **Smart Inbox Cleaning**: Automatically moves new emails to appropriate folders based on learned sender patterns
- **Email Filing**: Reorganizes existing emails in the inbox based on sender patterns  
- **Unjunking**: Restores emails from junk/spam folders based on trusted sender patterns
- **List Management**: Handles newsletters, notifications, and marketing emails by moving them to designated folders
- **Whitelisting**: Keeps important emails in the inbox based on sender addresses and domains
- **Retention Policy System**: Configurable handling of unknown senders with four options:
  - **Spammy**: Treats legitimate-looking unknown emails as list emails
  - **Hold**: Keeps unknown emails in inbox for configurable days before junking
  - **Quarantine**: Files unknown emails to configurable quarantine folder for review
  - **Paranoid**: Junks all unknown emails regardless of DKIM status
- **Sent Email Analysis**: Analyzes your sent emails to understand who you correspond with and suggests whitelist candidates
- **Intelligent Caching**: Folder analysis is cached for performance
- **Multiple Authentication Methods**: Supports OAuth2 (Microsoft 365) and password-based authentication
- **Flexible Data Storage**: Centralized data directory for configuration, cache, and domain rules files

## Container Deployment

Cleanbox can be deployed as a container for easy management and isolation. This is especially useful for automated cleaning and production deployments.

### Quick Container Setup

```bash
# Run the automated setup script
./scripts/setup-container.sh

# Or manually copy and customize templates
cp scripts/cleanbox-run.template ~/cleanbox-run
cp scripts/cb.template ~/cb
chmod +x ~/cleanbox-run ~/cb
```

### Container Features

- **Automated Cleaning**: Scheduled email processing using `cleanbox-run`
- **Manual Commands**: Interactive commands using `cb` utility  
- **Data Persistence**: Configuration, cache, and logs stored in a data directory
- **Authentication**: Support for Microsoft 365 OAuth2 and password-based auth
- **Multi-Engine**: Works with both Podman and Docker

For complete container deployment documentation, see [deploy/CONTAINER_DEPLOYMENT.md](deploy/CONTAINER_DEPLOYMENT.md).

## Development and Testing

Cleanbox includes a comprehensive test suite with improved infrastructure:

- **Organized Test Helpers**: Test utilities are organized in `spec/helpers/` for better maintainability
- **Improved Test Isolation**: Each test gets its own temporary configuration and directories
- **Better Error Handling**: Comprehensive error output for debugging test failures
- **Flexible Configuration**: Tests can override configuration options using `let` blocks
- **Clean Test Infrastructure**: Eliminated class variable warnings and improved test organization

### Running Tests

```bash
# Run the full test suite
bundle exec rspec

# Run specific test files
bundle exec rspec spec/cli/config_manager_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
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
   ./cleanbox clean --pretend --verbose
   ```
4. **If the preview looks good, run it for real**:
   ```bash
   ./cleanbox clean
   ```
5. **Check your junk/spam folder** after the first run to make sure nothing important was moved there
6. **Continue organizing emails** - Cleanbox will become more accurate over time

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
- **Unknown Senders**: Emails from unknown senders are handled according to your retention policy:
  - **Spammy**: Moved to list folders if they pass DKIM validation
  - **Hold**: Kept in inbox for a configurable period before being junked
  - **Quarantine**: Moved to a quarantine folder for manual review
  - **Paranoid**: Moved to junk/spam immediately (the original "aggressive" behavior)

### Important Notes
- **Works Best with Existing Organization**: Cleanbox is most effective when you've already started organizing your emails into folders
- **Can Be Aggressive Initially**: Until you've organized enough emails, Cleanbox may move legitimate emails to spam. Use the `--pretend` flag to preview actions before applying them
- **Improves Over Time**: As you organize more emails, Cleanbox becomes more accurate and less aggressive
- **Caching**: Folder analysis is cached for performance, so subsequent runs are faster

## Support

For issues and questions:
- Check the [troubleshooting guide](docs/troubleshooting.md)
- Review the configuration examples in [configuration.md](docs/configuration.md)
- Open an issue on GitHub

---

**Note**: Cleanbox is designed to work with IMAP email servers. Gmail support is planned but requires additional implementation for label-based organization vs traditional folder-based organization. 