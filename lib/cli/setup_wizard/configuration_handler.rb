# frozen_string_literal: true

require 'i18n'
require_relative '../../configuration'

module CLI
  module SetupWizardModules
    # Handles configuration file operations and management for the setup wizard
    module ConfigurationHandler
      def can_create_or_overwrite_configuration?
        @update_mode = false

        return true unless File.exist?(Configuration.config_file_path)

        case update_file_response
        when '1'
          @update_mode = true
          puts I18n.t('setup_wizard.existing_config.update_analysis')
          puts ''
        when '2'
          @update_mode = false
          puts I18n.t('setup_wizard.existing_config.complete_setup')
          puts ''
        when '3'
          puts I18n.t('setup_wizard.existing_config.setup_cancelled')
          return false
        else
          puts I18n.t('setup_wizard.existing_config.invalid_choice')
          return false
        end

        true
      end

      def authentication_setup?
        return true if auth_configured?

        case setup_auth_response
        when '1'
          puts I18n.t('setup_wizard.authentication.setup_choice')
          puts ''
          auth_cli = CLI::AuthCLI.new
          auth_cli.send(:setup_auth)
          puts ''
        when '2'
          puts I18n.t('setup_wizard.authentication.skip_choice')
          puts ''
        when '3'
          puts I18n.t('setup_wizard.existing_config.setup_cancelled')
          return false
        else
          puts I18n.t('setup_wizard.existing_config.invalid_choice')
          return false
        end

        true
      end

      def save_configuration(final_config, connection_details, secrets)
        display_saving_message
        handle_secrets_file(secrets)

        config = configuration_for_mode
        update_configuration_for_mode(config, final_config, connection_details)
        save_and_display_results(config)
      end

      def validate_and_preview(final_config)
        display_validation_message
        show_configuration_summary(final_config)
        return unless prompt_for_preview?

        handle_preview_response
      end

      private

      def auth_configured?
        return false unless Configuration.config_loaded?

        config = Configuration.options
        return false unless config[:host] && config[:username] && config[:auth_type]

        CLI::SecretsManager.auth_secrets_available?(config[:auth_type], data_dir: Configuration.data_dir)
      end

      def update_file_response
        puts I18n.t('setup_wizard.existing_config.prompt')
        puts ''
        puts I18n.t('setup_wizard.existing_config.choice_prompt')
        gets.chomp.strip
      end

      def setup_auth_response
        puts I18n.t('setup_wizard.authentication.not_configured')
        puts ''
        puts I18n.t('setup_wizard.existing_config.choice_prompt')
        gets.chomp.strip
      end

      # Set sensible defaults for other configuration options
      def default_config
        {
          sent_folder: detect_sent_folder || 'Sent Items',
          file_unread: false,
          sent_since_months: 24,
          valid_since_months: 12,
          list_since_months: 12,
          verbose: false,
          level: 'info',
          log_file: nil,
          data_dir: nil
        }
      end

      def display_saving_message
        puts ''
        puts I18n.t('setup_wizard.configuration.saving')
      end

      def handle_secrets_file(secrets)
        # Create .env file for sensitive credentials (only if not in update mode)
        CLI::SecretsManager.create_env_file(secrets) unless @update_mode
      end

      def configuration_for_mode
        # Load existing config or create new
        @update_mode ? Configuration.options : {}
      end

      def update_configuration_for_mode(config, final_config, connection_details)
        if @update_mode
          # In update mode, only update folder-related settings
          config.merge!({
                          whitelist_folders: final_config[:whitelist_folders],
                          list_folders: final_config[:list_folders],
                          list_domain_map: final_config[:domain_mappings]
                        })
          puts I18n.t('setup_wizard.configuration.updated_analysis')
        else
          # In full setup mode, update everything
          config.merge!(connection_details)
          config.merge!(default_config)
          config.merge!({
                          whitelist_folders: final_config[:whitelist_folders],
                          list_folders: final_config[:list_folders],
                          list_domain_map: final_config[:domain_mappings]
                        })
          puts I18n.t('setup_wizard.configuration.created_configuration')
        end
      end

      def save_and_display_results(config)
        # Save configuration
        config_manager.save_config(config)

        puts I18n.t('setup_wizard.configuration.config_saved_to', path: config_manager.config_path)
        puts ''
        puts I18n.t('setup_wizard.configuration.security_note')
      end

      def display_validation_message
        puts ''
        puts I18n.t('setup_wizard.configuration.validating')
      end

      def show_configuration_summary(final_config)
        # Show summary
        puts I18n.t('setup_wizard.configuration.summary')
        puts I18n.t('setup_wizard.configuration.whitelist_folders_summary',
                    folders: final_config[:whitelist_folders].join(', '))
        puts I18n.t('setup_wizard.configuration.list_folders_summary', folders: final_config[:list_folders].join(', '))
        puts I18n.t('setup_wizard.configuration.domain_mappings_summary', count: final_config[:domain_mappings].length)
      end

      def prompt_for_preview?
        puts ''
        puts I18n.t('setup_wizard.configuration.preview_prompt')
        preview = gets.chomp.strip.downcase

        %w[y yes].include?(preview)
      end

      def handle_preview_response
        puts ''
        puts I18n.t('setup_wizard.configuration.running_preview')
        system('./cleanbox clean --pretend --verbose')
      end
    end
  end
end
