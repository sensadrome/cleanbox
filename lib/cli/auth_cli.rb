# frozen_string_literal: true

require 'net/imap'
require_relative 'config_manager'
require_relative 'secrets_manager'
require_relative '../auth/authentication_manager'

module CLI
  class AuthCLI
    def initialize(data_dir: nil, config_path: nil)
      @config_manager = ConfigManager.new(config_path, data_dir)
      @logger = Logger.new(STDOUT)
    end

    def run(subcommand = nil)
      subcommand ||= ARGV.first
      case subcommand
      when 'setup'
        setup_auth
      when 'test'
        test_auth
      when 'show'
        show_auth
      when 'reset'
        reset_auth
      else
        show_help
      end
    end

    private

    def setup_auth
      puts "🔐 Cleanbox Authentication Setup"
      puts "================================"
      puts ""

      # Check for existing configuration
      if auth_configured?
        puts "⚠️  Authentication is already configured!"
        puts ""
        puts "What would you like to do?"
        puts "  1. Update authentication settings"
        puts "  2. Test current authentication"
        puts "  3. Cancel"
        puts ""
        print "Choice (1-3): "
        response = gets.chomp.strip
        
        case response
        when '1'
          puts "✅ Will update authentication settings."
          puts ""
        when '2'
          test_auth
          return
        when '3'
          puts "Setup cancelled."
          return
        else
          puts "Invalid choice. Setup cancelled."
          return
        end
      end

      # Get connection details
      connection_data = get_connection_details
      return unless connection_data

      # Test connection
      puts ""
      puts "🔍 Testing connection..."
      unless test_connection(connection_data[:details], connection_data[:secrets])
        puts "❌ Connection test failed. Please check your credentials and try again."
        return
      end

      # Save configuration
      save_auth_config(connection_data[:details], connection_data[:secrets])

      puts ""
      puts "✅ Authentication setup complete!"
      puts "You can now run:"
      puts "  ./cleanbox auth test    # Test your connection"
      puts "  ./cleanbox auth show    # View current settings"
      puts "  ./cleanbox setup        # Complete setup wizard"
    end

    def test_auth
      puts "🔍 Testing Authentication"
      puts "========================"
      puts ""

      unless auth_configured?
        puts "❌ No authentication configuration found."
        puts "Run './cleanbox auth setup' to configure authentication."
        return
      end

      config = @config_manager.load_config
      secrets = load_secrets

      puts "Testing connection to #{config[:host]}..."
      
      if test_connection(config, secrets)
        puts "✅ Authentication successful!"
        puts "Username: #{config[:username]}"
        puts "Host: #{config[:host]}"
        puts "Auth Type: #{config[:auth_type]}"
      else
        puts "❌ Authentication failed!"
        puts "Please check your credentials and run './cleanbox auth setup' to update them."
      end
    end

    def show_auth
      puts "📋 Authentication Configuration"
      puts "==============================="
      puts ""

      unless @config_manager.config_file_exists?
        puts "❌ No configuration file found."
        puts "Run './cleanbox auth setup' to configure authentication."
        return
      end

      config = @config_manager.load_config
      
      unless config[:host] && config[:username] && config[:auth_type]
        puts "❌ Incomplete authentication configuration."
        puts "Missing: #{[:host, :username, :auth_type].select { |k| !config[k] }.join(', ')}"
        puts "Run './cleanbox auth setup' to complete configuration."
        return
      end

      puts "Host: #{config[:host]}"
      puts "Username: #{config[:username]}"
      puts "Auth Type: #{config[:auth_type]}"
      puts ""
      
      # Check secrets status
      secrets_status = CLI::SecretsManager.auth_secrets_status(config[:auth_type])
      
      if secrets_status[:configured]
        puts "✅ Credentials: Configured"
        puts "Source: #{secrets_status[:source]}"
      else
        puts "❌ Credentials: Missing"
        puts "Missing: #{secrets_status[:missing].join(', ')}"
        puts "Source: #{secrets_status[:source]}"
        puts ""
        puts "To fix this:"
        case secrets_status[:source]
        when 'none'
          puts "  Run './cleanbox auth setup' to configure credentials"
        when 'env_file'
          puts "  Check your .env file at #{CLI::SecretsManager::ENV_FILE_PATH}"
          puts "  Ensure it contains the required variables"
        when 'environment'
          puts "  Check your environment variables"
          puts "  Ensure CLEANBOX_* variables are set correctly"
        end
      end

      puts ""
      puts "Configuration file: #{@config_manager.config_path}"
      puts "Secrets file: #{CLI::SecretsManager::ENV_FILE_PATH}"
    end

    def reset_auth
      puts "🔄 Reset Authentication Configuration"
      puts "===================================="
      puts ""

      unless auth_configured?
        puts "❌ No authentication configuration found."
        return
      end

      puts "⚠️  This will remove all authentication configuration!"
      puts "This includes:"
      puts "  - Connection settings from config file"
      puts "  - Credentials from .env file"
      puts ""
              print "Are you sure? (y/N): "
        response = gets.chomp.strip.downcase

      if response == 'y' || response == 'yes'
        reset_auth_config
        puts "✅ Authentication configuration has been reset."
        puts "Run './cleanbox auth setup' to configure authentication again."
      else
        puts "Reset cancelled."
      end
    end

    def show_help
      puts "Cleanbox Authentication Commands"
      puts "================================"
      puts ""
      puts "Usage: ./cleanbox auth <command>"
      puts ""
      puts "Commands:"
      puts "  setup    Interactive authentication setup"
      puts "  test     Test current authentication credentials"
      puts "  show     Display current authentication configuration"
      puts "  reset    Reset authentication configuration"
      puts ""
      puts "Examples:"
      puts "  ./cleanbox auth setup    # Set up authentication"
      puts "  ./cleanbox auth test     # Test your connection"
      puts "  ./cleanbox auth show     # View current settings"
      puts ""
    end

    private

    def get_connection_details
      details = {}
      secrets = {}

      # Host
      default_host = "outlook.office365.com"
      details[:host] = prompt_with_default("IMAP Host", default_host) do |host|
        host.match?(/\.(com|org|net|edu)$/) || host.include?('.')
      end

      # Username
      details[:username] = prompt("Email Address") do |email|
        email.include?('@')
      end

      # Authentication type
      auth_type = prompt_choice("Authentication Method", [
        { key: 'oauth2_microsoft', label: 'OAuth2 (Microsoft 365/Outlook)' },
        { key: 'password', label: 'Password (IMAP)' }
      ])
      details[:auth_type] = auth_type

      # Credentials
      if details[:auth_type] == 'oauth2_microsoft'
        secrets['CLEANBOX_CLIENT_ID'] = prompt("OAuth2 Client ID") { |id| !id.empty? }
        secrets['CLEANBOX_CLIENT_SECRET'] = prompt("OAuth2 Client Secret", secret: true) { |id| !id.empty? }
        secrets['CLEANBOX_TENANT_ID'] = prompt("OAuth2 Tenant ID") { |id| !id.empty? }
      else
        secrets['CLEANBOX_PASSWORD'] = prompt("IMAP Password", secret: true) { |pwd| !pwd.empty? }
      end

      { details: details, secrets: secrets }
    end

    def test_connection(config, secrets)
      # Temporarily set environment variables for authentication
      secrets.each { |key, value| ENV[key] = value }
      
      # Create options hash
      options = {
        host: config[:host],
        username: config[:username],
        auth_type: config[:auth_type],
        client_id: secret(:client_id),
        client_secret: secret(:client_secret),
        tenant_id: secret(:tenant_id),
        password: secret(:password)
      }

      # Create IMAP connection
      imap = Net::IMAP.new(config[:host], ssl: true)
      Auth::AuthenticationManager.authenticate_imap(imap, options)
      
      # Test connection by listing folders
      imap.list("", "*")
      imap.logout
      imap.disconnect
      
      true
    rescue => e
      @logger.error "Connection test failed: #{e.message}"
      false
    end

    def save_auth_config(details, secrets)
      # Create .env file for sensitive credentials
      CLI::SecretsManager.create_env_file(secrets)
      
      # Load existing config or create new
      config = @config_manager.load_config rescue {}
      
      # Update with authentication settings
      config.merge!(details)
      
      # Save configuration
      @config_manager.save_config(config)
      
      puts "✅ Authentication configuration saved"
      puts "Configuration file: #{@config_manager.config_path}"
      puts "Secrets file: #{CLI::SecretsManager::ENV_FILE_PATH}"
    end

    def reset_auth_config
      # Remove authentication settings from config
      config = @config_manager.load_config rescue {}
      config.delete(:host)
      config.delete(:username)
      config.delete(:auth_type)
      @config_manager.save_config(config)

      # Remove .env file
      env_file = CLI::SecretsManager::ENV_FILE_PATH
      File.delete(env_file) if File.exist?(env_file)
    end

    def auth_configured?
      return false unless @config_manager.config_file_exists?
      
      config = @config_manager.load_config rescue {}
      return false unless config[:host] && config[:username] && config[:auth_type]
      
      CLI::SecretsManager.auth_secrets_available?(config[:auth_type])
    end

    def load_secrets
      CLI::SecretsManager.load_env_file
      {
        'CLEANBOX_CLIENT_ID' => ENV['CLEANBOX_CLIENT_ID'],
        'CLEANBOX_CLIENT_SECRET' => ENV['CLEANBOX_CLIENT_SECRET'],
        'CLEANBOX_TENANT_ID' => ENV['CLEANBOX_TENANT_ID'],
        'CLEANBOX_PASSWORD' => ENV['CLEANBOX_PASSWORD']
      }
    end

    def secret(name)
      CLI::SecretsManager.value_from_env_or_secrets(name)
    end

    # Helper methods for user input
    def prompt(message, default: nil, secret: false)
      loop do
        if default
          print "#{message} [#{default}]: "
        else
          print "#{message}: "
        end
        
        input = if secret
          system('stty -echo')
          result = gets.chomp
          system('stty echo')
          puts
          result
        else
          gets.chomp
        end
        
        input = default if input.empty? && default
        
        if block_given?
          if yield(input)
            return input
          else
            puts "❌ Invalid input. Please try again."
          end
        else
          return input
        end
      end
    end

    def prompt_with_default(message, default)
      prompt(message, default: default) { |input| !input.empty? }
    end

    def prompt_choice(message, choices)
      puts "#{message}:"
      choices.each_with_index do |choice, index|
        puts "  #{index + 1}. #{choice[:label]}"
      end
      
      loop do
        print "Choice (1-#{choices.length}): "
        choice = gets.chomp.to_i
        
        if choice >= 1 && choice <= choices.length
          return choices[choice - 1][:key]
        else
          puts "❌ Invalid choice. Please enter 1-#{choices.length}."
        end
      end
    end
  end
end 