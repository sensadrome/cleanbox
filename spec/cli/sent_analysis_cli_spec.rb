require 'spec_helper'

RSpec.describe CLI::SentAnalysisCLI do
  let(:mock_imap) { double('IMAP') }
  let(:mock_email_analyzer) { double('EmailAnalyzer') }
  let(:options) { { data_dir: '/tmp/test_data', verbose: false } }
  let(:cli) { described_class.new(mock_imap, options) }

  before do
    allow(Analysis::EmailAnalyzer).to receive(:new).and_return(mock_email_analyzer)
    allow(ARGV).to receive(:first).and_return('collect')
  end

  describe '#initialize' do
    it 'sets up the email analyzer' do
      expect(Analysis::EmailAnalyzer).to receive(:new).with(
        mock_imap,
        logger: instance_of(Logger),
        folder_categorizer_class: Analysis::FolderCategorizer
      )
      described_class.new(mock_imap, options)
    end

    it 'sets data directory from options' do
      cli = described_class.new(mock_imap, options)
      expect(cli.data_dir).to eq('/tmp/test_data')
    end

    it 'falls back to current directory when no data_dir specified' do
      options_without_data_dir = { verbose: false }
      cli = described_class.new(mock_imap, options_without_data_dir)
      expect(cli.data_dir).to eq(Dir.pwd)
    end
  end

  describe '#run' do
    context 'with collect subcommand' do
      before do
        allow(ARGV).to receive(:first).and_return('collect')
        allow(cli).to receive(:collect_data)
      end

      it 'calls collect_data' do
        expect(cli).to receive(:collect_data)
        cli.run
      end
    end

    context 'with analyze subcommand' do
      before do
        allow(ARGV).to receive(:first).and_return('analyze')
        allow(cli).to receive(:analyze_data)
      end

      it 'calls analyze_data' do
        expect(cli).to receive(:analyze_data)
        cli.run
      end
    end

    context 'with compare subcommand' do
      before do
        allow(ARGV).to receive(:first).and_return('compare')
        allow(cli).to receive(:compare_sent_with_folders)
      end

      it 'calls compare_sent_with_folders' do
        expect(cli).to receive(:compare_sent_with_folders)
        cli.run
      end
    end

    context 'with help subcommand' do
      before do
        allow(ARGV).to receive(:first).and_return('help')
        allow(cli).to receive(:show_help)
      end

      it 'calls show_help' do
        expect(cli).to receive(:show_help)
        cli.run
      end
    end

    context 'with invalid subcommand' do
      before do
        allow(ARGV).to receive(:first).and_return('invalid')
        allow(cli).to receive(:show_help)
      end

      it 'calls show_help' do
        expect(cli).to receive(:show_help)
        cli.run
      end
    end

    context 'with no subcommand' do
      before do
        allow(ARGV).to receive(:first).and_return(nil)
        allow(cli).to receive(:collect_data)
      end

      it 'defaults to collect_data' do
        expect(cli).to receive(:collect_data)
        cli.run
      end
    end
  end

  describe '#save_json_data' do
    let(:test_data) { { 'test' => 'data' } }
    let(:filename) { 'test.json' }
    let(:expected_path) { File.join('/tmp/test_data', filename) }

    before do
      allow(File).to receive(:write)
    end

    it 'saves to the data directory' do
      expect(File).to receive(:write).with(expected_path, anything)
      cli.send(:save_json_data, test_data, filename)
    end
  end

  describe '#save_csv_data' do
    let(:test_data) do
      {
        'sent_recipients' => [
          { 'recipient' => 'test@example.com', 'message_id' => 1, 'date' => '2023-01-01' }
        ],
        'folder_senders' => [
          { 'folder' => 'Test', 'categorization' => 'whitelist', 'sender' => 'sender@example.com', 'message_id' => 2,
            'date' => '2023-01-01' }
        ]
      }
    end

    before do
      allow(File).to receive(:size).and_return(100)
      allow(cli).to receive(:puts)
    end

    it 'saves CSV files to the data directory' do
      csv_double = double('csv')
      allow(csv_double).to receive(:<<)

      expect(CSV).to receive(:open).with(File.join('/tmp/test_data', 'sent_recipients.csv'), 'w').and_yield(csv_double)
      expect(CSV).to receive(:open).with(File.join('/tmp/test_data', 'folder_senders.csv'), 'w').and_yield(csv_double)
      expect(CSV).to receive(:open).with(File.join('/tmp/test_data', 'sent_vs_folders.csv'), 'w').and_yield(csv_double)
      cli.send(:save_csv_data, test_data)
    end
  end

  describe '#analyze_data' do
    let(:json_path) { File.join('/tmp/test_data', 'sent_analysis_data.json') }
    let(:test_data) do
      {
        'sent_recipients' => [],
        'sent_analysis' => {},
        'folder_analysis' => { 'folders' => [] }
      }
    end

    context 'when data file exists' do
      before do
        allow(File).to receive(:exist?).with(json_path).and_return(true)
        allow(File).to receive(:read).with(json_path).and_return(test_data.to_json)
        allow(JSON).to receive(:parse).and_return(test_data)
        allow(cli).to receive(:puts)
      end

      it 'reads from the data directory' do
        expect(File).to receive(:exist?).with(json_path)
        expect(File).to receive(:read).with(json_path)
        cli.send(:analyze_data)
      end
    end

    context 'when data file does not exist' do
      before do
        allow(File).to receive(:exist?).with(json_path).and_return(false)
        allow(cli).to receive(:puts)
      end

      it 'shows error message' do
        expect(cli).to receive(:puts).with('❌ No data file found. Run \'collect\' first.')
        cli.send(:analyze_data)
      end
    end
  end

  describe '#detect_sent_folder' do
    before do
      allow(mock_imap).to receive(:select).and_raise(StandardError)
      allow(mock_imap).to receive(:select).with('Sent Items').and_return(true)
    end

    it 'tries to find a sent folder' do
      expect(mock_imap).to receive(:select).with('Sent Items')
      cli.send(:detect_sent_folder)
    end
  end

  describe '#safe_date_format' do
    it 'handles Date objects' do
      date = Date.new(2023, 1, 1)
      result = cli.send(:safe_date_format, date)
      expect(result).to match(/2023-01-01/)
    end

    it 'handles Time objects' do
      time = Time.new(2023, 1, 1, 12, 0, 0)
      result = cli.send(:safe_date_format, time)
      expect(result).to match(/2023-01-01/)
    end

    it 'handles string dates' do
      date_string = '2023-01-01'
      result = cli.send(:safe_date_format, date_string)
      expect(result).to eq(date_string)
    end

    it 'handles nil' do
      result = cli.send(:safe_date_format, nil)
      expect(result).to be_nil
    end
  end

  describe '#collect_data' do
    let(:sent_data) { { 'total_sent' => 100, 'sample_size' => 50 } }
    let(:folder_results) { { 'folders' => [], 'total_analyzed' => 0 } }
    let(:sent_recipients) { [{ 'recipient' => 'test@example.com' }] }
    let(:folder_senders) { [{ 'sender' => 'sender@example.com' }] }

    before do
      allow(cli).to receive(:puts)
      allow(mock_email_analyzer).to receive(:analyze_sent_items).and_return(sent_data)
      allow(mock_email_analyzer).to receive(:analyze_folders).and_return(folder_results)
      allow(cli).to receive(:collect_sent_recipients_with_progress).and_return(sent_recipients)
      allow(cli).to receive(:collect_folder_senders_with_progress).and_return(folder_senders)
      allow(cli).to receive(:save_json_data)
      allow(cli).to receive(:save_csv_data)
    end

    it 'collects and saves all data' do
      expect(mock_email_analyzer).to receive(:analyze_sent_items)
      expect(mock_email_analyzer).to receive(:analyze_folders)
      expect(cli).to receive(:collect_sent_recipients_with_progress)
      expect(cli).to receive(:collect_folder_senders_with_progress).with(folder_results[:folders])
      expect(cli).to receive(:save_json_data)
      expect(cli).to receive(:save_csv_data)

      cli.send(:collect_data)
    end
  end

  describe '#collect_sent_recipients_with_progress' do
    let(:message_ids) { [1, 2, 3] }
    let(:envelopes) do
      [
        double('envelope1', seqno: 1,
                            attr: { 'ENVELOPE' => double('envelope1_data', to: [double('recipient1', mailbox: 'test', host: 'example.com')], date: Time.now) }),
        double('envelope2', seqno: 2,
                            attr: { 'ENVELOPE' => double('envelope2_data', to: [double('recipient2', mailbox: 'user', host: 'test.com')], date: Time.now) })
      ]
    end

    before do
      allow(cli).to receive(:detect_sent_folder).and_return('Sent Items')
      allow(mock_imap).to receive(:select).with('Sent Items')
      allow(mock_imap).to receive(:search).with(['ALL']).and_return(message_ids)
      allow(mock_imap).to receive(:fetch).with(message_ids, 'ENVELOPE').and_return(envelopes)
      allow(cli).to receive(:puts)
      allow(cli).to receive(:safe_date_format).and_return('2023-01-01')
    end

    it 'collects sent recipients with progress' do
      result = cli.send(:collect_sent_recipients_with_progress)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first).to include('recipient' => 'test@example.com')
      expect(result.last).to include('recipient' => 'user@test.com')
    end

    context 'when sent folder is not found' do
      before do
        allow(cli).to receive(:detect_sent_folder).and_return(nil)
      end

      it 'returns empty array' do
        result = cli.send(:collect_sent_recipients_with_progress)
        expect(result).to eq([])
      end
    end
  end

  describe '#collect_folder_senders_with_progress' do
    let(:folders) do
      [
        { name: 'Test Folder', message_count: 10, categorization: 'whitelist' },
        { name: 'Another Folder', message_count: 5, categorization: 'list' }
      ]
    end
    let(:message_ids) { [1, 2] }
    let(:envelopes) do
      [
        double('envelope1', seqno: 1,
                            attr: { 'ENVELOPE' => double('envelope1_data', from: [double('sender1', mailbox: 'sender', host: 'example.com')], date: Time.now) }),
        double('envelope2', seqno: 2,
                            attr: { 'ENVELOPE' => double('envelope2_data', from: [double('sender2', mailbox: 'user', host: 'test.com')], date: Time.now) })
      ]
    end

    before do
      allow(mock_imap).to receive(:select)
      allow(mock_imap).to receive(:search).with(['ALL']).and_return(message_ids)
      allow(mock_imap).to receive(:fetch).with(message_ids, 'ENVELOPE').and_return(envelopes)
      allow(cli).to receive(:puts)
      allow(cli).to receive(:safe_date_format).and_return('2023-01-01')
    end

    it 'collects folder senders with progress' do
      result = cli.send(:collect_folder_senders_with_progress, folders)

      expect(result).to be_an(Array)
      expect(result.length).to eq(4) # 2 folders × 2 messages each
      expect(result.first).to include('folder' => 'Test Folder', 'categorization' => 'whitelist')
    end
  end

  describe '#compare_sent_with_folders' do
    let(:sent_recipients) { ['user1@example.com', 'user2@example.com'] }
    let(:test_data) do
      {
        'sent_recipients' => [
          { 'recipient' => 'user1@example.com' },
          { 'recipient' => 'user2@example.com' }
        ],
        'folder_analysis' => {
          'folders' => [
            {
              'name' => 'Folder1',
              'categorization' => 'whitelist',
              'senders' => ['user1@example.com', 'user3@example.com']
            },
            {
              'name' => 'Folder2',
              'categorization' => 'list',
              'senders' => ['user4@example.com', 'user5@example.com']
            }
          ]
        }
      }
    end

    before do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return(test_data.to_json)
      allow(JSON).to receive(:parse).and_return(test_data)
      allow(cli).to receive(:puts)
    end

    it 'compares sent recipients with folder senders' do
      expect(cli).to receive(:puts).with(/📊 SENT vs FOLDER COMPARISON/)
      expect(cli).to receive(:puts).with(/Folders ranked by overlap/)

      cli.send(:compare_sent_with_folders)
    end
  end

  describe '#average_overlap' do
    let(:folders) do
      [
        { overlap_percentage: 50.0 },
        { overlap_percentage: 75.0 },
        { overlap_percentage: 25.0 }
      ]
    end

    it 'calculates average overlap correctly' do
      result = cli.send(:average_overlap, folders)
      expect(result).to eq(50.0) # (50 + 75 + 25) / 3 = 50
    end

    it 'returns 0 for empty folders' do
      result = cli.send(:average_overlap, [])
      expect(result).to eq(0)
    end
  end

  describe '#show_help' do
    it 'displays the help header' do
      expect { cli.send(:show_help) }.to output(/Sent Analysis CLI - Analyze sent emails vs folder contents/).to_stdout
    end

    it 'displays all available commands' do
      expect { cli.send(:show_help) }.to output(/Commands:/).to_stdout
      expect { cli.send(:show_help) }.to output(/collect/).to_stdout
      expect { cli.send(:show_help) }.to output(/analyze/).to_stdout
      expect { cli.send(:show_help) }.to output(/compare/).to_stdout
      expect { cli.send(:show_help) }.to output(/help/).to_stdout
    end

    it 'displays command descriptions' do
      expect { cli.send(:show_help) }.to output(/Collect data from IMAP server/).to_stdout
      expect { cli.send(:show_help) }.to output(/Analyze collected data/).to_stdout
      expect { cli.send(:show_help) }.to output(/Compare sent emails with folder contents/).to_stdout
      expect { cli.send(:show_help) }.to output(/Show this help/).to_stdout
    end

    it 'displays usage examples' do
      expect { cli.send(:show_help) }.to output(/Usage:/).to_stdout
      expect { cli.send(:show_help) }.to output(/cleanbox sent-analysis collect/).to_stdout
      expect { cli.send(:show_help) }.to output(/cleanbox sent-analysis analyze/).to_stdout
      expect { cli.send(:show_help) }.to output(/cleanbox sent-analysis compare/).to_stdout
    end

    it 'displays complete help output with proper formatting' do
      expected_output = <<~EXPECTED
        Sent Analysis CLI - Analyze sent emails vs folder contents

        Commands:
          collect    - Collect data from IMAP server
          analyze    - Analyze collected data
          compare    - Compare sent emails with folder contents
          help       - Show this help

        Usage:
          cleanbox sent-analysis collect
          cleanbox sent-analysis analyze
          cleanbox sent-analysis compare
      EXPECTED

      expect { cli.send(:show_help) }.to output(expected_output).to_stdout
    end

    it 'includes proper spacing and formatting' do
      expect do
        cli.send(:show_help)
      end.to output(/Sent Analysis CLI - Analyze sent emails vs folder contents\n\nCommands:/).to_stdout
      expect { cli.send(:show_help) }.to output(/Commands:\n  collect/).to_stdout
      expect { cli.send(:show_help) }.to output(/Usage:\n  cleanbox sent-analysis collect/).to_stdout

      # Check that commands are properly indented
      expect { cli.send(:show_help) }.to output(/  collect/).to_stdout
      expect { cli.send(:show_help) }.to output(/  analyze/).to_stdout
      expect { cli.send(:show_help) }.to output(/  compare/).to_stdout
      expect { cli.send(:show_help) }.to output(/  help/).to_stdout
    end
  end
end
