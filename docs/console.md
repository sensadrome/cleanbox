# Cleanbox Console

The Cleanbox Console provides an interactive REPL (Read-Eval-Print Loop) interface for working with Cleanbox. It's perfect for exploring your email structure, testing configurations, and performing one-off operations.

## Quick Start

### Option 1: Run the Console Script

```bash
# Console (tries Pry first, falls back to IRB)
./bin/console

# With custom config file
./bin/console -c /path/to/config.yml
```

### Option 2: Start IRB/Pry Manually

```bash
# Start IRB
irb

# Or start Pry
pry
```

Then load the console:

```ruby
require_relative 'lib/console'
CleanboxConsole.help
```

## Available Commands

### Connection

- `CleanboxConsole.connect(config_file:, **options)` - Connect with custom configuration
- `CleanboxConsole.quick_connect` - Connect using default configuration
- `cb` or `cleanbox` - Quick access to the current instance

### Information

- `config` - Show current configuration
- `folders` - List available email folders
- `list_domains` - Show list domain mappings
- `message_counts` - Show message counts per folder
- `whitelisted_emails` - Show whitelisted email addresses
- `blacklisted_emails` - Show blacklisted email addresses

### Actions

- `clean_inbox!` - Process new messages in inbox
- `file_messages!` - File existing messages
- `unjunk!` - Unjunk messages from junk folder

### Settings

- `pretend!` - Enable pretend mode (no actual message moves)
- `no_pretend!` - Disable pretend mode
- `log_level(level)` - Set log level (debug, info, warn, error)

### Help

- `help` - Show available commands

## Example Usage

### Basic Session

```ruby
# Start console and connect
./bin/console

# Show help
help

# Check folders
folders

# See message counts
message_counts

# Clean inbox (in pretend mode first)
pretend!
clean_inbox!

# If everything looks good, disable pretend mode
no_pretend!
clean_inbox!
```

### Custom Configuration

```ruby
# Connect with specific configuration
cleanbox = CleanboxConsole.connect(
  host: 'imap.office365.com',
  username: 'user@example.com',
  pretend: true,
  level: 'debug'
)

# Work with the instance
cleanbox.folders
cleanbox.message_counts
```

### Programmatic Usage

```ruby
require_relative 'lib/console'

# Connect
cleanbox = CleanboxConsole.quick_connect

# Perform operations
cleanbox.clean!
cleanbox.file_messages!
cleanbox.unjunk!
```

## Configuration

The console will automatically try to load configuration from:

1. Environment variables (`CLEANBOX_CONFIG`, `CLEANBOX_DATA_DIR`)
2. Default config file locations
3. Command line options passed to `connect()`

## Safety Features

- **Pretend Mode**: Use `pretend!` to test operations without actually moving messages
- **Logging**: Set log levels to see exactly what operations would be performed
- **Validation**: The console validates connections and configurations before proceeding

## Troubleshooting

### Connection Issues

If auto-connection fails, you can connect manually:

```ruby
CleanboxConsole.connect(
  host: 'your.imap.server.com',
  username: 'your@email.com',
  # Add other required options
)
```

### Authentication Issues

Make sure you have:
- Valid credentials in your config file
- Proper OAuth2 setup for Microsoft 365/Gmail
- Network access to your IMAP server

### Permission Issues

Ensure the console scripts are executable:

```bash
chmod +x bin/console bin/pry-console
```

## Integration with Existing Code

The console module can be easily integrated into existing scripts or applications:

```ruby
require_relative 'lib/console'

# Use in your own code
class EmailProcessor
  def initialize
    @cleanbox = CleanboxConsole.quick_connect
  end
  
  def process_emails
    @cleanbox.clean!
  end
end
```

## Tips

1. **Start with Pretend Mode**: Always test operations with `pretend!` first
2. **Use Logging**: Set `log_level('debug')` to see detailed operation information
3. **Check Configuration**: Use `config` to verify your settings before connecting
4. **Explore Folders**: Use `folders` and `message_counts` to understand your email structure
5. **Save Sessions**: Use Pry's `save-file` feature to save useful command sequences 