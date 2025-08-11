# frozen_string_literal: true

require_relative 'interactive_prompts'

module CLI
  # Handles gathering authentication details from user input
  # Encapsulates all the business logic for different auth types
  class AuthenticationGatherer
    include InteractivePrompts

    attr_reader :connection_details, :secrets

    def initialize
      @connection_details = {}
      @secrets = {}
    end

    def gather_authentication_details!
      gather_connection_details
      gather_credentials_based_on_auth_type
    end

    private

    def gather_connection_details
      # Host
      @connection_details[:host] = prompt_for_host

      # Username
      @connection_details[:username] = prompt_for_username

      # Authentication type
      @connection_details[:auth_type] = prompt_for_auth_type
    end

    def prompt_for_host
      default_host = 'outlook.office365.com'
      prompt_with_default(I18n.t('cli.authentication_gatherer.prompts.imap_host'), default_host) do |host|
        host.match?(/\.(com|org|net|edu)$/) || host.include?('.')
      end
    end

    def prompt_for_username
      prompt(I18n.t('cli.authentication_gatherer.prompts.email_address')) do |email|
        email.include?('@')
      end
    end

    def prompt_for_auth_type
      prompt_choice(I18n.t('cli.authentication_gatherer.prompts.authentication_method'), [
                      { key: 'oauth2_microsoft_user',
                        label: I18n.t('cli.authentication_gatherer.choices.oauth2_user_based') },
                      { key: 'oauth2_microsoft',
                        label: I18n.t('cli.authentication_gatherer.choices.oauth2_application') },
                      { key: 'password', label: I18n.t('cli.authentication_gatherer.choices.password') }
                    ])
    end

    def gather_credentials_based_on_auth_type
      case @connection_details[:auth_type]
      when 'oauth2_microsoft_user'
        # User-based OAuth2 - no secrets needed, will use default client_id
        puts ''
        puts I18n.t('cli.authentication_gatherer.oauth2_user_info')
        puts I18n.t('cli.authentication_gatherer.oauth2_user_info_details')
        puts ''
      when 'oauth2_microsoft'
        @secrets['CLEANBOX_CLIENT_ID'] = prompt_for_client_id
        @secrets['CLEANBOX_CLIENT_SECRET'] = prompt_for_client_secret
        @secrets['CLEANBOX_TENANT_ID'] = prompt_for_tenant_id
      else
        @secrets['CLEANBOX_PASSWORD'] = prompt_for_password
      end
    end

    def prompt_for_client_id
      prompt(I18n.t('cli.authentication_gatherer.prompts.oauth2_client_id')) { |id| !id.empty? }
    end

    def prompt_for_client_secret
      prompt(I18n.t('cli.authentication_gatherer.prompts.oauth2_client_secret'), secret: true) { |id| !id.empty? }
    end

    def prompt_for_tenant_id
      prompt(I18n.t('cli.authentication_gatherer.prompts.oauth2_tenant_id')) { |id| !id.empty? }
    end

    def prompt_for_password
      prompt(I18n.t('cli.authentication_gatherer.prompts.imap_password'), secret: true) { |pwd| !pwd.empty? }
    end
  end
end
