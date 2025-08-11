# frozen_string_literal: true

require 'i18n'
require 'net/imap'
require_relative '../../auth/authentication_manager'
require_relative '../authentication_gatherer'

module CLI
  module SetupWizardModules
    # Handles IMAP connection and credentials management for the setup wizard
    module ConnectionSetup
      def retrieve_connection_details
        display_connection_setup_message
        initialize_connection_data

        if @update_mode
          # Use existing config in update mode
          puts I18n.t('setup_wizard.connection.using_existing_settings')
          setup_authentication_from_existing(Configuration.options)
        else
          # Use AuthenticationGatherer for full setup mode
          setup_authentication_with_gatherer
        end
      end

      def display_connection_setup_message
        puts I18n.t('setup_wizard.connection.setup')
        puts ''
      end

      def initialize_connection_data
        @details = {}
        @secrets = {}
      end

      def setup_authentication_with_gatherer
        gatherer = CLI::AuthenticationGatherer.new
        gatherer.gather_authentication_details!

        @details = gatherer.connection_details
        @secrets = gatherer.secrets
      end

      def setup_authentication_from_existing(existing_config)
        # Validate that the existing config has all required fields
        validate_existing_config!(existing_config)
        
        @details[:host] = existing_config[:host]
        @details[:username] = existing_config[:username]
        @details[:auth_type] = auth_type_from_config(existing_config)
        puts I18n.t('setup_wizard.connection.using_env_credentials')
      end

      def validate_existing_config!(existing_config)
        missing_fields = []
        missing_fields << 'host' if existing_config[:host].blank?
        missing_fields << 'username' if existing_config[:username].blank?
        missing_fields << 'auth_type' if existing_config[:auth_type].blank?
        
        if missing_fields.any?
          puts I18n.t('setup_wizard.connection.config_incomplete', missing_fields: missing_fields.join(', '))
          raise ArgumentError, "Configuration is incomplete: missing #{missing_fields.join(', ')}"
        end
      end

      def auth_type_from_config(existing_config)
        existing_config[:auth_type].tap do |auth_type|
          puts I18n.t('setup_wizard.connection.auth_from_config', auth_type: auth_type)
        end
      end

      def establish_imap_connection
        puts I18n.t('setup_wizard.connection.connecting_to', host: @details[:host])

        # Temporarily set environment variables for authentication
        # @secrets.each { |key, value| ENV[key] = value }

        # Create options hash using the same pattern as CleanboxCLI
        options = initial_options.merge(@details)

        # Create IMAP connection
        @imap_connection = Net::IMAP.new(@details[:host], ssl: true)
        Auth::AuthenticationManager.authenticate_imap(@imap_connection, options)

        puts I18n.t('setup_wizard.connection.connection_success')
        puts ''
      end

      def initial_options
        {
          host: '',
          username: nil,
          auth_type: nil, # oauth2_microsoft, oauth2_microsoft_user, oauth2_gmail, password
          client_id: secret(:client_id),
          client_secret: secret(:client_secret),
          tenant_id: secret(:tenant_id),
          password: secret(:password)
        }
      end

      def secret(name)
        key = "CLEANBOX_#{name.to_s.upcase}"
        return @secrets[key] unless @secrets[key].blank?

        CLI::SecretsManager.value_from_env_or_secrets(name)
      end
    end
  end
end
