# frozen_string_literal: true

require 'net/imap'
require_relative 'connection'
require_relative 'cleanbox'
require_relative 'configuration'
require_relative 'auth/authentication_manager'

# Monkey patch Cleanbox to add convenience methods
class Cleanbox
  # Enable pretend mode (don't actually move messages)
  def pretend!
    @options[:pretend] = true
    puts '✅ Pretend mode enabled - no messages will be moved'
  end

  # Disable pretend mode (actually move messages)
  def no_pretend!
    @options[:pretend] = false
    puts '✅ Pretend mode disabled - messages will be moved'
  end

  # Check if pretend mode is enabled
  def pretending?
    !!@options[:pretend]
  end
end

# Console interface for Cleanbox
# Provides an easy way to interact with Cleanbox from irb/pry
module CleanboxConsole
  class << self
    # Initialize a new Cleanbox instance with the given configuration
    # @param config_file [String] Path to configuration file (optional)
    # @param options [Hash] Additional options to override config
    # @return [Cleanbox] Configured Cleanbox instance
    def connect(config_file: nil, **options)
      # Load configuration
      config_opts = config_file ? { config_file: config_file } : {}
      Configuration.configure(config_opts.merge(options))

      # Create IMAP connection
      imap = Net::IMAP.new(Configuration.options[:host], ssl: true)

      # Authenticate
      Auth::AuthenticationManager.authenticate_imap(imap, Configuration.options)

      # Create and return Cleanbox instance
      Cleanbox.new(imap, Configuration.options)
    end

    # Quick connection using environment variables or default config
    # @return [Cleanbox] Configured Cleanbox instance
    def quick_connect
      connect
    end

    # Store the current cleanbox instance

    # Get the current cleanbox instance
    attr_accessor :cleanbox
  end
end

# Convenience method for quick access
def cb
  CleanboxConsole.cleanbox || CleanboxConsole.quick_connect
end

# Alias for shorter typing
def cleanbox
  cb
end

# Show help for available methods
def help
  puts <<~HELP
    Cleanbox Console - Available Commands:

    # Main instance
    cb                    - Quick access to Cleanbox instance
    cleanbox             - Same as cb

    # Cleanbox methods (use with cb.method_name):
    cb.show_folders!     - List available folders
    cb.show_lists!       - Show list domain mappings
    cb.clean!            - Process new messages in inbox
    cb.file_messages!    - File existing messages
    cb.unjunk!           - Unjunk messages from junk folder

    # Convenience methods (monkey patched):
    cb.pretend!          - Enable pretend mode (no actual moves)
    cb.no_pretend!       - Disable pretend mode (actual moves)
    cb.pretending?       - Check if pretend mode is enabled
    cb.log_level('debug') - Set log level

    # Configuration
    cb.options           - Show current options
    cb.options[:pretend] = true   - Direct option setting

    # Help
    help                 - Show this help message

    # Example Usage:
    # cb.pretend!                    # Test without moving messages
    # cb.clean!                     # See what would happen
    # cb.no_pretend!                # Actually do it
    # cb.clean!                     # Now actually move messages
  HELP
end
