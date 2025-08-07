# frozen_string_literal: true

require 'i18n'
require 'net/imap'
require_relative '../../auth/authentication_manager'

module CLI
  module SetupWizardModules
    # Handles IMAP connection and credentials management for the setup wizard
    module ConnectionSetup
      def retrieve_connection_details
        puts I18n.t('setup_wizard.connection.setup')
        puts ''

        details = {}
        secrets = {}

        # Load existing config if in update mode or if auth is already configured
        existing_config = {}
        if @update_mode || auth_configured?
          existing_config = Configuration.options
          puts I18n.t('setup_wizard.connection.using_existing_settings')
          puts ''
        end

        # Host
        default_host = existing_config[:host] || 'outlook.office365.com'
        if @update_mode && existing_config[:host]
          details[:host] = existing_config[:host]
          puts I18n.t('setup_wizard.connection.host_from_config', host: existing_config[:host])
        else
          details[:host] = prompt_with_default('IMAP Host', default_host) do |host|
            host.match?(/\.(com|org|net|edu)$/) || host.include?('.')
          end
        end

        # Username
        default_username = existing_config[:username]
        if @update_mode && default_username
          details[:username] = default_username
          puts I18n.t('setup_wizard.connection.username_from_config', username: default_username)
        else
          details[:username] = prompt('Email Address') do |email|
            email.include?('@')
          end
        end

        # Authentication type
        default_auth_type = existing_config[:auth_type]
        if @update_mode && default_auth_type
          details[:auth_type] = default_auth_type
          puts I18n.t('setup_wizard.connection.auth_from_config', auth_type: default_auth_type)
        else
          auth_type = prompt_choice('Authentication Method', [
                                      { key: 'oauth2_microsoft_user',
                                        label: 'OAuth2 (Microsoft 365 User - Recommended)' },
                                      { key: 'oauth2_microsoft', label: 'OAuth2 (Microsoft 365 Application)' },
                                      { key: 'password', label: 'Password (IMAP)' }
                                    ])
          details[:auth_type] = auth_type
        end

        # Credentials - in update mode, use existing .env file
        if @update_mode
          puts I18n.t('setup_wizard.connection.using_env_credentials')
        else
          case details[:auth_type]
          when 'oauth2_microsoft'
            secrets['CLEANBOX_CLIENT_ID'] = prompt('OAuth2 Client ID') { |id| !id.empty? }
            secrets['CLEANBOX_CLIENT_SECRET'] = prompt('OAuth2 Client Secret', secret: true) { |id| !id.empty? }
            secrets['CLEANBOX_TENANT_ID'] = prompt('OAuth2 Tenant ID') { |id| !id.empty? }
          when 'oauth2_microsoft_user'
            puts I18n.t('setup_wizard.connection.oauth2_info')
          when 'password'
            secrets['CLEANBOX_PASSWORD'] = prompt('IMAP Password', secret: true) { |pwd| !pwd.empty? }
          end
        end

        puts ''
        puts I18n.t('setup_wizard.connection.testing_connection')

        { details: details, secrets: secrets }
      end

      def connect_and_analyze(connection_details, secrets)
        puts I18n.t('setup_wizard.connection.connecting_to', host: connection_details[:host])

        # Temporarily set environment variables for authentication
        secrets.each { |key, value| ENV[key] = value }

        # Create options hash using the same pattern as CleanboxCLI
        options = default_options.merge(connection_details)

        # Create IMAP connection
        @imap_connection = Net::IMAP.new(connection_details[:host], ssl: true)
        Auth::AuthenticationManager.authenticate_imap(@imap_connection, options)

        puts I18n.t('setup_wizard.connection.connection_success')
        puts ''

        # Analyze folders
        puts I18n.t('setup_wizard.analysis.starting')
        puts ''

        # Use the new EmailAnalyzer
        analyzer = Analysis::EmailAnalyzer.new(
          @imap_connection,
          logger: @logger,
          folder_categorizer_class: Analysis::FolderCategorizer
        )

        # Get the raw folder data first
        folder_results = analyzer.analyze_folders
        raw_folders = folder_results[:folders]

        # Now do interactive categorization
        @analysis_results[:folders] = interactive_folder_categorization(raw_folders)

        # Analyze sent items
        puts I18n.t('setup_wizard.analysis.analyzing_sent_emails')
        @analysis_results[:sent_items] = analyzer.analyze_sent_items

        # Analyze domain patterns
        puts I18n.t('setup_wizard.analysis.analyzing_domains')
        @analysis_results[:domain_patterns] = analyzer.analyze_domain_patterns

        puts I18n.t('setup_wizard.analysis.analysis_complete')
        puts ''
      end

      def default_options
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

      def detect_sent_folder
        # Use the same logic as the main Cleanbox class
        imap_folders.detect { |f| f.attr.include?(:Sent) }&.name
      end

      def imap_folders
        @imap_folders ||= @imap_connection.list('', '*')
      end
    end
  end
end
