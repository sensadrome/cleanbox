# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe CLI::ConfigManager do
  let(:temp_config_path) { Tempfile.new(['test_config', '.yml']).path }
  let(:config_manager) { described_class.new(temp_config_path) }

  before do
    # Clean up any existing test config
    File.delete(temp_config_path) if File.exist?(temp_config_path)
  end

  after do
    # Clean up test config
    File.delete(temp_config_path) if File.exist?(temp_config_path)
  end

  describe '#initialize' do
    context 'with custom config path' do
      it 'uses the provided path' do
        custom_path = '/custom/path/config.yml'
        manager = described_class.new(custom_path)
        expect(manager.instance_variable_get(:@config_path)).to eq(custom_path)
      end
    end

    context 'without config path' do
      it 'uses default path from environment' do
        allow(ENV).to receive(:fetch).with('CLEANBOX_CONFIG', anything).and_return('/default/config.yml')
        manager = described_class.new
        expect(manager.instance_variable_get(:@config_path)).to eq('/default/config.yml')
      end
    end
  end

  describe '#show' do
    context 'when config file does not exist' do
      it 'shows appropriate message' do
        expect { config_manager.show }.to output("No configuration file found at #{temp_config_path}\n").to_stdout
      end
    end

    context 'when config file exists' do
      let(:sample_config) do
        {
          host: 'outlook.office365.com',
          username: 'test@example.com',
          whitelist_folders: ['Inbox', 'Sent'],
          deprecated_key: 'old_value'
        }
      end

      before do
        File.write(temp_config_path, sample_config.to_yaml)
        # Ensure the file exists
        expect(File.exist?(temp_config_path)).to be true
      end

      it 'shows recognized keys' do
        expect { config_manager.show }.to output(/Configuration from #{temp_config_path}:/).to_stdout
        expect { config_manager.show }.to output(/host: outlook\.office365\.com/).to_stdout
        expect { config_manager.show }.to output(/username: test@example\.com/).to_stdout
      end

      it 'shows deprecated keys warning' do
        expect { config_manager.show }.to output(/Note: Found deprecated keys in your config:/).to_stdout
        expect { config_manager.show }.to output(/- deprecated_key/).to_stdout
      end

      it 'shows missing recognized keys' do
        expect { config_manager.show }.to output(/Recognized keys you have not set/).to_stdout
        expect { config_manager.show }.to output(/- auth_type/).to_stdout
      end
    end
  end

  describe '#get' do
    context 'when key exists' do
      before do
        config = { username: 'test@example.com', folders: ['Inbox', 'Sent'] }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'shows string value' do
        expect { config_manager.get('username') }.to output(/test@example\.com/).to_stdout
      end

      it 'shows array value' do
        expect { config_manager.get('folders') }.to output(/- Inbox\n- Sent/m).to_stdout
      end
    end

    context 'when key does not exist' do
      before do
        config = { username: 'test@example.com' }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'shows not found message' do
        expect { config_manager.get('nonexistent') }.to output("Key 'nonexistent' not found in configuration\n").to_stdout
      end
    end
  end

  describe '#set' do
    context 'with string value' do
      it 'sets simple string value' do
        config_manager.set('username', 'new@example.com')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:username]).to eq('new@example.com')
      end

      it 'shows success message' do
        expect { config_manager.set('username', 'new@example.com') }
          .to output("Configuration saved to #{temp_config_path}\n").to_stdout
      end
    end

    context 'with YAML value' do
      it 'parses and sets array' do
        config_manager.set('folders', '["Inbox", "Sent"]')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:folders]).to eq(['Inbox', 'Sent'])
      end

      it 'parses and sets hash' do
        config_manager.set('settings', '{key1: value1, key2: value2}')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:settings]).to eq({ 'key1' => 'value1', 'key2' => 'value2' })
      end

      it 'falls back to string when YAML parsing fails' do
        config_manager.set('invalid_yaml', '{invalid: yaml:')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:invalid_yaml]).to eq('{invalid: yaml:')
      end
    end

    context 'with existing config' do
      before do
        existing_config = { username: 'old@example.com', folders: ['Old'] }
        File.write(temp_config_path, existing_config.to_yaml)
      end

      it 'updates existing key' do
        config_manager.set('username', 'new@example.com')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:username]).to eq('new@example.com')
        expect(loaded_config[:folders]).to eq(['Old']) # Preserves other keys
      end
    end
  end

  describe '#add' do
    context 'with array values' do
      before do
        config = { folders: ['Inbox'] }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'appends to existing array' do
        config_manager.add('folders', 'Sent')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:folders]).to eq(['Inbox', 'Sent'])
      end

      it 'shows success message' do
        expect { config_manager.add('folders', 'Sent') }
          .to output(/Added 'Sent' to folders.*Configuration saved to .+\.yml/m).to_stdout
      end
    end

    context 'with hash values' do
      before do
        config = { settings: { key1: 'value1' } }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'merges with existing hash' do
        config_manager.add('settings', '{key2: value2}')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:settings].transform_keys(&:to_s)).to eq({ "key1" => "value1", "key2" => "value2" })
      end

      it 'shows success message' do
        expect { config_manager.add('settings', '{key2: value2}') }
          .to output(/Merged hash into settings.*Configuration saved to .+\.yml/m).to_stdout
      end
    end

    context 'with new key' do
      it 'creates array for string value' do
        config_manager.add('folders', 'Inbox')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:folders]).to eq(['Inbox'])
      end

      it 'creates hash for hash value' do
        config_manager.add('settings', '{key1: value1}')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:settings]).to eq({ 'key1' => 'value1' })
      end
    end

    context 'with incompatible type' do
      before do
        config = { username: 'test@example.com' }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'shows error and exits' do
        expect { config_manager.add('username', 'new_value') }
          .to output("Cannot add to username (type: String)\n").to_stdout
          .and raise_error(SystemExit)
      end
    end
  end

  describe '#remove' do
    context 'with array values' do
      before do
        config = { folders: ['Inbox', 'Sent', 'Drafts'] }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'removes from array' do
        config_manager.remove('folders', 'Sent')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:folders]).to eq(['Inbox', 'Drafts'])
      end

      it 'shows success message' do
        expect { config_manager.remove('folders', 'Sent') }
          .to output(/Removed 'Sent' from folders.*Configuration saved to .+\.yml/m).to_stdout
      end

      it 'shows not found message for missing value' do
        expect { config_manager.remove('folders', 'Nonexistent') }
          .to output(/Value 'Nonexistent' not found in folders.*Configuration saved to .+\.yml/m).to_stdout
      end
    end

    context 'with hash values' do
      before do
        config = { settings: { key1: 'value1', key2: 'value2', key3: 'value3' } }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'removes keys from hash' do
        config_manager.remove('settings', '{key1: value1, key2: value2}')
        
        loaded_config = YAML.load_file(temp_config_path)
        loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
        expect(loaded_config[:settings].transform_keys(&:to_s)).to eq({ "key3" => "value3" })
      end

      it 'shows success message' do
        expect { config_manager.remove('settings', '{key1: value1, key2: value2}') }
          .to output(/(Removed keys key1, key2 from settings|No matching keys found in settings).*Configuration saved to .+\.yml/m).to_stdout
      end

      it 'shows no matching keys message' do
        expect { config_manager.remove('settings', '{nonexistent: value}') }
          .to output(/No matching keys found in settings.*Configuration saved to .+\.yml/m).to_stdout
      end
    end

    context 'with nonexistent key' do
      it 'shows error and exits' do
        expect { config_manager.remove('nonexistent', 'value') }
          .to output("Key 'nonexistent' not found in configuration\n").to_stdout
          .and raise_error(SystemExit)
      end
    end

    context 'with incompatible type' do
      before do
        config = { username: 'test@example.com' }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'shows error and exits' do
        expect { config_manager.remove('username', 'value') }
          .to output("Cannot remove from username (type: String)\n").to_stdout
          .and raise_error(SystemExit)
      end
    end
  end

  describe '#init' do
    context 'when config file does not exist' do
      it 'creates comprehensive config template' do
        expect { config_manager.init }.to output(/Comprehensive configuration template created at/).to_stdout
        
        expect(File.exist?(temp_config_path)).to be true
        config_content = File.read(temp_config_path)
        expect(config_content).to include('host:')
        expect(config_content).to include('username:')
        expect(config_content).to include('#')
      end
    end

    context 'when config file exists' do
      before do
        File.write(temp_config_path, { username: 'test@example.com' }.to_yaml)
      end

      it 'shows already exists message' do
        expect { config_manager.init }.to output(/Configuration file already exists at/).to_stdout
        expect { config_manager.init }.to output(/Use 'cleanbox config show' to view it/).to_stdout
      end
    end
  end

  describe '#handle_command' do
    context 'with show command' do
      it 'calls show method' do
        expect(config_manager).to receive(:show)
        config_manager.handle_command(['show'])
      end
    end

    context 'with get command' do
      it 'calls get method with key' do
        expect(config_manager).to receive(:get).with('username')
        config_manager.handle_command(['get', 'username'])
      end

      it 'shows usage and exits when key missing' do
        expect { config_manager.handle_command(['get']) }
          .to output("Usage: cleanbox config get <key>\n").to_stdout
          .and raise_error(SystemExit)
      end
    end

    context 'with set command' do
      it 'calls set method with key and value' do
        expect(config_manager).to receive(:set).with('username', 'test@example.com')
        config_manager.handle_command(['set', 'username', 'test@example.com'])
      end

      it 'shows usage and exits when key or value missing' do
        expect { config_manager.handle_command(['set']) }
          .to output(/Usage: cleanbox config set <key> <value>/).to_stdout
          .and raise_error(SystemExit)
      end
    end

    context 'with add command' do
      it 'calls add method with key and value' do
        expect(config_manager).to receive(:add).with('folders', 'Inbox')
        config_manager.handle_command(['add', 'folders', 'Inbox'])
      end

      it 'shows usage and exits when key or value missing' do
        expect { config_manager.handle_command(['add']) }
          .to output(/Usage: cleanbox config add <key> <value>/).to_stdout
          .and raise_error(SystemExit)
      end
    end

    context 'with remove command' do
      it 'calls remove method with key and value' do
        expect(config_manager).to receive(:remove).with('folders', 'Inbox')
        config_manager.handle_command(['remove', 'folders', 'Inbox'])
      end

      it 'shows usage and exits when key or value missing' do
        expect { config_manager.handle_command(['remove']) }
          .to output(/Usage: cleanbox config remove <key> <value>/).to_stdout
          .and raise_error(SystemExit)
      end
    end

    context 'with init command' do
      it 'calls init method' do
        expect(config_manager).to receive(:init)
        config_manager.handle_command(['init'])
      end
    end

    context 'with unknown command' do
      it 'shows error and exits' do
        expect {
          begin
            config_manager.handle_command(['unknown'])
          rescue SystemExit
          end
        }.to output(/Unknown config command: unknown.*Available commands: show, get, set, add, remove, init/m).to_stdout
      end
    end
  end

  describe '#load_config' do
    context 'when file exists' do
      before do
        config = { username: 'test@example.com', folders: ['Inbox'] }
        File.write(temp_config_path, config.to_yaml)
      end

      it 'loads and converts keys to symbols' do
        result = config_manager.load_config
        expect(result).to eq({ username: 'test@example.com', folders: ['Inbox'] })
      end
    end

    context 'when file does not exist' do
      it 'returns empty hash' do
        result = config_manager.load_config
        expect(result).to eq({})
      end
    end

    context 'when file is empty' do
      before do
        File.write(temp_config_path, '')
      end

      it 'returns empty hash' do
        result = config_manager.load_config
        expect(result).to eq({})
      end
    end
  end

  describe '#save_config' do
    it 'creates directory if needed' do
      nested_path = '/tmp/nested/dir/config.yml'
      manager = described_class.new(nested_path)
      
      expect { manager.save_config({ username: 'test' }) }
        .to output("Configuration saved to #{nested_path}\n").to_stdout
      
      expect(File.exist?(nested_path)).to be true
      loaded_config = YAML.load_file(nested_path)
      loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
      expect(loaded_config[:username]).to eq('test')
    end

    it 'saves config to file' do
      config = { username: 'test@example.com', folders: ['Inbox'] }
      config_manager.save_config(config)
      
      loaded_config = YAML.load_file(temp_config_path)
      loaded_config = loaded_config.transform_keys(&:to_sym) if loaded_config
      expect(loaded_config).to eq({ username: 'test@example.com', folders: ['Inbox'] })
    end
  end

  describe 'private methods' do
    describe '#get_recognized_keys' do
      it 'returns list of recognized keys' do
        keys = config_manager.send(:get_recognized_keys)
        expect(keys).to include(:host, :username, :auth_type, :whitelist_folders)
        expect(keys).to be_an(Array)
      end
    end

    describe '#create_comprehensive_config' do
      it 'returns comprehensive config hash' do
        config = config_manager.send(:create_comprehensive_config)
        expect(config).to be_a(Hash)
        # Check that the config contains expected keys (the actual values may vary)
        expect(config.keys).to include('host', 'username')
        expect(config['host']).to be_a(String)
        expect(config['username']).to be_a(String)
      end
    end

    describe '#save_config_with_comments' do
      it 'saves config with comments' do
        config = { username: 'test@example.com' }
        config_manager.send(:save_config_with_comments, config)
        
        content = File.read(temp_config_path)
        expect(content).to include('#')
        expect(content).to include('username: test@example.com')
      end
    end

    describe '#generate_yaml_with_comments' do
      it 'generates YAML with comments' do
        config = { username: 'test@example.com' }
        result = config_manager.send(:generate_yaml_with_comments, config)
        
        expect(result).to include('#')
        expect(result).to include('username: test@example.com')
      end
    end
  end

  describe 'integration scenarios' do
    it 'handles full config lifecycle' do
      # Initialize config
      config_manager.init
      expect(File.exist?(temp_config_path)).to be true

      # Set values
      config_manager.set('username', 'test@example.com')
      config_manager.set('host', 'outlook.office365.com')
      config_manager.set('folders', '["Inbox", "Sent"]')

      # Add to arrays
      config_manager.add('folders', 'Drafts')

              # Get values
        expect { config_manager.get('username') }.to output(/test@example\.com/).to_stdout

      # Remove from arrays
      config_manager.remove('folders', 'Drafts')

      # Show final config
      expect { config_manager.show }.to output(/username: test@example\.com/).to_stdout
      expect { config_manager.show }.to output(/host: outlook\.office365\.com/).to_stdout

      # Verify final state
      final_config = YAML.load_file(temp_config_path)
      final_config = final_config.transform_keys(&:to_sym) if final_config
      expect(final_config[:username]).to eq('test@example.com')
      expect(final_config[:host]).to eq('outlook.office365.com')
      expect(final_config[:folders]).to eq(['Inbox', 'Sent'])
    end
  end
end 