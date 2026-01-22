# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/console'

RSpec.describe Cleanbox do
  let(:mock_imap) { double('IMAP') }
  let(:options) { { host: 'test.example.com' } }
  let(:cleanbox) { described_class.new(mock_imap, options) }

  before do
    # Mock IMAP connection behavior required by initialize
    allow(mock_imap).to receive(:list).and_return([
      double('folder', name: 'INBOX', attr: []),
      double('folder', name: 'Sent', attr: [:Sent]),
    ])
    allow(mock_imap).to receive(:status).and_return({
      'MESSAGES' => 10,
      'UNSEEN' => 2
    })
  end

  describe '#search' do
    it 'selects folder and searches' do
      expect(mock_imap).to receive(:select).with('INBOX')
      expect(mock_imap).to receive(:search).with(['UNSEEN']).and_return([1, 2])
      
      ids = cleanbox.search(['UNSEEN'])
      expect(ids).to eq([1, 2])
    end

    it 'uses current_folder by default' do
      # When selecting the folder
      expect(mock_imap).to receive(:select).with('Sent')
      cleanbox.select_folder('Sent')

      # When searching
      expect(mock_imap).to receive(:select).with('Sent')
      expect(mock_imap).to receive(:search).with(['UNSEEN']).and_return([1])
      
      cleanbox.search(['UNSEEN'])
    end

    it 'allows specifying folder' do
      expect(mock_imap).to receive(:select).with('Sent')
      expect(mock_imap).to receive(:search).with(['ALL']).and_return([3])
      
      ids = cleanbox.search(['ALL'], folder: 'Sent')
      expect(ids).to eq([3])
    end
  end

  describe '#get_messages' do
    let(:mock_envelope) { double('envelope', attr: { 'BODY[HEADER]' => 'Header: value' }) }

    it 'fetches messages by ID' do
      expect(mock_imap).to receive(:select).with('INBOX')
      expect(mock_imap).to receive(:fetch).with([1], 'BODY.PEEK[HEADER]').and_return([mock_envelope])
      
      messages = cleanbox.get_messages([1])
      expect(messages.length).to eq(1)
      expect(messages.first).to be_a(CleanboxMessage)
    end
    
    it 'returns empty array for empty ids' do
      expect(cleanbox.get_messages([])).to eq([])
    end
    it 'fetches full messages when requested' do
      expect(mock_imap).to receive(:select).with('INBOX')
      expect(mock_imap).to receive(:fetch).with([1], 'BODY.PEEK[]').and_return([mock_envelope])
      
      cleanbox.get_messages([1], full: true)
    end
  end

  describe '#find' do
     it 'searches and fetches' do
        expect(cleanbox).to receive(:search).with('UNSEEN', folder: 'INBOX').and_return([1])
        expect(cleanbox).to receive(:get_messages).with([1], folder: 'INBOX', full: false).and_return([double('msg')])
        
        cleanbox.find('UNSEEN')
     end
  end

  describe '#where' do
    it 'passes full option to find' do
      expect(cleanbox).to receive(:find).with(['UNSEEN', 'NOT', 'DELETED'], folder: 'INBOX', full: true)
      cleanbox.where(seen: false, deleted: false, full: true)
    end
    it 'translates boolean flags' do
      expect(cleanbox).to receive(:find).with(['UNSEEN', 'NOT', 'DELETED'], folder: 'INBOX', full: false)
      cleanbox.where(seen: false, deleted: false)
    end

    it 'translates string fields' do
      expect(cleanbox).to receive(:find).with(['FROM', 'amazon', 'SUBJECT', 'delivery'], folder: 'INBOX', full: false)
      cleanbox.where(from: 'amazon', subject: 'delivery')
    end

    it 'translates dates' do
      date = Date.new(2025, 1, 1)
      expect(cleanbox).to receive(:find).with(['SINCE', '01-Jan-2025'], folder: 'INBOX', full: false)
      cleanbox.where(since: date)
    end

    it 'translates text search' do
      expect(cleanbox).to receive(:find).with(['TEXT', 'hello world'], folder: 'INBOX', full: false)
      cleanbox.where(text: 'hello world')
    end

    it 'translates multiple criteria' do
      date = Date.new(2025, 1, 1)
      expected_query = ['FROM', 'amazon', 'UNSEEN', 'SINCE', '01-Jan-2025']
      expect(cleanbox).to receive(:find).with(expected_query, folder: 'INBOX', full: false)
      cleanbox.where(from: 'amazon', seen: false, since: date)
    end
  end

  describe 'flag management' do
    describe '#mark_seen' do
      it 'adds Seen flag' do
        expect(mock_imap).to receive(:select).with('INBOX')
        expect(mock_imap).to receive(:store).with([1, 2], '+FLAGS', [:Seen])
        cleanbox.mark_seen([1, 2])
      end
    end

    describe '#mark_unseen' do
      it 'removes Seen flag' do
        expect(mock_imap).to receive(:select).with('INBOX')
        expect(mock_imap).to receive(:store).with([1, 2], '-FLAGS', [:Seen])
        cleanbox.mark_unseen([1, 2])
      end
    end

    describe '#mark_deleted' do
      it 'adds Deleted flag' do
        expect(mock_imap).to receive(:select).with('INBOX')
        expect(mock_imap).to receive(:store).with([1], '+FLAGS', [:Deleted])
        cleanbox.mark_deleted([1])
      end
    end

    describe '#undelete' do
      it 'removes Deleted flag' do
        expect(mock_imap).to receive(:select).with('INBOX')
        expect(mock_imap).to receive(:store).with([1], '-FLAGS', [:Deleted])
        cleanbox.undelete([1])
      end
    end
  end

  describe '#summarize' do
    let(:mock_envelope) do
      double('envelope', attr: {
        'ENVELOPE' => double('struct', from: [double('addr', mailbox: 'sender', host: 'example.com')])
      })
    end

    before do
      allow(cleanbox).to receive(:folders).and_return(%w[INBOX])
      allow(mock_imap).to receive(:status).with('INBOX', %w[MESSAGES UNSEEN]).and_return({
        'MESSAGES' => 10,
        'UNSEEN' => 3
      })
    end

    it 'shows stats and groups unread messages' do
      expect(mock_imap).to receive(:select).with('INBOX')
      expect(mock_imap).to receive(:search).with(['UNSEEN']).and_return([1, 2, 3])
      expect(mock_imap).to receive(:fetch).with([1, 2, 3], 'ENVELOPE').and_return([mock_envelope] * 3)

      cleanbox.summarize
      output = captured_output.string
      expect(output).to include('Total messages: 10')
      expect(output).to include('Unseen messages: 3')
      expect(output).to include('sender@example.com')
    end

    it 'handles no unread messages' do
      allow(mock_imap).to receive(:status).with('INBOX', %w[MESSAGES UNSEEN]).and_return({
        'MESSAGES' => 10,
        'UNSEEN' => 0
      })
      
      cleanbox.summarize
      output = captured_output.string
      expect(output).to include('Total messages: 10')
      expect(output).to include('Unseen messages: 0')
      expect(mock_imap).not_to receive(:search)
    end
  end

  describe '#list_messages' do
    let(:mock_mail) { double('Mail', subject: 'Hello', date: Time.now, from: ['sender@example.com']) }
    let(:mock_envelope) { double('envelope', attr: { 'BODY[HEADER]' => 'header' }) }

    before do
      allow(cleanbox).to receive(:folders).and_return(%w[INBOX])
      # Mock the internal calls made by get_messages which is called by where
      allow(Mail).to receive(:read_from_string).and_return(mock_mail)
    end

    it 'lists messages in table format' do
      expect(mock_imap).to receive(:select).with('INBOX').at_least(:once)
      expect(mock_imap).to receive(:search).with(['UNSEEN']).and_return([1])
      expect(mock_imap).to receive(:fetch).with([1], 'BODY.PEEK[HEADER]').and_return([
         double('data', seqno: 1, attr: { 'BODY[HEADER]' => 'header' })
      ])
      
      cleanbox.list_messages(seen: false)
      
      output = captured_output.string
      expect(output).to include('Listing 1 of 1 messages')
      expect(output).to include('Hello') # subject
    end
  end

  describe '#show_messages' do
    let(:messages) do
      [
        CleanboxMessage.new(double('data', seqno: 10, attr: { 'BODY[HEADER]' => 'header' })),
        CleanboxMessage.new(double('data', seqno: 20, attr: { 'BODY[HEADER]' => 'header' }))
      ]
    end

    before do
      # Mock message internals
      messages.each do |m|
        allow(m).to receive(:from_address).and_return('sender@example.com')
        allow(m).to receive(:date).and_return(Time.now)
        allow(m).to receive(:message).and_return(double('mail', subject: 'Subject'))
      end
    end

    it 'renders a table of messages' do
      cleanbox.show_messages(messages)
      output = captured_output.string
      
      expect(output).to include('Listing 2 of 2 messages')
      expect(output).to include('10')
      expect(output).to include('20')
      expect(output).to include('sender@example.com')
    end
  end

  describe '#read_message' do
    let(:mock_mail) do 
      double('Mail', 
        subject: 'Hello', 
        date: Time.now,
        from: ['sender@example.com'],
        to: ['me@example.com'],
        text_part: double('part', 
          body: double('body', raw_source: 'Hello World'.dup),
          content_transfer_encoding: '7bit',
          charset: 'UTF-8'
        )
      )
    end
    let(:mock_envelope) { double('envelope', attr: { 'BODY[]' => 'raw' }) }

    before do
      allow(cleanbox).to receive(:folders).and_return(%w[INBOX])
      # Mock the internal calls made by get_messages which is called by read_message
      allow(Mail).to receive(:read_from_string).and_return(mock_mail)
    end

    it 'fetches and displays the message' do
      expect(mock_imap).to receive(:select).with('INBOX').at_least(:once)
      expect(mock_imap).to receive(:fetch).with([1], 'BODY.PEEK[]').and_return([
         double('data', seqno: 1, attr: { 'BODY[]' => 'raw' })
      ])
      
      cleanbox.read_message(1)
      output = captured_output.string
      
      expect(output).to include('Subject: Hello')
      expect(output).to include('Hello World')
    end

    it 'strips links by default' do
      mock_mail_with_links = double('Mail',
        subject: 'Test',
        date: Time.now,
        from: ['sender@example.com'],
        to: ['me@example.com'],
        text_part: double('part', 
          body: double('body', raw_source: 'Check out https://example.com/very/long/url and [this link](https://example.com)'.dup),
          content_transfer_encoding: '7bit',
          charset: 'UTF-8'
        )
      )
      
      allow(Mail).to receive(:read_from_string).and_return(mock_mail_with_links)
      expect(mock_imap).to receive(:select).with('INBOX').at_least(:once)
      expect(mock_imap).to receive(:fetch).with([1], 'BODY.PEEK[]').and_return([
         double('data', seqno: 1, attr: { 'BODY[]' => 'raw' })
      ])
      
      cleanbox.read_message(1)
      output = captured_output.string
      
      expect(output).not_to include('https://example.com/very/long/url')
      expect(output).to include('this link') # Markdown link text should remain
    end
  end
end

# Make helper accessible for testing
class Cleanbox
  public :folders
end

RSpec.describe CleanboxMessage do
  let(:mock_mail) { double('Mail', subject: 'Hello', date: Time.now) }
  let(:mock_attr) { { 'BODY[HEADER]' => 'raw header' } }
  let(:mock_data) { double('Net::IMAP::FetchData', seqno: 123, attr: mock_attr) }
  
  subject { described_class.new(mock_data) }
  
  before do
    allow(mock_data).to receive(:seqno).and_return(123)
    allow(Mail).to receive(:read_from_string).and_return(mock_mail)
    allow(subject).to receive(:from_address).and_return('sender@example.com')
  end

  describe '#summary' do
    it 'returns a summary string' do
      expect(subject.summary).to include('123')
      expect(subject.summary).to include('sender@example.com')
      expect(subject.summary).to include('Hello')
    end
  end
  
  describe '#inspect' do
    it 'returns inspection string with summary' do
      expect(subject.inspect).to include('CleanboxMessage')
      expect(subject.inspect).to include(subject.summary)
    end
  end
end

