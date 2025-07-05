# frozen_string_literal: true

module CLI
  class SecretsManager
    DEFAULT_SECRETS_PATH = '/var/run/secrets/'

    def self.value_from_env_or_secrets(variable)
      val = ENV[variable.to_s.upcase] || password_from_secrets(variable.to_s)
      val.chomp if val.present?
    end

    def self.password_from_secrets(variable)
      secret_file = "#{secrets_path}#{variable}"
      return unless File.exist?(secret_file)

      File.read(secret_file).chomp
    end

    def self.secrets_path
      ENV.fetch('SECRETS_PATH') { DEFAULT_SECRETS_PATH }
    end
  end
end 