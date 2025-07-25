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
      expect(cli.instance_variable_get(:@data_dir)).to eq('/tmp/test_data')
    end

    it 'falls back to current directory when no data_dir specified' do
      options_without_data_dir = { verbose: false }
      cli = described_class.new(mock_imap, options_without_data_dir)
      expect(cli.instance_variable_get(:@data_dir)).to eq(Dir.pwd)
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
          { 'folder' => 'Test', 'categorization' => 'whitelist', 'sender' => 'sender@example.com', 'message_id' => 2, 'date' => '2023-01-01' }
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
end 