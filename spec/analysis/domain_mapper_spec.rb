# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analysis::DomainMapper do
  let(:folders) do
    [
      {
        name: 'GitHub',
        categorization: :list,
        domains: ['github.com'],
        message_count: 50
      },
      {
        name: 'Work',
        categorization: :whitelist,
        domains: ['company.com'],
        message_count: 100
      },
      {
        name: 'Amazon',
        categorization: :list,
        domains: ['amazon.com'],
        message_count: 75
      }
    ]
  end
  
  let(:mapper) { described_class.new(folders) }
  
  describe '#initialize' do
    it 'creates a new domain mapper with folders' do
      expect(mapper.instance_variable_get(:@folders)).to eq(folders)
      expect(mapper.instance_variable_get(:@mappings)).to eq({})
    end
    
    it 'uses provided logger or creates default' do
      custom_logger = Logger.new(StringIO.new)
      mapper_with_logger = described_class.new(folders, logger: custom_logger)
      expect(mapper_with_logger.instance_variable_get(:@logger)).to eq(custom_logger)
    end
  end
  
  describe '#generate_mappings' do
    context 'with GitHub folder' do
      it 'maps related GitHub domains' do
        mappings = mapper.generate_mappings
        
        expect(mappings['githubusercontent.com']).to eq('GitHub')
        expect(mappings['github.io']).to eq('GitHub')
        expect(mappings['githubapp.com']).to eq('GitHub')
      end
    end
    
    context 'with Amazon folder' do
      it 'maps related Amazon domains' do
        mappings = mapper.generate_mappings
        
        expect(mappings['amazon.co.uk']).to eq('Amazon')
        expect(mappings['amazon.de']).to eq('Amazon')
        expect(mappings['amazon.fr']).to eq('Amazon')
        expect(mappings['amazon.ca']).to eq('Amazon')
        expect(mappings['amazon.com.au']).to eq('Amazon')
      end
    end
    
    context 'with Facebook folder' do
      let(:folders) do
        [
          {
            name: 'Facebook',
            categorization: :list,
            domains: ['facebook.com'],
            message_count: 30
          }
        ]
      end
      
      it 'maps related Facebook domains' do
        mappings = mapper.generate_mappings
        
        expect(mappings['facebookmail.com']).to eq('Facebook')
        expect(mappings['fb.com']).to eq('Facebook')
        expect(mappings['messenger.com']).to eq('Facebook')
      end
    end
    
    context 'with multiple list folders' do
      let(:folders) do
        [
          {
            name: 'GitHub',
            categorization: :list,
            domains: ['github.com'],
            message_count: 50
          },
          {
            name: 'Amazon',
            categorization: :list,
            domains: ['amazon.com'],
            message_count: 75
          }
        ]
      end
      
      it 'maps domains for all list folders' do
        mappings = mapper.generate_mappings
        
        # GitHub mappings
        expect(mappings['githubusercontent.com']).to eq('GitHub')
        expect(mappings['github.io']).to eq('GitHub')
        
        # Amazon mappings
        expect(mappings['amazon.co.uk']).to eq('Amazon')
        expect(mappings['amazon.de']).to eq('Amazon')
      end
    end
    
    context 'with whitelist folders only' do
      let(:folders) do
        [
          {
            name: 'Work',
            categorization: :whitelist,
            domains: ['company.com'],
            message_count: 100
          }
        ]
      end
      
      it 'returns empty mappings' do
        mappings = mapper.generate_mappings
        expect(mappings).to be_empty
      end
    end
    
    context 'with domain already handled by another folder' do
      let(:folders) do
        [
          {
            name: 'GitHub',
            categorization: :list,
            domains: ['github.com', 'githubusercontent.com'],
            message_count: 50
          },
          {
            name: 'Other',
            categorization: :list,
            domains: ['other.com'],
            message_count: 25
          }
        ]
      end
      
      it 'does not create duplicate mappings' do
        mappings = mapper.generate_mappings
        
        # Should not create mapping for githubusercontent.com since it's already in the GitHub folder
        expect(mappings['githubusercontent.com']).to be_nil
        expect(mappings['github.io']).to eq('GitHub') # This one should still be mapped
      end
    end
  end
  
  describe 'private methods' do
    describe '#find_related_domains' do
      it 'finds related domains for GitHub' do
        related = mapper.send(:find_related_domains, 'github.com')
        expect(related).to include('githubusercontent.com', 'github.io', 'githubapp.com')
      end
      
      it 'finds related domains for Facebook' do
        related = mapper.send(:find_related_domains, 'facebook.com')
        expect(related).to include('facebookmail.com', 'fb.com', 'messenger.com')
      end
      
      it 'finds related domains for Amazon' do
        related = mapper.send(:find_related_domains, 'amazon.com')
        expect(related).to include('amazon.co.uk', 'amazon.de', 'amazon.fr', 'amazon.ca', 'amazon.com.au')
      end
      
      it 'finds related domains for eBay' do
        related = mapper.send(:find_related_domains, 'ebay.com')
        expect(related).to include('ebay.co.uk', 'ebay.de', 'ebay.fr', 'ebay.com.au')
      end
      
      it 'returns empty array for unknown domain' do
        related = mapper.send(:find_related_domains, 'unknown.com')
        expect(related).to eq([])
      end
      
      it 'handles case insensitive matching' do
        related = mapper.send(:find_related_domains, 'GITHUB.COM')
        expect(related).to include('githubusercontent.com', 'github.io', 'githubapp.com')
      end
    end
    
    describe '#suggest_domains_for_folder' do
      it 'suggests domains for Facebook folder' do
        suggested = mapper.send(:suggest_domains_for_folder, 'Facebook')
        expect(suggested).to include('facebookmail.com', 'fb.com', 'messenger.com', 'developers.facebook.com')
      end
      
      it 'suggests domains for GitHub folder' do
        suggested = mapper.send(:suggest_domains_for_folder, 'GitHub')
        expect(suggested).to include('githubusercontent.com', 'github.io', 'githubapp.com')
      end
      
      it 'suggests domains for Amazon folder' do
        suggested = mapper.send(:suggest_domains_for_folder, 'Amazon')
        expect(suggested).to include('amazon.co.uk', 'amazon.de', 'amazon.fr', 'amazon.ca', 'amazon.com.au')
      end
      
      it 'returns empty array for unknown folder' do
        suggested = mapper.send(:suggest_domains_for_folder, 'UnknownFolder')
        expect(suggested).to eq([])
      end
      
      it 'handles case insensitive matching' do
        suggested = mapper.send(:suggest_domains_for_folder, 'FACEBOOK')
        expect(suggested).to include('facebookmail.com', 'fb.com', 'messenger.com', 'developers.facebook.com')
      end
    end
    
    describe '#has_folder_for_domain?' do
      it 'returns true when domain exists in folders' do
        expect(mapper.send(:has_folder_for_domain?, 'github.com')).to be true
        expect(mapper.send(:has_folder_for_domain?, 'company.com')).to be true
      end
      
      it 'returns false when domain does not exist in folders' do
        expect(mapper.send(:has_folder_for_domain?, 'unknown.com')).to be false
      end
    end
  end
end 