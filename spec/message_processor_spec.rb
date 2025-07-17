# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MessageProcessor do
  let(:context) do
    {
      whitelisted_emails: ['whitelist@example.com'],
      whitelisted_domains: ['trusted.com'],
      list_domains: ['list.example.com'],
      list_domain_map: {'list.example.com' => 'Lists'},
      sender_map: {'sender@example.com' => 'Work'},
      list_folder: 'Lists'
    }
  end

  let(:processor) { MessageProcessor.new(context) }

  describe '#decide_for_new_message' do
    context 'when message is from whitelisted email' do
      let(:message) { build_message('whitelist@example.com', 'whitelist.com') }

      it 'returns keep action' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({action: :keep})
      end
    end

    context 'when message is from whitelisted domain' do
      let(:message) { build_message('someone@trusted.com', 'trusted.com') }

      it 'returns keep action' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({action: :keep})
      end
    end

    context 'when message is from list domain' do
      let(:message) { build_message('list@list.example.com', 'list.example.com') }

      it 'returns move action to list folder' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({action: :move, folder: 'Lists'})
      end
    end

    context 'when message is not whitelisted or list' do
      let(:message) { build_message('spam@spam.com', 'spam.com') }

      it 'returns junk action' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({action: :junk})
      end
    end
  end

  describe '#decide_for_filing' do
    context 'when sender is in sender map' do
      let(:message) { build_message('sender@example.com', 'example.com') }

      it 'returns move action to mapped folder' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({action: :move, folder: 'Work'})
      end
    end

    context 'when domain is in list domain map' do
      let(:message) { build_message('list@list.example.com', 'list.example.com') }

      it 'returns move action to list folder' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({action: :move, folder: 'Lists'})
      end
    end

    context 'when sender is not mapped' do
      let(:message) { build_message('unknown@example.com', 'example.com') }

      it 'returns keep action' do
        decision = processor.decide_for_filing(message)
        expect(decision).to eq({action: :keep})
      end
    end
  end

  describe '#decide_for_unjunking' do
    let(:message) { build_message('sender@example.com', 'example.com') }

    it 'uses filing logic' do
      decision = processor.decide_for_unjunking(message)
      expect(decision).to eq({action: :move, folder: 'Work'})
    end
  end

  describe 'DKIM validation' do
    let(:context) do
      {
        whitelisted_emails: [],
        whitelisted_domains: [],
        list_domains: ['example.com'],
        list_domain_map: {},
        sender_map: {},
        list_folder: 'Lists'
      }
    end

    context 'when message has valid DKIM' do
      let(:message) { build_message_with_headers('list@example.com', 'example.com', {'Authentication-Results' => 'dkim=pass'}) }

      it 'treats as valid list email' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({action: :move, folder: 'Lists'})
      end
    end

    context 'when message has invalid DKIM but domain is in list_domains' do
      let(:message) { build_message_with_headers('list@example.com', 'example.com', {'Authentication-Results' => 'dkim=fail'}) }

      it 'still treats as valid list email' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({action: :move, folder: 'Lists'})
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
        list_folder: 'Lists'
      }
    end

    context 'when message has fake headers' do
      let(:message) { build_message_with_headers('list@example.com', 'example.com', {'X-Antiabuse' => 'fake'}) }

      it 'treats as junk even if domain is in list_domains' do
        decision = processor.decide_for_new_message(message)
        expect(decision).to eq({action: :junk})
      end
    end
  end

  private

  def build_message(from_address, from_domain)
    double('message',
      from_address: from_address,
      from_domain: from_domain,
      message: double('mail', header_fields: [])
    )
  end

  def build_message_with_headers(from_address, from_domain, headers_hash)
    header_fields = headers_hash.map { |k, v| double('header', name: k, to_s: v) }
    double('message',
      from_address: from_address,
      from_domain: from_domain,
      message: double('mail', header_fields: header_fields)
    )
  end
end 