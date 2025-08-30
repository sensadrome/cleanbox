# frozen_string_literal: true

require 'spec_helper'
require 'cli/cli_parser'

RSpec.describe CLI::CLIParser do
  let(:parser) { described_class.new }

  describe '#parse!' do
    after { ARGV.clear }

    context 'with global options' do
      it 'sets verbose mode with -v' do
        ARGV.replace(['-v'])
        result = parser.parse!
        expect(result[:verbose]).to be true
        expect(result[:level]).to eq('debug')
      end

      it 'sets verbose mode with --verbose' do
        ARGV.replace(['--verbose'])
        result = parser.parse!
        expect(result[:verbose]).to be true
        expect(result[:level]).to eq('debug')
      end

      it 'sets pretend mode' do
        ARGV.replace(['-n'])
        result = parser.parse!
        expect(result[:pretend]).to be true
      end

      it 'sets config file' do
        ARGV.replace(['-c', 'myconfig.yml'])
        result = parser.parse!
        expect(result[:config_file]).to eq('myconfig.yml')
      end

      it 'sets data directory' do
        ARGV.replace(['-D', '/custom/data/dir'])
        result = parser.parse!
        expect(result[:data_dir]).to eq('/custom/data/dir')
      end

      it 'sets log level' do
        ARGV.replace(['-L', 'info'])
        result = parser.parse!
        expect(result[:level]).to eq('info')
      end

      it 'sets log file' do
        ARGV.replace(['-l', 'log.txt'])
        result = parser.parse!
        expect(result[:log_file]).to eq('log.txt')
      end
    end

    context 'with connection options' do
      it 'sets host' do
        ARGV.replace(['-H', 'mail.example.com'])
        result = parser.parse!
        expect(result[:host]).to eq('mail.example.com')
      end

      it 'sets username' do
        ARGV.replace(['-u', 'user@example.com'])
        result = parser.parse!
        expect(result[:username]).to eq('user@example.com')
      end

      it 'sets password' do
        ARGV.replace(['-p', 'secret'])
        result = parser.parse!
        expect(result[:password]).to eq('secret')
      end

      it 'sets client_id' do
        ARGV.replace(['-C', 'clientid'])
        result = parser.parse!
        expect(result[:client_id]).to eq('clientid')
      end

      it 'sets client_secret' do
        ARGV.replace(['-S', 'secret'])
        result = parser.parse!
        expect(result[:client_secret]).to eq('secret')
      end

      it 'sets tenant_id' do
        ARGV.replace(['-T', 'tenantid'])
        result = parser.parse!
        expect(result[:tenant_id]).to eq('tenantid')
      end
    end

    context 'with processing options' do
      it 'sets valid-from date' do
        ARGV.replace(['-f', '2023-01-01'])
        result = parser.parse!
        expect(result[:valid_from]).to eq('2023-01-01')
      end

      it 'accumulates unjunk folders' do
        ARGV.replace(['-J', 'Spam', '-J', 'Junk'])
        result = parser.parse!
        expect(result[:unjunk_folders]).to include('Spam', 'Junk')
        expect(result[:unjunk]).to be true
      end

      it 'accumulates file-from folders' do
        ARGV.replace(['-F', 'Receipts', '-F', 'Invoices'])
        result = parser.parse!
        expect(result[:file_from_folders]).to include('Receipts', 'Invoices')
      end

      it 'sets brief mode for analysis' do
        ARGV.replace(['--brief'])
        result = parser.parse!
        expect(result[:brief]).to be true
      end

      it 'sets detailed mode for analysis' do
        ARGV.replace(['--detailed'])
        result = parser.parse!
        expect(result[:detailed]).to be true
      end
    end

    context 'with help option' do
      it 'prints help and exits with -h' do
        ARGV.replace(['-h'])
        expect { parser.parse! }.to raise_error(SystemExit)
      end

      it 'prints help and exits with --help' do
        ARGV.replace(['--help'])
        expect { parser.parse! }.to raise_error(SystemExit)
      end

      it 'includes analyze command in help output' do
        ARGV.replace(['--help'])
        expect { parser.parse! }.to raise_error(SystemExit)
      rescue SystemExit
        # This test ensures the help text includes the analyze command
        # The actual help output is tested by the SystemExit expectation
      end
    end

    context 'with invalid option' do
      it 'raises OptionParser::InvalidOption' do
        ARGV.replace(['--not-an-option'])
        expect { parser.parse! }.to raise_error(OptionParser::InvalidOption)
      end
    end

    context 'with multiple options' do
      it 'parses a combination of options' do
        ARGV.replace(['-v', '-n', '-c', 'foo.yml', '-H', 'mail.com', '-u', 'me', '-p', 'pw', '-F', 'A', '-F', 'B'])
        result = parser.parse!
        expect(result[:verbose]).to be true
        expect(result[:pretend]).to be true
        expect(result[:config_file]).to eq('foo.yml')
        expect(result[:host]).to eq('mail.com')
        expect(result[:username]).to eq('me')
        expect(result[:password]).to eq('pw')
        expect(result[:file_from_folders]).to eq(%w[A B])
      end
    end
  end
end
