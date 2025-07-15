# frozen_string_literal: true

require 'spec_helper'
require 'cli/cli_parser'

RSpec.describe CLI::CLIParser do
  let(:options) { Hash.new { |h, k| h[k] = [] } }
  let(:parser) { described_class.new(options) }

  describe '#parse!' do
    after { ARGV.clear }

    context 'with global options' do
      it 'sets verbose mode with -v' do
        ARGV.replace(['-v'])
        parser.parse!
        expect(options[:verbose]).to be true
        expect(options[:level]).to eq('debug')
      end

      it 'sets verbose mode with --verbose' do
        ARGV.replace(['--verbose'])
        parser.parse!
        expect(options[:verbose]).to be true
        expect(options[:level]).to eq('debug')
      end

      it 'sets pretend mode' do
        ARGV.replace(['-n'])
        parser.parse!
        expect(options[:pretend]).to be true
      end

      it 'sets config file' do
        ARGV.replace(['-c', 'myconfig.yml'])
        parser.parse!
        expect(options[:config_file]).to eq('myconfig.yml')
      end

      it 'sets log level' do
        ARGV.replace(['-L', 'info'])
        parser.parse!
        expect(options[:level]).to eq('info')
      end

      it 'sets log file' do
        ARGV.replace(['-l', 'log.txt'])
        parser.parse!
        expect(options[:log_file]).to eq('log.txt')
      end
    end

    context 'with connection options' do
      it 'sets host' do
        ARGV.replace(['-H', 'mail.example.com'])
        parser.parse!
        expect(options[:host]).to eq('mail.example.com')
      end

      it 'sets username' do
        ARGV.replace(['-u', 'user@example.com'])
        parser.parse!
        expect(options[:username]).to eq('user@example.com')
      end

      it 'sets password' do
        ARGV.replace(['-p', 'secret'])
        parser.parse!
        expect(options[:password]).to eq('secret')
      end

      it 'sets client_id' do
        ARGV.replace(['-C', 'clientid'])
        parser.parse!
        expect(options[:client_id]).to eq('clientid')
      end

      it 'sets client_secret' do
        ARGV.replace(['-S', 'secret'])
        parser.parse!
        expect(options[:client_secret]).to eq('secret')
      end

      it 'sets tenant_id' do
        ARGV.replace(['-T', 'tenantid'])
        parser.parse!
        expect(options[:tenant_id]).to eq('tenantid')
      end
    end

    context 'with processing options' do
      it 'sets valid-from date' do
        ARGV.replace(['-f', '2023-01-01'])
        parser.parse!
        expect(options[:valid_from]).to eq('2023-01-01')
      end

      it 'accumulates unjunk folders' do
        ARGV.replace(['-J', 'Spam', '-J', 'Junk'])
        parser.parse!
        expect(options[:unjunk_folders]).to include('Spam', 'Junk')
        expect(options[:unjunk]).to be true
      end

      it 'accumulates file-from folders' do
        ARGV.replace(['-F', 'Receipts', '-F', 'Invoices'])
        parser.parse!
        expect(options[:file_from_folders]).to include('Receipts', 'Invoices')
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
        parser.parse!
        expect(options[:verbose]).to be true
        expect(options[:pretend]).to be true
        expect(options[:config_file]).to eq('foo.yml')
        expect(options[:host]).to eq('mail.com')
        expect(options[:username]).to eq('me')
        expect(options[:password]).to eq('pw')
        expect(options[:file_from_folders]).to eq(['A', 'B'])
      end
    end
  end
end 