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
      expect(analyzer_cli.options).to eq(options)
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
        { name: 'Work', message_count: 100, categorization: :whitelist, senders: ['alice@work.com'],
          domains: ['work.com'] },
        { name: 'Newsletters', message_count: 50, categorization: :list, senders: ['news@example.com'],
          domains: ['example.com'] }
      ]
    end

    let(:sent_items) do
      {
        frequent_correspondents: [['alice@work.com', 5], ['bob@friend.com', 3]],
        total_sent: 100,
        sample_size: 50
      }
    end

    let(:domain_analysis) do
      {
        'work.com' => 'work',
        'example.com' => 'newsletter',
        'friend.com' => 'personal'
      }
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

  describe 'other analysis methods' do
    before do
      allow(analyzer_cli.email_analyzer).to receive(:analyze_folders).and_return({
                                                                                   folders: [
                                                                                     { name: 'Work',
                                                                                       message_count: 100, senders: ['alice@work.com'], domains: ['work.com'] },
                                                                                     { name: 'Newsletters',
                                                                                       message_count: 50, senders: ['news@example.com'], domains: ['example.com'] }
                                                                                   ],
                                                                                   total_analyzed: 2,
                                                                                   total_skipped: 0,
                                                                                   total_folders: 2
                                                                                 })
      allow(analyzer_cli.email_analyzer).to receive(:analyze_sent_items).and_return({
                                                                                      frequent_correspondents: [],
                                                                                      total_sent: 0,
                                                                                      sample_size: 0
                                                                                    })
      allow(analyzer_cli.email_analyzer).to receive(:analyze_domain_patterns).and_return({})
      allow(analyzer_cli.email_analyzer).to receive(:generate_recommendations).and_return({
                                                                                            whitelist_folders: ['Work'],
                                                                                            list_folders: ['Newsletters'],
                                                                                            domain_mappings: { 'work.com' => 'Work' }
                                                                                          })
      allow(mock_imap).to receive(:select)
      allow(mock_imap).to receive(:search).and_return([])
      allow(mock_imap).to receive(:fetch).and_return([])
    end

    it 'analyzes inbox' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:analyze_inbox)

      expect(output.string).to include('📧 Inbox Analysis')
    end

    it 'analyzes senders' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:analyze_senders)

      expect(output.string).to include('👤 Sender Analysis')
    end

    it 'analyzes domains' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:analyze_domains)

      expect(output.string).to include('🌐 Domain Analysis')
    end

    it 'analyzes recommendations' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:analyze_recommendations)

      expect(output.string).to include('🤖 Configuration Recommendations')
    end

    it 'analyzes summary' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:analyze_summary)

      expect(output.string).to include('📊 Comprehensive Analysis Summary')
    end
  end

  describe 'display methods for other analyses' do
    let(:sent_items) do
      {
        frequent_correspondents: [['alice@work.com', 5], ['bob@friend.com', 3]],
        total_sent: 100,
        sample_size: 50
      }
    end

    let(:domain_analysis) do
      {
        'work.com' => 'work',
        'example.com' => 'newsletter',
        'friend.com' => 'personal'
      }
    end

    it 'shows brief inbox analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      inbox_data = {
        total_messages: 150,
        unread_messages: 25,
        recent_senders: ['alice@work.com'],
        senders: ['alice@work.com', 'bob@friend.com'],
        domains: ['work.com', 'friend.com']
      }
      analyzer_cli.send(:show_brief_inbox_analysis, inbox_data)

      expect(output.string).to include('📧 Inbox Summary:')
      expect(output.string).to include('150')
      expect(output.string).to include('25')
    end

    it 'shows brief sender analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      sender_analysis = {
        'alice@work.com' => { folders: ['Work'], total_count: 10, sent_count: 5 },
        'bob@friend.com' => { folders: ['Friends'], total_count: 5, sent_count: 2 }
      }
      analyzer_cli.send(:show_brief_sender_analysis, sender_analysis)

      expect(output.string).to include('👤 Sender Summary:')
      expect(output.string).to include('2')
    end

    it 'shows brief domain analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      domain_analysis_with_folders = {
        'work.com' => { categorization: 'work', folders: ['Work'], total_messages: 100 },
        'example.com' => { categorization: 'newsletter', folders: ['Newsletters'], total_messages: 50 },
        'friend.com' => { categorization: 'personal', folders: ['Friends'], total_messages: 25 }
      }
      analyzer_cli.send(:show_brief_domain_analysis, domain_analysis_with_folders)

      expect(output.string).to include('🌐 Domain Summary:')
      expect(output.string).to include('3')
    end

    it 'shows recommendations' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      recommendations = {
        whitelist_folders: ['Work'],
        list_folders: ['Newsletters'],
        domain_mappings: { 'work.com' => 'Work' }
      }

      folders = [
        { name: 'Work', message_count: 100 },
        { name: 'Newsletters', message_count: 50 }
      ]

      analyzer_cli.send(:show_recommendations, recommendations, folders)

      expect(output.string).to include('✅ Whitelist Folders:')
      expect(output.string).to include('📬 List Folders:')
    end

    it 'shows comprehensive summary' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
      allow(mock_imap).to receive(:select)
      allow(mock_imap).to receive(:search).and_return([])
      allow(mock_imap).to receive(:fetch).and_return([])

      recommendations = {
        whitelist_folders: ['Work'],
        list_folders: ['Newsletters'],
        domain_mappings: { 'work.com' => 'Work' }
      }
      analyzer_cli.send(:show_comprehensive_summary, [], sent_items, domain_analysis, recommendations)

      expect(output.string).to include('📊 Overall Statistics:')
    end
  end

  describe 'utility methods' do
    it 'shows progress' do
      # Test that the method doesn't raise an error
      expect { analyzer_cli.send(:show_progress, 'Processing...') }.not_to raise_error
    end

    it 'clears progress' do
      # Test that the method doesn't raise an error
      expect { analyzer_cli.send(:clear_progress) }.not_to raise_error
    end

    it 'extracts senders from envelopes' do
      mock_envelope = double('Envelope', attr: {
                               'ENVELOPE' => double('EnvelopeData',
                                                    from: [double('Address', mailbox: 'test', host: 'example.com')])
                             })

      result = analyzer_cli.send(:extract_senders, [mock_envelope])

      expect(result).to eq(['test@example.com'])
    end
  end

  describe 'detailed analysis methods' do
    let(:folders) do
      [
        { name: 'Work', message_count: 100, categorization: :whitelist, senders: ['alice@work.com'],
          domains: ['work.com'] },
        { name: 'Newsletters', message_count: 50, categorization: :list, senders: ['news@example.com'],
          domains: ['example.com'] }
      ]
    end

    let(:inbox_data) do
      {
        total_messages: 150,
        unread_messages: 25,
        recent_messages: 30,
        senders: ['alice@work.com', 'bob@friend.com', 'news@example.com'],
        domains: ['work.com', 'friend.com', 'example.com'],
        sample_size: 50
      }
    end

    let(:sender_analysis) do
      {
        'alice@work.com' => { folders: ['Work'], total_count: 10, sent_count: 5 },
        'bob@friend.com' => { folders: ['Friends'], total_count: 5, sent_count: 2 }
      }
    end

    let(:domain_analysis) do
      {
        'work.com' => { categorization: 'work', folders: ['Work'], total_messages: 100 },
        'example.com' => { categorization: 'newsletter', folders: ['Newsletters'], total_messages: 50 }
      }
    end

    it 'shows detailed folder analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_detailed_folder_analysis, folders)

      expect(output.string).to include('📊 Folder Analysis:')
      expect(output.string).to include('Work')
      expect(output.string).to include('Newsletters')
    end

    it 'shows detailed inbox analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_detailed_inbox_analysis, inbox_data)

      expect(output.string).to include('📧 Inbox Summary:')
      expect(output.string).to include('150')
    end

    it 'shows detailed sender analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_detailed_sender_analysis, sender_analysis)

      expect(output.string).to include('👤 Sender Summary:')
      expect(output.string).to include('2')
    end

    it 'shows detailed domain analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_detailed_domain_analysis, domain_analysis)

      expect(output.string).to include('🌐 Domain Summary:')
      expect(output.string).to include('2')
    end
  end

  describe 'standard analysis methods' do
    let(:folders) do
      [
        { name: 'Work', message_count: 100, categorization: :whitelist, senders: ['alice@work.com'],
          domains: ['work.com'] },
        { name: 'Newsletters', message_count: 50, categorization: :list, senders: ['news@example.com'],
          domains: ['example.com'] }
      ]
    end

    let(:inbox_data) do
      {
        total_messages: 150,
        unread_messages: 25,
        recent_messages: 30,
        senders: ['alice@work.com', 'bob@friend.com', 'news@example.com'],
        domains: ['work.com', 'friend.com', 'example.com'],
        sample_size: 50
      }
    end

    let(:sender_analysis) do
      {
        'alice@work.com' => { folders: ['Work'], total_count: 10, sent_count: 5 },
        'bob@friend.com' => { folders: ['Friends'], total_count: 5, sent_count: 2 }
      }
    end

    let(:domain_analysis) do
      {
        'work.com' => { categorization: 'work', folders: ['Work'], total_messages: 100 },
        'example.com' => { categorization: 'newsletter', folders: ['Newsletters'], total_messages: 50 }
      }
    end

    it 'shows standard folder analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_standard_folder_analysis, folders)

      expect(output.string).to include('📊 Folder Analysis:')
      expect(output.string).to include('Work')
      expect(output.string).to include('Newsletters')
    end

    it 'shows standard inbox analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_standard_inbox_analysis, inbox_data)

      expect(output.string).to include('📧 Inbox Summary:')
      expect(output.string).to include('150')
    end

    it 'shows standard sender analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_standard_sender_analysis, sender_analysis)

      expect(output.string).to include('👤 Sender Summary:')
      expect(output.string).to include('2')
    end

    it 'shows standard domain analysis' do
      output = StringIO.new
      allow($stdout).to receive(:puts) { |msg| output.puts(msg) }

      analyzer_cli.send(:show_standard_domain_analysis, domain_analysis)

      expect(output.string).to include('🌐 Domain Summary:')
      expect(output.string).to include('2')
    end
  end

  describe 'analysis logic methods' do
    let(:folders) do
      [
        { name: 'Work', message_count: 100, senders: ['alice@work.com'], domains: ['work.com'] },
        { name: 'Newsletters', message_count: 50, senders: ['news@example.com'], domains: ['example.com'] }
      ]
    end

    let(:sent_items) do
      {
        frequent_correspondents: [['alice@work.com', 5], ['bob@friend.com', 3]],
        total_sent: 100,
        sample_size: 50
      }
    end

    let(:domain_patterns) do
      {
        'work.com' => { categorization: 'work', folders: ['Work'], total_messages: 100 },
        'example.com' => { categorization: 'newsletter', folders: ['Newsletters'], total_messages: 50 }
      }
    end

    it 'analyzes inbox state' do
      allow(mock_imap).to receive(:select)
      allow(mock_imap).to receive(:search).and_return([])
      allow(mock_imap).to receive(:fetch).and_return([])

      result = analyzer_cli.send(:analyze_inbox_state)

      expect(result).to be_a(Hash)
      expect(result).to include(:total_messages, :unread_messages, :senders, :domains, :sample_size)
    end

    it 'analyzes sender patterns' do
      result = analyzer_cli.send(:analyze_sender_patterns, folders, sent_items)

      expect(result).to be_a(Hash)
      expect(result).to include('alice@work.com', 'news@example.com')
    end

    it 'analyzes domain patterns' do
      result = analyzer_cli.send(:analyze_domain_patterns, folders, domain_patterns)

      expect(result).to be_a(Hash)
      expect(result).to include('work.com', 'example.com')
    end
  end

  describe 'main analysis methods' do
    let(:mock_email_analyzer) { double('EmailAnalyzer') }
    let(:folder_results) do
      {
        folders: [
          { name: 'Work', message_count: 100, categorization: :whitelist, senders: ['alice@work.com'],
            domains: ['work.com'] },
          { name: 'Newsletters', message_count: 50, categorization: :list, senders: ['news@example.com'],
            domains: ['example.com'] }
        ],
        total_analyzed: 2,
        total_skipped: 0,
        total_folders: 2
      }
    end

    let(:sent_items) do
      {
        frequent_correspondents: [['alice@work.com', 5], ['bob@friend.com', 3]],
        total_sent: 100,
        sample_size: 50
      }
    end

    before do
      allow(analyzer_cli).to receive(:show_progress)
      allow(analyzer_cli).to receive(:clear_progress)
      allow(analyzer_cli).to receive(:puts)
      allow(analyzer_cli).to receive(:show_brief_folder_analysis)
      allow(analyzer_cli).to receive(:show_standard_folder_analysis)
      allow(analyzer_cli).to receive(:show_detailed_folder_analysis)
      allow(analyzer_cli).to receive(:show_date_range_impact)

      mock_logger = double('Logger')
      allow(mock_logger).to receive(:level=)

      analyzer_cli.instance_variable_set(:@email_analyzer, mock_email_analyzer)
      allow(mock_email_analyzer).to receive(:analyze_folders).and_return(folder_results)
      allow(mock_email_analyzer).to receive(:analyze_sent_items).and_return(sent_items)
      allow(mock_email_analyzer).to receive(:logger).and_return(mock_logger)
      allow(mock_email_analyzer).to receive(:instance_variable_set)
    end

    it 'analyzes folders with brief output' do
      analyzer_cli.options[:brief] = true

      analyzer_cli.send(:analyze_folders)

      expect(mock_email_analyzer).to have_received(:analyze_folders)
      expect(mock_email_analyzer).to have_received(:analyze_sent_items)
      expect(analyzer_cli).to have_received(:show_brief_folder_analysis).with(folder_results)
    end

    it 'analyzes folders with detailed output' do
      analyzer_cli.options[:detailed] = true

      analyzer_cli.send(:analyze_folders)

      expect(mock_email_analyzer).to have_received(:analyze_folders)
      expect(mock_email_analyzer).to have_received(:analyze_sent_items)
      expect(analyzer_cli).to have_received(:show_detailed_folder_analysis).with(folder_results[:folders])
    end

    it 'analyzes folders with standard output' do
      analyzer_cli.options[:brief] = false
      analyzer_cli.options[:detailed] = false

      analyzer_cli.send(:analyze_folders)

      expect(mock_email_analyzer).to have_received(:analyze_folders)
      expect(mock_email_analyzer).to have_received(:analyze_sent_items)
      expect(analyzer_cli).to have_received(:show_standard_folder_analysis).with(folder_results[:folders])
    end

    it 'shows date range impact' do
      analyzer_cli.send(:analyze_folders)

      expect(analyzer_cli).to have_received(:show_date_range_impact).with(folder_results[:folders])
    end
  end
end
