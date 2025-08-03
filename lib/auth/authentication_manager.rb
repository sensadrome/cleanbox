# frozen_string_literal: true

require_relative '../microsoft_365_application_token'
require_relative '../microsoft_365_user_token'

module Auth
  class AuthenticationManager
    class << self
      def data_dir=(dir)
        @data_dir = dir
      end

      def data_dir
        @data_dir || Dir.home
      end

      def token_data_dir
        # For tokens, always use home directory unless explicitly set to a custom directory
        if @data_dir && @data_dir != Dir.pwd
          @data_dir
        else
          Dir.home
        end
      end

      def determine_auth_type(host, auth_type)
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

      def authenticate_imap(imap, options)
        auth_type = determine_auth_type(options[:host], options[:auth_type])
        
        case auth_type
        when 'oauth2_microsoft'
          authenticate_microsoft_oauth2(imap, options)
        when 'oauth2_microsoft_user'
          authenticate_microsoft_user_oauth2(imap, options)
        when 'oauth2_gmail'
          authenticate_gmail_oauth2(imap, options)
        when 'password'
          authenticate_password(imap, options)
        else
          raise "Unknown authentication type: #{auth_type}"
        end
      end

      def default_token_file(username)
        # Sanitize username for filename
        safe_username = username.gsub(/[^a-zA-Z0-9]/, '_')
        
        # Use .cleanbox/tokens for home directory, just tokens for custom data directory
        if token_data_dir == Dir.home
          File.join(token_data_dir, '.cleanbox', 'tokens', "#{safe_username}.json")
        else
          File.join(token_data_dir, 'tokens', "#{safe_username}.json")
        end
      end

      private

      def authenticate_microsoft_oauth2(imap, options)
        token_request = Microsoft365ApplicationToken.new(
          options[:client_id], 
          options[:client_secret], 
          options[:tenant_id],
          logger: options[:logger]
        )
        imap.authenticate('XOAUTH2', options[:username], token_request.token)
      end

      def authenticate_microsoft_user_oauth2(imap, options)
        user_token = Microsoft365UserToken.new(
          client_id: options[:client_id],
          logger: options[:logger]
        )
        
        # Try to load existing tokens
        token_file = options[:token_file] || default_token_file(options[:username])
        if user_token.load_tokens_from_file(token_file)
          access_token = user_token.token
          if access_token
            imap.authenticate('XOAUTH2', options[:username], access_token)
            return
          end
        end
        
        raise "No valid tokens found. Please run 'cleanbox auth setup' to authenticate."
      end

      def authenticate_gmail_oauth2(imap, options)
        # TODO: Implement Gmail OAuth2 when needed
        raise "Gmail OAuth2 not yet implemented"
      end

      def authenticate_password(imap, options)
        imap.authenticate('PLAIN', options[:username], options[:password])
      end
    end
  end
end 