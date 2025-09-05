# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative '../configuration'

module CLI
  class ConfigManager
    attr_reader :config_path, :data_dir

    def initialize(config_path = nil, data_dir = nil)
      @data_dir = data_dir || Configuration.data_dir
      @config_path = config_path || Configuration.config_file_path
    end

    def config
      Configuration.options
    end

    def show
      puts "File.exist?(@config_path): #{File.exist?(@config_path)}"

      config_data = config
      if File.exist?(@config_path)
        puts "Configuration from #{@config_path}:"
        filtered_config = config_data.slice(*recognized_keys)
        puts filtered_config.to_yaml

        # Deprecated keys: present in config, not recognized
        deprecated_keys = config_data.keys - recognized_keys
        if deprecated_keys.any?
          puts ''
          puts 'Note: Found deprecated keys in your config:'
          deprecated_keys.each do |key|
            puts "  - #{key}"
          end
        end

        # Recognized keys not present in config
        missing_keys = recognized_keys - config_data.keys
        if missing_keys.any?
          puts ''
          puts 'Recognized keys you have not set (you may want to add these):'
          missing_keys.each do |key|
            puts "  - #{key}"
          end
        end
      else
        puts "No configuration file found at #{@config_path}"
      end
    end

    def get(key)
      key = key.to_sym
      config_data = config
      value = config_data[key]
      if value.nil?
        puts "Key '#{key}' not found in configuration"
      else
        puts value.to_yaml
      end
    end

    def set(key, value)
      key = key.to_sym
      config_data = config

      # Try to parse value as YAML for complex types
      begin
        parsed_value = YAML.safe_load(value)
        config_data[key] = parsed_value
      rescue StandardError
        # If YAML parsing fails, treat as string
        config_data[key] = value
      end

      save_config(config_data)
    end

    def add(key, value)
      key = key.to_sym
      config_data = config

      # Try to parse value as YAML for complex types
      begin
        parsed_value = YAML.safe_load(value)
      rescue StandardError
        # If YAML parsing fails, treat as string
        parsed_value = value
      end

      # Handle different types
      if config_data[key].is_a?(Array)
        # Append to array
        config_data[key] << parsed_value
        puts "Added '#{parsed_value}' to #{key}"
      elsif config_data[key].is_a?(Hash) && parsed_value.is_a?(Hash)
        # Merge with hash
        config_data[key] = config_data[key].deep_merge(parsed_value)
        puts "Merged hash into #{key}"
      elsif config_data[key].nil?
        # Create new array or hash based on value type
        if parsed_value.is_a?(Hash)
          config_data[key] = parsed_value
          puts "Created new hash for #{key}"
        else
          config_data[key] = [parsed_value]
          puts "Created new array for #{key} with '#{parsed_value}'"
        end
      else
        exit_with_error "Cannot add to #{key} (type: #{config_data[key].class})"
      end

      save_config(config_data)
    end

    def remove(key, value)
      key = key.to_sym
      config_data = config

      # Try to parse value as YAML for complex types
      begin
        parsed_value = YAML.safe_load(value)
      rescue StandardError
        # If YAML parsing fails, treat as string
        parsed_value = value
      end

      # Handle different types
      if config_data[key].is_a?(Array)
        # Remove from array
        if config_data[key].include?(parsed_value)
          config_data[key].delete(parsed_value)
          puts "Removed '#{parsed_value}' from #{key}"
        else
          puts "Value '#{parsed_value}' not found in #{key}"
        end
      elsif config_data[key].is_a?(Hash) && parsed_value.is_a?(Hash)
        # Remove keys from hash
        removed_keys = []
        parsed_value.each_key do |k|
          # Convert string key to symbol to match config_data keys
          if config_data[key].key?(k)
            config_data[key].delete(k)
            removed_keys << k
          end
        end
        if removed_keys.any?
          puts "Removed keys #{removed_keys.join(', ')} from #{key}"
        else
          puts "No matching keys found in #{key}"
        end
      elsif config_data[key].nil?
        exit_with_error "Key '#{key}' not found in configuration"
      else
        exit_with_error "Cannot remove from #{key} (type: #{config_data[key].class})"
      end

      save_config(config_data)
    end

    def init
      if File.exist?(@config_path)
        puts "Configuration file already exists at #{@config_path}"
        puts "Use 'cleanbox config show' to view it"
      else
        default_config = create_comprehensive_config
        save_config_with_comments(default_config)
        puts "Comprehensive configuration template created at #{@config_path}"
        puts 'Please edit it with your actual settings'
        puts 'See the comments in the file for detailed explanations of each option'
      end
    end

    def init_domain_rules
      default_domain_rules_path = File.expand_path('../../config/domain_rules.yml', __dir__)

      # Determine the user domain rules path based on data directory
      user_domain_rules_path = if @data_dir
                                 File.join(@data_dir, 'domain_rules.yml')
                               else
                                 File.expand_path('~/.cleanbox/domain_rules.yml')
                               end

      if File.exist?(user_domain_rules_path)
        puts "Domain rules file already exists at #{user_domain_rules_path}"
        puts 'Edit it to customize your domain mappings'
      else
        unless File.exist?(default_domain_rules_path)
          exit_with_error "Error: Default domain rules file not found at #{default_domain_rules_path}"
        end

        FileUtils.mkdir_p(File.dirname(user_domain_rules_path))
        FileUtils.cp(default_domain_rules_path, user_domain_rules_path)
        puts "✅ Domain rules file created at #{user_domain_rules_path}"
        puts ''
        puts 'This file contains patterns for automatically filing related email domains.'
        puts 'Edit it to customize your domain mappings, then restart cleanbox.'
        puts ''
        puts 'Examples of what you can customize:'
        puts '  - Add new domain patterns for your favorite services'
        puts '  - Modify existing patterns to match your email organization'
        puts '  - Add company-specific domains for automatic filing'
      end
    end

    def config_file_exists?
      File.exist?(@config_path)
    end

    def save_config(config)
      safe_config = config.slice(*recognized_keys)
      FileUtils.mkdir_p(File.dirname(@config_path))
      File.write(@config_path, safe_config.to_yaml)
      puts "Configuration saved to #{@config_path}"

      # Update the global configuration
      Configuration.configure(safe_config)
    end

    def handle_command(args, show_all: false)
      command = args.first

      case command
      when 'show'
        show
      when 'get'
        key = args[1]
        exit_with_error 'Usage: cleanbox config get <key>' if key.nil?
        get(key)
      when 'set'
        key = args[1]
        value = args[2]

        if key.nil? || value.blank?
          exit_with_error <<~ERROR
            Usage: cleanbox config set <key> <value>
            For complex values, edit the config file directly: #{@config_path}
          ERROR
        end
        set(key, value)
      when 'add'
        key = args[1]
        value = args[2]

        if key.nil? || value.blank?
          exit_with_error <<~ERROR
            Usage: cleanbox config add <key> <value>
            This will append to arrays or merge with hashes
          ERROR
        end
        add(key, value)
      when 'remove'
        key = args[1]
        value = args[2]

        if key.nil? || value.blank?
          exit_with_error <<~ERROR
            Usage: cleanbox config remove <key> <value>
            This will remove from arrays or delete keys from hashes
          ERROR
        end
        remove(key, value)
      when 'init'
        init
      when 'init-domain-rules'
        init_domain_rules
      else
        exit_with_error <<~ERROR
          Unknown config command: #{command}
          Available commands: show, get, set, add, remove, init, init-domain-rules
        ERROR
      end
    end

    private

    def recognized_keys
      # These are the keys that are currently recognized and used by Cleanbox
      %i[
        host
        username
        auth_type
        whitelist_folders
        whitelisted_domains
        list_folders
        list_domain_map
        sent_folder
        file_unread
        client_id
        client_secret
        tenant_id
        password
        unjunk
        file_from_folders
        hold_days
        sent_since_months
        valid_since_months
        list_since_months
        data_dir
        verbose
        level
        valid_from
        log_file
        blacklist_folder
        quarantine_folder
        retention_policy
      ]
    end

    def create_comprehensive_config
      {
        # Connection Settings
        'host' => 'outlook.office365.com',
        'username' => 'your-email@example.com',

        # Authentication Settings
        'auth_type' => 'oauth2_microsoft_user', # Options: oauth2_microsoft, oauth2_microsoft_user, oauth2_gmail, password
        'client_id' => nil,                 # OAuth2 client ID (set via environment variable CLEANBOX_CLIENT_ID or secrets)
        'client_secret' => nil,             # OAuth2 client secret (set via environment variable CLEANBOX_CLIENT_SECRET or secrets)
        'tenant_id' => nil,                 # Microsoft tenant ID (set via environment variable CLEANBOX_TENANT_ID or secrets)
        'password' => nil,                  # IMAP password (set via environment variable CLEANBOX_PASSWORD or secrets)

        # Processing Options
        'whitelist_folders' => %w[Family Work Clients], # Important folders - new emails from these senders stay in Inbox
        'whitelisted_domains' => ['example.com'], # Domains to keep (not delete)
        'list_folders' => %w[Newsletters Notifications], # List folders - new emails from these senders get moved to the list folder
        'list_domain_map' => {              # Map domains to specific list folders (e.g., facebook.com → Social)
          'facebook.com' => 'Social',
          'github.com' => 'Development'
        },
        'sent_folder' => 'Sent Items',      # Name of sent items folder
        'file_unread' => false,             # Whether to file unread messages in file mode

        # Unjunk Options
        'unjunk' => false,                  # Enable unjunk functionality

        # Filing Options
        'file_from_folders' => [], # Folders to use as reference when filing Inbox messages (file mode)

        # Processing Filters
        'valid_from' => nil,                # Use addresses found since this date (default: 1 year ago)
        'sent_since_months' => 24,          # Process sent emails from last X months
        'valid_since_months' => 12,         # Process other folders from last X months
        'list_since_months' => 12,          # Process list folders from last X months

        # Retention Policy Settings
        'retention_policy' => 'spammy', # Options: spammy, hold, quarantine, paranoid
        'quarantine_folder' => 'Quarantine', # Folder for quarantined emails
        'hold_days' => 7, # Days to hold unknown emails in inbox

        # Data Directory
        'data_dir' => nil, # Directory for cache, logs, and analysis files (defaults to current directory)

        # Debug/Testing Options

        'verbose' => false,                 # Run verbosely
        'level' => 'info',                  # Log level: debug, info, warn, error
        'log_file' => nil                   # Log file path (defaults to STDOUT)
      }
    end

    def save_config_with_comments(config)
      FileUtils.mkdir_p(File.dirname(@config_path))

      # Create YAML with comments
      yaml_content = generate_yaml_with_comments(config)
      File.write(@config_path, yaml_content)
    end

    def generate_yaml_with_comments(config)
      comments = {
        'host' => '# IMAP server hostname (e.g., outlook.office365.com, imap.gmail.com)',
        'username' => '# Your email address',
        'auth_type' => '# Authentication method: oauth2_microsoft, oauth2_microsoft_user, oauth2_gmail, or password',
        'client_id' => '# OAuth2 client ID (set via environment variable CLEANBOX_CLIENT_ID or secrets)',
        'client_secret' => '# OAuth2 client secret (set via environment variable CLEANBOX_CLIENT_SECRET or secrets)',
        'tenant_id' => '# Microsoft tenant ID (set via environment variable CLEANBOX_TENANT_ID or secrets)',
        'password' => '# IMAP password (set via environment variable CLEANBOX_PASSWORD or secrets)',
        'whitelist_folders' => multi_line_comment([
                                                    '# Important folders - Cleanbox learns from these folders to whitelist sender addresses,',
                                                    '# and new emails from these senders stay in Inbox',
                                                    '#',
                                                    '# Examples:',
                                                    '# - Family: Keep family emails in Inbox',
                                                    '# - Work: Keep work emails in Inbox',
                                                    '# - Clients: Keep client emails in Inbox'
                                                  ]),
        'whitelisted_domains' => '# Domains to keep in inbox (not moved or deleted)',
        'list_folders' => multi_line_comment([
                                               '# List folders - Cleanbox learns from these folders to whitelist sender addresses,',
                                               '# but new emails from these senders get moved to the list folder',
                                               '#',
                                               '# Examples:',
                                               '# - Newsletters: Move newsletter emails here',
                                               '# - Notifications: Move notification emails here',
                                               '# - Marketing: Move marketing emails here'
                                             ]),
        'list_domain_map' => multi_line_comment([
                                                  '# Map domains to specific list folders - Use for services where sender addresses',
                                                  '# change but domain stays the same',
                                                  '#',
                                                  '# Examples:',
                                                  '# - facebook.com: Social (Facebook notifications)',
                                                  '# - github.com: Development (GitHub notifications)',
                                                  '# - linkedin.com: Professional (LinkedIn updates)',
                                                  '# - twitter.com: Social (Twitter notifications)',
                                                  '#',
                                                  '# Wildcard patterns for subdomains:',
                                                  '# - *.channel4.com: TV and Film (matches hi.channel4.com, newsletter.channel4.com, etc.)',
                                                  '# - *.sub.example.com: Work (matches deep.sub.example.com, api.sub.example.com, etc.)',
                                                  '# Note: *.domain.com only matches single-level subdomains, not deeper nested ones'
                                                ]),
        'sent_folder' => '# Name of your sent items folder (varies by email provider)',
        'file_unread' => '# Whether to file unread messages in file mode (default: false = only file read messages)',
        'unjunk' => '# Enable unjunk functionality to restore emails from junk/spam',
        'file_from_folders' => multi_line_comment([
                                                    '# Folders to use as reference when filing Inbox messages (file mode)',
                                                    '# Defaults to whitelist_folders if not specified. Can also be set via -F/--file-from',
                                                    '#',
                                                    '# Example:',
                                                    '# whitelist_folders: [Family, Friends, Work]',
                                                    '# file_from_folders: [Family, Friends]  # Only file from Family/Friends, not Work'
                                                  ]),
        'valid_from' => '# Use addresses found since this date for domain mapping',
        'sent_since_months' => '# Process sent emails from last X months',
        'valid_since_months' => '# Process other folders from last X months',
        'list_since_months' => '# Process list folders from last X months',

        'verbose' => '# Run with detailed output',
        'level' => '# Log level: debug, info, warn, or error',
        'log_file' => '# Path to log file (leave nil for console output)'
      }

      yaml_lines = []
      yaml_lines << '# Cleanbox Configuration File'
      yaml_lines << '# ========================='
      yaml_lines << '#'
      yaml_lines << '# This file contains all available configuration options for Cleanbox.'
      yaml_lines << '# Edit the values below to match your email setup and preferences.'
      yaml_lines << '#'
      yaml_lines << '# For OAuth2 authentication, you can set sensitive values via:'
      yaml_lines << '# - Environment variables (CLEANBOX_CLIENT_ID, etc.)'
      yaml_lines << '# - Secrets management (if configured)'
      yaml_lines << '#'
      yaml_lines << ''

      config.each do |key, value|
        # Add comment if available
        yaml_lines << comments[key] if comments[key]

        # Handle different categories of options
        if should_comment_default?(key, value)
          # Comment out "set it and forget it" options with their defaults
          yaml_lines << "# #{key}: #{value}"
        elsif should_show_empty?(key)
          # Show empty for "optional but useful" options
          yaml_lines << if value.is_a?(Array) && value.empty?
                          "#{key}: []"
                        elsif value.is_a?(Hash) && value.empty?
                          "#{key}: {}"
                        else
                          "#{key}:"
                        end
        elsif value.nil?
          # Show examples for "you need to customize this" options
          yaml_lines << "#{key}:"
        elsif value.is_a?(String) && value.empty?
          yaml_lines << "#{key}: ''"
        elsif value.is_a?(Array) && value.empty?
          yaml_lines << "#{key}: []"
        elsif value.is_a?(Hash) && value.empty?
          yaml_lines << "#{key}: {}"
        else
          # Use YAML.dump to get proper formatting, then clean up
          yaml_str = YAML.dump({ key => value })
          # Remove the key prefix and leading/trailing whitespace
          yaml_str = yaml_str.gsub(/^---\n/, '').strip
          yaml_lines << yaml_str
        end
        yaml_lines << ''
      end

      yaml_lines.join("\n")
    end

    def multi_line_comment(lines)
      lines.join("\n")
    end

    def should_comment_default?(key, _value)
      # Comment out defaults for "set it and forget it" options
      %w[file_unread verbose level sent_since_months valid_since_months list_since_months].include?(key)
    end

    def should_show_example?(key)
      # Show examples for "you need to customize this" options
      %w[username whitelist_folders list_folders list_domain_map sent_folder].include?(key)
    end

    def should_show_empty?(key)
      # Show empty with helpful comments for "optional but useful" options
      %w[client_id client_secret tenant_id password file_from_folders valid_from log_file].include?(key)
    end

    def exit_with_error(error)
      warn error
      exit 1
    end
  end
end
