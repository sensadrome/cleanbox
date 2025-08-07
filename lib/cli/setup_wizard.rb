# frozen_string_literal: true

require 'net/imap'
require_relative 'config_manager'
require_relative 'secrets_manager'
require_relative 'auth_cli'
require_relative '../i18n_config'
require_relative '../auth/authentication_manager'
require_relative '../analysis/email_analyzer'
require_relative '../analysis/folder_categorizer'
require_relative '../analysis/domain_mapper'
require_relative '../configuration'
require_relative 'setup_wizard/interactive_prompts'
require_relative 'setup_wizard/configuration_handler'
require_relative 'setup_wizard/connection_setup'
require_relative 'setup_wizard/analysis_processor'
require_relative 'setup_wizard/workflow_orchestrator'

module CLI
  class SetupWizard
    include SetupWizardModules::InteractivePrompts
    include SetupWizardModules::ConfigurationHandler
    include SetupWizardModules::ConnectionSetup
    include SetupWizardModules::AnalysisProcessor
    include SetupWizardModules::WorkflowOrchestrator

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
  end
end
