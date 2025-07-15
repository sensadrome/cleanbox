# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI::Validator do
  let(:options) do
    {
      host: 'imap.example.com',
      username: 'user@example.com',
      auth_type: nil,
      client_id: 'cid',
      client_secret: 'csecret',
      tenant_id: 'tid',
      password: 'pw'
    }
  end

  before do
    # Stub exit to raise error instead of exiting
    allow_any_instance_of(Object).to receive(:exit) { |_, code=1| raise SystemExit.new(code) }
    # Stub $stderr
    @stderr = StringIO.new
    @orig_stderr = $stderr
    $stderr = @stderr
  end

  after do
    $stderr = @orig_stderr
  end

  describe '.validate_required_options!' do
    context 'when host is missing' do
      it 'prints error and exits' do
        options.delete(:host)
        expect {
          begin
            described_class.validate_required_options!(options)
          rescue SystemExit
          end
        }.to change { @stderr.string }.to(match(/IMAP host is required/))
      end
    end

    context 'when username is missing' do
      it 'prints error and exits' do
        options.delete(:username)
        expect {
          begin
            described_class.validate_required_options!(options)
          rescue SystemExit
          end
        }.to change { @stderr.string }.to(match(/IMAP username is required/))
      end
    end

    context 'when auth_type is oauth2_microsoft and any oauth2 field is missing' do
      before do
        allow(Auth::AuthenticationManager).to receive(:determine_auth_type).and_return('oauth2_microsoft')
      end

      it 'prints error and exits if client_id is missing' do
        options.delete(:client_id)
        expect {
          begin
            described_class.validate_required_options!(options)
          rescue SystemExit
          end
        }.to change { @stderr.string }.to(match(/OAuth2 Microsoft requires client_id, client_secret, and tenant_id/))
      end

      it 'prints error and exits if client_secret is missing' do
        options.delete(:client_secret)
        expect {
          begin
            described_class.validate_required_options!(options)
          rescue SystemExit
          end
        }.to change { @stderr.string }.to(match(/OAuth2 Microsoft requires client_id, client_secret, and tenant_id/))
      end

      it 'prints error and exits if tenant_id is missing' do
        options.delete(:tenant_id)
        expect {
          begin
            described_class.validate_required_options!(options)
          rescue SystemExit
          end
        }.to change { @stderr.string }.to(match(/OAuth2 Microsoft requires client_id, client_secret, and tenant_id/))
      end
    end

    context 'when auth_type is password and password is missing' do
      before do
        allow(Auth::AuthenticationManager).to receive(:determine_auth_type).and_return('password')
      end

      it 'prints error and exits' do
        options.delete(:password)
        expect {
          begin
            described_class.validate_required_options!(options)
          rescue SystemExit
          end
        }.to change { @stderr.string }.to(match(/Password authentication requires password/))
      end
    end

    context 'when all required options are present' do
      before do
        allow(Auth::AuthenticationManager).to receive(:determine_auth_type).and_return('oauth2_microsoft')
      end

      it 'does not print error or exit' do
        expect {
          described_class.validate_required_options!(options)
        }.not_to raise_error
        expect(@stderr.string).to eq("")
      end
    end
  end
end 