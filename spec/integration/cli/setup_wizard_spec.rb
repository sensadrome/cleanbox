# frozen_string_literal: true

require 'spec_helper'
require_relative '../../test_imap_service'

RSpec.describe 'SetupWizard Integration' do
  let(:temp_dir) { Dir.mktmpdir('cleanbox_test') }
  let(:config_path) { File.join(temp_dir, 'config.yml') }
  let(:env_path) { File.join(temp_dir, '.env') }

  before do
    # Ensure test isolation: remove any test config/env files before each test
    FileUtils.rm_f(config_path)
    FileUtils.rm_f(env_path)

    # Mock ConfigManager to use our test path
    allow(CLI::ConfigManager).to receive(:new).and_return(
      CLI::ConfigManager.new(config_path)
    )
    
    # Set the .env file path for SecretsManager
    stub_const("CLI::SecretsManager::ENV_FILE_PATH", env_path)
    
    # Mock user input for the test scenario
    mock_user_input
  end

  after do
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe 'connection failure' do
    it 'handles authentication failure gracefully' do
      # Mock IMAP to use our test fixture
      mock_imap_with_fixture('connection_failure')
      
      # Mock user input for connection failure scenario
      # Capture output
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      allow($stdout).to receive(:print) { |msg| output.print(msg) }

      # Run the setup wizard
      wizard = CLI::SetupWizard.new(verbose: false)
      
      # Mock gets on the specific wizard instance
      allow(wizard).to receive(:gets).and_return(
        'outlook.office365.com',  # IMAP Host
        'test@example.com',       # Email Address
        '1',                      # OAuth2 authentication
        'invalid_client_id',      # Client ID
        'invalid_client_secret',  # Client Secret
        'invalid_tenant_id'       # Tenant ID
      )
      
      wizard.run

      # Verify error message is shown
      expect(output.string).to include('❌ Connection failed')
      expect(output.string).to include('Invalid credentials')
      expect(output.string).to include('Please check your credentials and try again')
    end
  end

  describe 'happy path' do
    it 'completes setup successfully with folder analysis' do
      # Mock IMAP to use our test fixture
      mock_imap_with_fixture('happy_path')
      
      # Capture output
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      allow($stdout).to receive(:print) { |msg| output.print(msg) }

      # Run the setup wizard
      wizard = CLI::SetupWizard.new(verbose: false)
      
      # Mock gets on the specific wizard instance for happy path
      allow(wizard).to receive(:gets).and_return(
        'outlook.office365.com',  # IMAP Host
        'test@example.com',       # Email Address
        '1',                      # OAuth2 authentication
        'valid_client_id',        # Client ID
        'valid_client_secret',    # Client Secret
        'valid_tenant_id',        # Tenant ID
        '',                       # Accept default categorization for Inbox (Y)
        '',                       # Accept default categorization for Newsletters (Y)
        '',                       # Accept default categorization for Family (Y)
        '',                       # Accept default categorization for Work (Y)
        '',                       # Accept default categorization for Sent Items (Y)
        '',                       # No additional whitelist folders
        '',                       # No additional list folders
        '',                       # No custom domain mappings
        'n'                       # Don't preview (N)
      )
      
      wizard.run

      # Verify successful completion
      expect(output.string).to include('🎉 Setup complete!')
      expect(output.string).to include('✅ Connected successfully!')
      expect(output.string).to include('📁 Analyzing your email folders')
      expect(output.string).to include('✅ Analysis complete!')
      expect(output.string).to include('💾 Saving configuration')
      
      # Verify folder analysis output
      expect(output.string).to include('Analyzing folder "Inbox" (50 messages)')
      expect(output.string).to include('Analyzing folder "Newsletters" (120 messages)')
      expect(output.string).to include('Analyzing folder "Family" (30 messages)')
      expect(output.string).to include('Analyzing folder "Work" (80 messages)')
      
      # Verify configuration was saved
      expect(File.exist?(config_path)).to be true
      expect(File.exist?(env_path)).to be true
    end
  end

  private

  def mock_imap_with_fixture(fixture_name)
    # Create the test IMAP service
    test_imap = TestImapService.new(fixture_name)
    
    # Mock Net::IMAP.new to return our test service
    allow(Net::IMAP).to receive(:new).and_return(test_imap)
    
    # Mock the authentication manager to use our test service's auth methods
    allow(Auth::AuthenticationManager).to receive(:authenticate_imap) do |imap, options|
      if test_imap.auth_success?
        # Simulate successful authentication
        true
      else
        # Simulate authentication failure
        raise Net::IMAP::NoResponseError.new(test_imap.auth_error)
      end
    end
  end

  def mock_user_input
    # This will be overridden in specific tests
    allow(self).to receive(:gets).and_return('')
  end
end 