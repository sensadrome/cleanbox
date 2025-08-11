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
      default_host = 'outlook.office365.com'
      @connection_details[:host] = prompt_with_default(I18n.t('cli.authentication_gatherer.prompts.imap_host'), default_host) do |host|
        host.match?(/\.(com|org|net|edu)$/) || host.include?('.')
      end

      # Username
      @connection_details[:username] = prompt(I18n.t('cli.authentication_gatherer.prompts.email_address')) do |email|
        email.include?('@')
      end

      # Authentication type
      auth_type = prompt_choice(I18n.t('cli.authentication_gatherer.prompts.authentication_method'), [
                                  { key: 'oauth2_microsoft_user', label: I18n.t('cli.authentication_gatherer.choices.oauth2_user_based') },
                                  { key: 'oauth2_microsoft', label: I18n.t('cli.authentication_gatherer.choices.oauth2_application') },
                                  { key: 'password', label: I18n.t('cli.authentication_gatherer.choices.password') }
                                ])
      @connection_details[:auth_type] = auth_type
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
        @secrets['CLEANBOX_CLIENT_ID'] = prompt(I18n.t('cli.authentication_gatherer.prompts.oauth2_client_id')) { |id| !id.empty? }
        @secrets['CLEANBOX_CLIENT_SECRET'] = prompt(I18n.t('cli.authentication_gatherer.prompts.oauth2_client_secret'), secret: true) { |id| !id.empty? }
        @secrets['CLEANBOX_TENANT_ID'] = prompt(I18n.t('cli.authentication_gatherer.prompts.oauth2_tenant_id')) { |id| !id.empty? }
      else
        @secrets['CLEANBOX_PASSWORD'] = prompt(I18n.t('cli.authentication_gatherer.prompts.imap_password'), secret: true) { |pwd| !pwd.empty? }
      end
    end
  end
end 