# frozen_string_literal: true

require 'i18n'
require 'net/imap'
require_relative '../../auth/authentication_manager'

module CLI
  module SetupWizardModules
    # Handles IMAP connection and credentials management for the setup wizard
    module ConnectionSetup
      def retrieve_connection_details
        display_connection_setup_message
        initialize_connection_data
        existing_config = handle_existing_config
        setup_authentication(existing_config)
        setup_credentials
      end

      def display_connection_setup_message
        puts I18n.t('setup_wizard.connection.setup')
        puts ''
      end

      def initialize_connection_data
        @details = {}
        @secrets = {}
      end

      def handle_existing_config
        existing_config = {}
        if @update_mode || auth_configured?
          existing_config = Configuration.options
          puts I18n.t('setup_wizard.connection.using_existing_settings')
          puts ''
        end
        existing_config
      end

      def setup_authentication(existing_config)
        @details[:host] = setup_host(existing_config)
        @details[:username] = setup_username(existing_config)
        @details[:auth_type] = setup_auth_type(existing_config)
      end

      def setup_host(existing_config)
        default_host = existing_config[:host] || 'outlook.office365.com'
        if @update_mode && existing_config[:host]
          puts I18n.t('setup_wizard.connection.host_from_config', host: existing_config[:host])
          existing_config[:host]
        else
          prompt_with_default('IMAP Host', default_host) do |host|
            host.match?(/\.(com|org|net|edu)$/) || host.include?('.')
          end
        end
      end

      def setup_username(existing_config)
        default_username = existing_config[:username]
        if @update_mode && default_username
          puts I18n.t('setup_wizard.connection.username_from_config', username: default_username)
          default_username
        else
          prompt('Email Address') do |email|
            email.include?('@')
          end
        end
      end

      def setup_auth_type(existing_config)
        default_auth_type = existing_config[:auth_type]
        if @update_mode && default_auth_type
          puts I18n.t('setup_wizard.connection.auth_from_config', auth_type: default_auth_type)
          default_auth_type
        else
          prompt_choice('Authentication Method', [
                          { key: 'oauth2_microsoft_user', label: 'OAuth2 (Microsoft 365 User - Recommended)' },
                          { key: 'oauth2_microsoft', label: 'OAuth2 (Microsoft 365 Application)' },
                          { key: 'password', label: 'Password (IMAP)' }
                        ])
        end
      end

      def setup_credentials
        if @update_mode
          puts I18n.t('setup_wizard.connection.using_env_credentials')
        else
          case @details[:auth_type]
          when 'oauth2_microsoft'
            setup_oauth2_microsoft_credentials
          when 'oauth2_microsoft_user'
            puts I18n.t('setup_wizard.connection.oauth2_info')
          when 'password'
            setup_password_credentials
          end
        end
      end

      def setup_oauth2_microsoft_credentials
        @secrets['CLEANBOX_CLIENT_ID'] = prompt('OAuth2 Client ID') { |id| !id.empty? }
        @secrets['CLEANBOX_CLIENT_SECRET'] = prompt('OAuth2 Client Secret', secret: true) { |id| !id.empty? }
        @secrets['CLEANBOX_TENANT_ID'] = prompt('OAuth2 Tenant ID') { |id| !id.empty? }
      end

      def setup_password_credentials
        @secrets['CLEANBOX_PASSWORD'] = prompt('IMAP Password', secret: true) { |pwd| !pwd.empty? }
      end

      def establish_imap_connection
        puts I18n.t('setup_wizard.connection.connecting_to', host: @details[:host])

        # Temporarily set environment variables for authentication
        @secrets.each { |key, value| ENV[key] = value }

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
        CLI::SecretsManager.value_from_env_or_secrets(name)
      end
    end
  end
end
