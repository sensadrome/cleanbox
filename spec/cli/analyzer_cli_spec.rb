# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI::AnalyzerCLI do
  let(:mock_imap) { double('IMAP') }
  let(:options) { { verbose: false, brief: false, detailed: false } }
  let(:analyzer_cli) { CLI::AnalyzerCLI.new(mock_imap, options) }

  describe '#initialize' do
    it 'creates an analyzer CLI instance' do
      expect(analyzer_cli).to be_a(CLI::AnalyzerCLI)
    end

    it 'initializes with correct options' do
      expect(analyzer_cli.instance_variable_get(:@options)).to eq(options)
    end
  end

  describe '#show_help' do
    it 'displays help information' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      
      analyzer_cli.send(:show_help)
      
      expect(output.string).to include('Cleanbox Analysis Commands')
      expect(output.string).to include('Usage: ./cleanbox analyze')
      expect(output.string).to include('folders')
      expect(output.string).to include('inbox')
      expect(output.string).to include('senders')
      expect(output.string).to include('domains')
      expect(output.string).to include('recommendations')
      expect(output.string).to include('summary')
    end
  end

  describe 'analysis methods' do
    before do
      allow(analyzer_cli).to receive(:show_help)
    end

    it 'calls show_help for unknown subcommand' do
      ARGV.replace(['unknown'])
      expect(analyzer_cli).to receive(:show_help)
      analyzer_cli.run
    end

    it 'handles folders subcommand' do
      ARGV.replace(['folders'])
      expect(analyzer_cli).to receive(:analyze_folders)
      analyzer_cli.run
    end

    it 'handles inbox subcommand' do
      ARGV.replace(['inbox'])
      expect(analyzer_cli).to receive(:analyze_inbox)
      analyzer_cli.run
    end

    it 'handles senders subcommand' do
      ARGV.replace(['senders'])
      expect(analyzer_cli).to receive(:analyze_senders)
      analyzer_cli.run
    end

    it 'handles domains subcommand' do
      ARGV.replace(['domains'])
      expect(analyzer_cli).to receive(:analyze_domains)
      analyzer_cli.run
    end

    it 'handles recommendations subcommand' do
      ARGV.replace(['recommendations'])
      expect(analyzer_cli).to receive(:analyze_recommendations)
      analyzer_cli.run
    end

    it 'handles summary subcommand' do
      ARGV.replace(['summary'])
      expect(analyzer_cli).to receive(:analyze_summary)
      analyzer_cli.run
    end
  end

  describe 'display methods' do
    let(:folders) do
      [
        { name: 'Work', message_count: 100, categorization: :whitelist, senders: ['alice@work.com'], domains: ['work.com'] },
        { name: 'Newsletters', message_count: 50, categorization: :list, senders: ['news@example.com'], domains: ['example.com'] }
      ]
    end

    it 'shows brief folder analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      
      folder_results = {
        folders: folders,
        total_analyzed: 2,
        total_skipped: 0,
        total_folders: 2
      }
      
      analyzer_cli.send(:show_brief_folder_analysis, folder_results)
      
      expect(output.string).to include('📊 Folder Summary:')
      expect(output.string).to include('Total folders analyzed: 2')
      expect(output.string).to include('Total messages: 150')
      expect(output.string).to include('Whitelist folders: 1')
      expect(output.string).to include('List folders: 1')
    end

    it 'shows standard folder analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      
      analyzer_cli.send(:show_standard_folder_analysis, folders)
      
      expect(output.string).to include('📊 Folder Analysis:')
      expect(output.string).to include('📁 Work')
      expect(output.string).to include('📁 Newsletters')
      expect(output.string).to include('Messages: 100')
      expect(output.string).to include('Messages: 50')
    end
  end

  describe 'date range impact analysis' do
    let(:folders) do
      [
        { name: 'Low Volume', message_count: 3 },
        { name: 'Normal Volume', message_count: 50 }
      ]
    end

    it 'shows date range impact' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      
      analyzer_cli.send(:show_date_range_impact, folders)
      
      expect(output.string).to include('📅 Date Range Impact Analysis:')
      expect(output.string).to include('Current date range: 12 months')
      expect(output.string).to include('⚠️  Low volume folders that might miss patterns:')
      expect(output.string).to include('• Low Volume (3 messages)')
    end
  end
end 