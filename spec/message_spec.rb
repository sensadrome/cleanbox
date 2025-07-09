# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CleanboxMessage do
  let(:cleanbox) { double('Cleanbox') }
  let(:message_data) do
    {
      seqno: 123,
      attr: {
        'BODY[HEADER]' => "From: test@example.com\r\nSubject: Test Email\r\n\r\n"
      }
    }
  end
  let(:mock_imap_message) { double('IMAPMessage', message_data) }
  let(:message) { described_class.new(mock_imap_message, cleanbox) }

  before do
    # Mock basic cleanbox behavior
    allow(cleanbox).to receive(:whitelisted_emails).and_return([])
    allow(cleanbox).to receive(:whitelisted_domains).and_return([])
    allow(cleanbox).to receive(:list_domains).and_return([])
    allow(cleanbox).to receive(:list_domain_map).and_return({})
    allow(cleanbox).to receive(:list_folder).and_return('Lists')
    allow(cleanbox).to receive(:junk_folder).and_return('Junk')
    allow(cleanbox).to receive(:unjunking?).and_return(false)
    allow(cleanbox).to receive(:pretending?).and_return(false)
    allow(cleanbox).to receive(:logger).and_return(double('Logger', debug: nil, info: nil))
    
    # Mock the IMAP operations
    allow(message).to receive(:move_message_to_folder)
    allow(message).to receive(:keep!)
  end

  describe '#process!' do
    context 'when email is from a whitelisted sender' do
      before do
        allow(cleanbox).to receive(:whitelisted_emails).and_return(['friend@example.com'])
        allow(message).to receive(:from_address).and_return('friend@example.com')
      end

      it 'keeps the message in inbox' do
        expect(message).to receive(:keep!)
        expect(message).not_to receive(:move_message_to_folder)
        message.process!
      end
    end

    context 'when email is from a whitelisted domain' do
      before do
        allow(cleanbox).to receive(:whitelisted_domains).and_return(['trusted.com'])
        allow(message).to receive(:from_domain).and_return('trusted.com')
      end

      it 'keeps the message in inbox' do
        expect(message).to receive(:keep!)
        expect(message).not_to receive(:move_message_to_folder)
        message.process!
      end
    end

    context 'when email is from a list domain' do
      before do
        allow(cleanbox).to receive(:list_domains).and_return(['newsletter.com'])
        allow(message).to receive(:from_domain).and_return('newsletter.com')
        allow(message).to receive(:valid_list_email?).and_return(true)
      end

      it 'moves the message to list folder' do
        expect(message).to receive(:move_message_to_folder).with('Lists')
        message.process!
      end
    end

    context 'when email is from an unknown sender' do
      before do
        allow(message).to receive(:from_address).and_return('unknown@spam.com')
        allow(message).to receive(:valid_list_email?).and_return(false)
      end

      it 'moves the message to junk folder' do
        expect(message).to receive(:move_message_to_folder).with('Junk')
        message.process!
      end
    end
  end

  describe '#from_address' do
    it 'extracts the from address from the message' do
      allow(message).to receive(:message).and_return(
        double('Mail', from: ['test@example.com'])
      )
      
      expect(message.send(:from_address)).to eq('test@example.com')
    end
  end

  describe '#from_domain' do
    it 'extracts the domain from the from address' do
      allow(message).to receive(:from_address).and_return('user@example.com')
      
      expect(message.send(:from_domain)).to eq('example.com')
    end
  end
end 