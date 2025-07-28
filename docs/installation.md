# Installation

This guide will help you install Cleanbox and get it ready for use.

## Prerequisites

- **Ruby 2.6 or higher**
- **Bundler** (for dependency management)
- **Git** (for cloning the repository)

### Checking Your Ruby Version

```bash
ruby --version
```

If you don't have Ruby installed, you can install it using:

**macOS (using Homebrew):**
```bash
brew install ruby
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ruby ruby-bundler
```

**Windows:**
Download from [RubyInstaller](https://rubyinstaller.org/)

### Installing Bundler

If you don't have Bundler installed:

```bash
gem install bundler
```

## Installation Steps

### 1. Clone the Repository

```bash
git clone <repository-url>
cd cleanbox
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Make the Script Executable

```bash
chmod +x cleanbox
```

### 4. Verify Installation

```bash
./cleanbox --help
```

You should see the help output with available commands.

## Quick Setup

After installation, you can get started quickly using the interactive setup wizard:

```bash
./cleanbox setup
```

This will:
- Guide you through authentication setup
- Analyze your email structure
- Create configuration files
- Provide recommendations for your setup

## Manual Setup

If you prefer to configure Cleanbox manually:

### 1. Initialize Configuration

```bash
./cleanbox config init
```

This creates a template configuration file at `~/.cleanbox.yml`.

### 2. Edit Configuration

```bash
nano ~/.cleanbox.yml
```

See the [Configuration](configuration.md) guide for detailed configuration options.

### 3. Set Up Authentication

See the [Authentication](authentication.md) guide for setting up your email connection.

## Data Directory (Optional)

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

## Next Steps

After installation:

1. **[Authentication Setup](authentication.md)** - Configure your email connection
2. **[Configuration](configuration.md)** - Set up your preferences and rules
3. **[Usage](usage.md)** - Learn how to use Cleanbox effectively

## Troubleshooting Installation

### Common Issues

**"Command not found: bundle"**
- Install Bundler: `gem install bundler`

**"Permission denied" when running cleanbox**
- Make the script executable: `chmod +x cleanbox`

**"Ruby version too old"**
- Update Ruby to version 2.6 or higher
- Consider using a Ruby version manager like `rbenv` or `rvm`

**"Bundle install fails"**
- Check your Ruby version: `ruby --version`
- Ensure you have write permissions in the directory
- Try running `bundle update` to update dependencies

### Getting Help

If you encounter issues during installation:

1. Check the [troubleshooting guide](troubleshooting.md)
2. Ensure you meet all prerequisites
3. Open an issue on GitHub with details about your system and the error message 