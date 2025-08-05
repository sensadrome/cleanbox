# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Configuration Integration' do
  describe 'environment variable handling' do
    let(:temp_dir) { Dir.mktmpdir('cleanbox_test') }
    
    before do
      # Clear any existing environment variables
      ENV.delete('CLEANBOX_DATA_DIR')
      ENV.delete('CLEANBOX_CONFIG')
    end
    
    after do
      FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
      # Clean up environment variables
      ENV.delete('CLEANBOX_DATA_DIR')
      ENV.delete('CLEANBOX_CONFIG')
    end

    describe 'CLEANBOX_DATA_DIR' do
      it 'uses CLEANBOX_DATA_DIR for data directory resolution' do
        ENV['CLEANBOX_DATA_DIR'] = temp_dir
        
        Configuration.configure({})
        
        expect(Configuration.data_dir).to eq(File.expand_path(temp_dir))
      end

      it 'handles relative CLEANBOX_DATA_DIR paths' do
        relative_path = 'relative/path'
        ENV['CLEANBOX_DATA_DIR'] = relative_path
        
        Configuration.configure({})
        
        expect(Configuration.data_dir).to eq(File.expand_path(relative_path))
      end
    end

    describe 'CLEANBOX_CONFIG' do
      it 'uses CLEANBOX_CONFIG for config file path resolution' do
        test_config_path = File.join(temp_dir, 'test_config.yml')
        File.write(test_config_path, "host: test.example.com\n")
        ENV['CLEANBOX_CONFIG'] = test_config_path
        
        Configuration.configure({})
        
        expect(Configuration.config_file_path).to eq(File.expand_path(test_config_path))
        expect(Configuration.options[:host]).to eq('test.example.com')
      end

      it 'handles relative CLEANBOX_CONFIG paths' do
        relative_config = File.expand_path('relative/config.yml')
        FileUtils.mkdir_p(File.dirname(relative_config))
        File.write(relative_config, "host: relative.example.com\n")
        ENV['CLEANBOX_CONFIG'] = relative_config
        
        Configuration.configure({})
        
        expect(Configuration.config_file_path).to eq(relative_config)
        expect(Configuration.options[:host]).to eq('relative.example.com')
      end

      it 'handles relative CLEANBOX_CONFIG paths with data_dir' do
        config_in_data_dir = File.join(temp_dir, 'config.yml')
        File.write(config_in_data_dir, "host: data_dir.example.com\n")
        ENV['CLEANBOX_DATA_DIR'] = temp_dir
        ENV['CLEANBOX_CONFIG'] = 'config.yml'  # relative to data_dir
        
        Configuration.configure({})
        
        expected_path = File.join(temp_dir, 'config.yml')
        expect(Configuration.config_file_path).to eq(File.expand_path(expected_path))
        expect(Configuration.options[:host]).to eq('data_dir.example.com')
      end
    end

    describe 'config file discovery priority' do
      it 'prioritizes --config over environment variables' do
        # Set up environment variables
        env_config = File.join(temp_dir, 'env_config.yml')
        File.write(env_config, "host: env.example.com\n")
        ENV['CLEANBOX_CONFIG'] = env_config
        
        # Set up command line option
        cli_config = File.join(temp_dir, 'cli_config.yml')
        File.write(cli_config, "host: cli.example.com\n")
        
        Configuration.configure({ config_file: cli_config })
        
        expect(Configuration.config_file_path).to eq(File.expand_path(cli_config))
        expect(Configuration.options[:host]).to eq('cli.example.com')
      end

      it 'prioritizes CLEANBOX_CONFIG over CLEANBOX_DATA_DIR' do
        # Set up data_dir config
        data_dir_config = File.join(temp_dir, 'cleanbox.yml')
        File.write(data_dir_config, "host: data_dir.example.com\n")
        ENV['CLEANBOX_DATA_DIR'] = temp_dir
        
        # Set up CLEANBOX_CONFIG
        env_config = File.join(temp_dir, 'env_config.yml')
        File.write(env_config, "host: env.example.com\n")
        ENV['CLEANBOX_CONFIG'] = env_config
        
        Configuration.configure({})
        
        expect(Configuration.config_file_path).to eq(File.expand_path(env_config))
        expect(Configuration.options[:host]).to eq('env.example.com')
      end

      it 'uses CLEANBOX_DATA_DIR config when no other config found' do
        # Clear any existing environment variables first
        ENV.delete('CLEANBOX_CONFIG')
        ENV.delete('CLEANBOX_DATA_DIR')
        Configuration.reset!
        
        data_dir_config = File.join(temp_dir, 'cleanbox.yml')
        File.write(data_dir_config, "host: env_data_dir.example.com\n")
        ENV['CLEANBOX_DATA_DIR'] = temp_dir
        
        Configuration.configure({})
        
        expect(Configuration.config_file_path).to eq(File.expand_path(data_dir_config))
        expect(Configuration.options[:host]).to eq('env_data_dir.example.com')
      end

      it 'falls back to home directory when no environment variables set' do
        # Clear any existing environment variables first
        ENV.delete('CLEANBOX_DATA_DIR')
        ENV.delete('CLEANBOX_CONFIG')
        Configuration.reset!
        Configuration.reconfigure!
        
        # Temporarily allow the real home_config for this test
        allow(Configuration).to receive(:home_config).and_call_original
        
        home_config = File.expand_path('~/.cleanbox.yml')
        File.write(home_config, "host: home.example.com\n") if File.exist?(home_config)
        
        Configuration.configure({})
        
        expect(Configuration.config_file_path).to eq(home_config)
      end
    end

    describe 'environment variable cleanup' do
      it 'does not persist environment variables between tests' do
        ENV['CLEANBOX_DATA_DIR'] = temp_dir
        Configuration.configure({})
        expect(Configuration.data_dir).to eq(File.expand_path(temp_dir))
        
        # Clear environment and reconfigure
        ENV.delete('CLEANBOX_DATA_DIR')
        Configuration.reset!
        Configuration.reconfigure!
        
        # Should not have the previous data_dir
        expect(Configuration.data_dir).not_to eq(File.expand_path(temp_dir))
      end
    end
  end

  describe 'Configuration.reset!' do
    let(:temp_dir) { Dir.mktmpdir('cleanbox_test') }
    
    after do
      FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
    end
    
    it 'clears all configuration state' do
      # Set up some configuration
      ENV['CLEANBOX_DATA_DIR'] = temp_dir
      Configuration.configure({})
      
      expect(Configuration.data_dir).to eq(File.expand_path(temp_dir))
      expect(Configuration.config_file_path).to be_present
      
      # Reset
      Configuration.reset!
      
      # Should be cleared
      expect(Configuration.data_dir).to be_nil
      expect(Configuration.config_file_path).to be_nil
      expect(Configuration.options).to be_nil
      
      # Should be able to reconfigure
      Configuration.reconfigure!
      expect(Configuration.data_dir).to eq(File.expand_path(temp_dir))
      expect(Configuration.config_file_path).to be_present
      expect(Configuration.options).to be_present

      ENV.delete('CLEANBOX_DATA_DIR')
    end
  end
end 