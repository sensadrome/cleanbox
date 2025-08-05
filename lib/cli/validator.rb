# frozen_string_literal: true

module CLI
  class Validator
    class << self
      def validate_required_options!(options)
        validate_host!(options)
        validate_username!(options)
        validate_auth_requirements!(options)
      end

      private

      def validate_host!(options)
        if options[:host].blank?
          $stderr.puts "Error: IMAP host is required. Set it in ~/.cleanbox.yml or use --host option."
          exit 1
        end
      end

      def validate_username!(options)
        if options[:username].blank?
          $stderr.puts "Error: IMAP username is required. Set it in ~/.cleanbox.yml or use --user option."
          exit 1
        end
      end

      def validate_auth_requirements!(options)
        auth_type = Auth::AuthenticationManager.determine_auth_type(options[:host], options[:auth_type])
        
        case auth_type
        when 'oauth2_microsoft'
          validate_microsoft_oauth2!(options)
        when 'oauth2_microsoft_user'
          validate_microsoft_user_oauth2!(options)
        when 'password'
          validate_password_auth!(options)
        end
      end

      def validate_microsoft_oauth2!(options)
        if options[:client_id].blank? || options[:client_secret].blank? || options[:tenant_id].blank?
          $stderr.puts "Error: OAuth2 Microsoft requires client_id, client_secret, and tenant_id."
          $stderr.puts "Set them in environment variables or secrets."
          exit 1
        end
      end

      def validate_microsoft_user_oauth2!(options)
        # User-based OAuth2 doesn't require client credentials - they use default app
        # Validation is handled by checking if valid tokens exist
        true
      end

      def validate_password_auth!(options)
        if options[:password].blank?
          $stderr.puts "Error: Password authentication requires password."
          $stderr.puts "Set it in environment variables or secrets."
          exit 1
        end
      end
    end
  end
end 