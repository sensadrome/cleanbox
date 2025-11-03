# frozen_string_literal: true

require 'net/imap'
require 'securerandom'
require_relative '../configuration'
require_relative 'config_manager'
require_relative 'secrets_manager'
require_relative '../auth/authentication_manager'
require_relative 'authentication_gatherer'

module CLI
  class AuthCLI
    include InteractivePrompts
    
    def initialize
      @logger = Logger.new($stdout)
    end

    def config
      Configuration.options
    end

    def data_dir
      Configuration.data_dir
    end

    def config_manager
      @config_manager ||= ConfigManager.new
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
      puts '🔐 Cleanbox Authentication Setup'
      puts '================================'
      puts ''

      # Check for existing configuration
      if auth_configured?
        puts '⚠️  Authentication is already configured!'
        puts ''
        puts 'What would you like to do?'
        puts '  1. Update authentication settings'
        puts '  2. Test current authentication'
        puts '  3. Cancel'
        puts ''
        print 'Choice (1-3): '
        response = gets.chomp.strip

        case response
        when '1'
          puts '✅ Will update authentication settings.'
          puts ''
        when '2'
          test_auth
          return
        when '3'
          puts 'Setup cancelled.'
          return
        else
          puts 'Invalid choice. Setup cancelled.'
          return
        end
      end

      # Get connection details
      connection_data = connection_details
      return unless connection_data

      # Test connection or setup OAuth2
      puts ''
      if connection_data[:details][:auth_type] == 'oauth2_microsoft_user'
        setup_user_oauth2(connection_data[:details])
      else
        puts '🔍 Testing connection...'
        unless test_connection(connection_data[:details], connection_data[:secrets])
          puts '❌ Connection test failed. Please check your credentials and try again.'
          return
        end

        # Save configuration
        save_auth_config(connection_data[:details], connection_data[:secrets])
      end

      puts ''
      puts '✅ Authentication setup complete!'
      puts 'You can now run:'
      puts '  ./cleanbox auth test    # Test your connection'
      puts '  ./cleanbox auth show    # View current settings'
      puts '  ./cleanbox setup        # Complete setup wizard'
    end

    def test_auth
      puts '🔍 Testing Authentication'
      puts '========================'
      puts ''

      unless auth_configured?
        puts '❌ No authentication configuration found.'
        puts "Run './cleanbox auth setup' to configure authentication."
        return
      end

      secrets = load_secrets

      puts "Testing connection to #{config[:host]}..."

      if test_connection(config, secrets)
        puts '✅ Authentication successful!'
        puts "Username: #{config[:username]}"
        puts "Host: #{config[:host]}"
        puts "Auth Type: #{config[:auth_type]}"
      else
        puts '❌ Authentication failed!'
        puts "Please check your credentials and run './cleanbox auth setup' to update them."
      end
    end

    def show_auth
      puts '📋 Authentication Configuration'
      puts '==============================='
      puts ''

      unless Configuration.config_loaded?
        puts '❌ No configuration file found.'
        puts "Run './cleanbox auth setup' to configure authentication."
        return
      end

      unless config[:host] && config[:username] && config[:auth_type]
        puts '❌ Incomplete authentication configuration.'
        puts "Missing: #{%i[host username auth_type].reject { |k| config[k] }.join(', ')}"
        puts "Run './cleanbox auth setup' to complete configuration."
        return
      end

      puts "Host: #{config[:host]}"
      puts "Username: #{config[:username]}"
      puts "Auth Type: #{config[:auth_type]}"
      puts ''

      # Check secrets status
      secrets_status = CLI::SecretsManager.auth_secrets_status(config[:auth_type], data_dir: data_dir)

      if secrets_status[:configured]
        puts '✅ Credentials: Configured'
        puts "Source: #{secrets_status[:source]}"
      else
        puts '❌ Credentials: Missing'
        puts "Missing: #{secrets_status[:missing].join(', ')}"
        puts "Source: #{secrets_status[:source]}"
        puts ''
        puts 'To fix this:'
        case secrets_status[:source]
        when 'none'
          puts "  Run './cleanbox auth setup' to configure credentials"
        when 'env_file'
          puts "  Check your .env file at #{CLI::SecretsManager::ENV_FILE_PATH}"
          puts '  Ensure it contains the required variables'
        when 'environment'
          puts '  Check your environment variables'
          puts '  Ensure CLEANBOX_* variables are set correctly'
        end
      end

      puts ''
      puts "Configuration file: #{Configuration.config_file_path}"
      puts "Secrets file: #{CLI::SecretsManager::ENV_FILE_PATH}"
    end

    def reset_auth
      puts '🔄 Reset Authentication Configuration'
      puts '===================================='
      puts ''

      unless auth_configured?
        puts '❌ No authentication configuration found.'
        return
      end

      puts '⚠️  This will remove all authentication configuration!'
      puts 'This includes:'
      puts '  - Connection settings from config file'
      puts '  - Credentials from .env file'
      puts ''
      print 'Are you sure? (y/N): '
      response = gets.chomp.strip.downcase

      if %w[y yes].include?(response)
        reset_auth_config
        puts '✅ Authentication configuration has been reset.'
        puts "Run './cleanbox auth setup' to configure authentication again."
      else
        puts 'Reset cancelled.'
      end
    end

    def show_help
      puts 'Cleanbox Authentication Commands'
      puts '================================'
      puts ''
      puts 'Usage: ./cleanbox auth <command>'
      puts ''
      puts 'Commands:'
      puts '  setup    Interactive authentication setup'
      puts '  test     Test current authentication credentials'
      puts '  show     Display current authentication configuration'
      puts '  reset    Reset authentication configuration'
      puts ''
      puts 'Examples:'
      puts '  ./cleanbox auth setup    # Set up authentication'
      puts '  ./cleanbox auth test     # Test your connection'
      puts '  ./cleanbox auth show     # View current settings'
      puts ''
    end

    def connection_details
      @gatherer ||= AuthenticationGatherer.new
      @gatherer.gather_authentication_details!
      { details: @gatherer.connection_details, secrets: @gatherer.secrets }
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
      imap.list('', '*')
      imap.logout
      imap.disconnect

      true
    rescue StandardError => e
      @logger.error "Connection test failed: #{e.message}"
      false
    end

    def save_auth_config(details, secrets)
      # Create .env file for sensitive credentials
      CLI::SecretsManager.create_env_file(secrets)

      # Load existing config or create new
      config = begin
        config_manager.load_config
      rescue StandardError
        {}
      end

      # Update with authentication settings
      config.merge!(details)

      # Save configuration
      config_manager.save_config(config)

      puts '✅ Authentication configuration saved'
      puts "Configuration file: #{config_manager.config_path}"
      puts "Secrets file: #{CLI::SecretsManager::ENV_FILE_PATH}"
    end

    def reset_auth_config
      # Remove authentication settings from config
      config = Configuration.options
      config.delete(:host)
      config.delete(:username)
      config.delete(:auth_type)
      config_manager.save_config(config)

      # Remove .env file
      env_file = CLI::SecretsManager::ENV_FILE_PATH
      FileUtils.rm_f(env_file)
    end

    def auth_configured?
      return false unless Configuration.config_loaded?
      return false unless config[:host] && config[:username] && config[:auth_type]

      CLI::SecretsManager.auth_secrets_available?(config[:auth_type], data_dir: data_dir)
    end

    def load_secrets
      CLI::SecretsManager.load_env_file
      {
        'CLEANBOX_CLIENT_ID' => ENV.fetch('CLEANBOX_CLIENT_ID', nil),
        'CLEANBOX_CLIENT_SECRET' => ENV.fetch('CLEANBOX_CLIENT_SECRET', nil),
        'CLEANBOX_TENANT_ID' => ENV.fetch('CLEANBOX_TENANT_ID', nil),
        'CLEANBOX_PASSWORD' => ENV.fetch('CLEANBOX_PASSWORD', nil)
      }
    end

    def secret(name)
      CLI::SecretsManager.value_from_env_or_secrets(name)
    end



    def setup_user_oauth2(details)
      require_relative '../microsoft_365_user_token'
      require_relative '../oauth/local_callback_server'

      puts '🔐 Microsoft 365 User-based OAuth2 Setup'
      puts '========================================'
      puts ''

      flow = select_user_oauth_flow
      redirect_uri = user_oauth_redirect_uri(flow)

      user_token = Microsoft365UserToken.new(logger: @logger, redirect_uri: redirect_uri)

      state = SecureRandom.hex(16)
      auth_url = user_token.authorization_url(state: state)

      puts 'Please visit this URL to authorize Cleanbox:'
      puts ''
      puts auth_url
      puts ''

      authorization_code = if flow == :automatic
                              obtain_authorization_code_via_callback(redirect_uri, state)
                            else
                              obtain_authorization_code_manually
                            end

      unless authorization_code
        puts '❌ OAuth2 setup cancelled. No authorization code received.'
        return
      end

      puts ''
      puts '🔄 Exchanging authorization code for tokens...'

      begin
        if user_token.exchange_code_for_tokens(authorization_code)
          token_file = default_token_file(details[:username])
          user_token.save_tokens_to_file(token_file)

          config = begin
            config_manager.load_config
          rescue StandardError
            {}
          end
          config.merge!(details)
          config_manager.save_config(config)

          puts '✅ OAuth2 setup successful!'
          puts "✅ Tokens saved to: #{token_file}"
          puts "✅ Configuration saved to: #{config_manager.config_path}"
          puts ''
          puts 'You can now run:'
          puts '  ./cleanbox auth test    # Test your connection'
          puts '  ./cleanbox auth show    # View current settings'
          puts '  ./cleanbox setup        # Complete setup wizard'
        else
          puts '❌ Failed to exchange authorization code for tokens.'
          puts 'Please check the authorization code and try again.'
        end
      rescue StandardError => e
        puts "❌ OAuth2 setup failed: #{e.message}"
        puts 'Please try again or contact support if the problem persists.'
      end
    end

    def default_token_file(username)
      # Sanitize username for filename
      safe_username = username.gsub(/[^a-zA-Z0-9]/, '_')
      File.join(Dir.home, '.cleanbox', 'tokens', "#{safe_username}.json")
    end

    def select_user_oauth_flow
      env_value = ENV['CLEANBOX_AUTH_MANUAL']
      return :manual if truthy?(env_value)
      return :automatic if falsey?(env_value)

      puts 'Select authorization flow:'
      puts '  1. Automatic callback (requires access to http://localhost:4567)'
      puts '  2. Manual code entry (use when browser cannot reach localhost)'
      print 'Choice (1-2): '

      choice = gets&.chomp&.strip
      choice == '2' ? :manual : :automatic
    end

    def user_oauth_redirect_uri(flow)
      if flow == :manual
        Microsoft365UserToken::NATIVE_CLIENT_REDIRECT_URI
      else
        ENV.fetch('CLEANBOX_OAUTH_REDIRECT_URI', Microsoft365UserToken::DEFAULT_REDIRECT_URI)
      end
    end

    def obtain_authorization_code_manually
      puts "After you grant permissions, copy the 'code' parameter from the browser's address bar."
      print 'Authorization code: '
      authorization_code = gets&.chomp&.strip

      if authorization_code.to_s.empty?
        puts '❌ No authorization code provided.'
        nil
      else
        authorization_code
      end
    end

    def obtain_authorization_code_via_callback(redirect_uri, state)
      puts "After you grant permissions, Cleanbox will listen on #{redirect_uri} to receive the authorization response."
      puts 'If you are running inside a container or over SSH, ensure the port is forwarded.'
      puts ''
      puts 'Waiting for authorization callback (Ctrl+C to cancel)...'

      callback_server = OAuth::LocalCallbackServer.new(
        redirect_uri: redirect_uri,
        expected_state: state,
        logger: @logger,
        timeout: oauth_callback_timeout
      )

      callback_server.wait_for_authorization_code
    rescue OAuth::LocalCallbackServer::CallbackTimeoutError => e
      puts "❌ #{e.message}"
      nil
    rescue OAuth::LocalCallbackServer::CallbackServerError => e
      puts "❌ Authorization callback failed: #{e.message}"
      nil
    rescue Interrupt
      puts "\n❌ Authorization cancelled by user."
      nil
    end

    def oauth_callback_timeout
      timeout_env = ENV['CLEANBOX_OAUTH_CALLBACK_TIMEOUT']
      return OAuth::LocalCallbackServer::DEFAULT_TIMEOUT unless timeout_env

      Integer(timeout_env)
    rescue ArgumentError
      @logger&.warn("Invalid CLEANBOX_OAUTH_CALLBACK_TIMEOUT value '#{timeout_env}', using default.")
      OAuth::LocalCallbackServer::DEFAULT_TIMEOUT
    end

    def truthy?(value)
      %w[1 true yes y].include?(value.to_s.strip.downcase)
    end

    def falsey?(value)
      return false unless value
      %w[0 false no n automatic auto].include?(value.to_s.strip.downcase)
    end
  end
end
