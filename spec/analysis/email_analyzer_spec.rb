# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::EmailAnalyzer do
  let(:mock_imap) { instance_double(Net::IMAP) }
  let(:mock_folder) { instance_double(Net::IMAP::MailboxList, name: 'TestFolder') }
  let(:mock_logger) { instance_double(Logger) }
  let(:mock_categorizer_class) { class_double(Analysis::FolderCategorizer) }
  let(:mock_categorizer) { instance_double(Analysis::FolderCategorizer) }
  
  let(:analyzer) do
    described_class.new(
      mock_imap,
      logger: mock_logger,
      folder_categorizer_class: mock_categorizer_class
    )
  end
  
  before do
    allow(mock_logger).to receive(:info)
    allow(mock_logger).to receive(:debug)
    allow(mock_logger).to receive(:error)
    allow(mock_categorizer_class).to receive(:new).and_return(mock_categorizer)
  end
  
  describe '#initialize' do
    it 'creates a new analyzer with dependencies' do
      expect(analyzer.imap_connection).to eq(mock_imap)
      expect(analyzer.logger).to eq(mock_logger)
      expect(analyzer.folder_categorizer_class).to eq(mock_categorizer_class)
    end
    
    it 'uses default logger when none provided' do
      analyzer_with_default = described_class.new(mock_imap)
      expect(analyzer_with_default.logger).to be_a(Logger)
    end
  end
  
  describe '#analyze_folders' do
    let(:mock_status) { { 'MESSAGES' => 50, 'UNSEEN' => 10 } }
    let(:mock_envelopes) { [] }
    
    before do
      allow(mock_imap).to receive(:list).and_return([mock_folder])
      allow(mock_imap).to receive(:select)
      allow(mock_imap).to receive(:status).and_return(mock_status)
      allow(mock_imap).to receive(:search).and_return([1, 2, 3])
      allow(mock_imap).to receive(:fetch).and_return(mock_envelopes)
      allow(mock_folder).to receive(:attr).and_return([])
    end
    
    context 'with normal folder' do
      before do
        allow(mock_categorizer).to receive(:skip?).and_return(false)
        allow(mock_categorizer).to receive(:categorization).and_return(:list)
        allow(mock_categorizer).to receive(:categorization_reason).and_return('folder name suggests list/newsletter content')
      end
      
      it 'analyzes folders and returns results' do
        results = analyzer.analyze_folders
        
        expect(results).to be_a(Hash)
        expect(results[:folders]).to be_an(Array)
        expect(results[:folders].first[:name]).to eq('TestFolder')
        expect(results[:folders].first[:message_count]).to eq(50)
        expect(results[:folders].first[:categorization]).to eq(:list)
        expect(results[:total_analyzed]).to eq(1)
        expect(results[:total_skipped]).to eq(0)
      end
      
      it 'skips INBOX folder' do
        allow(mock_folder).to receive(:name).and_return('INBOX')
        
        results = analyzer.analyze_folders
        expect(results[:folders]).to be_empty
        expect(results[:total_analyzed]).to eq(0)
        expect(results[:total_skipped]).to eq(0)
      end
      
      it 'sorts folders by message count descending' do
        mock_folder2 = instance_double(Net::IMAP::MailboxList, name: 'Folder2', attr: [])
        mock_categorizer2 = instance_double(Analysis::FolderCategorizer)
        
        allow(mock_imap).to receive(:list).and_return([mock_folder, mock_folder2])
        allow(mock_categorizer_class).to receive(:new).and_return(mock_categorizer, mock_categorizer2)
        allow(mock_categorizer2).to receive(:skip?).and_return(false)
        allow(mock_categorizer2).to receive(:categorization).and_return(:whitelist)
        allow(mock_categorizer2).to receive(:categorization_reason).and_return('folder name suggests personal/professional emails')
        allow(mock_imap).to receive(:status).and_return({ 'MESSAGES' => 25 }, { 'MESSAGES' => 100 })
        
        results = analyzer.analyze_folders
        
        expect(results[:folders].first[:message_count]).to eq(100)
        expect(results[:folders].last[:message_count]).to eq(25)
      end
    end
    
    context 'with folder that should be skipped' do
      before do
        allow(mock_categorizer).to receive(:skip?).and_return(true)
        allow(mock_categorizer).to receive(:categorization_reason).and_return('system folder')
      end
      
      it 'skips the folder' do
        results = analyzer.analyze_folders
        expect(results[:folders]).to be_empty
        expect(results[:total_analyzed]).to eq(0)
        expect(results[:total_skipped]).to eq(1)
      end
      
      it 'logs skipped folders' do
        analyzer.analyze_folders
        expect(mock_logger).to have_received(:debug).with(/Found 1 folders to analyze/)
      end
    end
    
    context 'when folder analysis fails' do
      before do
        allow(mock_imap).to receive(:select).and_raise(StandardError, 'Access denied')
        allow(mock_categorizer).to receive(:skip?).and_return(false)
        allow(mock_categorizer).to receive(:categorization).and_return(:list)
        allow(mock_categorizer).to receive(:categorization_reason).and_return('folder name suggests list/newsletter content')
      end
      
      it 'handles errors gracefully' do
        results = analyzer.analyze_folders
        
        expect(results[:folders].first[:message_count]).to eq(0)
        expect(results[:folders].first[:senders]).to eq([])
        expect(results[:folders].first[:domains]).to eq([])
      end
      
      it 'logs debug message for errors' do
        analyzer.analyze_folders
        expect(mock_logger).to have_received(:error).with(/Could not analyze folder TestFolder/)
      end
    end
  end
  
  describe '#analyze_sent_items' do
    context 'when sent folder is found' do
      let(:mock_envelopes) do
        [
          instance_double('Envelope', attr: { 'ENVELOPE' => mock_envelope1 }),
          instance_double('Envelope', attr: { 'ENVELOPE' => mock_envelope2 }),
          instance_double('Envelope', attr: { 'ENVELOPE' => mock_envelope1 }) # Duplicate
        ]
      end
      
      let(:mock_envelope1) do
        instance_double('EnvelopeData', to: [instance_double('Address', mailbox: 'user1', host: 'example.com')])
      end
      
      let(:mock_envelope2) do
        instance_double('EnvelopeData', to: [instance_double('Address', mailbox: 'user2', host: 'domain.com')])
      end
      
      before do
        allow(analyzer).to receive(:detect_sent_folder).and_return('Sent Items')
        allow(mock_imap).to receive(:select)
        allow(mock_imap).to receive(:search).and_return([1, 2, 3])
        allow(mock_imap).to receive(:fetch).and_return(mock_envelopes)
      end
      
      it 'analyzes sent items and returns frequent correspondents' do
        result = analyzer.analyze_sent_items
        
        expect(result[:frequent_correspondents]).to be_an(Array)
        expect(result[:total_sent]).to eq(3)
        expect(result[:sample_size]).to eq(3)
      end
      
      it 'counts frequency of recipients' do
        result = analyzer.analyze_sent_items
        
        # user1@example.com appears twice, user2@domain.com appears once
        expect(result[:frequent_correspondents].first[0]).to eq('user1@example.com')
        expect(result[:frequent_correspondents].first[1]).to eq(2)
      end
    end
    
    context 'when no sent folder is found' do
      before do
        allow(analyzer).to receive(:detect_sent_folder).and_return(nil)
      end
      
      it 'returns empty result' do
        result = analyzer.analyze_sent_items
        
        expect(result[:frequent_correspondents]).to eq([])
        expect(result[:total_sent]).to eq(0)
      end
    end
    
    context 'when analysis fails' do
      before do
        allow(analyzer).to receive(:detect_sent_folder).and_return('Sent Items')
        allow(mock_imap).to receive(:select).and_raise(StandardError, 'Connection failed')
      end
      
      it 'handles errors gracefully' do
        result = analyzer.analyze_sent_items
        
        expect(result[:frequent_correspondents]).to eq([])
        expect(result[:total_sent]).to eq(0)
      end
      
      it 'logs error message' do
        analyzer.analyze_sent_items
        expect(mock_logger).to have_received(:error).with(/Could not analyze sent items/)
      end
    end
  end
  
  describe '#analyze_domain_patterns' do
    before do
      analyzer.instance_variable_set(:@analysis_results, {
        folders: [
          { name: 'GitHub', domains: ['github.com'] },
          { name: 'Facebook', domains: ['facebook.com'] },
          { name: 'Amazon', domains: ['amazon.com'] }
        ]
      })
    end
    
    it 'categorizes domains by type' do
      patterns = analyzer.analyze_domain_patterns
      
      expect(patterns['github.com']).to eq('development')
      expect(patterns['facebook.com']).to eq('social')
      expect(patterns['amazon.com']).to eq('shopping')
    end
    
    it 'handles unknown domains' do
      analyzer.instance_variable_set(:@analysis_results, {
        folders: [{ name: 'Unknown', domains: ['unknown.com'] }]
      })
      
      patterns = analyzer.analyze_domain_patterns
      expect(patterns['unknown.com']).to eq('other')
    end
  end
  
  describe '#generate_recommendations' do
    let(:mock_domain_mapper) { instance_double(Analysis::DomainMapper) }
    let(:mock_domain_mapper_class) { class_double(Analysis::DomainMapper) }
    
         before do
       analyzer.instance_variable_set(:@analysis_results, {
         folders: [
           { name: 'Work', categorization: :whitelist, domains: ['company.com'] },
           { name: 'Newsletters', categorization: :list, domains: ['newsletter.com'] },
           { name: 'Shopping', categorization: :list, domains: ['shop.com'] }
         ],
         sent_items: {
           frequent_correspondents: [['friend@example.com', 10]]
         }
       })
      
      allow(mock_domain_mapper_class).to receive(:new).and_return(mock_domain_mapper)
      allow(mock_domain_mapper).to receive(:generate_mappings).and_return({
        'example.com' => 'Newsletters',
        'shop.com' => 'Shopping'
      })
    end
    
    it 'generates recommendations with folder categorizations' do
      recommendations = analyzer.generate_recommendations(domain_mapper_class: mock_domain_mapper_class)
      
      expect(recommendations[:whitelist_folders]).to include('Work')
      expect(recommendations[:list_folders]).to include('Newsletters', 'Shopping')
      expect(recommendations[:frequent_correspondents]).to eq([['friend@example.com', 10]])
    end
    
    it 'includes domain mappings' do
      recommendations = analyzer.generate_recommendations(domain_mapper_class: mock_domain_mapper_class)
      
      expect(recommendations[:domain_mappings]['example.com']).to eq('Newsletters')
      expect(recommendations[:domain_mappings]['shop.com']).to eq('Shopping')
    end
    
    it 'uses default domain mapper class when not specified' do
      recommendations = analyzer.generate_recommendations
      
      expect(recommendations).to have_key(:whitelist_folders)
      expect(recommendations).to have_key(:list_folders)
      expect(recommendations).to have_key(:domain_mappings)
    end
  end
  
  describe 'private methods' do
    describe '#detect_sent_folder' do
      it 'finds common sent folder names' do
        allow(mock_imap).to receive(:select).with('Sent Items').and_raise(StandardError)
        allow(mock_imap).to receive(:select).with('Sent').and_return(true)
        
        result = analyzer.send(:detect_sent_folder)
        expect(result).to eq('Sent')
      end
      
      it 'returns nil when no sent folder is found' do
        allow(mock_imap).to receive(:select).and_raise(StandardError)
        
        result = analyzer.send(:detect_sent_folder)
        expect(result).to be_nil
      end
    end
    
    describe '#categorize_domain' do
      it 'categorizes social media domains' do
        expect(analyzer.send(:categorize_domain, 'facebook.com')).to eq('social')
        expect(analyzer.send(:categorize_domain, 'twitter.com')).to eq('social')
        expect(analyzer.send(:categorize_domain, 'instagram.com')).to eq('social')
      end
      
      it 'categorizes development domains' do
        expect(analyzer.send(:categorize_domain, 'github.com')).to eq('development')
        expect(analyzer.send(:categorize_domain, 'gitlab.com')).to eq('development')
      end
      
      it 'categorizes shopping domains' do
        expect(analyzer.send(:categorize_domain, 'amazon.com')).to eq('shopping')
        expect(analyzer.send(:categorize_domain, 'ebay.com')).to eq('shopping')
      end
      
      it 'categorizes financial domains' do
        expect(analyzer.send(:categorize_domain, 'paypal.com')).to eq('financial')
        expect(analyzer.send(:categorize_domain, 'stripe.com')).to eq('financial')
      end
      
      it 'categorizes tech company domains' do
        expect(analyzer.send(:categorize_domain, 'google.com')).to eq('tech_company')
        expect(analyzer.send(:categorize_domain, 'microsoft.com')).to eq('tech_company')
      end
      
      it 'categorizes unknown domains as other' do
        expect(analyzer.send(:categorize_domain, 'unknown.com')).to eq('other')
      end
    end
  end
end 