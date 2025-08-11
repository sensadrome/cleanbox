# frozen_string_literal: true

# generate_recommendations

require 'i18n'
require_relative '../../analysis/email_analyzer'
require_relative '../../analysis/folder_categorizer'
require_relative '../../analysis/domain_mapper'

module CLI
  module SetupWizardModules
    # Handles email analysis, folder categorization, and recommendation generation
    module AnalysisProcessor
      def interactive_folder_categorization(folders)
        folders.map { |folder| categorize_single_folder(folder) }
      end

      def categorize_single_folder(folder)
        initial_categorization = display_folder_analysis(folder)
        final_categorization = user_categorization_choice(initial_categorization)
        folder[:categorization] = final_categorization
        folder
      end

      def display_folder_analysis(folder)
        name = folder[:name]
        message_count = folder[:message_count]

        puts ''
        puts I18n.t('setup_wizard.analysis.analyzing_folder', name: name, message_count: message_count)

        categorizer = Analysis::FolderCategorizer.new(
          folder,
          imap_connection: @imap_connection,
          logger: @logger
        )

        initial_categorization = categorizer.categorization
        reason = categorizer.categorization_reason

        puts I18n.t('setup_wizard.analysis.folder_categorization',
                    category: initial_categorization.upcase, reason: reason)

        initial_categorization
      end

      def user_categorization_choice(initial_categorization)
        puts I18n.t('setup_wizard.analysis.accept_categorization_prompt',
                    choice: initial_categorization[0].upcase)
        response = gets.chomp.strip.downcase

        process_categorization_response(response, initial_categorization)
      end

      def process_categorization_response(response, initial_categorization)
        case response
        when '', 'y', 'yes'
          initial_categorization
        when 'n', 'no'
          handle_manual_categorization(initial_categorization)
        when 'l'
          :list
        when 'w'
          :whitelist
        when 's'
          :skip
        else
          puts I18n.t('setup_wizard.analysis.invalid_choice_default',
                      category: initial_categorization)
          initial_categorization
        end
      end

      def handle_manual_categorization(initial_categorization)
        puts I18n.t('setup_wizard.analysis.manual_categorization_prompt')
        choice = gets.chomp.strip.downcase

        case choice
        when 'l'
          :list
        when 'w'
          :whitelist
        when 's'
          :skip
        else
          puts I18n.t('setup_wizard.analysis.invalid_choice_default',
                      category: initial_categorization)
          initial_categorization
        end
      end
    end
  end
end
