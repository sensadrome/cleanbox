# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe CLI::AuthCLI do
  let(:temp_dir) { Dir.mktmpdir }
  let(:config_path) { File.join(temp_dir, '.cleanbox.yml') }
  let(:env_path) { File.join(temp_dir, '.env') }
  let(:auth_cli) { described_class.new(data_dir: temp_dir, config_path: config_path) }

  before do
    # Set up the environment for testing
    stub_const('CLI::SecretsManager::ENV_FILE_PATH', env_path)
  end

  after do
    FileUtils.remove_entry temp_dir if Dir.exist?(temp_dir)
  end

  describe 'authentication configuration detection' do
    it 'detects when authentication is properly configured' do
      # Create a config file with auth settings
      File.write(config_path, YAML.dump({
        host: 'outlook.office365.com',
        username: 'test@example.com',
        auth_type: 'oauth2_microsoft'
      }))

      # Create an env file with secrets
      File.write(env_path, "CLEANBOX_CLIENT_ID=test_id\nCLEANBOX_CLIENT_SECRET=test_secret\nCLEANBOX_TENANT_ID=test_tenant")

      # Create AuthCLI with mocked config manager
      auth_cli = described_class.new(data_dir: temp_dir, config_path: config_path)
      
      # Mock the config manager to use our test files
      allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(true)
      allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
        host: 'outlook.office365.com',
        username: 'test@example.com',
        auth_type: 'oauth2_microsoft'
      })

      # Test that auth_configured? returns true
      expect(auth_cli.send(:auth_configured?)).to be true
    end

    it 'detects when authentication is missing' do
      # Create AuthCLI with mocked config manager
      auth_cli = described_class.new(data_dir: temp_dir, config_path: config_path)
      
      # Mock the config manager to return false for config_file_exists?
      allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(false)

      # Test that auth_configured? returns false
      expect(auth_cli.send(:auth_configured?)).to be false
    end

    it 'detects when config exists but credentials are missing' do
      # Create AuthCLI with mocked config manager
      auth_cli = described_class.new(data_dir: temp_dir, config_path: config_path)
      
      # Mock the config manager to return true for config_file_exists? but false for secrets
      allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(true)
      allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
        host: 'outlook.office365.com',
        username: 'test@example.com',
        auth_type: 'oauth2_microsoft'
      })
      allow(CLI::SecretsManager).to receive(:auth_secrets_available?).with('oauth2_microsoft').and_return(false)

      # Test that auth_configured? returns false when credentials are missing
      expect(auth_cli.send(:auth_configured?)).to be false
    end

    it 'detects when config exists but auth_type is missing' do
      # Create AuthCLI with mocked config manager
      auth_cli = described_class.new(data_dir: temp_dir, config_path: config_path)
      
      # Mock the config manager to return true for config_file_exists? but missing auth_type
      allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(true)
      allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
        host: 'outlook.office365.com',
        username: 'test@example.com'
        # Missing auth_type
      })

      # Test that auth_configured? returns false when auth_type is missing
      expect(auth_cli.send(:auth_configured?)).to be false
    end
  end

  describe 'secrets management' do
    it 'correctly detects available secrets' do
      # Clear any existing environment variables
      ENV.delete('CLEANBOX_PASSWORD')
      
      # Create an env file with secrets
      File.write(env_path, "CLEANBOX_CLIENT_ID=test_id\nCLEANBOX_CLIENT_SECRET=test_secret\nCLEANBOX_TENANT_ID=test_tenant")

      # Test the secrets manager directly
      expect(CLI::SecretsManager.auth_secrets_available?('oauth2_microsoft')).to be true
      expect(CLI::SecretsManager.auth_secrets_available?('password')).to be false
    end

    it 'correctly detects missing secrets' do
      # Clear any existing environment variables
      ENV.delete('CLEANBOX_CLIENT_ID')
      ENV.delete('CLEANBOX_CLIENT_SECRET')
      ENV.delete('CLEANBOX_CLIENT_TENANT_ID')
      ENV.delete('CLEANBOX_TENANT_ID')
      
      # Create an env file with only some secrets (missing tenant_id)
      File.write(env_path, "CLEANBOX_CLIENT_ID=test_id\nCLEANBOX_CLIENT_SECRET=test_secret")

      # Test the secrets manager directly
      expect(CLI::SecretsManager.auth_secrets_available?('oauth2_microsoft')).to be false
    end
  end

  describe '#save_auth_config' do
    let(:details) do
      {
        host: 'outlook.office365.com',
        username: 'test@example.com',
        auth_type: 'oauth2_microsoft'
      }
    end

    let(:secrets) do
      {
        'CLEANBOX_CLIENT_ID' => 'test_id',
        'CLEANBOX_CLIENT_SECRET' => 'test_secret',
        'CLEANBOX_TENANT_ID' => 'test_tenant'
      }
    end

    it 'saves auth settings to config and creates env file' do
      # Mock the config manager
      allow_any_instance_of(CLI::ConfigManager).to receive(:config_path).and_return(config_path)
      allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({})
      allow_any_instance_of(CLI::ConfigManager).to receive(:save_config) do |instance, config|
        File.write(config_path, config.to_yaml)
      end

      auth_cli.send(:save_auth_config, details, secrets)
      
      config = YAML.load_file(config_path)
      expect(config[:host]).to eq('outlook.office365.com')
      expect(config[:username]).to eq('test@example.com')
      expect(config[:auth_type]).to eq('oauth2_microsoft')
      
      env_content = File.read(env_path)
      expect(env_content).to include('CLEANBOX_CLIENT_ID=test_id')
      expect(env_content).to include('CLEANBOX_CLIENT_SECRET=test_secret')
      expect(env_content).to include('CLEANBOX_TENANT_ID=test_tenant')
    end
  end

  describe '#reset_auth_config' do
    before do
      # Create initial config with auth settings and other settings
      File.write(config_path, YAML.dump({
        host: 'outlook.office365.com',
        username: 'test@example.com',
        auth_type: 'oauth2_microsoft',
        whitelist_folders: ['Work'],
        list_folders: ['Newsletters']
      }))
      File.write(env_path, "CLEANBOX_CLIENT_ID=test_id\nCLEANBOX_CLIENT_SECRET=test_secret\nCLEANBOX_TENANT_ID=test_tenant")
    end

    it 'removes auth settings from config and deletes env file' do
      # Mock the config manager
      allow_any_instance_of(CLI::ConfigManager).to receive(:config_path).and_return(config_path)
      allow_any_instance_of(CLI::ConfigManager).to receive(:load_config) do
        YAML.load_file(config_path)
      end
      allow_any_instance_of(CLI::ConfigManager).to receive(:save_config) do |instance, config|
        File.write(config_path, config.to_yaml)
      end

      auth_cli.send(:reset_auth_config)
      
      config = YAML.load_file(config_path)
      expect(config[:host]).to be_nil
      expect(config[:username]).to be_nil
      expect(config[:auth_type]).to be_nil
      # The other settings should remain unchanged
      expect(config[:whitelist_folders]).to eq(['Work'])
      expect(config[:list_folders]).to eq(['Newsletters'])
      
      expect(File.exist?(env_path)).to be false
    end
  end

  describe '#run' do
    before do
      allow(auth_cli).to receive(:setup_auth)
      allow(auth_cli).to receive(:test_auth)
      allow(auth_cli).to receive(:show_auth)
      allow(auth_cli).to receive(:reset_auth)
      allow(auth_cli).to receive(:show_help)
    end

    it 'calls setup_auth when subcommand is setup' do
      ARGV.replace(['setup'])
      auth_cli.run
      expect(auth_cli).to have_received(:setup_auth)
    end

    it 'calls test_auth when subcommand is test' do
      ARGV.replace(['test'])
      auth_cli.run
      expect(auth_cli).to have_received(:test_auth)
    end

    it 'calls show_auth when subcommand is show' do
      ARGV.replace(['show'])
      auth_cli.run
      expect(auth_cli).to have_received(:show_auth)
    end

    it 'calls reset_auth when subcommand is reset' do
      ARGV.replace(['reset'])
      auth_cli.run
      expect(auth_cli).to have_received(:reset_auth)
    end

    it 'calls show_help for unknown subcommand' do
      ARGV.replace(['unknown'])
      auth_cli.run
      expect(auth_cli).to have_received(:show_help)
    end

    it 'calls show_help when no subcommand provided' do
      ARGV.replace([])
      auth_cli.run
      expect(auth_cli).to have_received(:show_help)
    end
  end

  describe '#setup_auth' do
    before do
      allow(auth_cli).to receive(:puts)
      allow(auth_cli).to receive(:print)
      allow(auth_cli).to receive(:gets).and_return('test_input')
      allow(auth_cli).to receive(:get_connection_details)
      allow(auth_cli).to receive(:test_connection)
      allow(auth_cli).to receive(:save_auth_config)
      allow(auth_cli).to receive(:test_auth)
    end

    context 'when authentication is already configured' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(true)
      end

      it 'offers to update settings when user chooses 1' do
        allow(auth_cli).to receive(:gets).and_return('1')
        allow(auth_cli).to receive(:get_connection_details).and_return({
          details: { host: 'test.com' },
          secrets: { 'CLEANBOX_PASSWORD' => 'test' }
        })
        allow(auth_cli).to receive(:test_connection).and_return(true)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:get_connection_details)
        expect(auth_cli).to have_received(:test_connection)
        expect(auth_cli).to have_received(:save_auth_config)
      end

      it 'calls test_auth when user chooses 2' do
        allow(auth_cli).to receive(:gets).and_return('2')

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:test_auth)
      end

      it 'cancels when user chooses 3' do
        allow(auth_cli).to receive(:gets).and_return('3')

        auth_cli.send(:setup_auth)

        expect(auth_cli).not_to have_received(:get_connection_details)
      end

      it 'cancels when user provides invalid input' do
        allow(auth_cli).to receive(:gets).and_return('invalid')

        auth_cli.send(:setup_auth)

        expect(auth_cli).not_to have_received(:get_connection_details)
      end
    end

    context 'when authentication is not configured' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(false)
      end

      it 'proceeds with setup when connection test succeeds' do
        allow(auth_cli).to receive(:get_connection_details).and_return({
          details: { host: 'test.com' },
          secrets: { 'CLEANBOX_PASSWORD' => 'test' }
        })
        allow(auth_cli).to receive(:test_connection).and_return(true)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:get_connection_details)
        expect(auth_cli).to have_received(:test_connection)
        expect(auth_cli).to have_received(:save_auth_config)
      end

      it 'fails when connection test fails' do
        allow(auth_cli).to receive(:get_connection_details).and_return({
          details: { host: 'test.com' },
          secrets: { 'CLEANBOX_PASSWORD' => 'test' }
        })
        allow(auth_cli).to receive(:test_connection).and_return(false)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:get_connection_details)
        expect(auth_cli).to have_received(:test_connection)
        expect(auth_cli).not_to have_received(:save_auth_config)
      end

      it 'fails when get_connection_details returns nil' do
        allow(auth_cli).to receive(:get_connection_details).and_return(nil)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:get_connection_details)
        expect(auth_cli).not_to have_received(:test_connection)
        expect(auth_cli).not_to have_received(:save_auth_config)
      end

      it 'fails when connection test fails due to missing credentials' do
        allow(auth_cli).to receive(:get_connection_details).and_return({
          details: { host: 'test.com', auth_type: 'oauth2_microsoft' },
          secrets: { 'CLEANBOX_CLIENT_ID' => 'test_id' }
          # Missing client_secret and tenant_id
        })
        allow(auth_cli).to receive(:test_connection).and_return(false)

        expect(auth_cli).to receive(:puts).with("❌ Connection test failed. Please check your credentials and try again.")

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:get_connection_details)
        expect(auth_cli).to have_received(:test_connection)
        expect(auth_cli).not_to have_received(:save_auth_config)
      end
    end
  end

  describe '#test_auth' do
    before do
      allow(auth_cli).to receive(:puts)
      allow(auth_cli).to receive(:test_connection)
    end

    context 'when authentication is configured' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(true)
        allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
          host: 'test.com',
          username: 'test@example.com',
          auth_type: 'password'
        })
        allow(auth_cli).to receive(:load_secrets).and_return({
          'CLEANBOX_PASSWORD' => 'test_password'
        })
      end

      it 'succeeds when connection test passes' do
        allow(auth_cli).to receive(:test_connection).and_return(true)

        auth_cli.send(:test_auth)

        expect(auth_cli).to have_received(:test_connection)
      end

      it 'fails when connection test fails' do
        allow(auth_cli).to receive(:test_connection).and_return(false)

        auth_cli.send(:test_auth)

        expect(auth_cli).to have_received(:test_connection)
      end
    end

    context 'when authentication is not configured' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(false)
      end

      it 'shows error message' do
        auth_cli.send(:test_auth)

        expect(auth_cli).not_to have_received(:test_connection)
      end
    end

    context 'when credentials are missing but config exists' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(false)
        allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(true)
        allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
          host: 'test.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        })
      end

      it 'shows error message about missing credentials' do
        expect(auth_cli).to receive(:puts).with("❌ No authentication configuration found.")
        expect(auth_cli).to receive(:puts).with("Run './cleanbox auth setup' to configure authentication.")

        auth_cli.send(:test_auth)

        expect(auth_cli).not_to have_received(:test_connection)
      end
    end
  end

  describe '#show_auth' do
    before do
      allow(auth_cli).to receive(:puts)
      allow(CLI::SecretsManager).to receive(:auth_secrets_status)
    end

    context 'when config file exists and is complete' do
      before do
        allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(true)
        allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
          host: 'test.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        })
        allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
          configured: true,
          source: 'environment',
          missing: []
        })
      end

      it 'shows configuration details' do
        auth_cli.send(:show_auth)

        expect(CLI::SecretsManager).to have_received(:auth_secrets_status).with('oauth2_microsoft')
      end
    end

    context 'when config file does not exist' do
      before do
        allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(false)
      end

      it 'shows error message' do
        auth_cli.send(:show_auth)

        expect(CLI::SecretsManager).not_to have_received(:auth_secrets_status)
      end
    end

    context 'when config is incomplete' do
      before do
        allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(true)
        allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
          host: 'test.com'
          # Missing username and auth_type
        })
      end

      it 'shows error message with missing fields' do
        auth_cli.send(:show_auth)

        expect(CLI::SecretsManager).not_to have_received(:auth_secrets_status)
      end
    end

    context 'when credentials are missing' do
      before do
        allow_any_instance_of(CLI::ConfigManager).to receive(:config_file_exists?).and_return(true)
        allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
          host: 'test.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        })
      end

      context 'when no credentials are available (source: none)' do
        before do
          allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
            configured: false,
            source: 'none',
            missing: ['client_id', 'client_secret', 'tenant_id']
          })
        end

        it 'shows missing credentials with setup instructions' do
          expect(auth_cli).to receive(:puts).with("❌ Credentials: Missing")
          expect(auth_cli).to receive(:puts).with("Missing: client_id, client_secret, tenant_id")
          expect(auth_cli).to receive(:puts).with("Source: none")
          expect(auth_cli).to receive(:puts).with("To fix this:")
          expect(auth_cli).to receive(:puts).with("  Run './cleanbox auth setup' to configure credentials")

          auth_cli.send(:show_auth)
        end
      end

      context 'when credentials are in .env file but missing (source: env_file)' do
        before do
          allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
            configured: false,
            source: 'env_file',
            missing: ['client_secret']
          })
        end

        it 'shows missing credentials with .env file instructions' do
          expect(auth_cli).to receive(:puts).with("❌ Credentials: Missing")
          expect(auth_cli).to receive(:puts).with("Missing: client_secret")
          expect(auth_cli).to receive(:puts).with("Source: env_file")
          expect(auth_cli).to receive(:puts).with("To fix this:")
          expect(auth_cli).to receive(:puts).with("  Check your .env file at #{CLI::SecretsManager::ENV_FILE_PATH}")
          expect(auth_cli).to receive(:puts).with("  Ensure it contains the required variables")

          auth_cli.send(:show_auth)
        end
      end

      context 'when credentials are in environment but missing (source: environment)' do
        before do
          allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
            configured: false,
            source: 'environment',
            missing: ['tenant_id']
          })
        end

        it 'shows missing credentials with environment variable instructions' do
          expect(auth_cli).to receive(:puts).with("❌ Credentials: Missing")
          expect(auth_cli).to receive(:puts).with("Missing: tenant_id")
          expect(auth_cli).to receive(:puts).with("Source: environment")
          expect(auth_cli).to receive(:puts).with("To fix this:")
          expect(auth_cli).to receive(:puts).with("  Check your environment variables")
          expect(auth_cli).to receive(:puts).with("  Ensure CLEANBOX_* variables are set correctly")

          auth_cli.send(:show_auth)
        end
      end

      context 'when some credentials are missing for password auth' do
        before do
          allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
            host: 'test.com',
            username: 'test@example.com',
            auth_type: 'password'
          })
          allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
            configured: false,
            source: 'none',
            missing: ['password']
          })
        end

        it 'shows missing password with setup instructions' do
          expect(auth_cli).to receive(:puts).with("❌ Credentials: Missing")
          expect(auth_cli).to receive(:puts).with("Missing: password")
          expect(auth_cli).to receive(:puts).with("Source: none")
          expect(auth_cli).to receive(:puts).with("To fix this:")
          expect(auth_cli).to receive(:puts).with("  Run './cleanbox auth setup' to configure credentials")

          auth_cli.send(:show_auth)
        end
      end
    end
  end

  describe '#reset_auth' do
    before do
      allow(auth_cli).to receive(:puts)
      allow(auth_cli).to receive(:print)
      allow(auth_cli).to receive(:gets)
      allow(auth_cli).to receive(:reset_auth_config)
    end

    context 'when authentication is configured' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(true)
      end

      it 'resets when user confirms with y' do
        allow(auth_cli).to receive(:gets).and_return('y')

        auth_cli.send(:reset_auth)

        expect(auth_cli).to have_received(:reset_auth_config)
      end

      it 'resets when user confirms with yes' do
        allow(auth_cli).to receive(:gets).and_return('yes')

        auth_cli.send(:reset_auth)

        expect(auth_cli).to have_received(:reset_auth_config)
      end

      it 'cancels when user does not confirm' do
        allow(auth_cli).to receive(:gets).and_return('n')

        auth_cli.send(:reset_auth)

        expect(auth_cli).not_to have_received(:reset_auth_config)
      end
    end

    context 'when authentication is not configured' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(false)
      end

      it 'shows error message' do
        auth_cli.send(:reset_auth)

        expect(auth_cli).not_to have_received(:reset_auth_config)
      end
    end
  end

  describe '#show_help' do
    it 'displays help information' do
      expect { auth_cli.send(:show_help) }.to output(/Cleanbox Authentication Commands/).to_stdout
    end
  end

  describe '#get_connection_details' do
    before do
      allow(auth_cli).to receive(:prompt_with_default).and_return('test.com')
      allow(auth_cli).to receive(:prompt).and_return('test@example.com')
      allow(auth_cli).to receive(:prompt_choice).and_return('oauth2_microsoft')
    end

    it 'returns connection details for oauth2_microsoft' do
      allow(auth_cli).to receive(:prompt_choice).and_return('oauth2_microsoft')
      allow(auth_cli).to receive(:prompt).and_return('test@example.com', 'client_id', 'client_secret', 'tenant_id')

      result = auth_cli.send(:get_connection_details)

      expect(result[:details][:host]).to eq('test.com')
      expect(result[:details][:username]).to eq('test@example.com')
      expect(result[:details][:auth_type]).to eq('oauth2_microsoft')
      expect(result[:secrets]['CLEANBOX_CLIENT_ID']).to eq('client_id')
      expect(result[:secrets]['CLEANBOX_CLIENT_SECRET']).to eq('client_secret')
      expect(result[:secrets]['CLEANBOX_TENANT_ID']).to eq('tenant_id')
    end

    it 'returns connection details for password authentication' do
      allow(auth_cli).to receive(:prompt_choice).and_return('password')
      allow(auth_cli).to receive(:prompt).and_return('test@example.com', 'password123')

      result = auth_cli.send(:get_connection_details)

      expect(result[:details][:auth_type]).to eq('password')
      expect(result[:secrets]['CLEANBOX_PASSWORD']).to eq('password123')
    end
  end

  describe '#test_connection' do
    let(:config) do
      {
        host: 'test.com',
        username: 'test@example.com',
        auth_type: 'password'
      }
    end

    let(:secrets) do
      {
        'CLEANBOX_PASSWORD' => 'test_password'
      }
    end

    before do
      allow(Net::IMAP).to receive(:new).and_return(double('imap'))
      allow(Auth::AuthenticationManager).to receive(:authenticate_imap)
      allow(auth_cli).to receive(:secret).and_return('test_value')
    end

    it 'succeeds when connection and authentication work' do
      mock_imap = double('imap')
      allow(Net::IMAP).to receive(:new).and_return(mock_imap)
      allow(mock_imap).to receive(:list).and_return([])
      allow(mock_imap).to receive(:logout)
      allow(mock_imap).to receive(:disconnect)

      result = auth_cli.send(:test_connection, config, secrets)

      expect(result).to be true
    end

    it 'fails when connection raises an error' do
      allow(Net::IMAP).to receive(:new).and_raise(StandardError, 'Connection failed')

      result = auth_cli.send(:test_connection, config, secrets)

      expect(result).to be false
    end
  end

  describe '#load_secrets' do
    before do
      allow(CLI::SecretsManager).to receive(:load_env_file)
      ENV['CLEANBOX_CLIENT_ID'] = 'test_id'
      ENV['CLEANBOX_CLIENT_SECRET'] = 'test_secret'
      ENV['CLEANBOX_TENANT_ID'] = 'test_tenant'
      ENV['CLEANBOX_PASSWORD'] = 'test_password'
    end

    after do
      ENV.delete('CLEANBOX_CLIENT_ID')
      ENV.delete('CLEANBOX_CLIENT_SECRET')
      ENV.delete('CLEANBOX_TENANT_ID')
      ENV.delete('CLEANBOX_PASSWORD')
    end

    it 'loads all secrets from environment' do
      result = auth_cli.send(:load_secrets)

      expect(result['CLEANBOX_CLIENT_ID']).to eq('test_id')
      expect(result['CLEANBOX_CLIENT_SECRET']).to eq('test_secret')
      expect(result['CLEANBOX_TENANT_ID']).to eq('test_tenant')
      expect(result['CLEANBOX_PASSWORD']).to eq('test_password')
    end
  end

  describe '#secret' do
    it 'calls SecretsManager.value_from_env_or_secrets' do
      allow(CLI::SecretsManager).to receive(:value_from_env_or_secrets).with('test_name').and_return('test_value')

      result = auth_cli.send(:secret, 'test_name')

      expect(result).to eq('test_value')
      expect(CLI::SecretsManager).to have_received(:value_from_env_or_secrets).with('test_name')
    end
  end

  describe '#prompt' do
    before do
      allow(auth_cli).to receive(:puts)
      allow(auth_cli).to receive(:print)
      allow(auth_cli).to receive(:gets)
    end

    it 'returns input when no validation block is provided' do
      allow(auth_cli).to receive(:gets).and_return('test_input')

      result = auth_cli.send(:prompt, 'Test message')

      expect(result).to eq('test_input')
    end

    it 'returns input when validation passes' do
      allow(auth_cli).to receive(:gets).and_return('valid_input')

      result = auth_cli.send(:prompt, 'Test message') { |input| input == 'valid_input' }

      expect(result).to eq('valid_input')
    end

    it 'retries when validation fails' do
      allow(auth_cli).to receive(:gets).and_return('invalid_input', 'valid_input')
      allow(auth_cli).to receive(:puts)

      result = auth_cli.send(:prompt, 'Test message') { |input| input == 'valid_input' }

      expect(result).to eq('valid_input')
      expect(auth_cli).to have_received(:puts).with('❌ Invalid input. Please try again.')
    end

    it 'uses default value when input is empty' do
      allow(auth_cli).to receive(:gets).and_return('')

      result = auth_cli.send(:prompt, 'Test message', default: 'default_value')

      expect(result).to eq('default_value')
    end
  end

  describe '#prompt_with_default' do
    it 'calls prompt with default and validation' do
      allow(auth_cli).to receive(:prompt).and_return('test_result')

      result = auth_cli.send(:prompt_with_default, 'Test message', 'default_value')

      expect(result).to eq('test_result')
      expect(auth_cli).to have_received(:prompt).with('Test message', default: 'default_value')
    end
  end

  describe '#prompt_choice' do
    before do
      allow(auth_cli).to receive(:puts)
      allow(auth_cli).to receive(:print)
      allow(auth_cli).to receive(:gets)
    end

    it 'returns the correct choice key' do
      choices = [
        { key: 'option1', label: 'Option 1' },
        { key: 'option2', label: 'Option 2' }
      ]
      allow(auth_cli).to receive(:gets).and_return('1')

      result = auth_cli.send(:prompt_choice, 'Test choices', choices)

      expect(result).to eq('option1')
    end

    it 'retries when invalid choice is provided' do
      choices = [
        { key: 'option1', label: 'Option 1' },
        { key: 'option2', label: 'Option 2' }
      ]
      allow(auth_cli).to receive(:gets).and_return('invalid', '2')

      result = auth_cli.send(:prompt_choice, 'Test choices', choices)

      expect(result).to eq('option2')
    end
  end
end 