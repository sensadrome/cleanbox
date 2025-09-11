# frozen_string_literal: true

require 'spec_helper'
require_relative '../helpers/imap_fixture_helper'
require_relative '../test_imap_service'

RSpec.describe 'Cleanbox Message Commands - End to End' do
  include ImapFixtureHelper

  def mock_imap_response(status, text)
    OpenStruct.new(name: status, data: OpenStruct.new(text: text))
  end

  let(:test_imap) { mock_imap_with_fixture('message_commands_e2e') }
  let(:blacklist_policy) { :permissive }
  let(:cleanbox) { Cleanbox.new(test_imap, options) }
  let(:options) do
    {
      whitelist_folders: %w[Family Work],
      list_folders: %w[Newsletters],
      valid_from: '01-Jan-2024',
      cache: false,
      junk_folder: 'Junk',
      blacklist_folder: 'Blacklist',
      blacklist_policy: blacklist_policy
    }
  end

  def messages_in_folder(folder_name)
    test_imap.get_folder_contents(folder_name)
  end

  before do
    # Pre-authenticate the test IMAP service
    test_imap.authenticate('oauth2', 'test@example.com', 'token')

    # Spy on IMAP methods to track calls for all tests
    allow(test_imap).to receive(:copy).and_call_original
    allow(test_imap).to receive(:store).and_call_original
    allow(test_imap).to receive(:expunge).and_call_original
  end

  describe 'file_messages!' do
    it 'moves messages out of INBOX' do
      expect { cleanbox.file_messages! }.to change { messages_in_folder('INBOX').length }.by(-6)
    end

    it 'moves family messages to Family folder' do
      expect { cleanbox.file_messages! }.to change { messages_in_folder('Family').length }.by(2)
    end

    it 'moves work messages to Work folder' do
      expect { cleanbox.file_messages! }.to change { messages_in_folder('Work').length }.by(2)
    end

    it 'moves newsletter messages to Newsletters folder' do
      expect { cleanbox.file_messages! }.to change { messages_in_folder('Newsletters').length }.by(2)
    end

    it 'keeps unread messages in INBOX' do
      cleanbox.file_messages!
      
      inbox_senders = messages_in_folder('INBOX').map { |m| m['sender'] }
      expect(inbox_senders).to include('mom@family.com')         # Unread, should stay in INBOX
      expect(inbox_senders).to include('newsletter@arstechnica.com') # Unread, should stay in INBOX
      expect(inbox_senders).to include('spam@fakebank.com')      # Unread, should stay in INBOX
      expect(inbox_senders).to include('recentlyjunked@spam.com') # Unread, should stay in INBOX
    end

    it 'moves read messages from INBOX to appropriate folders' do
      cleanbox.file_messages!
      
      inbox_senders = messages_in_folder('INBOX').map { |m| m['sender'] }
      expect(inbox_senders).not_to include('sister@family.com')  # Should be moved to Family
      expect(inbox_senders).not_to include('boss@work.com')      # Should be moved to Work
      expect(inbox_senders).not_to include('colleague@work.com') # Should be moved to Work
      expect(inbox_senders).not_to include('newsletter@techcrunch.com') # Should be moved to Newsletters
      expect(inbox_senders).not_to include('newsletter@wired.com')      # Should be moved to Newsletters
    end

    it 'calls IMAP methods' do
      cleanbox.file_messages!
      
      expect(test_imap).to have_received(:copy).at_least(1).times
      expect(test_imap).to have_received(:store).at_least(1).times
      expect(test_imap).to have_received(:expunge).at_least(1).times
    end

    context 'when blacklist_policy is set to hardcore' do
      let(:blacklist_policy) { :hardcore }

      it 'moves messages out of INBOX' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('INBOX').length }.by(-7)
      end

      it 'moves blacklisted messages to Junk folder' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('Junk').length }.by(1)
      end

      it 'moves family messages to Family folder' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('Family').length }.by(2)
      end

      it 'moves work messages to Work folder' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('Work').length }.by(2)
      end

      it 'moves newsletter messages to Newsletters folder' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('Newsletters').length }.by(2)
      end

      it 'calls IMAP methods' do
        cleanbox.file_messages!
        
        expect(test_imap).to have_received(:copy).at_least(1).times
        expect(test_imap).to have_received(:store).at_least(1).times
        expect(test_imap).to have_received(:expunge).at_least(1).times
      end
    end

    context 'when blacklist_policy is permissive' do
      it 'moves messages out of INBOX' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('INBOX').length }.by(-6)
      end

      it 'keeps blacklisted messages in INBOX' do
        cleanbox.file_messages!
        
        inbox_senders = messages_in_folder('INBOX').map { |m| m['sender'] }
        expect(inbox_senders).to include('spam@fakebank.com')
        expect(inbox_senders).to include('phishing@scam.com')
        expect(inbox_senders).to include('unknown@example.com')
      end

      it 'does not move blacklisted messages to Junk' do
        expect { cleanbox.file_messages! }.not_to change { messages_in_folder('Junk').length }
      end

      it 'moves family messages to Family folder' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('Family').length }.by(2)
      end

      it 'moves work messages to Work folder' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('Work').length }.by(2)
      end

      it 'moves newsletter messages to Newsletters folder' do
        expect { cleanbox.file_messages! }.to change { messages_in_folder('Newsletters').length }.by(2)
      end

      it 'calls IMAP methods' do
        cleanbox.file_messages!
        
        expect(test_imap).to have_received(:copy).at_least(1).times
        expect(test_imap).to have_received(:store).at_least(1).times
        expect(test_imap).to have_received(:expunge).at_least(1).times
      end
    end
  end

  describe 'unjunk!' do
    it 'moves legitimate messages out of Junk folder' do
      expect { cleanbox.unjunk! }.to change { messages_in_folder('Junk').length }.by(-2)
    end

    it 'moves family messages from Junk to Family folder' do
      expect { cleanbox.unjunk! }.to change { messages_in_folder('Family').length }.by(1)
    end

    it 'moves work messages from Junk to Work folder' do
      expect { cleanbox.unjunk! }.to change { messages_in_folder('Work').length }.by(1)
    end

    it 'moves legitimate messages out of Junk folder' do
      expect { cleanbox.unjunk! }.to change { messages_in_folder('Junk').length }.by(-2)
    end

    it 'moves specific senders from Junk to appropriate folders' do
      cleanbox.unjunk!
      
      junk_senders = messages_in_folder('Junk').map { |m| m['sender'] }
      expect(junk_senders).not_to include('sister@family.com')  # Should be moved to Family
      expect(junk_senders).not_to include('boss@work.com')      # Should be moved to Work
    end

    it 'keeps spam messages in Junk folder' do
      cleanbox.unjunk!
      
      junk_senders = messages_in_folder('Junk').map { |m| m['sender'] }
      expect(junk_senders).to include('spam@fakebank.com')      # Should stay in Junk
      expect(junk_senders).to include('phishing@scam.com')      # Should stay in Junk
    end

    it 'calls IMAP methods' do
      cleanbox.unjunk!
      
      expect(test_imap).to have_received(:copy).at_least(1).times
      expect(test_imap).to have_received(:store).at_least(1).times
      expect(test_imap).to have_received(:expunge).at_least(1).times
    end
  end
end
