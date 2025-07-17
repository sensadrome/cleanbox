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

  describe '#from_address' do
    it 'extracts the from address from the message' do
      allow(message).to receive(:message).and_return(
        double('Mail', from: ['test@example.com'])
      )
      
      expect(message.from_address).to eq('test@example.com')
    end

    it 'converts address to lowercase' do
      allow(message).to receive(:message).and_return(
        double('Mail', from: ['TEST@EXAMPLE.COM'])
      )
      
      expect(message.from_address).to eq('test@example.com')
    end
  end

  describe '#from_domain' do
    it 'extracts the domain from the from address' do
      allow(message).to receive(:from_address).and_return('user@example.com')
      
      expect(message.from_domain).to eq('example.com')
    end

    it 'handles complex domains' do
      allow(message).to receive(:from_address).and_return('user@sub.example.com')
      
      expect(message.from_domain).to eq('sub.example.com')
    end
  end

  describe '#message' do
    it 'parses the IMAP message header data' do
      expect(Mail).to receive(:read_from_string).with("From: test@example.com\r\nSubject: Test Email\r\n\r\n")
      
      message.message
    end

    it 'caches the parsed message' do
      expect(Mail).to receive(:read_from_string).once.and_return(double('Mail'))
      
      message.message
      message.message # Should not call Mail.read_from_string again
    end
  end

  describe '#authentication_result' do
    it 'finds Authentication-Results header' do
      mock_mail = double('Mail')
      mock_header = double('Header', name: 'Authentication-Results', to_s: 'dkim=pass')
      allow(mock_mail).to receive(:header_fields).and_return([mock_header])
      allow(message).to receive(:message).and_return(mock_mail)
      
      expect(message.authentication_result).to eq(mock_header)
    end

    it 'returns nil when no Authentication-Results header' do
      mock_mail = double('Mail')
      allow(mock_mail).to receive(:header_fields).and_return([])
      allow(message).to receive(:message).and_return(mock_mail)
      
      expect(message.authentication_result).to be_nil
    end

    it 'caches the result' do
      mock_mail = double('Mail')
      mock_header = double('Header', name: 'Authentication-Results')
      allow(mock_mail).to receive(:header_fields).and_return([mock_header])
      allow(message).to receive(:message).and_return(mock_mail)
      
      message.authentication_result
      message.authentication_result # Should not search header_fields again
    end
  end

  describe '#has_fake_headers?' do
    it 'detects X-Antiabuse header' do
      mock_mail = double('Mail')
      mock_header = double('Header', name: 'X-Antiabuse')
      allow(mock_mail).to receive(:header_fields).and_return([mock_header])
      allow(message).to receive(:message).and_return(mock_mail)
      
      expect(message.has_fake_headers?).to be true
    end

    it 'returns false when no fake headers present' do
      mock_mail = double('Mail')
      allow(mock_mail).to receive(:header_fields).and_return([])
      allow(message).to receive(:message).and_return(mock_mail)
      
      expect(message.has_fake_headers?).to be false
    end

    it 'ignores other headers' do
      mock_mail = double('Mail')
      mock_header = double('Header', name: 'Subject')
      allow(mock_mail).to receive(:header_fields).and_return([mock_header])
      allow(message).to receive(:message).and_return(mock_mail)
      
      expect(message.has_fake_headers?).to be false
    end
  end
end 