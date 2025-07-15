# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe CLI::SecretsManager do
  let(:secrets_dir) { Dir.mktmpdir }
  let(:env_file_path) { File.expand_path('.env') }

  before do
    # Clear ENV for test isolation
    @original_env = ENV.to_hash
    ENV.delete('CLEANBOX_PASSWORD')
    ENV.delete('PASSWORD')
    ENV.delete('SECRETS_PATH')
    FileUtils.rm_f(env_file_path)
  end

  after do
    ENV.replace(@original_env)
    FileUtils.rm_f(env_file_path)
    FileUtils.rm_rf(secrets_dir)
  end

  describe '.value_from_env_or_secrets' do
    context 'when CLEANBOX_ prefixed env var is set' do
      it 'returns the value from CLEANBOX_ env var' do
        ENV['CLEANBOX_PASSWORD'] = 'supersecret'
        expect(described_class.value_from_env_or_secrets(:password)).to eq('supersecret')
      end
    end

    context 'when non-prefixed env var is set' do
      it 'returns the value from non-prefixed env var' do
        ENV['PASSWORD'] = 'othersecret'
        expect(described_class.value_from_env_or_secrets(:password)).to eq('othersecret')
      end
    end

    context 'when .env file exists' do
      before do
        File.write(env_file_path, "CLEANBOX_PASSWORD=fromenvfile\n")
      end

      it 'loads .env and returns the value' do
        expect(described_class.value_from_env_or_secrets(:password)).to eq('fromenvfile')
      end

      it 'removes quotes from .env values' do
        File.write(env_file_path, "CLEANBOX_PASSWORD='quotedval'\n")
        expect(described_class.value_from_env_or_secrets(:password)).to eq('quotedval')
      end
    end

    context 'when secrets file exists' do
      before do
        ENV['SECRETS_PATH'] = secrets_dir + '/'
        File.write(File.join(secrets_dir, 'password'), "secretfromfile\n")
      end

      it 'returns the value from the secrets file' do
        expect(described_class.value_from_env_or_secrets(:password)).to eq('secretfromfile')
      end
    end

    context 'when nothing is set' do
      it 'returns nil' do
        expect(described_class.value_from_env_or_secrets(:password)).to be_nil
      end
    end

    context 'when value is present but has trailing newline' do
      it 'chomps the value' do
        ENV['CLEANBOX_PASSWORD'] = "withnewline\n"
        expect(described_class.value_from_env_or_secrets(:password)).to eq('withnewline')
      end
    end
  end

  describe '.load_env_file' do
    it 'loads variables from .env file into ENV' do
      File.write(env_file_path, "FOO=bar\nBAR=baz\n")
      described_class.load_env_file
      expect(ENV['FOO']).to eq('bar')
      expect(ENV['BAR']).to eq('baz')
    end

    it 'ignores comments and blank lines' do
      File.write(env_file_path, "# comment\n\nFOO=bar\n")
      described_class.load_env_file
      expect(ENV['FOO']).to eq('bar')
    end

    it 'removes quotes from values' do
      File.write(env_file_path, "FOO='bar'\nBAR=\"baz\"\n")
      described_class.load_env_file
      expect(ENV['FOO']).to eq('bar')
      expect(ENV['BAR']).to eq('baz')
    end
  end

  describe '.create_env_file' do
    it 'creates a .env file with the given secrets' do
      secrets = { 'FOO' => 'bar', 'BAR' => 'baz' }
      described_class.create_env_file(secrets)
      content = File.read(env_file_path)
      expect(content).to include('FOO=bar')
      expect(content).to include('BAR=baz')
    end

    it 'skips nil or empty values' do
      secrets = { 'FOO' => '', 'BAR' => nil, 'BAZ' => 'ok' }
      described_class.create_env_file(secrets)
      content = File.read(env_file_path)
      expect(content).to include('BAZ=ok')
      expect(content).not_to include('FOO=')
      expect(content).not_to include('BAR=')
    end

    it 'prints a success message' do
      secrets = { 'FOO' => 'bar' }
      expect { described_class.create_env_file(secrets) }
        .to output(/Created .env file with sensitive credentials/).to_stdout
    end
  end

  describe 'private methods' do
    describe '.password_from_secrets' do
      it 'returns nil if file does not exist' do
        expect(described_class.send(:password_from_secrets, 'notfound')).to be_nil
      end

      it 'returns the value from the file if it exists' do
        ENV['SECRETS_PATH'] = secrets_dir + '/'
        File.write(File.join(secrets_dir, 'mysecret'), "shhh\n")
        expect(described_class.send(:password_from_secrets, 'mysecret')).to eq('shhh')
      end
    end

    describe '.secrets_path' do
      it 'returns the default path if SECRETS_PATH is not set' do
        expect(described_class.send(:secrets_path)).to eq('/var/run/secrets/')
      end

      it 'returns the custom path if SECRETS_PATH is set' do
        ENV['SECRETS_PATH'] = '/tmp/mysecrets/'
        expect(described_class.send(:secrets_path)).to eq('/tmp/mysecrets/')
      end
    end
  end
end 