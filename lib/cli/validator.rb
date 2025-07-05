# frozen_string_literal: true

module CLI
  class Validator
    def self.validate_required_options!(options)
      validate_host!(options)
      validate_username!(options)
      validate_auth_requirements!(options)
    end

    private

    def self.validate_host!(options)
      if options[:host].blank?
        puts "Error: IMAP host is required. Set it in ~/.cleanbox.yml or use --host option."
        exit 1
      end
    end

    def self.validate_username!(options)
      if options[:username].blank?
        puts "Error: IMAP username is required. Set it in ~/.cleanbox.yml or use --user option."
        exit 1
      end
    end

    def self.validate_auth_requirements!(options)
      auth_type = Auth::AuthenticationManager.determine_auth_type(options[:host], options[:auth_type])
      
      case auth_type
      when 'oauth2_microsoft'
        validate_microsoft_oauth2!(options)
      when 'password'
        validate_password_auth!(options)
      end
    end

    def self.validate_microsoft_oauth2!(options)
      if options[:client_id].blank? || options[:client_secret].blank? || options[:tenant_id].blank?
        puts "Error: OAuth2 Microsoft requires client_id, client_secret, and tenant_id."
        puts "Set them in environment variables or secrets."
        exit 1
      end
    end

    def self.validate_password_auth!(options)
      if options[:password].blank?
        puts "Error: Password authentication requires password."
        puts "Set it in environment variables or secrets."
        exit 1
      end
    end
  end
end 