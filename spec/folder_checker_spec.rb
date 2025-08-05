# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CleanboxFolderChecker do
  let(:mock_imap) { double('IMAP') }
  let(:options) { { folder: 'TestFolder' } }
  let(:checker) { described_class.new(mock_imap, options) }
  let(:temp_cache_dir) { File.join(Dir.tmpdir, "cleanbox_test_cache_#{SecureRandom.hex(8)}") }

  before do
    # Mock the cache directory to use a temporary location for tests that need it
    allow(described_class).to receive(:cache_dir).and_return(temp_cache_dir)
    
    # Mock IMAP connection behavior
    allow(mock_imap).to receive(:select)
    allow(mock_imap).to receive(:list).and_return([
      double('folder', name: 'TestFolder'),
      double('folder', name: 'OtherFolder')
    ])
    allow(mock_imap).to receive(:status).and_return({
      'MESSAGES' => 100,
      'UIDNEXT' => 101,
      'UIDVALIDITY' => 12345
    })
  end

  after do
    FileUtils.remove_entry(temp_cache_dir) if Dir.exist?(temp_cache_dir)
  rescue Errno::ENOENT
    # Directory already removed
  end

  describe '#initialize' do
    it 'selects the folder if it exists' do
      expect(mock_imap).to receive(:select).with('TestFolder')
      described_class.new(mock_imap, options)
    end

    it 'does not select folder if it does not exist' do
      allow(mock_imap).to receive(:list).and_return([
        double('folder', name: 'OtherFolder')
      ])
      expect(mock_imap).not_to receive(:select)
      described_class.new(mock_imap, options)
    end
  end

  describe '#email_addresses' do
    context 'when folder does not exist' do
      before do
        allow(mock_imap).to receive(:list).and_return([
          double('folder', name: 'OtherFolder')
        ])
      end

      it 'returns empty array' do
        expect(checker.email_addresses).to eq([])
      end
    end

    context 'when folder exists' do
      let(:mock_envelopes) do
        [
          double('envelope', attr: { 'ENVELOPE' => double('envelope_data', from: [
            double('address', mailbox: 'sender1', host: 'example.com'),
            double('address', mailbox: 'sender2', host: 'test.com')
          ])}),
          double('envelope', attr: { 'ENVELOPE' => double('envelope_data', from: [
            double('address', mailbox: 'sender3', host: 'example.com')
          ])})
        ]
      end

      before do
        allow(mock_imap).to receive(:search).and_return([1, 2])
        allow(mock_imap).to receive(:fetch).and_return(mock_envelopes)
      end

      it 'returns unique email addresses' do
        expect(checker.email_addresses).to eq([
          'sender1@example.com',
          'sender2@test.com',
          'sender3@example.com'
        ])
      end

      context 'with caching enabled' do
        before do
          allow(checker).to receive(:cache_enabled?).and_return(true)
        end

        it 'uses cached data when available and valid' do
          cached_emails = ['cached1@example.com', 'cached2@test.com']
          cache_data = {
            'emails' => cached_emails,
            'stats' => { messages: 100, uidnext: 101, uidvalidity: 12345 }
          }
          
          allow(described_class).to receive(:load_folder_cache).and_return(cache_data)
          allow(described_class).to receive(:cache_valid?).and_return(true)
          
          expect(checker.email_addresses).to eq(cached_emails)
        end

        it 'fetches and caches when cache is invalid' do
          allow(described_class).to receive(:load_folder_cache).and_return(nil)
          allow(described_class).to receive(:save_folder_cache)
          
          result = checker.email_addresses
          
          expect(result).to eq([
            'sender1@example.com',
            'sender2@test.com',
            'sender3@example.com'
          ])
          expect(described_class).to have_received(:save_folder_cache)
        end

        it 'fetches and caches when cache is stale' do
          cached_emails = ['cached1@example.com']
          cache_data = {
            'emails' => cached_emails,
            'stats' => { messages: 50, uidnext: 51, uidvalidity: 12345 } # Different stats
          }
          
          allow(described_class).to receive(:load_folder_cache).and_return(cache_data)
          allow(described_class).to receive(:cache_valid?).and_return(false)
          allow(described_class).to receive(:save_folder_cache)
          
          result = checker.email_addresses
          
          expect(result).to eq([
            'sender1@example.com',
            'sender2@test.com',
            'sender3@example.com'
          ])
          expect(described_class).to have_received(:save_folder_cache)
        end
      end

      context 'with caching disabled' do
        before do
          allow(checker).to receive(:cache_enabled?).and_return(false)
        end

        it 'always fetches fresh data' do
          expect(described_class).not_to receive(:load_folder_cache)
          expect(described_class).not_to receive(:save_folder_cache)
          
          checker.email_addresses
        end
      end
    end
  end

  describe '#domains' do
    before do
      allow(checker).to receive(:email_addresses).and_return([
        'sender1@example.com',
        'sender2@test.com',
        'sender3@example.com'
      ])
    end

    it 'returns unique domains from email addresses' do
      expect(checker.domains).to eq(['example.com', 'test.com'])
    end

    it 'returns empty array when no emails' do
      allow(checker).to receive(:email_addresses).and_return([])
      expect(checker.domains).to eq([])
    end
  end

  describe 'cache management' do


    describe '.data_dir' do
      context 'when data_dir is set' do
        let(:config_options) { { data_dir: '/custom/data/dir' } }
        
        it 'returns the set data directory' do
          expect(described_class.data_dir).to eq('/custom/data/dir')
        end
      end

      context 'when data_dir is not set' do
        it 'returns working directory when not set' do
          # Use default config_options (empty hash)
          expect(described_class.data_dir).to eq(Dir.pwd)
        end
      end
    end

    describe '.cache_dir' do
      context 'when data_dir is set' do
        let(:config_options) { { data_dir: '/custom/data/dir' } }
        
        it 'returns cache directory based on data directory' do
          # Don't use the mocked cache_dir for this test
          allow(described_class).to receive(:cache_dir).and_call_original
          expected_path = File.join('/custom/data/dir', 'cache', 'folder_emails')
          expect(described_class.cache_dir).to eq(expected_path)
        end
      end

      context 'when data_dir is not set' do
        it 'returns default cache directory when data_dir not set' do
          # Use default config_options (empty hash)
          # Don't use the mocked cache_dir for this test
          allow(described_class).to receive(:cache_dir).and_call_original
          expected_path = File.join(Dir.pwd, 'cache', 'folder_emails')
          expect(described_class.cache_dir).to eq(expected_path)
        end
      end
    end

    describe '.cache_file_for_folder' do
      it 'returns the correct cache file path' do
        expected_path = File.join(temp_cache_dir, 'TestFolder.yml')
        expect(described_class.cache_file_for_folder('TestFolder')).to eq(expected_path)
      end
    end

    describe '.load_folder_cache' do
      it 'returns nil when cache file does not exist' do
        expect(described_class.load_folder_cache('NonExistentFolder')).to be_nil
      end

      it 'loads cache data when file exists' do
        cache_data = { 'emails' => ['test@example.com'], 'stats' => { messages: 10 } }
        cache_file = described_class.cache_file_for_folder('TestFolder')
        
        FileUtils.mkdir_p(File.dirname(cache_file))
        File.write(cache_file, cache_data.to_yaml)
        
        expect(described_class.load_folder_cache('TestFolder')).to eq(cache_data)
      end

      it 'returns nil on YAML parse error' do
        cache_file = described_class.cache_file_for_folder('TestFolder')
        
        FileUtils.mkdir_p(File.dirname(cache_file))
        File.write(cache_file, "invalid: yaml: content: with: colons: everywhere:")
        
        expect(described_class.load_folder_cache('TestFolder')).to be_nil
      end
    end

    describe '.save_folder_cache' do
      it 'creates cache directory and saves data' do
        cache_data = { 'emails' => ['test@example.com'], 'stats' => { messages: 10 } }
        
        described_class.save_folder_cache('TestFolder', cache_data)
        
        cache_file = described_class.cache_file_for_folder('TestFolder')
        expect(File.exist?(cache_file)).to be true
        
        loaded_data = YAML.load_file(cache_file)
        expect(loaded_data).to eq(cache_data)
      end
    end

    describe '.cache_valid?' do
      it 'returns false when cache does not exist' do
        current_stats = { messages: 10, uidnext: 11, uidvalidity: 12345 }
        expect(described_class.cache_valid?('NonExistentFolder', current_stats)).to be false
      end

      it 'returns false when cache has no stats' do
        cache_data = { 'emails' => ['test@example.com'] }
        allow(described_class).to receive(:load_folder_cache).and_return(cache_data)
        
        current_stats = { messages: 10, uidnext: 11, uidvalidity: 12345 }
        expect(described_class.cache_valid?('TestFolder', current_stats)).to be false
      end

      it 'returns true when stats match' do
        cache_data = {
          'emails' => ['test@example.com'],
          'stats' => { messages: 10, uidnext: 11, uidvalidity: 12345 }
        }
        allow(described_class).to receive(:load_folder_cache).and_return(cache_data)
        
        current_stats = { messages: 10, uidnext: 11, uidvalidity: 12345 }
        expect(described_class.cache_valid?('TestFolder', current_stats)).to be true
      end

      it 'returns false when stats do not match' do
        cache_data = {
          'emails' => ['test@example.com'],
          'stats' => { messages: 10, uidnext: 11, uidvalidity: 12345 }
        }
        allow(described_class).to receive(:load_folder_cache).and_return(cache_data)
        
        current_stats = { messages: 15, uidnext: 11, uidvalidity: 12345 } # Different message count
        expect(described_class.cache_valid?('TestFolder', current_stats)).to be false
      end
    end

    describe '.update_cache_stats' do
      it 'updates cache stats without changing emails' do
        original_cache = {
          'emails' => ['test@example.com'],
          'stats' => { messages: 10, uidnext: 11, uidvalidity: 12345 },
          'cached_at' => '2023-01-01T00:00:00Z'
        }
        
        allow(described_class).to receive(:load_folder_cache).and_return(original_cache)
        allow(described_class).to receive(:save_folder_cache)
        allow(mock_imap).to receive(:status).and_return({
          'MESSAGES' => 15,
          'UIDNEXT' => 16,
          'UIDVALIDITY' => 12345
        })
        
        described_class.update_cache_stats('TestFolder', mock_imap)
        
        expected_updated_cache = {
          'emails' => ['test@example.com'],
          'stats' => { messages: 15, uidnext: 16, uidvalidity: 12345 },
          'cached_at' => anything
        }
        
        expect(described_class).to have_received(:save_folder_cache).with('TestFolder', expected_updated_cache)
      end
    end
  end

  describe 'date filtering' do
    context 'with valid_from option' do
      let(:options) { { folder: 'TestFolder', valid_from: '2023-01-01' } }

      it 'uses valid_from date for search' do
        expect(checker.send(:date_search)).to eq(['SINCE', '01-Jan-2023'])
      end
    end

    context 'with valid_since_months option' do
      let(:options) { { folder: 'TestFolder', valid_since_months: 6 } }

      it 'uses valid_since_months for search' do
        expected_date = (Date.today << 6).strftime('%d-%b-%Y')
        expect(checker.send(:date_search)).to eq(['SINCE', expected_date])
      end
    end

    context 'with default options' do
      it 'uses 12 months as default' do
        expected_date = (Date.today << 12).strftime('%d-%b-%Y')
        expect(checker.send(:date_search)).to eq(['SINCE', expected_date])
      end
    end
  end

  describe 'address field selection' do
    context 'with address option' do
      let(:options) { { folder: 'TestFolder', address: :to } }

      it 'uses specified address field' do
        expect(checker.send(:address)).to eq(:to)
      end
    end

    context 'without address option' do
      it 'defaults to :from' do
        expect(checker.send(:address)).to eq(:from)
      end
    end
  end

  describe 'cache enabling/disabling' do
    context 'when cache is enabled by default' do
      it 'enables cache' do
        expect(checker.send(:cache_enabled?)).to be true
      end
    end

    context 'when cache is disabled via options' do
      let(:options) { { folder: 'TestFolder', cache: false } }

      it 'disables cache' do
        expect(checker.send(:cache_enabled?)).to be false
      end
    end

    context 'when cache is disabled via environment' do
      before do
        ENV['CLEANBOX_CACHE'] = 'false'
      end

      after do
        ENV.delete('CLEANBOX_CACHE')
      end

      it 'disables cache' do
        expect(checker.send(:cache_enabled?)).to be false
      end
    end
  end
end 