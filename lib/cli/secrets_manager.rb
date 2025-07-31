# frozen_string_literal: true

require 'dotenv'

module CLI
  class SecretsManager
    DEFAULT_SECRETS_PATH = '/var/run/secrets/'
    ENV_FILE_PATH = File.expand_path('.env')

    class << self
      def value_from_env_or_secrets(variable)
        # Load .env file if it exists
        load_env_file
        
        # Check environment variable first
        env_var = "CLEANBOX_#{variable.to_s.upcase}"
        val = ENV[env_var] || ENV[variable.to_s.upcase] || password_from_secrets(variable.to_s)
        val.chomp if val.present?
      end

      def load_env_file
        return unless File.exist?(ENV_FILE_PATH)
        
        # Use the dotenv gem to load the .env file
        Dotenv.load(ENV_FILE_PATH)
      end

      def create_env_file(secrets)
        env_content = []
        env_content << "# Cleanbox Environment Variables"
        env_content << "# ============================="
        env_content << "# This file contains sensitive credentials for Cleanbox."
        env_content << "# DO NOT commit this file to version control!"
        env_content << "#"
        env_content << ""
        
        secrets.each do |key, value|
          next if value.nil? || value.empty?
          env_content << "#{key}=#{value}"
        end
        
        File.write(ENV_FILE_PATH, env_content.join("\n"))
        puts "✅ Created .env file with sensitive credentials"
        puts "   Location: #{ENV_FILE_PATH}"
        puts "   Note: This file is already in .gitignore"
      end

      def auth_secrets_available?(auth_type)
        load_env_file
        
        case auth_type
        when 'oauth2_microsoft'
          !!(ENV['CLEANBOX_CLIENT_ID'] && ENV['CLEANBOX_CLIENT_SECRET'] && ENV['CLEANBOX_TENANT_ID'])
        when 'password'
          !!ENV['CLEANBOX_PASSWORD']
        else
          false
        end
      end

      def auth_secrets_status(auth_type)
        # Store original environment state before loading .env file
        original_env = {}
        case auth_type
        when 'oauth2_microsoft'
          ['CLEANBOX_CLIENT_ID', 'CLEANBOX_CLIENT_SECRET', 'CLEANBOX_TENANT_ID'].each do |var|
            original_env[var] = ENV[var] if ENV.key?(var)
          end
        when 'password'
          original_env['CLEANBOX_PASSWORD'] = ENV['CLEANBOX_PASSWORD'] if ENV.key?('CLEANBOX_PASSWORD')
        end
        
        load_env_file
        
        case auth_type
        when 'oauth2_microsoft'
          {
            configured: !!(ENV['CLEANBOX_CLIENT_ID'] && ENV['CLEANBOX_CLIENT_SECRET'] && ENV['CLEANBOX_TENANT_ID']),
            missing: [
              ('client_id' unless ENV['CLEANBOX_CLIENT_ID']),
              ('client_secret' unless ENV['CLEANBOX_CLIENT_SECRET']),
              ('tenant_id' unless ENV['CLEANBOX_TENANT_ID'])
            ].compact,
            source: detect_secret_source_with_original(['CLEANBOX_CLIENT_ID', 'CLEANBOX_CLIENT_SECRET', 'CLEANBOX_TENANT_ID'], original_env)
          }
        when 'password'
          {
            configured: !!ENV['CLEANBOX_PASSWORD'],
            missing: ENV['CLEANBOX_PASSWORD'] ? [] : ['password'],
            source: detect_secret_source_with_original(['CLEANBOX_PASSWORD'], original_env)
          }
        else
          { configured: false, missing: ['unknown_auth_type'], source: 'unknown' }
        end
      end

      def detect_secret_source(env_vars)
        if env_vars.any? { |var| ENV[var] }
          'environment'
        elsif File.exist?(ENV_FILE_PATH)
          'env_file'
        else
          'none'
        end
      end

      def detect_secret_source_with_original(env_vars, original_env)
        # Check if any of the variables were originally in the environment
        # (before loading .env file)
        if env_vars.any? { |var| original_env.key?(var) }
          'environment'
        elsif File.exist?(ENV_FILE_PATH)
          'env_file'
        else
          'none'
        end
      end

      private

      def password_from_secrets(variable)
        secret_file = "#{secrets_path}#{variable}"
        return unless File.exist?(secret_file)

        File.read(secret_file).chomp
      end

      def secrets_path
        ENV.fetch('SECRETS_PATH') { DEFAULT_SECRETS_PATH }
      end
    end
  end
end 