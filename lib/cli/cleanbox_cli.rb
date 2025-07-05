# frozen_string_literal: true

require 'net/imap'
require_relative 'config_manager'
require_relative 'cli_parser'
require_relative 'validator'
require_relative 'secrets_manager'
require_relative '../auth/authentication_manager'

module CLI
  class CleanboxCLI
    def initialize
      @config_manager = ConfigManager.new
      @options = default_options
      load_config
    end

    def run
      parse_options
      handle_config_command
      validate_options
      execute_action
    end

    private

    def default_options
      {
        host: '',
        username: nil,
        auth_type: nil,  # oauth2_microsoft, oauth2_gmail, password
        clean_folders: [],
        whitelisted_domains: [],
        list_domains: [],
        list_folders: [],
        domain_map: {},
        pretend: false,
        sent_folder: 'Sent Items',
        move_read: false,
        client_id: secret(:client_id),
        client_secret: secret(:client_secret),
        tenant_id: secret(:tenant_id),
        password: secret(:password),
        unjunk: false,
        unjunk_folders: [],
        file_from_folders: []
      }
    end

      def load_config
        config_options = @config_manager.load_config
        @options = @options.deep_merge(config_options)
      end

      def parse_options
        CLI::CLIParser.new(@options).parse!
      end

      def handle_config_command
        return unless ARGV.first == 'config'
        @config_manager.handle_command(ARGV[1..-1])
        exit 0
      end

      def validate_options
        CLI::Validator.validate_required_options!(@options)
      end

      def execute_action
        action = determine_action
        imap = create_imap_connection
        Cleanbox.new(imap, @options).send(action)
      end

      def determine_action
        return 'unjunk!' if @options[:unjunk]
        return 'show_lists!' if ARGV.last == 'list'
        return 'file_messages!' if %w[file filing].include?(ARGV.last)
        return 'show_folders!' if ARGV.last == 'folders'
        
        'clean!'  # default action
      end

      def create_imap_connection
        host = @options.delete(:host)
        imap = Net::IMAP.new(host, ssl: true)
        Auth::AuthenticationManager.authenticate_imap(imap, @options)
        imap
      end

      # Secret retrieval method
      def secret(name)
        CLI::SecretsManager.value_from_env_or_secrets(name)
      end
    end
  end 