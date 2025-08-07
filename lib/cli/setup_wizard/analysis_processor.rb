# frozen_string_literal: true

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

      private

      def categorize_single_folder(folder)
        initial_categorization, reason = display_folder_analysis(folder)
        final_categorization = get_user_categorization_choice(folder, initial_categorization)
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
        
        [initial_categorization, reason]
      end

      def get_user_categorization_choice(folder, initial_categorization)
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

      def generate_recommendations
        puts I18n.t('setup_wizard.recommendations.generating')
        puts ''

        # Use the new EmailAnalyzer to generate recommendations
        analyzer = Analysis::EmailAnalyzer.new(
          @imap_connection,
          logger: @logger,
          folder_categorizer_class: Analysis::FolderCategorizer
        )

        # Set the analysis results so the analyzer can use them
        analyzer.instance_variable_set(:@analysis_results, @analysis_results)

        analyzer.generate_recommendations(domain_mapper_class: Analysis::DomainMapper)
      end

      def interactive_configuration(recommendations)
        puts I18n.t('setup_wizard.recommendations.configuration')
        puts ''

        final_config = {
          whitelist_folders: [],
          list_folders: [],
          domain_mappings: {}
        }

        # Sent items analysis
        if recommendations[:frequent_correspondents].any?
          puts I18n.t('setup_wizard.recommendations.frequent_correspondents')
          recommendations[:frequent_correspondents].first(10).each do |email, count|
            puts I18n.t('setup_wizard.recommendations.correspondent_entry', email: email, count: count)
          end
          puts ''
        end

        # Whitelist folders
        puts I18n.t('setup_wizard.recommendations.whitelist_folders')
        recommendations[:whitelist_folders].each do |folder_name|
          folder = @analysis_results[:folders].find { |f| f[:name] == folder_name }
          puts I18n.t('setup_wizard.recommendations.folder_entry', folder_name: folder_name,
                                                                   message_count: folder[:message_count])
        end

        puts ''
        puts I18n.t('setup_wizard.recommendations.add_whitelist_prompt')
        additional_whitelist = gets.chomp.strip
        if additional_whitelist && !additional_whitelist.empty?
          final_config[:whitelist_folders] =
            recommendations[:whitelist_folders] + additional_whitelist.split(',').map(&:strip)
        else
          final_config[:whitelist_folders] = recommendations[:whitelist_folders]
        end

        # List folders
        puts ''
        puts I18n.t('setup_wizard.recommendations.list_folders')
        recommendations[:list_folders].each do |folder_name|
          folder = @analysis_results[:folders].find { |f| f[:name] == folder_name }
          puts I18n.t('setup_wizard.recommendations.folder_entry', folder_name: folder_name,
                                                                   message_count: folder[:message_count])
        end

        puts ''
        puts I18n.t('setup_wizard.recommendations.add_list_prompt')
        additional_list = gets.chomp.strip
        final_config[:list_folders] = if additional_list && !additional_list.empty?
                                        recommendations[:list_folders] + additional_list.split(',').map(&:strip)
                                      else
                                        recommendations[:list_folders]
                                      end

        # Domain mappings
        if recommendations[:domain_mappings].any?
          puts ''
          puts I18n.t('setup_wizard.recommendations.domain_mappings')
          puts ''
          puts I18n.t('setup_wizard.domain_mappings.explanation')
          puts ''
          puts I18n.t('setup_wizard.domain_mappings.suggested_mappings')
          recommendations[:domain_mappings].each do |domain, folder|
            puts I18n.t('setup_wizard.domain_mappings.mapping_entry', domain: domain, folder: folder)
          end

          puts ''
          puts I18n.t('setup_wizard.domain_mappings.customize_prompt')
          custom_mappings = gets.chomp.strip
          if custom_mappings && !custom_mappings.empty?
            custom_mappings.split(',').each do |mapping|
              domain, folder = mapping.split('=')
              final_config[:domain_mappings][domain.strip] = folder.strip if domain && folder
            end
          else
            final_config[:domain_mappings] = recommendations[:domain_mappings]
          end
        end

        final_config
      end
    end
  end
end
