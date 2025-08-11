# frozen_string_literal: true

require 'net/imap'
require_relative 'interactive_prompts'
require_relative 'config_manager'
require_relative 'secrets_manager'
require_relative 'auth_cli'
require_relative '../i18n_config'
require_relative '../auth/authentication_manager'
require_relative '../analysis/email_analyzer'
require_relative '../analysis/folder_categorizer'
require_relative '../analysis/domain_mapper'
require_relative '../configuration'
require_relative 'setup_wizard/workflow_orchestrator'
require_relative 'setup_wizard/configuration_handler'
require_relative 'setup_wizard/connection_setup'
require_relative 'setup_wizard/analysis_performer'
require_relative 'setup_wizard/analysis_processor'
require_relative 'setup_wizard/interactive_configuration'

module CLI
  # Handles the whole setup wizard
  class SetupWizard
    include SetupWizardModules::WorkflowOrchestrator
    include InteractivePrompts
    include SetupWizardModules::ConfigurationHandler
    include SetupWizardModules::ConnectionSetup
    include SetupWizardModules::AnalysisPerformer
    include SetupWizardModules::AnalysisProcessor
    include SetupWizardModules::InteractiveConfiguration

    attr_reader :imap_connection, :provider, :verbose, :update_mode

    def initialize(verbose: false)
      @analysis_results = {}
      @verbose = verbose
      @logger = Logger.new($stdout)
      @logger.level = verbose ? Logger::DEBUG : Logger::INFO
    end

    def config_manager
      @config_manager ||= ConfigManager.new
    end

    def detect_sent_folder
      # Use the same logic as the main Cleanbox class
      imap_folders.detect { |f| f.attr.include?(:Sent) }&.name
    end

    def imap_folders
      @imap_folders ||= @imap_connection.list('', '*')
    end

    def display_testing_message
      puts ''
      puts I18n.t('setup_wizard.connection.testing_connection')
    end
  end
end
