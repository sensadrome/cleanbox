# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cleanbox do
  let(:mock_imap) { double('IMAP') }
  let(:options) do
    {
      host: 'test.example.com',
      username: 'test@example.com',
      whitelist_folders: %w[Family Work],
      list_folders: ['Newsletters'],
      whitelisted_domains: ['trusted.com'],

      list_domain_map: { 'newsletter.com' => 'Newsletters' },
      sent_folder: 'Sent',
      sent_since_months: 24,
      list_since_months: 12,
      valid_since_months: 12
    }
  end
  let(:cleanbox) { described_class.new(mock_imap, options) }

  before do
    # Mock the logger to prevent output during tests
    allow(cleanbox).to receive(:logger).and_return(double('logger', info: nil, debug: nil, warn: nil, error: nil))

    # Mock IMAP connection behavior
    allow(mock_imap).to receive(:select)
    allow(mock_imap).to receive(:search).and_return([])
    allow(mock_imap).to receive(:fetch).and_return([])
    allow(mock_imap).to receive(:expunge)
    allow(mock_imap).to receive(:list).and_return([
                                                    double('folder', name: 'INBOX', attr: []),
                                                    double('folder', name: 'Family', attr: []),
                                                    double('folder', name: 'Work', attr: []),
                                                    double('folder', name: 'Newsletters', attr: []),
                                                    double('folder', name: 'Sent', attr: [:Sent]),
                                                    double('folder', name: 'Junk', attr: [:Junk])
                                                  ])
    allow(mock_imap).to receive(:status).and_return({
                                                      'MESSAGES' => 10,
                                                      'UIDNEXT' => 11,
                                                      'UIDVALIDITY' => 12_345
                                                    })
  end

  describe '#initialize' do
    it 'initializes with imap connection and options' do
      expect(cleanbox.imap_connection).to eq(mock_imap)
      expect(cleanbox.options).to eq(options)
    end

    it 'sets up list_domain_map and sender_map' do
      expect(cleanbox.list_domain_map).to eq({ 'newsletter.com' => 'Newsletters' })
      expect(cleanbox.sender_map).to eq({})
    end
  end

  describe '#clean!' do
    let(:mock_message) { double('CleanboxMessage') }
    let(:mock_processor) { double('processor') }

    before do
      allow(cleanbox).to receive(:new_messages).and_return([mock_message])
      allow(cleanbox).to receive(:clear_deleted_messages!)
      allow(cleanbox).to receive(:message_processing_context).and_return({})
      allow(MessageProcessor).to receive(:new).and_return(mock_processor)
      allow(cleanbox).to receive(:execute_decision)
      allow(mock_processor).to receive(:decide_for_new_message).and_return({ action: :keep })
    end

    it 'processes new messages and clears deleted messages' do
      expect(cleanbox).to receive(:clear_deleted_messages!)

      cleanbox.clean!
    end
  end

  describe '#build_whitelist!' do
    let(:mock_folder_checker) { double('CleanboxFolderChecker') }

    before do
      allow(CleanboxFolderChecker).to receive(:new).and_return(mock_folder_checker)
      allow(mock_folder_checker).to receive(:email_addresses).and_return(['family@example.com', 'work@trusted.com'])
    end

    it 'builds whitelist from whitelist folders and sent emails' do
      expect(cleanbox.logger).to receive(:info).with('Building White List....')

      cleanbox.send(:build_whitelist!)

      expect(cleanbox.whitelisted_emails).to include('family@example.com', 'work@trusted.com')
    end

    it 'creates CleanboxFolderChecker instances for each whitelist folder' do
      cleanbox.send(:build_whitelist!)

      expect(CleanboxFolderChecker).to have_received(:new).with(
        mock_imap,
        hash_including(folder: 'Family', logger: cleanbox.logger)
      )
      expect(CleanboxFolderChecker).to have_received(:new).with(
        mock_imap,
        hash_including(folder: 'Work', logger: cleanbox.logger)
      )
    end

    it 'creates CleanboxFolderChecker for sent folder with correct options' do
      cleanbox.send(:build_whitelist!)

      expect(CleanboxFolderChecker).to have_received(:new).with(
        mock_imap,
        hash_including(
          folder: 'Sent',
          logger: cleanbox.logger,
          address: :to,
          since: anything
        )
      )
    end
  end



  describe '#build_blacklist!' do
    let(:mock_folder_checker) { double('CleanboxFolderChecker') }

    before do
      allow(CleanboxFolderChecker).to receive(:new).and_return(mock_folder_checker)
      allow(mock_folder_checker).to receive(:email_addresses).and_return(['spam@example.com', 'unwanted@newsletter.com'])
    end

    it 'builds blacklist from unsubscribe folder and junk folder' do
      expect(cleanbox.logger).to receive(:info).with('Building Blacklist....')

      cleanbox.send(:build_blacklist!)

      expect(cleanbox.blacklisted_emails).to eq([])  # No unsubscribe folder configured
      expect(cleanbox.junk_emails).to include('spam@example.com', 'unwanted@newsletter.com')
    end

    it 'creates CleanboxFolderChecker for junk folder' do
      cleanbox.send(:build_blacklist!)

      expect(CleanboxFolderChecker).to have_received(:new).with(
        mock_imap,
        hash_including(
          folder: 'Junk',
          logger: cleanbox.logger
        )
      )
    end
  end

  # Removed blacklist_folders tests - method no longer exists

  describe '#new_messages' do
    let(:mock_envelope) { double('envelope', attr: { 'BODY[HEADER]' => 'test header' }) }

    before do
      allow(cleanbox).to receive(:new_message_ids).and_return([1, 2])
      allow(mock_imap).to receive(:fetch).and_return([mock_envelope])
    end

    it 'fetches and creates CleanboxMessage instances' do
      expect(mock_imap).to receive(:fetch).with([1, 2], 'BODY.PEEK[HEADER]')

      messages = cleanbox.send(:new_messages)

      expect(messages.size).to eq(1)
      expect(messages.first).to be_a(CleanboxMessage)
    end

    it 'returns empty array when no new message ids' do
      allow(cleanbox).to receive(:new_message_ids).and_return([])

      expect(cleanbox.send(:new_messages)).to eq([])
    end
  end

  describe '#new_message_ids' do
    it 'searches for unseen, non-deleted messages in INBOX' do
      expect(mock_imap).to receive(:select).with('INBOX')
      expect(mock_imap).to receive(:search).with(%w[UNSEEN NOT DELETED])

      cleanbox.send(:new_message_ids)
    end

    it 'caches the result' do
      allow(mock_imap).to receive(:search).and_return([1, 2, 3])

      first_call = cleanbox.send(:new_message_ids)
      second_call = cleanbox.send(:new_message_ids)

      expect(first_call).to eq(second_call)
      expect(mock_imap).to have_received(:search).once
    end
  end

  describe '#message_processing_context' do
    before do
      allow(cleanbox).to receive(:whitelisted_emails).and_return(['family@example.com'])
      allow(cleanbox).to receive(:whitelisted_domains).and_return(['trusted.com'])

      allow(cleanbox).to receive(:list_domain_map).and_return({ 'newsletter.com' => 'Newsletters' })
      allow(cleanbox).to receive(:sender_map).and_return({ 'sender@example.com' => 'Work' })
      allow(cleanbox).to receive(:list_folder).and_return('Lists')
      allow(cleanbox).to receive(:unjunking?).and_return(false)
      allow(cleanbox).to receive(:blacklisted_emails).and_return([])
      allow(cleanbox).to receive(:junk_emails).and_return([])
    end

    it 'includes blacklisted emails and junk emails in the context' do
      context = cleanbox.send(:message_processing_context)
      
      expect(context[:blacklisted_emails]).to eq([])  # No unsubscribe folder configured
      expect(context[:junk_emails]).to eq([])  # Not built yet
    end

    it 'includes all required context keys' do
      context = cleanbox.send(:message_processing_context)
      
      expect(context).to include(
        :whitelisted_emails,
        :whitelisted_domains,
        :list_domain_map,
        :sender_map,
        :list_folder,
        :unjunking,
        :blacklisted_emails,
        :junk_emails
      )
    end
  end

  describe '#file_messages!' do
    let(:mock_processor) { double('processor') }

    before do
      allow(cleanbox).to receive(:all_messages).and_return([])
      allow(cleanbox).to receive(:clear_deleted_messages!)
      allow(cleanbox).to receive(:message_processing_context).and_return({})
      allow(MessageProcessor).to receive(:new).and_return(mock_processor)
      allow(cleanbox).to receive(:execute_decision)
      allow(mock_processor).to receive(:decide_for_filing).and_return({ action: :keep })
    end

    it 'processes all messages with filing logic' do
      expect(cleanbox).to receive(:clear_deleted_messages!)

      cleanbox.file_messages!
    end
  end

  describe '#unjunk!' do
    let(:mock_processor) { double('processor') }

    before do
      allow(cleanbox).to receive(:junk_messages).and_return([])
      allow(cleanbox).to receive(:clear_deleted_messages!)
      allow(cleanbox).to receive(:message_processing_context).and_return({})
      allow(cleanbox).to receive(:unjunk_folders).and_return(['CleanFolder'])
      allow(MessageProcessor).to receive(:new).and_return(mock_processor)
      allow(cleanbox).to receive(:execute_decision)
      allow(mock_processor).to receive(:decide_for_filing).and_return({ action: :keep })
    end

    it 'processes junk messages with filing logic' do
      expect(cleanbox).to receive(:clear_deleted_messages!)

      cleanbox.unjunk!
    end
  end

  describe '#show_lists!' do
    before do
      cleanbox.list_domain_map = {
        'newsletter.com' => 'Newsletters',
        'updates.com' => 'Updates'
      }
    end

    it 'shows domain mappings' do
      cleanbox.show_lists!
      expect(captured_output.string).to include("'newsletter.com' => 'Newsletters'")
    end
  end

  describe '#show_folders!' do
    let(:mock_folder) { double('folder', to_s: 'TestFolder (Total: 10, 2 new)') }

    before do
      allow(cleanbox).to receive(:cleanbox_folders).and_return([mock_folder])
    end

    it 'shows all cleanbox folders' do
      cleanbox.show_folders!
      expect(captured_output.string).to include("TestFolder (Total: 10, 2 new)")
    end
  end

  describe '#clear_deleted_messages!' do
    context 'when pretending' do
      before do
        allow(cleanbox).to receive(:pretending?).and_return(true)
      end

      it 'does not expunge messages' do
        expect(mock_imap).not_to receive(:expunge)

        cleanbox.send(:clear_deleted_messages!)
      end
    end

    context 'when not pretending' do
      before do
        allow(cleanbox).to receive(:pretending?).and_return(false)
      end

      it 'expunges messages from current folder' do
        expect(mock_imap).to receive(:expunge)

        cleanbox.send(:clear_deleted_messages!)
      end

      it 'selects specified folder before expunging' do
        expect(mock_imap).to receive(:select).with('TestFolder')
        expect(mock_imap).to receive(:expunge)

        cleanbox.send(:clear_deleted_messages!, 'TestFolder')
      end
    end
  end

  describe '#build_sender_map!' do
    let(:mock_folder_checker) { double('CleanboxFolderChecker') }

    before do
      allow(CleanboxFolderChecker).to receive(:new).and_return(mock_folder_checker)
      allow(mock_folder_checker).to receive(:email_addresses).and_return(['sender@example.com'])
      allow(cleanbox).to receive(:folders_to_file).and_return(%w[Family Work])
    end

    it 'builds sender map from folders to file' do
      expect(cleanbox.logger).to receive(:info).with('Building sender maps....')
      expect(cleanbox.logger).to receive(:debug).with('  adding addresses from Family')
      expect(cleanbox.logger).to receive(:debug).with('  adding addresses from Work')

      cleanbox.send(:build_sender_map!)

      expect(cleanbox.sender_map['sender@example.com']).to eq('Family')
    end
  end

  describe '#build_clean_sender_map!' do
    let(:mock_folder_checker) { double('CleanboxFolderChecker') }

    before do
      allow(CleanboxFolderChecker).to receive(:new).and_return(mock_folder_checker)
      allow(mock_folder_checker).to receive(:email_addresses).and_return(['clean@example.com'])
      allow(cleanbox).to receive(:unjunk_folders).and_return(['CleanFolder'])
    end

    it 'builds sender map from unjunk folders' do
      expect(cleanbox.logger).to receive(:info).with('Building sender maps for folder CleanFolder')

      cleanbox.send(:build_clean_sender_map!)

      expect(cleanbox.sender_map['clean@example.com']).to eq('CleanFolder')
    end
  end

  describe '#all_messages' do
    let(:mock_envelope) { double('envelope', attr: { 'BODY[HEADER]' => 'test header' }) }

    before do
      allow(cleanbox).to receive(:all_message_ids).and_return([1, 2, 3])
      allow(mock_imap).to receive(:fetch).and_return([mock_envelope])
    end

    it 'fetches messages in slices and creates CleanboxMessage instances' do
      expect(mock_imap).to receive(:fetch).with([1, 2, 3], 'BODY.PEEK[HEADER]')

      messages = cleanbox.send(:all_messages)

      expect(messages.size).to eq(1)
      expect(messages.first).to be_a(CleanboxMessage)
    end
  end

  describe '#all_message_ids' do
    before do
      allow(cleanbox).to receive(:date_search).and_return(%w[SINCE 01-Jan-2023])
    end

    it 'searches for non-deleted messages with date filter' do
      expect(mock_imap).to receive(:select).with('INBOX')
      expect(mock_imap).to receive(:search).with(%w[NOT DELETED SINCE 01-Jan-2023 SEEN])

      cleanbox.send(:all_message_ids)
    end

    context 'when file_unread is false' do
      before do
        allow(cleanbox).to receive(:options).and_return(options.merge(file_unread: false))
      end

      it 'adds SEEN to search terms' do
        expect(mock_imap).to receive(:search).with(%w[NOT DELETED SINCE 01-Jan-2023 SEEN])

        cleanbox.send(:all_message_ids)
      end
    end
  end

  describe '#junk_messages' do
    let(:mock_envelope) { double('envelope', attr: { 'BODY[HEADER]' => 'test header' }) }

    before do
      allow(cleanbox).to receive(:junk_message_ids).and_return([1, 2])
      allow(mock_imap).to receive(:fetch).and_return([mock_envelope])
    end

    it 'fetches junk messages and creates CleanboxMessage instances' do
      expect(mock_imap).to receive(:fetch).with([1, 2], 'BODY.PEEK[HEADER]')

      messages = cleanbox.send(:junk_messages)

      expect(messages.size).to eq(1)
      expect(messages.first).to be_a(CleanboxMessage)
    end
  end

  describe '#junk_message_ids' do
    before do
      allow(cleanbox).to receive(:imap_junk_folder).and_return('Junk')
      allow(cleanbox).to receive(:date_search).and_return(%w[SINCE 01-Jan-2023])
    end

    it 'searches for non-deleted messages in junk folder' do
      expect(mock_imap).to receive(:select).with('Junk')
      expect(mock_imap).to receive(:search).with(%w[NOT DELETED SINCE 01-Jan-2023])

      cleanbox.send(:junk_message_ids)
    end
  end

  describe '#imap_junk_folder' do
    it 'finds folder with Junk attribute' do
      expect(cleanbox.send(:imap_junk_folder)).to eq('Junk')
    end

    it 'returns nil when no junk folder found' do
      allow(mock_imap).to receive(:list).and_return([
                                                      double('folder', name: 'INBOX', attr: [])
                                                    ])

      expect(cleanbox.send(:imap_junk_folder)).to be_nil
    end
  end

  describe '#imap_sent_folder' do
    it 'finds folder with Sent attribute' do
      expect(cleanbox.send(:imap_sent_folder)).to eq('Sent')
    end

    it 'returns nil when no sent folder found' do
      allow(mock_imap).to receive(:list).and_return([
                                                      double('folder', name: 'INBOX', attr: [])
                                                    ])

      expect(cleanbox.send(:imap_sent_folder)).to be_nil
    end
  end

  describe 'configuration methods' do
    describe '#list_folder' do
      it 'returns configured list folder or default' do
        expect(cleanbox.list_folder).to eq('Lists')
      end

      it 'returns custom list folder from options' do
        allow(cleanbox).to receive(:options).and_return(options.merge(list_folder: 'CustomLists'))
        expect(cleanbox.list_folder).to eq('CustomLists')
      end
    end

    describe '#junk_folder' do
      it 'returns configured junk folder or default' do
        expect(cleanbox.junk_folder).to eq('Junk')
      end

      it 'returns custom junk folder from options' do
        allow(cleanbox).to receive(:options).and_return(options.merge(junk_folder: 'CustomJunk'))
        expect(cleanbox.junk_folder).to eq('CustomJunk')
      end
    end

    describe '#whitelisted_domains' do
      it 'returns whitelisted domains from options' do
        expect(cleanbox.whitelisted_domains).to eq(['trusted.com'])
      end
    end

    describe '#pretending?' do
      it 'returns pretend status from options' do
        expect(cleanbox.pretending?).to be false
      end

      it 'returns true when pretend is set' do
        allow(cleanbox).to receive(:options).and_return(options.merge(pretend: true))
        expect(cleanbox.pretending?).to be true
      end
    end

    describe '#unjunking?' do
      it 'returns unjunk status from options' do
        expect(cleanbox.unjunking?).to be false
      end

      it 'returns true when unjunk is set' do
        allow(cleanbox).to receive(:options).and_return(options.merge(unjunk: true))
        expect(cleanbox.unjunking?).to be true
      end
    end
  end

  describe 'date calculation methods' do
    describe '#sent_since_date' do
      it 'calculates date based on sent_since_months' do
        expected_date = (Date.today << 24).strftime('%d-%b-%Y')
        expect(cleanbox.send(:sent_since_date)).to eq(expected_date)
      end
    end

    describe '#list_since_date' do
      it 'calculates date based on list_since_months' do
        expected_date = (Date.today << 12).strftime('%d-%b-%Y')
        expect(cleanbox.send(:list_since_date)).to eq(expected_date)
      end
    end

    describe '#valid_from_date' do
      context 'when valid_from is set' do
        before do
          allow(cleanbox).to receive(:options).and_return(options.merge(valid_from: '2023-01-01'))
        end

        it 'parses the valid_from date' do
          expect(cleanbox.send(:valid_from_date)).to eq(Date.parse('2023-01-01'))
        end
      end

      context 'when valid_from is not set' do
        it 'calculates date based on valid_since_months' do
          expected_date = Date.today << 12
          expect(cleanbox.send(:valid_from_date)).to eq(expected_date)
        end
      end
    end
  end
end
