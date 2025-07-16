# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::FolderCategorizer do
  let(:folder_data) do
    {
      name: 'TestFolder',
      message_count: 100,
      senders: ['test@example.com', 'user@domain.com'],
      domains: ['example.com', 'domain.com'],
      attributes: {}
    }
  end
  
  let(:categorizer) { described_class.new(folder_data) }
  
  describe '#initialize' do
    it 'creates a new categorizer with folder data' do
      expect(categorizer.folder).to eq('TestFolder')
      expect(categorizer.message_count).to eq(100)
      expect(categorizer.senders).to eq(['test@example.com', 'user@domain.com'])
      expect(categorizer.domains).to eq(['example.com', 'domain.com'])
    end
  end
  
  describe '#skip?' do
    context 'with low volume folder' do
      let(:folder_data) { { name: 'TestFolder', message_count: 3, senders: [], domains: [] } }
      
      it 'returns true for low volume folders' do
        expect(categorizer.skip?).to be true
      end
    end
    
    context 'with system folder' do
      let(:folder_data) { { name: 'Sent Items', message_count: 100, senders: [], domains: [] } }
      
      it 'returns true for system folders' do
        expect(categorizer.skip?).to be true
      end
    end
    
    context 'with normal folder' do
      it 'returns false for normal folders' do
        expect(categorizer.skip?).to be false
      end
    end
  end
  
  describe '#categorization' do
    context 'with list folder by name' do
      let(:folder_data) { { name: 'Newsletters', message_count: 100, senders: [], domains: [] } }
      
      it 'categorizes as list' do
        expect(categorizer.categorization).to eq(:list)
      end
    end
    
    context 'with whitelist folder by name' do
      let(:folder_data) { { name: 'Family', message_count: 100, senders: [], domains: [] } }
      
      it 'categorizes as whitelist' do
        expect(categorizer.categorization).to eq(:whitelist)
      end
    end

    context 'with bulk headers' do
      let(:imap_connection) { double('imap_connection') }
      let(:categorizer) { described_class.new(folder_data, imap_connection: imap_connection) }
      
      before do
        allow(imap_connection).to receive(:select).with('TestFolder')
        allow(imap_connection).to receive(:search).with(['ALL']).and_return([1, 2, 3, 4, 5])
        
        # Mock fetch responses with bulk headers
        headers_with_bulk = double('headers_with_bulk')
        allow(headers_with_bulk).to receive(:attr).and_return({
          'BODY[HEADER]' => "List-Unsubscribe: <mailto:unsubscribe@example.com>\nFrom: newsletter@example.com\nSubject: Weekly Update"
        })
        
        allow(imap_connection).to receive(:fetch).and_return([headers_with_bulk])
      end
      
      it 'categorizes as list when bulk headers are detected' do
        expect(categorizer.categorization).to eq(:list)
      end
    end

    context 'with sender-based categorization' do
      context 'when senders are empty' do
        let(:folder_data) { { name: 'TestFolder', message_count: 100, senders: [], domains: [] } }
        
        it 'categorizes as skip' do
          expect(categorizer.categorization).to eq(:skip)
        end
      end

      context 'when mostly single domain with high volume' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 60,
            senders: ['newsletter@company.com', 'updates@company.com', 'alerts@company.com'],
            domains: ['company.com']
          }
        end
        
        it 'categorizes as list' do
          expect(categorizer.categorization).to eq(:list)
        end
      end

      context 'when diverse senders with personal names' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 50,
            senders: ['john.smith@gmail.com', 'jane.doe@yahoo.com', 'bob.wilson@hotmail.com'],
            domains: ['gmail.com', 'yahoo.com', 'hotmail.com']
          }
        end
        
        it 'categorizes as whitelist' do
          expect(categorizer.categorization).to eq(:whitelist)
        end
      end

      context 'when high volume with mixed senders' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 150,
            senders: ['sender1@domain1.com', 'sender2@domain2.com', 'sender3@domain3.com'],
            domains: ['domain1.com', 'domain2.com', 'domain3.com']
          }
        end
        
        it 'categorizes as list' do
          expect(categorizer.categorization).to eq(:list)
        end
      end

      context 'when low volume with mixed senders' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 30,
            senders: ['sender1@domain1.com', 'sender2@domain2.com'],
            domains: ['domain1.com', 'domain2.com']
          }
        end
        
        it 'categorizes as skip' do
          expect(categorizer.categorization).to eq(:skip)
        end
      end
    end
  end
  
  describe '#categorization_reason' do
    context 'with list folder' do
      let(:folder_data) { { name: 'Newsletters', message_count: 100, senders: [], domains: [] } }
      
      it 'provides appropriate reason' do
        expect(categorizer.categorization_reason).to include('folder name suggests list/newsletter content')
      end
    end
    
    context 'with whitelist folder' do
      let(:folder_data) { { name: 'Family', message_count: 100, senders: [], domains: [] } }
      
      it 'provides appropriate reason' do
        expect(categorizer.categorization_reason).to include('folder name suggests personal/professional emails')
      end
    end

    context 'with bulk headers' do
      let(:imap_connection) { double('imap_connection') }
      let(:categorizer) { described_class.new(folder_data, imap_connection: imap_connection) }
      
      before do
        allow(imap_connection).to receive(:select).with('TestFolder')
        allow(imap_connection).to receive(:search).with(['ALL']).and_return([1, 2, 3, 4, 5])
        
        headers_with_bulk = double('headers_with_bulk')
        allow(headers_with_bulk).to receive(:attr).and_return({
          'BODY[HEADER]' => "List-Unsubscribe: <mailto:unsubscribe@example.com>\nFrom: newsletter@example.com"
        })
        
        allow(imap_connection).to receive(:fetch).and_return([headers_with_bulk])
      end
      
      it 'provides appropriate reason' do
        expect(categorizer.categorization_reason).to include('found newsletter/bulk email headers')
      end
    end

    context 'with sender-based list categorization' do
      let(:folder_data) do
        {
          name: 'TestFolder',
          message_count: 60,
          senders: ['newsletter@company.com', 'updates@company.com'],
          domains: ['company.com']
        }
      end
      
      it 'provides appropriate reason' do
        expect(categorizer.categorization_reason).to include('sender patterns suggest list/newsletter content')
      end
    end

    context 'with sender-based whitelist categorization' do
      let(:folder_data) do
        {
          name: 'TestFolder',
          message_count: 50,
          senders: ['john.smith@gmail.com', 'jane.doe@yahoo.com'],
          domains: ['gmail.com', 'yahoo.com']
        }
      end
      
      it 'provides appropriate reason' do
        expect(categorizer.categorization_reason).to include('sender patterns suggest personal correspondence')
      end
    end

    context 'with low volume skip' do
      let(:folder_data) { { name: 'TestFolder', message_count: 3, senders: [], domains: [] } }
      
      it 'provides appropriate reason' do
        expect(categorizer.categorization_reason).to include('low volume (3 messages)')
      end
    end

    context 'with system folder skip' do
      let(:folder_data) { { name: 'Sent Items', message_count: 100, senders: [], domains: [] } }
      
      it 'provides appropriate reason' do
        expect(categorizer.categorization_reason).to include('system folder')
      end
    end
  end

  describe '#has_bulk_headers?' do
    let(:imap_connection) { double('imap_connection') }
    let(:categorizer) { described_class.new(folder_data, imap_connection: imap_connection) }
    
    context 'when no IMAP connection is provided' do
      let(:categorizer) { described_class.new(folder_data) }
      
      it 'returns false' do
        expect(categorizer.send(:has_bulk_headers?)).to be false
      end
    end
    
    context 'when IMAP connection is provided' do
      before do
        allow(imap_connection).to receive(:select).with('TestFolder')
      end
      
      context 'when no messages are found' do
        before do
          allow(imap_connection).to receive(:search).with(['ALL']).and_return([])
        end
        
        it 'returns false' do
          expect(categorizer.send(:has_bulk_headers?)).to be false
        end
      end
      
      context 'when messages are found' do
        before do
          allow(imap_connection).to receive(:search).with(['ALL']).and_return([1, 2, 3, 4, 5])
        end
        
        context 'when bulk headers are detected in majority of messages' do
          before do
            headers_with_bulk = double('headers_with_bulk')
            allow(headers_with_bulk).to receive(:attr).and_return({
              'BODY[HEADER]' => "List-Unsubscribe: <mailto:unsubscribe@example.com>\nFrom: newsletter@example.com"
            })
            
            allow(imap_connection).to receive(:fetch).and_return([headers_with_bulk])
          end
          
          it 'returns true' do
            expect(categorizer.send(:has_bulk_headers?)).to be true
          end
        end
        
        context 'when bulk headers are detected in minority of messages' do
          before do
            headers_without_bulk = double('headers_without_bulk')
            allow(headers_without_bulk).to receive(:attr).and_return({
              'BODY[HEADER]' => "From: sender@example.com\nSubject: Regular Email"
            })
            
            allow(imap_connection).to receive(:fetch).and_return([headers_without_bulk])
          end
          
          it 'returns false' do
            expect(categorizer.send(:has_bulk_headers?)).to be false
          end
        end
        
        context 'when IMAP operations fail' do
          before do
            allow(imap_connection).to receive(:search).and_raise(StandardError, 'Connection failed')
          end
          
          it 'returns false and logs the error' do
            logger = double('logger')
            allow(logger).to receive(:debug)
            categorizer_with_logger = described_class.new(folder_data, imap_connection: imap_connection, logger: logger)
            
            expect(categorizer_with_logger.send(:has_bulk_headers?)).to be false
            expect(logger).to have_received(:debug).with(/Could not analyze headers for TestFolder/)
          end
        end
      end
    end
  end

  describe '#has_bulk_headers_pattern?' do
    let(:headers) { double('headers') }
    
    context 'with List-Unsubscribe header' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "List-Unsubscribe: <mailto:unsubscribe@example.com>\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with Precedence: bulk header' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "Precedence: bulk\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with X-Mailer header containing mailing' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "X-Mailer: Some Mailing System\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with X-Mailer header containing newsletter' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "X-Mailer: Newsletter System\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with X-Mailer header containing campaign' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "X-Mailer: Campaign Manager\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with X-Campaign header' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "X-Campaign: weekly-newsletter\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with X-Mailing-List header' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "X-Mailing-List: <mailto:list@example.com>\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with Feedback-ID header' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "Feedback-ID: 123456:example.com:mailing\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with X-Auto-Response-Suppress header' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "X-Auto-Response-Suppress: All\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
    
    context 'with regular email headers' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "From: sender@example.com\nSubject: Regular Email\nTo: recipient@example.com"
        })
      end
      
      it 'returns false' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be false
      end
    end
    
    context 'with case insensitive matching' do
      before do
        allow(headers).to receive(:attr).and_return({
          'BODY[HEADER]' => "list-unsubscribe: <mailto:unsubscribe@example.com>\nFrom: sender@example.com"
        })
      end
      
      it 'returns true' do
        expect(categorizer.send(:has_bulk_headers_pattern?, headers)).to be true
      end
    end
  end

  describe 'private methods' do
    describe '#categorize_by_senders' do
      context 'when senders are empty' do
        let(:folder_data) { { name: 'TestFolder', message_count: 100, senders: [], domains: [] } }
        
        it 'returns skip' do
          expect(categorizer.send(:categorize_by_senders)).to eq(:skip)
        end
      end

      context 'when mostly single domain with high volume' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 60,
            senders: ['newsletter@company.com', 'updates@company.com', 'alerts@company.com'],
            domains: ['company.com']
          }
        end
        
        it 'returns list' do
          expect(categorizer.send(:categorize_by_senders)).to eq(:list)
        end
      end

      context 'when diverse senders with personal names' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 50,
            senders: ['john.smith@gmail.com', 'jane.doe@yahoo.com', 'bob.wilson@hotmail.com'],
            domains: ['gmail.com', 'yahoo.com', 'hotmail.com']
          }
        end
        
        it 'returns whitelist' do
          expect(categorizer.send(:categorize_by_senders)).to eq(:whitelist)
        end
      end

      context 'when high volume with mixed senders' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 150,
            senders: ['sender1@domain1.com', 'sender2@domain2.com', 'sender3@domain3.com'],
            domains: ['domain1.com', 'domain2.com', 'domain3.com']
          }
        end
        
        it 'returns list' do
          expect(categorizer.send(:categorize_by_senders)).to eq(:list)
        end
      end

      context 'when low volume with mixed senders' do
        let(:folder_data) do
          {
            name: 'TestFolder',
            message_count: 30,
            senders: ['sender1@domain1.com', 'sender2@domain2.com'],
            domains: ['domain1.com', 'domain2.com']
          }
        end
        
        it 'returns skip' do
          expect(categorizer.send(:categorize_by_senders)).to eq(:skip)
        end
      end
    end
  end
end 