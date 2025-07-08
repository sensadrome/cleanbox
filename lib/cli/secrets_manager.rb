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
        
        # Simple .env file parser
        File.readlines(ENV_FILE_PATH).each do |line|
          line.strip!
          next if line.empty? || line.start_with?('#')
          
          if line.include?('=')
            key, value = line.split('=', 2)
            ENV[key.strip] = value.strip.gsub(/^["']|["']$/, '') # Remove quotes
          end
        end
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