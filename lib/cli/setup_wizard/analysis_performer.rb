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
        progress_callback = lambda do |current, total, folder_name|
          percentage = (current.to_f / total * 100).round(1)
          # Clear the line and write progress
          $stdout.print "\r\033[K  📈 Progress: #{percentage}% (#{current}/#{total}) - #{folder_name}"
          $stdout.flush
        end

        folder_results = analyzer.analyze_folders(progress_callback)
        folders_for_categorization = folder_results[:folders]

        # Now do interactive categorization (alphabetically sorted)
        @analysis_results[:folders] = interactive_folder_categorization(folders_for_categorization.sort_by do |f|
          f[:name].downcase
        end)
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
          folder_categorizer_class: Analysis::FolderCategorizer,
          analysis_mode: analysis_mode_for_update,
          blacklist_folder: @blacklist_folder
        )
      end

      def generate_recommendations
        puts I18n.t('setup_wizard.recommendations.generating')
        puts ''

        analyzer.generate_recommendations(domain_mapper_class: Analysis::DomainMapper)
      end

      private

      def analysis_mode_for_update
        return :full unless @update_mode

        prompt_for_analysis_mode
      end

      def prompt_for_analysis_mode
        puts I18n.t('setup_wizard.analysis.mode_choice_prompt')
        puts ''

        choice = gets.chomp.strip.downcase

        case choice
        when '1', 'full'
          :full
        when '2', 'partial'
          :partial
        when '3', 'skip'
          :skip
        else
          puts I18n.t('setup_wizard.analysis.invalid_mode_choice')
          prompt_for_analysis_mode # Recursive call for invalid input
        end
      end
    end
  end
end
