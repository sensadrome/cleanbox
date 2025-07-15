# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI::CleanboxCLI do
  let(:cli) { described_class.new }

  before do
    # Mock the config manager to return predictable test data
    allow_any_instance_of(CLI::ConfigManager).to receive(:load_config).and_return({
      host: 'test.example.com',
      username: 'test@example.com',
      auth_type: 'password',
      whitelist_folders: ['Family', 'Work'],
      list_folders: ['Newsletters']
    })

    # Mock secrets manager to return nil for all secrets
    allow(CLI::SecretsManager).to receive(:value_from_env_or_secrets).and_return(nil)
  end

  describe '#initialize' do
    it 'creates a new CLI instance' do
      expect(cli).to be_a(CLI::CleanboxCLI)
    end

    it 'initializes with loaded config options' do
      expect(cli.instance_variable_get(:@options)).to include(
        host: 'test.example.com',
        username: 'test@example.com',
        auth_type: 'password'
      )
    end
  end

  describe '#run' do
    context 'when no arguments are provided' do
      before do
        # Mock the help display to avoid actual execution
        allow(cli).to receive(:show_help)
        allow(cli).to receive(:exit)
        # Mock the execute_action to prevent network calls
        allow(cli).to receive(:execute_action)
        # Mock ARGV to be empty
        allow(ARGV).to receive(:empty?).and_return(true)
        allow(ARGV).to receive(:include?).and_return(false)
      end

      it 'shows help' do
        expect(cli).to receive(:show_help)
        cli.run
      end
    end

    context 'when setup command is provided' do
      before do
        ARGV.replace(['setup'])
        allow(CLI::SetupWizard).to receive(:new).and_return(double(run: nil))
        allow(cli).to receive(:exit)
        # Mock puts to suppress CLI output during tests
        allow($stdout).to receive(:puts)
        allow($stderr).to receive(:puts)
      end

      after do
        ARGV.clear
      end

      it 'runs the setup wizard' do
        expect(CLI::SetupWizard).to receive(:new).with(verbose: false)
        cli.run
      end
    end
  end

  describe 'default_options' do
    it 'includes all required configuration keys' do
      options = cli.send(:default_options)
      
      expect(options).to include(
        :host,
        :username,
        :auth_type,
        :whitelist_folders,
        :list_folders,
        :list_domain_map
      )
    end
  end
end 