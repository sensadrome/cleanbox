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
  end
end 