# frozen_string_literal: true

require 'i18n'
require_relative '../../configuration'

module CLI
  module SetupWizardModules
    # Handles configuration file operations and management for the setup wizard
    module InteractiveConfiguration
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

        retention_policy = prompt_for_retention_policy
        final_config[:retention_policy] = retention_policy

        # Configure retention policy specific settings
        configure_retention_policy_settings(final_config, retention_policy)

        # Add blacklist folder from workflow orchestrator
        final_config[:blacklist_folder] = @blacklist_folder if @blacklist_folder

        final_config
      end

      def prompt_for_retention_policy
        prompt_choice(I18n.t('setup_wizard.recommendations.retention_policy_prompt'), retention_policy_choices)
      end

      def retention_policy_choices
        retention_policy_options.map do |option|
          {
            key: option,
            label: I18n.t("setup_wizard.recommendations.retention_policy_options.#{option}")
          }
        end
      end

      def retention_policy_options
        %w[spammy hold quarantine paranoid]
      end

      def configure_retention_policy_settings(final_config, retention_policy)
        case retention_policy
        when :hold
          puts ''
          puts I18n.t('setup_wizard.retention_policy.hold_days_prompt')
          hold_days_input = gets.chomp.strip
          final_config[:hold_days] = hold_days_input.empty? ? 7 : hold_days_input.to_i
        when :quarantine
          puts ''
          puts I18n.t('setup_wizard.retention_policy.quarantine_folder_prompt')
          quarantine_folder_input = gets.chomp.strip
          final_config[:quarantine_folder] = quarantine_folder_input.empty? ? 'Quarantine' : quarantine_folder_input
        end
      end
    end
  end
end
