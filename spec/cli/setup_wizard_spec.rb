# frozen_string_literal: true

require 'spec_helper'
require 'cli/setup_wizard'

RSpec.describe CLI::SetupWizard do
  let(:wizard) { described_class.new(verbose: false) }
  let(:mock_config_manager) { instance_double(CLI::ConfigManager) }
  let(:mock_imap) { instance_double(Net::IMAP) }
  let(:mock_analyzer) { instance_double(Analysis::EmailAnalyzer) }

  before do
    # Mock dependencies
    allow(CLI::ConfigManager).to receive(:new).and_return(mock_config_manager)
    allow(mock_config_manager).to receive(:load_config).and_return({})
    allow(mock_config_manager).to receive(:save_config)
    allow(mock_config_manager).to receive(:instance_variable_get).with(:@config_path).and_return('/tmp/test_config.yml')
    
    allow(CLI::SecretsManager).to receive(:create_env_file)
    allow(CLI::SecretsManager).to receive(:value_from_env_or_secrets).and_return('test_value')
    
    allow(Net::IMAP).to receive(:new).and_return(mock_imap)
    allow(Auth::AuthenticationManager).to receive(:authenticate_imap)
    
    # Mock file existence check
    allow(File).to receive(:exist?).and_return(false)
    
    # Mock system calls
    allow(wizard).to receive(:system)
  end

  describe '#initialize' do
    it 'creates a new setup wizard with default settings' do
      wizard = described_class.new
      expect(wizard.config_manager).to respond_to(:load_config)
      expect(wizard.provider).to be_nil
    end

    it 'creates a setup wizard with verbose logging' do
      wizard = described_class.new(verbose: true)
      expect(wizard.instance_variable_get(:@verbose)).to be true
    end
  end

  describe '#run' do
    context 'when configuration file exists' do
      before do
        allow(File).to receive(:exist?).and_return(true)
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
          
          # Mock the config manager to return existing config for update mode
          allow(mock_config_manager).to receive(:load_config).and_return(existing_config)
          
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
          expect(wizard.instance_variable_get(:@update_mode)).to be true
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

        it 'loads existing config for update mode' do
          allow(wizard).to receive(:interactive_configuration).and_return({
            whitelist_folders: ['Work'],
            list_folders: ['Newsletters'],
            domain_mappings: { 'example.com' => 'Newsletters' }
          })
          allow(wizard).to receive(:save_configuration)
          allow(wizard).to receive(:validate_and_preview)
          expect(mock_config_manager).to receive(:load_config).ordered
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
          expect(wizard.instance_variable_get(:@update_mode)).to be false
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
        expect(wizard.instance_variable_get(:@update_mode)).to be false
      end

      it 'calls all setup steps in order' do
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
          allow(wizard).to receive(:get_connection_details).and_return({
            details: { host: 'test.com', username: 'test@example.com' },
            secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
          })
          allow(wizard).to receive(:connect_and_analyze).and_raise(RuntimeError, 'Connection failed')
        end

        it 'handles connection errors gracefully' do
          expect { wizard.run }.to output(/❌ Connection failed: Connection failed/).to_stdout
        end

        it 'does not proceed with setup' do
          expect(wizard).not_to receive(:generate_recommendations)
          wizard.run
        end
      end
    end
  end
end 