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
  # let(:output) { StringIO.new }

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
    FileUtils.rm_rf(temp_dir)
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
        let(:existing_config) do
          {
            host: 'outlook.office365.com',
            username: 'test@example.com',
            auth_type: 'oauth2_microsoft'
          }
        end

        before do
          allow(wizard).to receive(:gets).and_return("1\n")

          # Mock the prompt methods that retrieve_connection_details calls
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
          wizard.run
          expect(output.string).to include('Configuration file already exists!')
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
          wizard.run
          expect(output.string).to include('Using existing connection settings')
        end

        context 'with missing host' do
          let(:config_options) do
            {
              username: 'test@example.com',
              auth_type: 'oauth2_microsoft'
            }
          end

          it 'fails fast when config is incomplete' do
            # Expect the wizard to fail fast when config is missing required fields
            wizard.run
            expect(output.string).to include('Configuration is incomplete')
            expect(wizard.run).to be_nil
          end
        end

        context 'with valid existing config' do
          let(:config_options) do
            {
              host: 'outlook.office365.com',
              username: 'test@example.com',
              auth_type: 'oauth2_microsoft'
            }
          end

          before do
            # Mock successful IMAP connection and analysis
            allow(mock_imap).to receive(:list).and_return([
              double('folder', name: 'INBOX'),
              double('folder', name: 'Sent'),
              double('folder', name: 'Drafts')
            ])
            allow(mock_imap).to receive(:select).and_return(double('response', data: []))
            allow(mock_imap).to receive(:search).and_return(['1', '2', '3'])
            allow(mock_imap).to receive(:fetch).and_return([
              double('message', attr: { 'from' => 'sender@example.com', 'subject' => 'Test 1' }),
              double('message', attr: { 'from' => 'sender@example.com', 'subject' => 'Test 2' }),
              double('message', attr: { 'from' => 'sender@example.com', 'subject' => 'Test 3' })
            ])

            # Mock successful analysis and configuration
            allow(wizard).to receive(:run_analysis).and_return({
              total_messages: 3,
              folder_counts: { 'INBOX' => 3 },
              domain_counts: { 'example.com' => 3 }
            })
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

          it 'successfully proceeds with folder analysis using existing credentials' do
            wizard.run
            expect(output.string).to include('Using existing connection settings')
            expect(output.string).to include('Setup complete')
          end

          it 'runs analysis on existing folders' do
            expect(wizard).to receive(:run_analysis)
            wizard.run
          end

          it 'generates recommendations based on analysis' do
            expect(wizard).to receive(:generate_recommendations)
            wizard.run
          end

          it 'saves the final configuration' do
            expect(wizard).to receive(:save_configuration)
            wizard.run
          end

          context 'blacklist folder detection' do

            context 'with preconfigured blacklist folder' do
              let(:config_options) do
                {
                  host: 'outlook.office365.com',
                  username: 'test@example.com',
                  auth_type: 'oauth2_microsoft',
                  blacklist_folder: 'Junk'
                }
              end

              it 'uses preconfigured blacklist folder' do
                wizard.run
                
                expect(output.string).to include('Using existing connection settings')
                expect(output.string).to include('Setup complete')
                # Should not show blacklist folder detection since it's preconfigured
                expect(output.string).not_to include('🚫 Blacklist Folder Detection')
              end
            end

            context 'with potential blacklist folders detected' do
              before do
                # Override the mock_imap.list to return potential blacklist candidates
                allow(mock_imap).to receive(:list).and_return([
                  double('folder', name: 'INBOX'),
                  double('folder', name: 'Unsubscribe'),
                  double('folder', name: 'Blacklist'),
                  double('folder', name: 'Sent')
                ])
              end

              it 'detects and prompts for blacklist folder choice' do
                wizard.run
                
                expect(output.string).to include('🚫 Blacklist Folder Detection')
                expect(output.string).to include('Found potential blacklist folders')
                expect(output.string).to include('Unsubscribe')
                expect(output.string).to include('Blacklist')
              end
            end

            context 'with no potential blacklist folders' do
              before do
                # Override the mock_imap.list to return no blacklist candidates
                allow(mock_imap).to receive(:list).and_return([
                  double('folder', name: 'INBOX'),
                  double('folder', name: 'Work'),
                  double('folder', name: 'Sent')
                ])
              end

              it 'prompts to create blacklist folder' do
                wizard.run
                
                expect(output.string).to include('🚫 Blacklist Folder Detection')
                expect(output.string).to include('No obvious blacklist folders found')
                expect(output.string).to include('Would you like to create a blacklist folder')
              end
            end
          end
        end
      end

      context 'when user chooses full setup mode (2)' do
        before do
          allow(wizard).to receive(:gets).and_return("2\n")
          allow(wizard).to receive(:retrieve_connection_details).and_return({
                                                                         details: { host: 'test.com',
                                                                                    username: 'test@example.com' },
                                                                         secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
                                                                       })
          allow(wizard).to receive(:run_analysis)
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
          wizard.run
          expect(output.string).to include('Setup cancelled')
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
          wizard.run
          expect(output.string).to include('Invalid choice')
        end
      end
    end

    context 'when configuration file does not exist' do
      before do
        allow(File).to receive(:exist?).and_return(false)
        # allow(wizard).to receive(:auth_configured?).and_return(false)
        # Mock the user to choose to skip authentication setup
        allow(wizard).to receive(:gets).and_return("2\n")
        allow(wizard).to receive(:retrieve_connection_details) do
          wizard.instance_variable_set(:@details, { host: 'test.com', username: 'test@example.com', auth_type: 'password' })
          wizard.instance_variable_set(:@secrets, { 'CLEANBOX_PASSWORD' => 'password123' })
          nil
        end
        allow(wizard).to receive(:determine_blacklist_folder).and_return('blacklisted')
        allow(wizard).to receive(:run_analysis)
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

        expect(wizard).to receive(:retrieve_connection_details).ordered
        expect(wizard).to receive(:run_analysis).ordered
        expect(wizard).to receive(:generate_recommendations).ordered
        expect(wizard).to receive(:interactive_configuration).ordered
        expect(wizard).to receive(:save_configuration).ordered
        expect(wizard).to receive(:validate_and_preview).ordered

        wizard.run
      end

      it 'outputs welcome message' do
        wizard.run
        expect(output.string).to include('Welcome to Cleanbox Setup Wizard!')
      end
    end

    context 'error handling' do
      context 'when connection fails' do
        before do
          allow(File).to receive(:exist?).and_return(false)
          allow(wizard).to receive(:auth_configured?).and_return(false)
          # Mock the user to choose to skip authentication setup
          allow(wizard).to receive(:gets).and_return("2\n")
          allow(wizard).to receive(:retrieve_connection_details) do
            wizard.instance_variable_set(:@details, { host: 'test.com', username: 'test@example.com', auth_type: 'password' })
            wizard.instance_variable_set(:@secrets, { 'CLEANBOX_PASSWORD' => 'password123' })
            nil
          end
          allow(wizard).to receive(:establish_imap_connection).and_raise(RuntimeError, 'Connection failed')
        end

        it 'handles connection errors gracefully' do
          # Mock the authentication setup to skip it
          allow_any_instance_of(CLI::AuthCLI).to receive(:setup_auth)

          wizard.run
          expect(output.string).to include('❌ Connection failed: Connection failed')
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
        # allow(wizard).to receive(:auth_configured?).and_return(false)
      end

      context 'when user chooses to set up authentication (1)' do
        before do
          allow(wizard).to receive(:gets).and_return("1\n")

          # Mock AuthenticationGatherer since we now use it directly
          mock_gatherer = instance_double(CLI::AuthenticationGatherer)
          allow(mock_gatherer).to receive(:gather_authentication_details!)
          allow(mock_gatherer).to receive(:connection_details).and_return({
            host: 'test.com',
            username: 'test@example.com',
            auth_type: 'password'
          })
          allow(mock_gatherer).to receive(:secrets).and_return({ 'CLEANBOX_PASSWORD' => 'password123' })
          allow(CLI::AuthenticationGatherer).to receive(:new).and_return(mock_gatherer)

          allow(wizard).to receive(:determine_blacklist_folder)
          allow(wizard).to receive(:run_analysis)
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
          wizard.run
          expect(output.string).to include('Authentication not configured!')
        end

        it 'offers to set up authentication' do
          wizard.run
          expect(output.string).to include('Set up authentication now')
        end
      end

      context 'when user chooses to skip authentication setup (2)' do
        before do
          allow(wizard).to receive(:gets).and_return("2\n")
          allow(wizard).to receive(:retrieve_connection_details).and_return({
                                                                         details: { host: 'test.com',
                                                                                    username: 'test@example.com' },
                                                                         secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
                                                                       })
          allow(wizard).to receive(:run_analysis)
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
          wizard.run
          expect(output.string).to include('Skipping authentication setup')
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
          wizard.run
          expect(output.string).to include('Setup cancelled')
        end
      end
    end

    context 'when authentication is already configured' do
      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(wizard).to receive(:auth_configured?).and_return(true)
        allow(wizard).to receive(:retrieve_connection_details).and_return({
                                                                       details: { host: 'test.com',
                                                                                  username: 'test@example.com' },
                                                                       secrets: { 'CLEANBOX_PASSWORD' => 'password123' }
                                                                     })
        allow(wizard).to receive(:run_analysis)
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
        wizard.run
        expect(output.string).not_to include('Authentication not configured!')
      end
    end
  end

  describe '#interactive_folder_categorization' do
    let(:folders) do
      [
        { name: 'Work', message_count: 100, categorization: :whitelist, categorization_reason: 'Contains work emails' },
        { name: 'Newsletters', message_count: 50, categorization: :list, categorization_reason: 'Contains newsletters' },
        { name: 'Family', message_count: 25, categorization: :whitelist, categorization_reason: 'Contains family emails' }
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

        expect(result.first[:categorization]).to eq(:whitelist)
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
