# frozen_string_literal: true

require 'spec_helper'
require 'cli/setup_wizard'

RSpec.describe CLI::SetupWizard do
  let(:temp_dir) { Dir.mktmpdir('cleanbox_test') }
  let(:config_path) { File.join(temp_dir, '.cleanbox.yml') }
  let(:config_options) { { config_file: config_path } }
  let(:wizard) { described_class.new(verbose: false) }
  let(:mock_imap) { instance_double(Net::IMAP) }
  let(:mock_analyzer) { instance_double(Analysis::EmailAnalyzer) }

  before do
    # Mock dependencies
    allow(CLI::SecretsManager).to receive(:create_env_file)
    allow(CLI::SecretsManager).to receive(:value_from_env_or_secrets).and_return('test_value')
    allow(CLI::SecretsManager).to receive(:auth_secrets_available?).and_return(false)
    
    allow(Net::IMAP).to receive(:new).and_return(mock_imap)
    allow(Auth::AuthenticationManager).to receive(:authenticate_imap)
    
    # Mock system calls
    allow(wizard).to receive(:system)
  end

  after do
    FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
  end

  describe '#initialize' do
    it 'creates a new setup wizard with default settings' do
      wizard = described_class.new
      expect(wizard.config_manager).to respond_to(:load_config)
      expect(wizard.provider).to be_nil
    end

    it 'creates a setup wizard with verbose logging' do
      wizard = described_class.new(verbose: true)
      expect(wizard.verbose).to be true
    end
  end

  describe '#run' do
    context 'when configuration file exists' do
      before do
        allow(File).to receive(:exist?).and_return(true)
        allow(wizard).to receive(:auth_configured?).and_return(true)
      end

      context 'when user chooses update mode (1)' do
        let(:existing_config) {
          {
            host: 'outlook.office365.com',
            username: 'test@example.com',
            auth_type: 'oauth2_microsoft'
          }
        }

        before do
          allow(wizard).to receive(:gets).and_return("1\n")
          
          # Mock the prompt methods that get_connection_details calls
          allow(wizard).to receive(:prompt).and_return('test_value')
          allow(wizard).to receive(:prompt_with_default).and_return('outlook.office365.com')
          allow(wizard).to receive(:prompt_choice).and_return('oauth2_microsoft')
          
          # Mock IMAP connection methods to prevent actual connection attempts
          allow(mock_imap).to receive(:list).and_return([])
          allow(mock_imap).to receive(:select).and_return(double('response', data: []))
          allow(mock_imap).to receive(:search).and_return([])
          allow(mock_imap).to receive(:fetch).and_return([])
        end

        it 'prompts for update mode choice' do
          expect { wizard.run }.to output(/Configuration file already exists!/).to_stdout
        end

        it 'sets update mode and proceeds with setup' do
          wizard.run
          expect(wizard.update_mode).to be true
        end

        it 'uses existing config in update mode' do
          allow(wizard).to receive(:interactive_configuration).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:save_configuration)
          allow(wizard).to receive(:validate_and_preview)
          expect { wizard.run }.to output(/Using existing connection settings/).to_stdout
        end

        it 'uses existing config for update mode' do
          allow(wizard).to receive(:interactive_configuration).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:save_configuration)
          allow(wizard).to receive(:validate_and_preview)
          wizard.run
        end

        context 'with missing host' do
          let(:existing_config) {
            {
              username: 'test@example.com',
              auth_type: 'oauth2_microsoft'
            }
          }

          it 'prompts for host' do
            # Mock prompt_with_default to output the expected message and return a value
            allow(wizard).to receive(:prompt_with_default).with("IMAP Host", "outlook.office365.com") do |message, default|
              puts "#{message}: #{default}"
              "outlook.office365.com"
            end
            
            # Mock other required methods to prevent actual execution
            allow(wizard).to receive(:interactive_configuration).and_return({
              whitelist_folders: ['Work'],
              list_folders: ['Newsletters'],
              domain_mappings: { 'example.com' => 'Newsletters' }
            })
            allow(wizard).to receive(:save_configuration)
            allow(wizard).to receive(:validate_and_preview)
            
            expect { wizard.run }.to output(/IMAP Host/).to_stdout
          end
        end
        
      end

      context 'when user chooses full setup mode (2)' do
        before do
          allow(wizard).to receive(:gets).and_return("2\n")
          allow(wizard).to receive(:get_connection_details).and_return({
            details: { host: 'test.com', username: 'test@example.com' },
            secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
          })
          allow(wizard).to receive(:connect_and_analyze)
          allow(wizard).to receive(:generate_recommendations).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:interactive_configuration).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:save_configuration)
          allow(wizard).to receive(:validate_and_preview)
        end

        it 'sets full setup mode and proceeds' do
          wizard.run
          expect(wizard.update_mode).to be false
        end
      end

      context 'when user cancels (3)' do
        before do
          allow(wizard).to receive(:gets).and_return("3\n")
        end

        it 'exits early without proceeding' do
          expect(wizard.run).to be_nil
        end

        it 'outputs cancellation message' do
          expect { wizard.run }.to output(/Setup cancelled/).to_stdout
        end
      end

      context 'when user provides invalid input' do
        before do
          allow(wizard).to receive(:gets).and_return("invalid\n")
        end

        it 'exits early without proceeding' do
          expect(wizard.run).to be_nil
        end

        it 'outputs error message' do
          expect { wizard.run }.to output(/Invalid choice/).to_stdout
        end
      end
    end

    context 'when configuration file does not exist' do
      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(wizard).to receive(:auth_configured?).and_return(false)
        # Mock the user to choose to skip authentication setup
        allow(wizard).to receive(:gets).and_return("2\n")
        allow(wizard).to receive(:get_connection_details).and_return({
          details: { host: 'test.com', username: 'test@example.com' },
          secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
        })
        allow(wizard).to receive(:connect_and_analyze)
        allow(wizard).to receive(:generate_recommendations).and_return({
          whitelist_folders: ['Work'],
          list_folders: ['Newsletters'],
          domain_mappings: { 'example.com' => 'Newsletters' }
        })
        allow(wizard).to receive(:interactive_configuration).and_return({
          whitelist_folders: ['Work'],
          list_folders: ['Newsletters'],
          domain_mappings: { 'example.com' => 'Newsletters' }
        })
        allow(wizard).to receive(:save_configuration)
        allow(wizard).to receive(:validate_and_preview)
      end

      it 'sets full setup mode and proceeds' do
        wizard.run
        expect(wizard.update_mode).to be false
      end

      it 'calls all setup steps in order' do
        # Mock the authentication setup to skip it
        allow_any_instance_of(CLI::AuthCLI).to receive(:setup_auth)
        
        expect(wizard).to receive(:get_connection_details).ordered
        expect(wizard).to receive(:connect_and_analyze).ordered
        expect(wizard).to receive(:generate_recommendations).ordered
        expect(wizard).to receive(:interactive_configuration).ordered
        expect(wizard).to receive(:save_configuration).ordered
        expect(wizard).to receive(:validate_and_preview).ordered
        
        wizard.run
      end

      it 'outputs welcome message' do
        expect { wizard.run }.to output(/Welcome to Cleanbox Setup Wizard!/).to_stdout
      end
    end

    context 'error handling' do
      context 'when connection fails' do
        before do
          allow(File).to receive(:exist?).and_return(false)
          allow(wizard).to receive(:auth_configured?).and_return(false)
          # Mock the user to choose to skip authentication setup
          allow(wizard).to receive(:gets).and_return("2\n")
          allow(wizard).to receive(:get_connection_details).and_return({
            details: { host: 'test.com', username: 'test@example.com' },
            secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
          })
          allow(wizard).to receive(:connect_and_analyze).and_raise(RuntimeError, 'Connection failed')
        end

        it 'handles connection errors gracefully' do
          # Mock the authentication setup to skip it
          allow_any_instance_of(CLI::AuthCLI).to receive(:setup_auth)
          
          expect { wizard.run }.to output(/❌ Connection failed: Connection failed/).to_stdout
        end

        it 'does not proceed with setup' do
          # Mock the authentication setup to skip it
          allow_any_instance_of(CLI::AuthCLI).to receive(:setup_auth)
          
          expect(wizard).not_to receive(:generate_recommendations)
          wizard.run
        end
      end
    end
  end

  describe '#auth_configured?' do
    context 'when no config file exists' do
      it 'returns false' do
        expect(wizard.send(:auth_configured?)).to be false
      end
    end

    context 'when config file exists but has no auth fields' do
      it 'returns false' do
        expect(wizard.send(:auth_configured?)).to be false
      end
    end

    context 'when config file exists with auth fields but no secrets' do
      before do
        allow(CLI::SecretsManager).to receive(:auth_secrets_available?).and_return(false)
      end

      it 'returns false' do
        expect(wizard.send(:auth_configured?)).to be false
      end
    end

    context 'when config file exists with auth fields and secrets' do
      let(:config_options) do
        {
          host: 'outlook.office365.com',
          username: 'test@example.com',
          auth_type: 'oauth2_microsoft'
        }
      end

      before do
        allow(CLI::SecretsManager).to receive(:auth_secrets_available?).and_return(true)
      end

      it 'returns true' do
        expect(wizard.send(:auth_configured?)).to be true
      end
    end
  end

  describe '#run with authentication detection' do
    context 'when authentication is not configured' do
      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(wizard).to receive(:auth_configured?).and_return(false)
      end

      context 'when user chooses to set up authentication (1)' do
        before do
          allow(wizard).to receive(:gets).and_return("1\n")
          # Mock the AuthCLI methods to prevent actual execution
          allow_any_instance_of(CLI::AuthCLI).to receive(:setup_auth)
          allow(wizard).to receive(:get_connection_details).and_return({
            details: { host: 'test.com', username: 'test@example.com' },
            secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
          })
          allow(wizard).to receive(:connect_and_analyze)
          allow(wizard).to receive(:generate_recommendations).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:interactive_configuration).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:save_configuration)
          allow(wizard).to receive(:validate_and_preview)
        end

        it 'prompts for authentication setup choice' do
          expect { wizard.run }.to output(/Authentication not configured!/).to_stdout
        end

        it 'offers to set up authentication' do
          expect { wizard.run }.to output(/Set up authentication now/).to_stdout
        end
      end

      context 'when user chooses to skip authentication setup (2)' do
        before do
          allow(wizard).to receive(:gets).and_return("2\n")
          allow(wizard).to receive(:get_connection_details).and_return({
            details: { host: 'test.com', username: 'test@example.com' },
            secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
          })
          allow(wizard).to receive(:connect_and_analyze)
          allow(wizard).to receive(:generate_recommendations).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:interactive_configuration).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:save_configuration)
          allow(wizard).to receive(:validate_and_preview)
        end

        it 'skips authentication setup and continues' do
          expect { wizard.run }.to output(/Skipping authentication setup/).to_stdout
        end
      end

      context 'when user cancels (3)' do
        before do
          allow(wizard).to receive(:gets).and_return("3\n")
        end

        it 'exits early' do
          expect(wizard.run).to be_nil
        end

        it 'outputs cancellation message' do
          expect { wizard.run }.to output(/Setup cancelled/).to_stdout
        end
      end
    end

    context 'when authentication is already configured' do
      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(wizard).to receive(:auth_configured?).and_return(true)
        allow(wizard).to receive(:get_connection_details).and_return({
          details: { host: 'test.com', username: 'test@example.com' },
          secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
        })
        allow(wizard).to receive(:connect_and_analyze)
        allow(wizard).to receive(:generate_recommendations).and_return({
          whitelist_folders: ['Work'],
          list_folders: ['Newsletters'],
          domain_mappings: { 'example.com' => 'Newsletters' }
        })
        allow(wizard).to receive(:interactive_configuration).and_return({
          whitelist_folders: ['Work'],
          list_folders: ['Newsletters'],
          domain_mappings: { 'example.com' => 'Newsletters' }
        })
        allow(wizard).to receive(:save_configuration)
        allow(wizard).to receive(:validate_and_preview)
      end

      it 'skips authentication setup and proceeds directly' do
        expect { wizard.run }.not_to output(/Authentication not configured!/).to_stdout
      end
    end
  end

  describe '#interactive_folder_categorization' do
    let(:folders) do
      [
        { name: 'Work', message_count: 100 },
        { name: 'Newsletters', message_count: 50 },
        { name: 'Family', message_count: 25 }
      ]
    end

    let(:mock_categorizer) { instance_double(Analysis::FolderCategorizer) }

    before do
      allow(Analysis::FolderCategorizer).to receive(:new).and_return(mock_categorizer)
      allow(wizard).to receive(:puts)
      allow(wizard).to receive(:gets).and_return("Y\n")
    end

    context 'when user accepts default categorization' do
      before do
        allow(mock_categorizer).to receive(:categorization).and_return(:whitelist)
        allow(mock_categorizer).to receive(:categorization_reason).and_return('Contains work emails')
      end

      it 'accepts empty response as yes' do
        allow(wizard).to receive(:gets).and_return("\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:whitelist)
      end

      it 'accepts "y" as yes' do
        allow(wizard).to receive(:gets).and_return("y\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:whitelist)
      end

      it 'accepts "yes" as yes' do
        allow(wizard).to receive(:gets).and_return("yes\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:whitelist)
      end
    end

    context 'when user disagrees and chooses different option' do
      before do
        allow(mock_categorizer).to receive(:categorization).and_return(:list)
        allow(mock_categorizer).to receive(:categorization_reason).and_return('Contains newsletters')
      end

      it 'allows user to choose whitelist when disagreeing' do
        allow(wizard).to receive(:gets).and_return("n\n", "w\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:whitelist)
      end

      it 'allows user to choose list when disagreeing' do
        allow(wizard).to receive(:gets).and_return("n\n", "l\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:list)
      end

      it 'allows user to choose skip when disagreeing' do
        allow(wizard).to receive(:gets).and_return("n\n", "s\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:skip)
      end

      it 'uses default when invalid choice is provided' do
        allow(wizard).to receive(:gets).and_return("n\n", "invalid\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:list)
      end
    end

    context 'when user directly chooses an option' do
      before do
        allow(mock_categorizer).to receive(:categorization).and_return(:whitelist)
        allow(mock_categorizer).to receive(:categorization_reason).and_return('Contains work emails')
      end

      it 'allows direct choice of whitelist' do
        allow(wizard).to receive(:gets).and_return("w\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:whitelist)
      end

      it 'allows direct choice of list' do
        allow(wizard).to receive(:gets).and_return("l\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:list)
      end

      it 'allows direct choice of skip' do
        allow(wizard).to receive(:gets).and_return("s\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:skip)
      end

      it 'uses default when invalid direct choice is provided' do
        allow(wizard).to receive(:gets).and_return("x\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.first[:categorization]).to eq(:whitelist)
      end
    end

    context 'with multiple folders' do
      before do
        allow(mock_categorizer).to receive(:categorization).and_return(:whitelist, :list, :skip)
        allow(mock_categorizer).to receive(:categorization_reason).and_return('Work emails', 'Newsletters', 'Personal')
      end

      it 'processes all folders with different user choices' do
        allow(wizard).to receive(:gets).and_return("Y\n", "n\n", "w\n", "l\n")
        
        result = wizard.send(:interactive_folder_categorization, folders)
        
        expect(result.length).to eq(3)
        expect(result[0][:categorization]).to eq(:whitelist)  # Accepted default
        expect(result[1][:categorization]).to eq(:whitelist)  # Disagreed, chose whitelist
        expect(result[2][:categorization]).to eq(:list)       # Direct choice
      end
    end
  end
end 