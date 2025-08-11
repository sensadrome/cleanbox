# frozen_string_literal: true

module CLI
  # Validate connection options
  class Validator
    class << self
      def validate_required_options!(options, secrets)
        validate_host!(options)
        validate_username!(options)
        secrets.each { |key, value| ENV[key] = value }
        auth_requirements_valid?(options).tap do
          secrets.each_key { |key| ENV.delete(key) }
        end
      end

      private

      def validate_host!(options)
        return unless options[:host].blank?

        warn 'Error: IMAP host is required. Set it in ~/.cleanbox.yml or use --host option.'
        exit 1
      end

      def validate_username!(options)
        return unless options[:username].blank?

        warn 'Error: IMAP username is required. Set it in ~/.cleanbox.yml or use --user option.'
        exit 1
      end

      def auth_requirements_valid?(options)
        case options[:auth_type]
        when 'oauth2_microsoft'
          validate_microsoft_oauth2!(options)
        when 'oauth2_microsoft_user'
          # validate_microsoft_user_oauth2!(options)
          true
        when 'password'
          validate_password_auth!(options)
        end
      end

      def validate_microsoft_oauth2!(options)
        return unless options[:client_id].blank? || options[:client_secret].blank? || options[:tenant_id].blank?

        warn 'Error: OAuth2 Microsoft requires client_id, client_secret, and tenant_id.'
        warn 'Set them in environment variables or secrets.'
        exit 1
      end

      def validate_microsoft_user_oauth2!(_options)
        # User-based OAuth2 doesn't require client credentials - they use default app
        # Validation is handled by checking if valid tokens exist
        true
      end

      def validate_password_auth!(options)
        return unless options[:password].blank?

        warn 'Error: Password authentication requires password.'
        warn 'Set it in environment variables or secrets.'
        exit 1
      end
    end
  end
end
