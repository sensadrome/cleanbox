# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe CLI::ConfigManager do
  let(:temp_config_path) { Tempfile.new(['test_config', '.yml']).path }
  let(:config_manager) { described_class.new(temp_config_path) }

  after do
    File.delete(temp_config_path) if File.exist?(temp_config_path)
  end

  describe '#initialize' do
    it 'creates a new config manager instance' do
      expect(config_manager).to be_a(CLI::ConfigManager)
    end

    it 'sets the config path' do
      expect(config_manager.instance_variable_get(:@config_path)).to eq(temp_config_path)
    end
  end

  describe '#load_config' do
    context 'when config file exists' do
      let(:test_config) do
        {
          host: 'test.example.com',
          username: 'test@example.com',
          whitelist_folders: ['Family', 'Work']
        }
      end

      before do
        File.write(temp_config_path, test_config.to_yaml)
      end

      it 'loads the configuration from file' do
        config = config_manager.load_config
        expect(config[:host]).to eq('test.example.com')
        expect(config[:username]).to eq('test@example.com')
        expect(config[:whitelist_folders]).to eq(['Family', 'Work'])
      end
    end

    context 'when config file does not exist' do
      it 'returns an empty hash' do
        config = config_manager.load_config
        expect(config).to eq({})
      end
    end
  end

  describe '#save_config' do
    let(:test_config) do
      {
        host: 'test.example.com',
        username: 'test@example.com',
        whitelist_folders: ['Family', 'Work']
      }
    end

    it 'saves configuration to file' do
      config_manager.save_config(test_config)
      
      expect(File.exist?(temp_config_path)).to be true
      
      loaded_config = YAML.load_file(temp_config_path)
      expect(loaded_config[:host]).to eq('test.example.com')
      expect(loaded_config[:username]).to eq('test@example.com')
      expect(loaded_config[:whitelist_folders]).to eq(['Family', 'Work'])
    end
  end

  describe '#get_recognized_keys' do
    it 'returns an array of recognized configuration keys' do
      keys = config_manager.send(:get_recognized_keys)
      
      expect(keys).to be_an(Array)
      expect(keys).to include(:host, :username, :whitelist_folders, :list_folders)
    end
  end

  describe '#create_comprehensive_config' do
    it 'returns a hash with all configuration options' do
      config = config_manager.send(:create_comprehensive_config)
      
      expect(config).to be_a(Hash)
      expect(config['host']).to eq('outlook.office365.com')
      expect(config['auth_type']).to eq('oauth2_microsoft')
      expect(config['whitelist_folders']).to be_an(Array)
    end
  end
end 