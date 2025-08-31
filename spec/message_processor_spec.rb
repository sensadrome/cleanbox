# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MessageProcessor do
  let(:context) do
    {
      whitelisted_emails: ['whitelist@example.com'],
      whitelisted_domains: ['trusted.com'],
      list_domains: ['list.example.com'],
      list_domain_map: { 'list.example.com' => 'Lists' },
      sender_map: { 'sender@example.com' => 'Work' },
      list_folder: 'Lists',
      blacklisted_emails: ['list@list.example.com'],  # User blacklisted (unsubscribe folder)
      junk_emails: ['spam@example.com', 'unwanted@trusted.com'],  # From junk folder
      retention_policy: :spammy
    }
  end

  let(:processor) { MessageProcessor.new(context) }

  describe '#decide_for_new_message' do
    context 'when message is from whitelisted email' do
      let(:message) { build_message('whitelist@example.com', 'whitelist.com') }

      it 'returns keep action' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :keep })
      end
    end

    context 'when message is from whitelisted domain' do
      let(:message) { build_message('someone@trusted.com', 'trusted.com') }

      it 'returns keep action' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :keep })
      end
    end

    context 'when message is from list domain' do
      let(:message) { build_message('newsletter@list.example.com', 'list.example.com') }

      it 'returns move action to list folder' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :move, folder: 'Lists' })
      end
    end

    context 'when message is from list domain but user blacklisted' do
      let(:message) { build_message('list@list.example.com', 'list.example.com') }

      it 'returns junk action (user blacklist always wins over list classification)' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :junk })
      end
    end

    context 'when message is from whitelisted domain but found in junk folder' do
      let(:message) { build_message('unwanted@trusted.com', 'trusted.com') }

      it 'returns keep action (whitelist protects against junk folder false positives)' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :keep })
      end
    end

    context 'when message is from junk folder but not whitelisted' do
      let(:message) { build_message('spam@example.com', 'example.com') }

      it 'returns junk action (junk folder provides fallback blacklisting)' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :junk })
      end
    end

    context 'when message is not whitelisted or list' do
      let(:message) { build_message('spam@spam.com', 'spam.com', valid_list_email: false) }

      it 'returns junk action' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :junk })
      end
    end
  end

  describe '#decide_for_filing' do
    context 'when sender is in sender map' do
      let(:message) { build_message('sender@example.com', 'example.com') }

      it 'returns move action to mapped folder' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :move, folder: 'Work' })
      end
    end

    context 'when domain is in list domain map' do
      let(:message) { build_message('list@list.example.com', 'list.example.com') }

      it 'returns move action to list folder' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :move, folder: 'Lists' })
      end
    end

    context 'when domain matches wildcard pattern in list domain map' do
      let(:context) do
        {
          whitelisted_emails: [],
          whitelisted_domains: [],
          list_domains: [],
          list_domain_map: { '*.channel4.com' => 'TV and Film' },
          sender_map: {},
          list_folder: 'Lists',
          retention_policy: :spammy
        }
      end

      let(:message) { build_message('newsletter@hi.channel4.com', 'hi.channel4.com') }

      it 'returns move action to mapped folder' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :move, folder: 'TV and Film' })
      end
    end

    context 'when domain does not match wildcard pattern' do
      let(:context) do
        {
          whitelisted_emails: [],
          whitelisted_domains: [],
          list_domains: [],
          list_domain_map: { '*.channel4.com' => 'TV and Film' },
          sender_map: {},
          list_folder: 'Lists',
          retention_policy: :spammy
        }
      end

      let(:message) { build_message('deep@sub.hi.channel4.com', 'sub.hi.channel4.com') }

      it 'does not match and returns keep action' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :keep })
      end
    end

    context 'when multiple wildcard patterns exist' do
      let(:context) do
        {
          whitelisted_emails: [],
          whitelisted_domains: [],
          list_domains: [],
          list_domain_map: { 
            '*.channel4.com' => 'TV and Film',
            '*.example.com' => 'Work',
            'api.*.com' => 'Development'
          },
          sender_map: {},
          list_folder: 'Lists',
          retention_policy: :spammy
        }
      end

      let(:message) { build_message('newsletter@hi.channel4.com', 'hi.channel4.com') }

      it 'matches the correct wildcard pattern' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :move, folder: 'TV and Film' })
      end
    end

    context 'when exact match takes precedence over wildcard' do
      let(:context) do
        {
          whitelisted_emails: [],
          whitelisted_domains: [],
          list_domains: [],
          list_domain_map: { 
            '*.channel4.com' => 'TV and Film',
            'hi.channel4.com' => 'Specific Channel4'
          },
          sender_map: {},
          list_folder: 'Lists',
          retention_policy: :spammy
        }
      end

      let(:message) { build_message('newsletter@hi.channel4.com', 'hi.channel4.com') }

      it 'uses exact match over wildcard' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :move, folder: 'Specific Channel4' })
      end
    end

    context 'when sender is not mapped' do
      let(:message) { build_message('unknown@example.com', 'example.com') }

      it 'returns keep action' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :keep })
      end
    end

    context 'when sender is blacklisted but has a folder mapping' do
      let(:message) { build_message('spam@example.com', 'example.com') }

      it 'still returns keep action (blacklist does not affect filing decisions)' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({ action: :keep })
      end
    end
  end

  describe '#decide_for_unjunking' do
    let(:message) { build_message('sender@example.com', 'example.com') }

    it 'uses filing logic' do
      decision = processor.decide_for_unjunking(message)
      expect(decision).to eq({ action: :move, folder: 'Work' })
    end
  end

  describe 'Retention Policy' do
    context "when set to 'spammy'" do
      let(:context) do
        {
          whitelisted_emails: [],
          whitelisted_domains: [],
          list_domains: [],
          list_domain_map: {},
          sender_map: {},
          list_folder: 'Lists',
          retention_policy: :spammy
        }
      end

      context 'with a valid DKIM message' do
        let(:message) do
          build_message_with_headers('unknown@example.com', 'example.com', { 'Authentication-Results' => 'dkim=pass' })
        end

        it 'treats as valid list email' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :move, folder: 'Lists' })
        end
      end

      context 'with an invalid DKIM message' do
        let(:message) do
          build_message_with_headers('unknown@example.com', 'example.com', { 'Authentication-Results' => 'dkim=fail' })
        end

        it 'junks the email' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :junk })
        end
      end

      context 'with a message from explicitly mapped domain' do
        let(:context) do
          {
            whitelisted_emails: [],
            whitelisted_domains: [],
            list_domain_map: { 'example.com' => 'Lists' },
            sender_map: {},
            list_folder: 'Lists',
            retention_policy: :spammy
          }
        end

        let(:message) do
          build_message_with_headers('list@example.com', 'example.com', { 'Authentication-Results' => 'dkim=fail' })
        end

        it 'treats as valid list email regardless of DKIM' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :move, folder: 'Lists' })
        end
      end
    end

    context "when set to 'paranoid'" do
      let(:context) do
        {
          whitelisted_emails: [],
          whitelisted_domains: [],
          list_domains: [],
          list_domain_map: {},
          sender_map: {},
          list_folder: 'Lists',
          retention_policy: :paranoid
        }
      end

      let(:message) { build_message('unknown@example.com', 'example.com', date_sent: DateTime.now - 1) }

      it 'junks unknown emails regardless of DKIM status' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :junk })
      end
    end

    context "when set to 'hold'" do
      let(:context) do
        {
          whitelisted_emails: [],
          whitelisted_domains: [],
          list_domain_map: {},
          sender_map: {},
          list_folder: 'Lists',
          retention_policy: :hold,
          hold_days: 7
        }
      end

      context 'with a recent message' do
        let(:message) { build_message('recent@example.com', 'example.com', date_sent: DateTime.now - 2) }

        it 'holds the email in inbox' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :keep })
        end
      end

      context 'with an old message' do
        let(:message) { build_message('old@example.com', 'example.com', date_sent: DateTime.now - 10) }

        it 'junks the email' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :junk })
        end
      end
    end

    context "when set to 'quarantine'" do
      let(:context) do
        {
          whitelisted_emails: ['trusted@example.com'],
          whitelisted_domains: ['trusted.com'],
          list_domains: ['list.example.com'],
          list_domain_map: { 
            '*.channel4.com' => 'TV and Film',
            'blog.com' => 'Blogs'
          },
          sender_map: { 'person@blog.com' => 'Blogs' },
          list_folder: 'Lists',
          retention_policy: :quarantine,
          quarantine_folder: 'Quarantine'
        }
      end

      context 'with unknown email' do
        let(:message) { build_message('unknown@example.com', 'example.com', date_sent: DateTime.now - 1) }

        it 'files unknown emails to quarantine folder' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :move, folder: 'Quarantine' })
        end
      end

      context 'with whitelisted email' do
        let(:message) { build_message('trusted@example.com', 'example.com') }

        it 'keeps whitelisted email in inbox (whitelist overrides quarantine)' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :keep })
        end
      end

      context 'with whitelisted domain' do
        let(:message) { build_message('someone@trusted.com', 'trusted.com') }

        it 'keeps email from whitelisted domain in inbox (whitelist overrides quarantine)' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :keep })
        end
      end

      context 'with known sender in sender_map' do
        let(:message) { build_message('person@blog.com', 'blog.com') }

        it 'moves email to mapped folder (sender_map overrides quarantine)' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :move, folder: 'Blogs' })
        end
      end

      context 'with known domain in list_domain_map' do
        let(:message) { build_message('newsletter@blog.com', 'blog.com') }

        it 'moves email to mapped folder (list_domain_map overrides quarantine)' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :move, folder: 'Blogs' })
        end
      end

      context 'with wildcard domain match' do
        let(:message) { build_message('newsletter@hi.channel4.com', 'hi.channel4.com') }

        it 'moves email to mapped folder (wildcard pattern overrides quarantine)' do
          decision = processor.decide_for_new_message(message)
          expect(decision).to eq({ action: :move, folder: 'TV and Film' })
        end
      end
    end
  end

  describe 'fake headers detection' do
    let(:context) do
      {
        whitelisted_emails: [],
        whitelisted_domains: [],
        list_domains: ['example.com'],
        list_domain_map: {},
        sender_map: {},
        list_folder: 'Lists',
        retention_policy: :spammy
      }
    end

    context 'when message has fake headers' do
      let(:message) { build_message_with_headers('list@example.com', 'example.com', { 'X-Antiabuse' => 'fake' }) }

      it 'treats as junk even if domain is in list_domains' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({ action: :junk })
      end
    end
  end



  private

  def build_message(from_address, from_domain, valid_list_email: true, date_sent: DateTime.now)
    # header_fields.detect { |f| f.name == 'Authentication-Results' }
    headers = valid_list_email ? list_email_headers : []
    double('message',
           from_address: from_address,
           from_domain: from_domain,
           date: date_sent,
           message: double('mail', header_fields: headers, date: date_sent))
  end

  def list_email_headers
    [
      OpenStruct.new(name: 'Authentication-Results', value: <<~RESULTS
        Authentication-Results: spf=pass (sender IP is 1.2.3.4)
        smtp.mailfrom=mail.example.com; dkim=pass (signature was verified)
        header.d=mg2.example.com;dmarc=pass action=none
        header.from=example.com;compauth=pass reason=100
      RESULTS
      )
    ]
  end

  def build_message_with_headers(from_address, from_domain, headers_hash, date_sent: DateTime.now)
    header_fields = headers_hash.map { |k, v| double('header', name: k, to_s: v) }
    double('message',
           from_address: from_address,
           from_domain: from_domain,
           date: date_sent,
           message: double('mail', header_fields: header_fields))
  end
end
