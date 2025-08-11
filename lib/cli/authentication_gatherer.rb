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
      @connection_details[:host] = prompt_with_default('IMAP Host', default_host) do |host|
        host.match?(/\.(com|org|net|edu)$/) || host.include?('.')
      end

      # Username
      @connection_details[:username] = prompt('Email Address') do |email|
        email.include?('@')
      end

      # Authentication type
      auth_type = prompt_choice('Authentication Method', [
                                  { key: 'oauth2_microsoft_user', label: 'OAuth2 (Microsoft 365 - User-based)' },
                                  { key: 'oauth2_microsoft', label: 'OAuth2 (Microsoft 365 - Application-level)' },
                                  { key: 'password', label: 'Password (IMAP)' }
                                ])
      @connection_details[:auth_type] = auth_type
    end

    def gather_credentials_based_on_auth_type
      case @connection_details[:auth_type]
      when 'oauth2_microsoft_user'
        # User-based OAuth2 - no secrets needed, will use default client_id
        puts ''
        puts 'ℹ️  Using default OAuth2 client for user-based authentication.'
        puts '   Users will be prompted to consent to permissions.'
        puts ''
      when 'oauth2_microsoft'
        @secrets['CLEANBOX_CLIENT_ID'] = prompt('OAuth2 Client ID') { |id| !id.empty? }
        @secrets['CLEANBOX_CLIENT_SECRET'] = prompt('OAuth2 Client Secret', secret: true) { |id| !id.empty? }
        @secrets['CLEANBOX_TENANT_ID'] = prompt('OAuth2 Tenant ID') { |id| !id.empty? }
      else
        @secrets['CLEANBOX_PASSWORD'] = prompt('IMAP Password', secret: true) { |pwd| !pwd.empty? }
      end
    end
  end
end 