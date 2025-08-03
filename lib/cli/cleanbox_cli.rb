# frozen_string_literal: true

require 'net/imap'
require_relative 'config_manager'
require_relative 'cli_parser'
require_relative 'validator'
require_relative 'secrets_manager'
require_relative 'setup_wizard'
require_relative 'analyzer_cli'
require_relative 'sent_analysis_cli'
require_relative 'auth_cli'
require_relative '../auth/authentication_manager'

module CLI
  class CleanboxCLI
    attr_reader :options, :config_manager
    def initialize
      @options = default_options
      parse_options
      @config_manager = ConfigManager.new(nil, data_dir)
      load_config
    end

    def run
      parse_options
      handle_auth_command
      handle_setup_command
      handle_analyze_command
      handle_sent_analysis_command
      update_config_manager_if_needed
      handle_config_command
      handle_no_args_help
      validate_options
      execute_action
    end

    private

    def resolve_data_dir
      # If explicitly set, use it (convert to absolute if relative)
      if @options[:data_dir]
        File.expand_path(@options[:data_dir])
      else
        # Otherwise, fall back to working directory
        Dir.pwd
      end
    end

    def data_dir
      @data_dir ||= resolve_data_dir
    end

    def default_options
      {
        host: '',
        username: nil,
        auth_type: nil,  # oauth2_microsoft, oauth2_gmail, password
        whitelist_folders: [],
        whitelisted_domains: [],
        list_domains: [],
        list_folders: [],
        list_domain_map: {},

        sent_folder: 'Sent Items',
        file_unread: false,
        client_id: secret(:client_id),
        client_secret: secret(:client_secret),
        tenant_id: secret(:tenant_id),
        password: secret(:password),
        unjunk: false,
        unjunk_folders: [],
        file_from_folders: [],
        sent_since_months: 24,
        valid_since_months: 12,
        list_since_months: 12,
        data_dir: nil,
        brief: false,
        detailed: false,
        analysis_folder: nil
      }
    end

    def load_config
      config_options = @config_manager.load_config
      @options = @options.deep_merge(config_options)
    end

    def parse_options
      CLI::CLIParser.new(@options).parse!
    end

    def handle_auth_command
      return unless ARGV.first == 'auth'
      ARGV.delete('auth')  # Remove 'auth' from ARGV
      subcommand = ARGV.pop  # Get and remove the subcommand, leaving ARGV empty
      CLI::AuthCLI.new(data_dir: data_dir, config_path: @options[:config_file]).run(subcommand)
      exit 0
    end

    def handle_config_command
      return unless ARGV.first == 'config'
      
      # Extract config subcommand and arguments
      config_args = ARGV[1..-1]
      
      # Check if --all flag is present in the original ARGV
      show_all = ARGV.include?('--all')
      
      # Remove --all from config_args if present (to avoid double processing)
      config_args = config_args.reject { |arg| arg == '--all' }
      
      # Pass the show_all flag to the config manager
      @config_manager.handle_command(config_args, show_all: show_all)
      exit 0
    end

    def handle_setup_command
      return unless ARGV.first == 'setup'
      ARGV.delete('setup')  # Remove 'setup' from ARGV so it doesn't interfere with STDIN
      CLI::SetupWizard.new(verbose: @options[:verbose]).run
      exit 0
    end

    def handle_analyze_command
      return unless ARGV.first == 'analyze'
      ARGV.delete('analyze')  # Remove 'analyze' from ARGV
      
      # Create IMAP connection for analysis
      imap = create_imap_connection
      
      # Set the data directory for cache operations
      CleanboxFolderChecker.data_dir = data_dir
      
      # Set the data directory for domain rules
      Analysis::DomainMapper.data_dir = data_dir
      
      # Set the data directory for authentication tokens
      Auth::AuthenticationManager.data_dir = data_dir
      
      # Run analysis
      CLI::AnalyzerCLI.new(imap, @options).run
      exit 0
    end

    def handle_sent_analysis_command
      return unless ARGV.first == 'sent-analysis'
      ARGV.delete('sent-analysis')  # Remove 'sent-analysis' from ARGV
      
      # Create IMAP connection for analysis
      imap = create_imap_connection
      
      # Set the data directory for cache operations
      CleanboxFolderChecker.data_dir = data_dir
      
      # Set the data directory for domain rules
      Analysis::DomainMapper.data_dir = data_dir
      
      # Set the data directory for authentication tokens
      Auth::AuthenticationManager.data_dir = data_dir
      
      # Run sent analysis
      CLI::SentAnalysisCLI.new(imap, @options).run
      exit 0
    end

    def handle_no_args_help
      return unless ARGV.empty? && !@options[:unjunk]
      show_help
      exit 0
    end

    def validate_options
      CLI::Validator.validate_required_options!(@options)
    end

    def execute_action
      action = determine_action
      imap = create_imap_connection
      
      # Set the data directory for cache operations
      CleanboxFolderChecker.data_dir = data_dir
      
      # Set the data directory for domain rules
      Analysis::DomainMapper.data_dir = data_dir
      
      # Set the data directory for authentication tokens
      Auth::AuthenticationManager.data_dir = data_dir
      
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

    def update_config_manager_if_needed
      return unless @options[:config_file]
      
      # Create new config manager with specified config file
      @config_manager = ConfigManager.new(@options[:config_file], data_dir)
      load_config
    end

    def show_help
      puts "Cleanbox - Intelligent Email Management"
      puts "======================================="
      puts ""
      puts "Cleanbox learns from your existing email organization to automatically"
      puts "clean your inbox, file messages, and manage spam."
      puts ""
      puts "Quick Start:"
      puts "  ./cleanbox setup          # Interactive setup wizard"
      puts "  ./cleanbox --pretend      # Preview what would happen"
      puts "  ./cleanbox clean          # Clean your inbox"
      puts ""
      puts "Common Commands:"
      puts "  ./cleanbox --help         # Show detailed help"
      puts "  ./cleanbox auth setup     # Set up authentication"
      puts "  ./cleanbox auth test      # Test authentication"
      puts "  ./cleanbox setup          # Interactive setup wizard"
      puts "  ./cleanbox analyze        # Analyze email patterns"
      puts "  ./cleanbox sent-analysis  # Analyze sent vs folder patterns"
      puts "  ./cleanbox config show    # Show current configuration"
      puts "  ./cleanbox --pretend      # Preview without making changes"
      puts "  ./cleanbox clean          # Clean your inbox"
      puts "  ./cleanbox file           # File existing inbox messages"
      puts "  ./cleanbox list           # Show email-to-folder mappings"
      puts "  ./cleanbox folders        # List all folders"
      puts ""
      puts "For detailed help and all options:"
      puts "  ./cleanbox --help"
      puts ""
    end

    # Secret retrieval method
    def secret(name)
      CLI::SecretsManager.value_from_env_or_secrets(name)
    end
  end
end 