# Cleanbox Documentation

An intelligent email management tool that **learns from your existing organization patterns** to automatically clean your inbox. Unlike traditional spam filters that use heuristics, Cleanbox observes how you've already organized your emails into folders and applies those same patterns to new incoming messages.

## What Makes Cleanbox Different

**Traditional spam filters** use complex algorithms to detect spam based on email content, headers, and sender reputation. Cleanbox takes a different approach: it learns from **your actual behavior** by analyzing which senders you've already moved to folders, kept in your inbox, or marked as spam.

### Key Benefits:
- **Learns Your Preferences**: If you've moved emails from `newsletter@example.com` to a "Newsletters" folder, Cleanbox will automatically move future emails from that sender
- **No False Positives**: Since it's based on your existing organization, it won't incorrectly flag emails you actually want to see
- **Adapts Over Time**: As you organize more emails, Cleanbox becomes more accurate
- **Works Best with Existing Organization**: The more you've already organized your emails, the better Cleanbox performs

## Quick Start

1. **[Installation](installation.md)** - Get Cleanbox up and running
2. **[Authentication Setup](authentication.md)** - Configure your email connection
3. **[Configuration](configuration.md)** - Set up your preferences and rules
4. **[Usage](usage.md)** - Learn how to use Cleanbox effectively

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

## Documentation

- **[Installation](installation.md)** - Prerequisites, installation steps, and basic setup
- **[Authentication](authentication.md)** - Microsoft 365 OAuth2, standard IMAP, and security setup
- **[Configuration](configuration.md)** - Configuration files, domain rules, and data directory management
- **[Usage](usage.md)** - Commands, examples, and advanced usage patterns
- **[Sent Analysis](sent-analysis.md)** - Understanding your email communication patterns
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions
- **[Development](development.md)** - Contributing and development setup

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
- **Unknown Senders**: Emails from unknown senders get moved to junk/spam (this is where the "aggressive" behavior comes from)

### Important Notes
- **Works Best with Existing Organization**: Cleanbox is most effective when you've already started organizing your emails into folders
- **Can Be Aggressive Initially**: Until you've organized enough emails, Cleanbox may move legitimate emails to spam. Use the `--pretend` flag to preview actions before applying them
- **Improves Over Time**: As you organize more emails, Cleanbox becomes more accurate and less aggressive
- **Caching**: Folder analysis is cached for performance, so subsequent runs are faster

## Support

For issues and questions:
- Check the [troubleshooting guide](troubleshooting.md)
- Review the configuration examples in [configuration.md](configuration.md)
- Open an issue on GitHub

---

**Note**: Cleanbox is designed to work with IMAP email servers. Gmail support is planned but requires additional implementation for label-based organization vs traditional folder-based organization. 