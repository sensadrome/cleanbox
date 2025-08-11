# frozen_string_literal: true

# generate_recommendations

require 'i18n'
require_relative '../../analysis/email_analyzer'
require_relative '../../analysis/folder_categorizer'
require_relative '../../analysis/domain_mapper'

module CLI
  module SetupWizardModules
    # Handles email analysis, folder categorization, and recommendation generation
    module AnalysisPerformer
      def run_analysis
        initialize_analysis

        perform_folder_analysis
        perform_sent_analysis
        perform_domain_analysis

        display_analysis_complete
      end

      def initialize_analysis
        puts I18n.t('setup_wizard.analysis.starting')
        puts ''
      end

      def perform_folder_analysis
        # Get the raw folder data first
        folder_results = analyzer.analyze_folders
        raw_folders = folder_results[:folders]

        # Now do interactive categorization
        @analysis_results[:folders] = interactive_folder_categorization(raw_folders)
      end

      def perform_sent_analysis
        puts I18n.t('setup_wizard.analysis.analyzing_sent_emails')
        @analysis_results[:sent_items] = analyzer.analyze_sent_items
      end

      def perform_domain_analysis
        puts I18n.t('setup_wizard.analysis.analyzing_domains')
        @analysis_results[:domain_patterns] = analyzer.analyze_domain_patterns
      end

      def display_analysis_complete
        puts I18n.t('setup_wizard.analysis.analysis_complete')
        puts ''
      end

      def analyzer
        @analyzer ||= Analysis::EmailAnalyzer.new(
          @imap_connection,
          logger: @logger,
          folder_categorizer_class: Analysis::FolderCategorizer
        )
      end

      def generate_recommendations
        puts I18n.t('setup_wizard.recommendations.generating')
        puts ''

        analyzer.generate_recommendations(domain_mapper_class: Analysis::DomainMapper)
      end
    end
  end
end
