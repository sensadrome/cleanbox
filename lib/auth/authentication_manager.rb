# frozen_string_literal: true

require_relative '../microsoft_365_application_token'

module Auth
  class AuthenticationManager
    def self.determine_auth_type(host, auth_type)
      return auth_type if auth_type.present?
      
        # Auto-detect based on host
        case host
        when /outlook\.office365\.com/
          'oauth2_microsoft'
        when /imap\.gmail\.com/
          'oauth2_gmail'
        else
          'password'  # Default to password auth for other IMAP servers
        end
      end

      def self.authenticate_imap(imap, options)
        auth_type = determine_auth_type(options[:host], options[:auth_type])
        
        case auth_type
        when 'oauth2_microsoft'
          authenticate_microsoft_oauth2(imap, options)
        when 'oauth2_gmail'
          authenticate_gmail_oauth2(imap, options)
        when 'password'
          authenticate_password(imap, options)
        else
          raise "Unknown authentication type: #{auth_type}"
        end
      end

      private

      def self.authenticate_microsoft_oauth2(imap, options)
        token_request = Microsoft365ApplicationToken.new(
          options[:client_id], 
          options[:client_secret], 
          options[:tenant_id]
          )
        imap.authenticate('XOAUTH2', options[:username], token_request.token)
      end

      def self.authenticate_gmail_oauth2(imap, options)
        # TODO: Implement Gmail OAuth2 when needed
        raise "Gmail OAuth2 not yet implemented"
      end

      def self.authenticate_password(imap, options)
        imap.authenticate('PLAIN', options[:username], options[:password])
      end
    end
  end 