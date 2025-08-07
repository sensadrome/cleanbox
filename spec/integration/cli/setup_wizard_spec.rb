# frozen_string_literal: true

require 'spec_helper'
require_relative '../../test_imap_service'

RSpec.describe 'SetupWizard Integration' do
  let(:temp_dir) { Dir.mktmpdir('cleanbox_test') }
  let(:config_path) { File.join(temp_dir, 'config.yml') }
  let(:env_path) { File.join(temp_dir, '.env') }
  let(:config_options) { { config_file: config_path } }

  before do
    # Ensure test isolation: remove any test config/env files before each test
    FileUtils.rm_f(config_path)
    FileUtils.rm_f(env_path)

    # Mock ConfigManager to use our test path
    allow(CLI::ConfigManager).to receive(:new).and_return(
      CLI::ConfigManager.new(config_path)
    )

    # Set the .env file path for SecretsManager
    stub_const('CLI::SecretsManager::ENV_FILE_PATH', env_path)

    # Mock user input for the test scenario
    mock_user_input

    # Mock AuthCLI methods to prevent actual execution
    allow_any_instance_of(CLI::AuthCLI).to receive(:setup_auth)
  end

  after do
    FileUtils.rm_rf(temp_dir)
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
        '2',                      # Complete setup (overwrite everything) - handle existing config
        '2',                      # Skip authentication setup
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
        '2',                      # Complete setup (overwrite everything) - handle existing config
        '2',                      # Skip authentication setup
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

  describe 'interactive categorization' do
    it 'handles user input for folder categorization and domain mappings' do
      # Mock IMAP to use our test fixture
      mock_imap_with_fixture('interactive_categorization')

      # Capture output
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      allow($stdout).to receive(:print) { |msg| output.print(msg) }

      # Run the setup wizard
      wizard = CLI::SetupWizard.new(verbose: false)

      # Mock gets on the specific wizard instance for interactive categorization
      allow(wizard).to receive(:gets).and_return(
        '2',                      # Complete setup (overwrite everything) - handle existing config
        '2',                      # Skip authentication setup
        'outlook.office365.com',  # IMAP Host
        'test@example.com',       # Email Address
        '1',                      # OAuth2 authentication
        'valid_client_id',        # Client ID
        'valid_client_secret',    # Client Secret
        'valid_tenant_id',        # Tenant ID
        '',                       # Accept default categorization for Inbox (Y)
        '',                       # Accept default categorization for GitHub (Y)
        '',                       # Accept default categorization for Amazon (Y)
        '',                       # Accept default categorization for Facebook (Y)
        '',                       # Accept default categorization for Work (Y)
        '',                       # Accept default categorization for Sent Items (Y)
        '',                       # No additional whitelist folders
        '',                       # No additional list folders
        '',                       # Accept default domain mappings (Enter)
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
      expect(output.string).to include('Analyzing folder "GitHub" (45 messages)')
      expect(output.string).to include('Analyzing folder "Amazon" (80 messages)')
      expect(output.string).to include('Analyzing folder "Facebook" (30 messages)')
      expect(output.string).to include('Analyzing folder "Work" (120 messages)')

      # Verify domain mappings were shown
      expect(output.string).to include('🔗 Domain Mappings')
      expect(output.string).to include('Suggested mappings:')

      # Verify configuration was saved
      expect(File.exist?(config_path)).to be true
      expect(File.exist?(env_path)).to be true
    end

    it 'handles user overriding folder categorizations' do
      # Mock IMAP to use our test fixture
      mock_imap_with_fixture('interactive_categorization')

      # Capture output
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      allow($stdout).to receive(:print) { |msg| output.print(msg) }

      # Run the setup wizard
      wizard = CLI::SetupWizard.new(verbose: false)

      # Mock gets on the specific wizard instance with overrides
      allow(wizard).to receive(:gets).and_return(
        '2',                      # Complete setup (overwrite everything) - handle existing config
        '2',                      # Skip authentication setup
        'outlook.office365.com',  # IMAP Host
        'test@example.com',       # Email Address
        '1',                      # OAuth2 authentication
        'valid_client_id',        # Client ID
        'valid_client_secret',    # Client Secret
        'valid_tenant_id',        # Tenant ID
        '',                       # Accept default categorization for Inbox (Y)
        'w',                      # Override GitHub to whitelist
        '',                       # Accept default categorization for Amazon (Y)
        'l',                      # Override Facebook to list
        '',                       # Accept default categorization for Work (Y)
        '',                       # Accept default categorization for Sent Items (Y)
        '',                       # No additional whitelist folders
        '',                       # No additional list folders
        '',                       # Accept default domain mappings (Enter)
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
      expect(output.string).to include('Analyzing folder "GitHub" (45 messages)')
      expect(output.string).to include('Analyzing folder "Amazon" (80 messages)')
      expect(output.string).to include('Analyzing folder "Facebook" (30 messages)')
      expect(output.string).to include('Analyzing folder "Work" (120 messages)')

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
    allow(Auth::AuthenticationManager).to receive(:authenticate_imap) do |_imap, _options|
      raise Net::IMAP::NoResponseError, test_imap.auth_error unless test_imap.auth_success?

      # Simulate successful authentication by calling authenticate on the test service
      test_imap.authenticate('oauth2', 'test@example.com', 'token')
      true

      # Simulate authentication failure
    end
  end

  def mock_user_input
    # This will be overridden in specific tests
    allow(self).to receive(:gets).and_return('')
  end
end
