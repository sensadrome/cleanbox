# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'
require_relative '../../lib/cli/authentication_gatherer'

RSpec.describe CLI::AuthCLI do
  let(:temp_dir) { Dir.mktmpdir }
  let(:config_path) { File.join(temp_dir, '.cleanbox.yml') }
  let(:env_path) { File.join(temp_dir, '.env') }
  let(:auth_cli) { described_class.new }

  before do
    # Set up the environment for testing
    stub_const('CLI::SecretsManager::ENV_FILE_PATH', env_path)
    # Reset the env file loaded flag for each test
    CLI::SecretsManager.reset_env_file_loaded
  end

  after do
    FileUtils.rm_rf temp_dir
  end

  describe 'authentication configuration detection' do
    context 'when authentication is properly configured' do
      before do
        # Create a config file with authentication details
        config_content = {
          host: 'outlook.office365.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        }.to_yaml
        File.write(config_path, config_content)

        # Create an env file with secrets
        File.write(env_path,
                   "CLEANBOX_CLIENT_ID=test_id\nCLEANBOX_CLIENT_SECRET=test_secret\nCLEANBOX_TENANT_ID=test_tenant")

        # Configure with the config file
        Configuration.configure({ config_file: config_path })
      end

      it 'returns true' do
        # Test that auth_configured? returns true
        expect(auth_cli.send(:auth_configured?)).to be true
      end
    end

    context 'when authentication is missing' do
      let(:config_options) do
        {
          config_file: '/non/existent/config.yml'
        }
      end

      it 'returns false' do
        # Test that auth_configured? returns false
        expect(auth_cli.send(:auth_configured?)).to be false
      end
    end

    context 'when config exists but credentials are missing' do
      before do
        # Create a config file with authentication details
        config_content = {
          host: 'outlook.office365.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        }.to_yaml
        File.write(config_path, config_content)

        # Ensure no .env file exists for this test
        FileUtils.rm_f(env_path)
        # Clear any environment variables that might interfere
        ENV.delete('CLEANBOX_CLIENT_ID')
        ENV.delete('CLEANBOX_CLIENT_SECRET')
        ENV.delete('CLEANBOX_TENANT_ID')

        # Configure with the config file
        Configuration.configure({ config_file: config_path })
      end

      it 'returns false' do
        # Test that auth_configured? returns false when credentials are missing
        expect(auth_cli.send(:auth_configured?)).to be false
      end
    end

    context 'when config exists but auth_type is missing' do
      before do
        # Create a config file with authentication details but missing auth_type
        config_content = {
          host: 'outlook.office365.com',
          username: 'test@example.com'
          # Missing auth_type
        }.to_yaml
        File.write(config_path, config_content)

        # Configure with the config file
        Configuration.configure({ config_file: config_path })
      end

      it 'returns false' do
        # Test that auth_configured? returns false when auth_type is missing
        expect(auth_cli.send(:auth_configured?)).to be false
      end
    end
  end

  describe 'secrets management' do
    it 'correctly detects available secrets' do
      # Clear any existing environment variables
      ENV.delete('CLEANBOX_PASSWORD')

      # Create an env file with secrets
      File.write(env_path,
                 "CLEANBOX_CLIENT_ID=test_id\nCLEANBOX_CLIENT_SECRET=test_secret\nCLEANBOX_TENANT_ID=test_tenant")

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

    # Override config_options to use a real temp directory
    let(:config_options) do
      {
        config_file: config_path,
        data_dir: temp_dir
      }
    end

    it 'saves auth settings to config and creates env file' do
      # Use real file operations instead of mocking ConfigManager
      auth_cli.send(:save_auth_config, details, secrets)

      # Verify the config was saved correctly
      expect(File.exist?(config_path)).to be true
      config = YAML.load_file(config_path)
      expect(config[:host]).to eq('outlook.office365.com')
      expect(config[:username]).to eq('test@example.com')
      expect(config[:auth_type]).to eq('oauth2_microsoft')

      # Verify the env file was created
      expect(File.exist?(env_path)).to be true
      env_content = File.read(env_path)
      expect(env_content).to include('CLEANBOX_CLIENT_ID=test_id')
      expect(env_content).to include('CLEANBOX_CLIENT_SECRET=test_secret')
      expect(env_content).to include('CLEANBOX_TENANT_ID=test_tenant')
    end
  end

  describe '#reset_auth_config' do
    let(:config_options) do
      {
        host: 'outlook.office365.com',
        username: 'test@example.com',
        auth_type: 'oauth2_microsoft',
        whitelist_folders: ['Work'],
        list_folders: ['Newsletters']
      }
    end

    before do
      # Create env file for testing
      File.write(env_path,
                 "CLEANBOX_CLIENT_ID=test_id\nCLEANBOX_CLIENT_SECRET=test_secret\nCLEANBOX_TENANT_ID=test_tenant")
    end

    it 'removes auth settings from config and deletes env file' do
      # Mock the config manager to use our test paths
      allow_any_instance_of(CLI::ConfigManager).to receive(:config_path).and_return(config_path)
      allow_any_instance_of(CLI::ConfigManager).to receive(:load_config) do
        # Return the current configuration from Configuration
        Configuration.options
      end
      allow_any_instance_of(CLI::ConfigManager).to receive(:save_config) do |_instance, config|
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
      allow(auth_cli).to receive(:gets).and_return('test_input')
      allow(auth_cli).to receive(:connection_details)
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
        allow(auth_cli).to receive(:connection_details).and_return({
                                                                     details: { host: 'test.com' },
                                                                     secrets: { 'CLEANBOX_PASSWORD' => 'test' }
                                                                   })
        allow(auth_cli).to receive(:test_connection).and_return(true)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:connection_details)
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

        expect(auth_cli).not_to have_received(:connection_details)
      end

      it 'cancels when user provides invalid input' do
        allow(auth_cli).to receive(:gets).and_return('invalid')

        auth_cli.send(:setup_auth)

        expect(auth_cli).not_to have_received(:connection_details)
      end
    end

    context 'when authentication is not configured' do
      before do
        allow(auth_cli).to receive(:auth_configured?).and_return(false)
      end

      it 'proceeds with setup when connection test succeeds' do
        allow(auth_cli).to receive(:connection_details).and_return({
                                                                     details: { host: 'test.com' },
                                                                     secrets: { 'CLEANBOX_PASSWORD' => 'test' }
                                                                   })
        allow(auth_cli).to receive(:test_connection).and_return(true)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:connection_details)
        expect(auth_cli).to have_received(:test_connection)
        expect(auth_cli).to have_received(:save_auth_config)
      end

      it 'fails when connection test fails' do
        allow(auth_cli).to receive(:connection_details).and_return({
                                                                     details: { host: 'test.com' },
                                                                     secrets: { 'CLEANBOX_PASSWORD' => 'test' }
                                                                   })
        allow(auth_cli).to receive(:test_connection).and_return(false)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:connection_details)
        expect(auth_cli).to have_received(:test_connection)
        expect(auth_cli).not_to have_received(:save_auth_config)
      end

      it 'fails when connection_details returns nil' do
        allow(auth_cli).to receive(:connection_details).and_return(nil)

        auth_cli.send(:setup_auth)

        expect(auth_cli).to have_received(:connection_details)
        expect(auth_cli).not_to have_received(:test_connection)
        expect(auth_cli).not_to have_received(:save_auth_config)
      end

      it 'fails when connection test fails due to missing credentials' do
        allow(auth_cli).to receive(:connection_details).and_return({
                                                                     details: { host: 'test.com',
                                                                                auth_type: 'oauth2_microsoft' },
                                                                     secrets: { 'CLEANBOX_CLIENT_ID' => 'test_id' }
                                                                     # Missing client_secret and tenant_id
                                                                   })
        allow(auth_cli).to receive(:test_connection).and_return(false)

        auth_cli.send(:setup_auth)
        expect(captured_output.string).to include("❌ Connection test failed. Please check your credentials and try again.")

        expect(auth_cli).to have_received(:connection_details)
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
        expect(auth_cli).to receive(:puts).with('❌ No authentication configuration found.')
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
        # Create a config file with authentication details
        config_content = {
          host: 'test.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        }.to_yaml
        File.write(config_path, config_content)

        # Configure with the config file
        Configuration.configure({ config_file: config_path })

        allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
                                                                                 configured: true,
                                                                                 source: 'environment',
                                                                                 missing: []
                                                                               })
      end

      it 'shows configuration details' do
        auth_cli.send(:show_auth)

        expect(CLI::SecretsManager).to have_received(:auth_secrets_status).with('oauth2_microsoft', data_dir: nil)
      end
    end

    context 'when config file does not exist' do
      let(:config_options) do
        {
          config_file: '/non/existent/config.yml'
        }
      end

      it 'shows error message' do
        auth_cli.send(:show_auth)

        expect(CLI::SecretsManager).not_to have_received(:auth_secrets_status)
      end
    end

    context 'when config is complete but credentials are missing' do
      before do
        # Create a config file with authentication details
        config_content = {
          host: 'test.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        }.to_yaml
        File.write(config_path, config_content)

        # Configure with the config file
        Configuration.configure({ config_file: config_path })
      end

      it 'shows missing credentials message' do
        allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
                                                                                 configured: false,
                                                                                 source: 'none',
                                                                                 missing: %w[client_id client_secret
                                                                                             tenant_id]
                                                                               })

        auth_cli.send(:show_auth)

        expect(CLI::SecretsManager).to have_received(:auth_secrets_status)
      end
    end

    context 'when credentials are missing' do
      before do
        # Create a config file with authentication details
        config_content = {
          host: 'test.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        }.to_yaml
        File.write(config_path, config_content)

        # Configure with the config file
        Configuration.configure({ config_file: config_path })
      end

      context 'when no credentials are available (source: none)' do
        before do
          allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
                                                                                   configured: false,
                                                                                   source: 'none',
                                                                                   missing: %w[client_id client_secret
                                                                                               tenant_id]
                                                                                 })
        end

        it 'shows missing credentials with setup instructions' do
          expect(auth_cli).to receive(:puts).with('❌ Credentials: Missing')
          expect(auth_cli).to receive(:puts).with('Missing: client_id, client_secret, tenant_id')
          expect(auth_cli).to receive(:puts).with('Source: none')
          expect(auth_cli).to receive(:puts).with('To fix this:')
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
          expect(auth_cli).to receive(:puts).with('❌ Credentials: Missing')
          expect(auth_cli).to receive(:puts).with('Missing: client_secret')
          expect(auth_cli).to receive(:puts).with('Source: env_file')
          expect(auth_cli).to receive(:puts).with('To fix this:')
          expect(auth_cli).to receive(:puts).with("  Check your .env file at #{CLI::SecretsManager::ENV_FILE_PATH}")
          expect(auth_cli).to receive(:puts).with('  Ensure it contains the required variables')

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
          expect(auth_cli).to receive(:puts).with('❌ Credentials: Missing')
          expect(auth_cli).to receive(:puts).with('Missing: tenant_id')
          expect(auth_cli).to receive(:puts).with('Source: environment')
          expect(auth_cli).to receive(:puts).with('To fix this:')
          expect(auth_cli).to receive(:puts).with('  Check your environment variables')
          expect(auth_cli).to receive(:puts).with('  Ensure CLEANBOX_* variables are set correctly')

          auth_cli.send(:show_auth)
        end
      end

      context 'when some credentials are missing for password auth' do
        let(:config_options) do
          {
            host: 'test.com',
            username: 'test@example.com',
            auth_type: 'password'
          }
        end

        before do
          allow(CLI::SecretsManager).to receive(:auth_secrets_status).and_return({
                                                                                   configured: false,
                                                                                   source: 'none',
                                                                                   missing: ['password']
                                                                                 })
        end

        it 'shows missing password with setup instructions' do
          expect(auth_cli).to receive(:puts).with('❌ Credentials: Missing')
          expect(auth_cli).to receive(:puts).with('Missing: password')
          expect(auth_cli).to receive(:puts).with('Source: none')
          expect(auth_cli).to receive(:puts).with('To fix this:')
          expect(auth_cli).to receive(:puts).with("  Run './cleanbox auth setup' to configure credentials")

          auth_cli.send(:show_auth)
        end
      end
    end
  end

  describe '#reset_auth' do
    before do
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
      auth_cli.send(:show_help)
      expect(captured_output.string).to include("Cleanbox Authentication Commands")
    end
  end

  describe '#connection_details' do
    let(:mock_gatherer) { instance_double(CLI::AuthenticationGatherer) }

    before do
      allow(CLI::AuthenticationGatherer).to receive(:new).and_return(mock_gatherer)
    end

    it 'returns connection details for oauth2_microsoft' do
      allow(mock_gatherer).to receive(:gather_authentication_details!)
      allow(mock_gatherer).to receive(:connection_details).and_return({
                                                                        host: 'test.com',
                                                                        username: 'test@example.com',
                                                                        auth_type: 'oauth2_microsoft'
                                                                      })
      allow(mock_gatherer).to receive(:secrets).and_return({
                                                             'CLEANBOX_CLIENT_ID' => 'client_id',
                                                             'CLEANBOX_CLIENT_SECRET' => 'client_secret',
                                                             'CLEANBOX_TENANT_ID' => 'tenant_id'
                                                           })

      result = auth_cli.send(:connection_details)

      expect(result[:details][:host]).to eq('test.com')
      expect(result[:details][:username]).to eq('test@example.com')
      expect(result[:details][:auth_type]).to eq('oauth2_microsoft')
      expect(result[:secrets]['CLEANBOX_CLIENT_ID']).to eq('client_id')
      expect(result[:secrets]['CLEANBOX_CLIENT_SECRET']).to eq('client_secret')
      expect(result[:secrets]['CLEANBOX_TENANT_ID']).to eq('tenant_id')
    end

    it 'returns connection details for password authentication' do
      allow(mock_gatherer).to receive(:gather_authentication_details!)
      allow(mock_gatherer).to receive(:connection_details).and_return({
                                                                        host: 'test.com',
                                                                        username: 'test@example.com',
                                                                        auth_type: 'password'
                                                                      })
      allow(mock_gatherer).to receive(:secrets).and_return({
                                                             'CLEANBOX_PASSWORD' => 'password123'
                                                           })

      result = auth_cli.send(:connection_details)

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

  describe '#setup_user_oauth2' do
    let(:details) { { username: 'test@example.com' } }
    let(:user_token) { instance_double('Microsoft365UserToken') }
    let(:auth_url) { 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=test&scope=test&response_type=code&redirect_uri=test' }

    before do
      allow(Microsoft365UserToken).to receive(:new).and_return(user_token)
      allow(user_token).to receive(:authorization_url).and_return(auth_url)
      allow(user_token).to receive(:exchange_code_for_tokens).and_return(true)
      allow(user_token).to receive(:save_tokens_to_file)
      allow(auth_cli).to receive(:gets)
      allow(auth_cli).to receive(:default_token_file).and_return('/tmp/test_token.json')
      allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({})
      allow_any_instance_of(CLI::ConfigManager).to receive(:save_config)
    end

    context 'when authorization code is provided' do
      before do
        allow(auth_cli).to receive(:gets).and_return('test_auth_code')
      end

      it 'displays authorization URL and prompts for code' do
        auth_cli.send(:setup_user_oauth2, details)

        expect(captured_output.string).to include("🔐 Microsoft 365 User-based OAuth2 Setup")
        expect(captured_output.string).to include("========================================")
        expect(captured_output.string).to include(auth_url)
        expect(captured_output.string).to include("Please visit this URL to authorize Cleanbox:")
        expect(captured_output.string).to include("After you grant permissions, you'll receive an authorization code.")
        expect(captured_output.string).to include("Please enter the authorization code: ")
      end

      it 'exchanges code for tokens and saves configuration' do
        auth_cli.send(:setup_user_oauth2, details)

        expect(user_token).to have_received(:exchange_code_for_tokens).with('test_auth_code')
        expect(user_token).to have_received(:save_tokens_to_file).with('/tmp/test_token.json')
        # NOTE: We can't easily test the ConfigManager save_config call with the current setup
        # The important part is that the method completes successfully
      end

      it 'displays success messages' do
        auth_cli.send(:setup_user_oauth2, details)

        expect(captured_output.string).to include("✅ OAuth2 setup successful!")
        expect(captured_output.string).to include("✅ Tokens saved to: /tmp/test_token.json")
        expect(captured_output.string).to include(/✅ Configuration saved to: .*\.yml/)
      end
    end

    context 'when no authorization code is provided' do
      before do
        allow(auth_cli).to receive(:gets).and_return('')
      end

      it 'cancels setup and displays error message' do
        auth_cli.send(:setup_user_oauth2, details)

        expect(captured_output.string).to include("❌ No authorization code provided. Setup cancelled.")
        expect(user_token).not_to have_received(:exchange_code_for_tokens)
      end
    end

    context 'when token exchange fails' do
      before do
        allow(auth_cli).to receive(:gets).and_return('test_auth_code')
        allow(user_token).to receive(:exchange_code_for_tokens).and_return(false)
      end

      it 'displays error message' do
        auth_cli.send(:setup_user_oauth2, details)

        expect(captured_output.string).to include("❌ Failed to exchange authorization code for tokens.")
        expect(captured_output.string).to include("Please check the authorization code and try again.")
      end
    end

    context 'when token exchange raises an error' do
      before do
        allow(auth_cli).to receive(:gets).and_return('test_auth_code')
        allow(user_token).to receive(:exchange_code_for_tokens).and_raise(StandardError.new('Test error'))
      end

      it 'displays error message with details' do
        auth_cli.send(:setup_user_oauth2, details)

        expect(captured_output.string).to include("❌ OAuth2 setup failed: Test error")
        expect(captured_output.string).to include("Please try again or contact support if the problem persists.")
      end
    end
  end

  describe '#default_token_file' do
    it 'sanitizes username and returns correct path' do
      result = auth_cli.send(:default_token_file, 'test@example.com')

      expect(result).to eq(File.join(Dir.home, '.cleanbox', 'tokens', 'test_example_com.json'))
    end

    it 'handles special characters in username' do
      result = auth_cli.send(:default_token_file, 'test+user@example.com')

      expect(result).to eq(File.join(Dir.home, '.cleanbox', 'tokens', 'test_user_example_com.json'))
    end
  end
end
