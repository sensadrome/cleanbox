# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI::ConfigManager, 'safety checks' do
  describe '#check_test_safety!' do
    context 'when attempting to write to real home config during tests' do
      it 'raises an error for ~/.cleanbox.yml' do
        real_home_config = File.expand_path('~/.cleanbox.yml')
        manager = described_class.new(real_home_config)

        expect do
          manager.save_config({ host: 'test.example.com' })
        end.to raise_error(/TEST SAFETY VIOLATION/)
      end

      it 'raises an error for ~/.cleanbox/ directory paths' do
        real_home_path = File.expand_path('~/.cleanbox/config.yml')
        manager = described_class.new(real_home_path)

        expect do
          manager.save_config({ host: 'test.example.com' })
        end.to raise_error(/TEST SAFETY VIOLATION/)
      end
    end

    context 'when writing to temporary test directories' do
      it 'allows writing to temp paths' do
        temp_path = File.join(Dir.tmpdir, 'test_config.yml')
        manager = described_class.new(temp_path)

        expect do
          manager.save_config({ host: 'test.example.com' })
        end.not_to raise_error

        # Clean up
        FileUtils.rm_f(temp_path)
      end

      it 'allows writing to paths from config helpers' do
        # temp_config_path comes from the shared context
        manager = described_class.new(temp_config_path)

        expect do
          manager.save_config({ host: 'test.example.com' })
        end.not_to raise_error
      end
    end
  end

  describe 'File.write safeguard' do
    it 'prevents direct File.write to ~/.cleanbox.yml' do
      real_home_config = File.expand_path('~/.cleanbox.yml')

      expect do
        File.write(real_home_config, 'test data')
      end.to raise_error(/TEST SAFETY VIOLATION/)
    end

    it 'prevents direct File.write to ~/.cleanbox/ directory' do
      real_home_path = File.expand_path('~/.cleanbox/test.txt')

      expect do
        File.write(real_home_path, 'test data')
      end.to raise_error(/TEST SAFETY VIOLATION/)
    end

    it 'allows File.write to temporary paths' do
      temp_path = File.join(Dir.tmpdir, 'test_file.txt')

      expect do
        File.write(temp_path, 'test data')
      end.not_to raise_error

      # Clean up
      FileUtils.rm_f(temp_path)
    end
  end
end
