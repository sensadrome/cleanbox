# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI::CleanboxCLI do
  let(:cli) { described_class.new }

  # Override the default config options for this test
  let(:config_options) do
    {
      host: 'test.example.com',
      username: 'test@example.com',
      auth_type: 'password',
      whitelist_folders: %w[Family Work],
      list_folders: ['Newsletters'],
      # Use a non-existent config file to avoid loading real config
      config_file: '/non/existent/test_config.yml',
      data_dir: nil
    }
  end

  before do
    # Mock secrets manager to return nil for all secrets
    allow(CLI::SecretsManager).to receive(:value_from_env_or_secrets).and_return(nil)

    # Mock CLI parser to prevent actual argument parsing for most tests
    allow_any_instance_of(CLI::CLIParser).to receive(:parse!).and_return({})
  end

  describe '#initialize' do
    before do
      # Override the global mock to return our test config options for these tests
      allow_any_instance_of(CLI::CLIParser).to receive(:parse!).and_return(config_options)
    end

    it 'creates a new CLI instance' do
      expect(cli).to be_a(CLI::CleanboxCLI)
    end

    it 'initializes with loaded config options' do
      expect(cli.options).to include(
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
        # Mock parse_command_line_options to prevent actual argument parsing
        allow(cli).to receive(:parse_command_line_options)
        # Mock validate_options to prevent validation errors
        # allow(cli).to receive(:validate_options)
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
        # Mock parse_command_line_options to prevent actual argument parsing
        allow(cli).to receive(:parse_command_line_options)
        # Mock validate_options to prevent validation errors
        allow(cli).to receive(:validate_options)
        # Mock execute_action to prevent network calls
        allow(cli).to receive(:execute_action)
      end

      after do
        ARGV.clear
      end

      it 'runs the setup wizard' do
        expect(CLI::SetupWizard).to receive(:new).with(verbose: false)
        cli.run
      end
    end

    context 'when config command is provided' do
      before do
        ARGV.replace(%w[config show])
        allow(cli).to receive(:exit)
        allow(cli).to receive(:parse_command_line_options)
        allow(cli).to receive(:validate_options)
        allow(cli).to receive(:execute_action)
        allow(cli.config_manager).to receive(:handle_command)
      end

      after do
        ARGV.clear
      end

      it 'handles config command' do
        expect(cli.config_manager).to receive(:handle_command).with(['show'], show_all: false)
        cli.run
      end
    end

    context 'when unjunk option is provided' do
      before do
        allow(cli).to receive(:exit)
        allow(cli).to receive(:parse_command_line_options)
        allow(cli).to receive(:validate_options)
        allow(cli).to receive(:execute_action)
        allow(ARGV).to receive(:empty?).and_return(false)
        allow(ARGV).to receive(:include?).and_return(false)
        cli.options[:unjunk] = true
      end

      it 'does not show help when unjunk is set' do
        expect(cli).not_to receive(:show_help)
        cli.run
      end
    end
  end

  describe '#determine_action' do
    it 'returns unjunk! when unjunk option is set' do
      cli.options[:unjunk] = true
      expect(cli.send(:determine_action)).to eq('unjunk!')
    end

    it 'returns show_lists! when list command is provided' do
      ARGV.replace(['list'])
      expect(cli.send(:determine_action)).to eq('show_lists!')
    end

    it 'returns file_messages! when file command is provided' do
      ARGV.replace(['file'])
      expect(cli.send(:determine_action)).to eq('file_messages!')
    end

    it 'returns file_messages! when filing command is provided' do
      ARGV.replace(['filing'])
      expect(cli.send(:determine_action)).to eq('file_messages!')
    end

    it 'returns show_folders! when folders command is provided' do
      ARGV.replace(['folders'])
      expect(cli.send(:determine_action)).to eq('show_folders!')
    end

    it 'returns clean! as default action' do
      ARGV.clear
      expect(cli.send(:determine_action)).to eq('clean!')
    end
  end

  describe '#handle_config_command' do
    before do
      allow(cli).to receive(:exit)
      allow(cli.config_manager).to receive(:handle_command)
    end

    it 'handles config command with subcommand' do
      ARGV.replace(%w[config show])
      cli.send(:handle_config_command)
      expect(cli.config_manager).to have_received(:handle_command).with(['show'], show_all: false)
    end

    it 'handles config command with --all flag' do
      ARGV.replace(['config', 'show', '--all'])
      cli.send(:handle_config_command)
      expect(cli.config_manager).to have_received(:handle_command).with(['show'], show_all: true)
    end

    it 'does nothing when first argument is not config' do
      ARGV.replace(%w[other command])
      cli.send(:handle_config_command)
      expect(cli.config_manager).not_to have_received(:handle_command)
    end
  end

  describe '#handle_setup_command' do
    before do
      allow(cli).to receive(:exit)
      allow(CLI::SetupWizard).to receive(:new).and_return(double(run: nil))
    end

    it 'runs setup wizard when setup command is present' do
      ARGV.replace(['setup'])
      cli.send(:handle_setup_command)
      expect(CLI::SetupWizard).to have_received(:new).with(verbose: false)
    end

    it 'does nothing when setup command is not present' do
      ARGV.replace(%w[other command])
      cli.send(:handle_setup_command)
      expect(CLI::SetupWizard).not_to have_received(:new)
    end
  end

  describe '#handle_no_args_help' do
    before do
      allow(cli).to receive(:show_help)
      allow(cli).to receive(:exit)
    end

    it 'shows help when no arguments and not unjunking' do
      ARGV.clear
      cli.options[:unjunk] = false
      cli.send(:handle_no_args_help)
      expect(cli).to have_received(:show_help)
    end

    it 'does not show help when unjunking' do
      ARGV.clear
      cli.options[:unjunk] = true
      cli.send(:handle_no_args_help)
      expect(cli).not_to have_received(:show_help)
    end

    it 'does not show help when arguments are present' do
      ARGV.replace(%w[some args])
      cli.send(:handle_no_args_help)
      expect(cli).not_to have_received(:show_help)
    end
  end

  describe '#update_config_manager_if_needed' do
    it 'updates config manager when config_file is set' do
      cli.options[:config_file] = '/custom/config.yml'
      expect(CLI::ConfigManager).to receive(:new).with('/custom/config.yml')
      cli.send(:update_config_manager_if_needed)
    end

    it 'does nothing when config_file is not set' do
      cli.options[:config_file] = nil
      expect(CLI::ConfigManager).not_to receive(:new)
      cli.send(:update_config_manager_if_needed)
    end
  end

  describe '#show_help' do
    it 'outputs help text' do
      expect { cli.send(:show_help) }.to output(/Cleanbox - Intelligent Email Management/).to_stdout
    end

    it 'includes quick start information' do
      expect { cli.send(:show_help) }.to output(/Quick Start/).to_stdout
    end

    it 'includes common commands' do
      expect { cli.send(:show_help) }.to output(/Common Commands/).to_stdout
    end
  end

  describe '#secret' do
    it 'calls SecretsManager with the correct parameter' do
      expect(CLI::SecretsManager).to receive(:value_from_env_or_secrets).with(:test_secret)
      cli.send(:secret, :test_secret)
    end
  end

  describe '#create_imap_connection' do
    let(:mock_imap) { double('IMAP') }
    let(:mock_auth_manager) { double('AuthManager') }

    before do
      allow(Net::IMAP).to receive(:new).and_return(mock_imap)
      allow(Auth::AuthenticationManager).to receive(:authenticate_imap)
      cli.options[:host] = 'imap.example.com'
    end

    it 'creates IMAP connection with correct host' do
      expect(Net::IMAP).to receive(:new).with('imap.example.com', ssl: true)
      cli.send(:create_imap_connection)
    end

    it 'authenticates the IMAP connection' do
      expect(Auth::AuthenticationManager).to receive(:authenticate_imap).with(mock_imap, anything)
      cli.send(:create_imap_connection)
    end

    it 'removes host from options' do
      cli.send(:create_imap_connection)
      expect(cli.options[:host]).to be_nil
    end
  end

  describe '#execute_action' do
    let(:mock_imap) { double('IMAP') }
    let(:mock_cleanbox) { double('Cleanbox') }

    before do
      allow(cli).to receive(:create_imap_connection).and_return(mock_imap)
      allow(Cleanbox).to receive(:new).and_return(mock_cleanbox)
      allow(mock_cleanbox).to receive(:send)
      allow(ARGV).to receive(:last).and_return('list')
    end

    it 'creates Cleanbox instance with IMAP connection and options' do
      expect(Cleanbox).to receive(:new).with(mock_imap, cli.options)
      cli.send(:execute_action)
    end

    it 'calls the determined action on Cleanbox' do
      expect(mock_cleanbox).to receive(:send).with('show_lists!')
      cli.send(:execute_action)
    end
  end

  describe '#handle_analyze_command' do
    let(:mock_imap) { double('IMAP') }
    let(:mock_analyzer_cli) { double('AnalyzerCLI') }

    before do
      allow(cli).to receive(:create_imap_connection).and_return(mock_imap)
      allow(CLI::AnalyzerCLI).to receive(:new).and_return(mock_analyzer_cli)
      allow(mock_analyzer_cli).to receive(:run)
      allow(cli).to receive(:exit)
      allow(ARGV).to receive(:first).and_return('analyze')
      allow(ARGV).to receive(:delete).with('analyze')
    end

    it 'creates IMAP connection for analysis' do
      expect(cli).to receive(:create_imap_connection)
      cli.send(:handle_analyze_command)
    end

    it 'creates AnalyzerCLI with IMAP connection and options' do
      expect(CLI::AnalyzerCLI).to receive(:new).with(mock_imap, cli.options)
      cli.send(:handle_analyze_command)
    end

    it 'runs the analyzer CLI' do
      expect(mock_analyzer_cli).to receive(:run)
      cli.send(:handle_analyze_command)
    end

    it 'exits after running analysis' do
      expect(cli).to receive(:exit).with(0)
      cli.send(:handle_analyze_command)
    end

    it 'removes analyze from ARGV' do
      expect(ARGV).to receive(:delete).with('analyze')
      cli.send(:handle_analyze_command)
    end

    context 'when analyze command is not provided' do
      before do
        allow(ARGV).to receive(:first).and_return('other')
      end

      it 'does not create IMAP connection' do
        expect(cli).not_to receive(:create_imap_connection)
        cli.send(:handle_analyze_command)
      end

      it 'does not create AnalyzerCLI' do
        expect(CLI::AnalyzerCLI).not_to receive(:new)
        cli.send(:handle_analyze_command)
      end

      it 'does not exit' do
        expect(cli).not_to receive(:exit)
        cli.send(:handle_analyze_command)
      end
    end
  end
end
