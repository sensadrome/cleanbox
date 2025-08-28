# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Microsoft365UserToken do
  let(:logger) { double('Logger') }
  let(:token) { described_class.new(logger: logger) }
  let(:default_redirect_uri) { 'urn:ietf:wg:oauth:2.0:oob' }
  before do
    allow(logger).to receive(:debug)
    allow(logger).to receive(:error)
  end

  describe '#initialize' do
    it 'uses default values when no parameters provided' do
      token = described_class.new
      expect(token.client_id).to eq('b3fc8598-3357-4f5d-ac0a-969016f6bb24')
      expect(token.redirect_uri).to eq(default_redirect_uri)
      expect(token.scope).to eq('https://outlook.office365.com/IMAP.AccessAsUser.All offline_access openid')
    end

    it 'allows custom values to be provided' do
      custom_token = described_class.new(
        client_id: 'custom_client_id',
        redirect_uri: 'custom_redirect_uri',
        scope: 'custom_scope',
        logger: logger
      )

      expect(custom_token.client_id).to eq('custom_client_id')
      expect(custom_token.redirect_uri).to eq('custom_redirect_uri')
      expect(custom_token.scope).to eq('custom_scope')
    end
  end

  describe '#authorization_url' do
    it 'generates correct authorization URL with default state' do
      url = token.authorization_url

      expect(url).to include('https://login.microsoftonline.com/common/oauth2/v2.0/authorize')
      expect(url).to include('client_id=b3fc8598-3357-4f5d-ac0a-969016f6bb24')
      expect(url).to include('response_type=code')
      expect(url).to include('redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob')
      expect(url).to include('scope=https%3A%2F%2Foutlook.office365.com%2FIMAP.AccessAsUser.All+offline_access+openid')
      expect(url).to include('state=')
    end

    it 'generates authorization URL with custom state' do
      url = token.authorization_url(state: 'custom_state_123')

      expect(url).to include('state=custom_state_123')
    end

    it 'generates different state values for different calls' do
      url1 = token.authorization_url
      url2 = token.authorization_url

      state1 = URI.parse(url1).query.split('&').find { |p| p.start_with?('state=') }
      state2 = URI.parse(url2).query.split('&').find { |p| p.start_with?('state=') }

      expect(state1).not_to eq(state2)
    end
  end

  describe '#exchange_code_for_tokens' do
    let(:mock_response) { double('HTTPResponse') }
    let(:mock_http) { double('Net::HTTP') }
    let(:mock_request) { double('HTTPRequest') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:request).and_return(mock_response)
      allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:body=)
      allow(mock_request).to receive(:[]=)
      allow(mock_response).to receive(:code).and_return('200')
      allow(mock_response).to receive(:read_body).and_return(successful_token_response)
    end

    let(:successful_token_response) do
      {
        access_token: 'test_access_token',
        refresh_token: 'test_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer'
      }.to_json
    end

    it 'successfully exchanges authorization code for tokens' do
      result = token.exchange_code_for_tokens('test_auth_code')

      expect(result).to be true
      expect(token.access_token).to eq('test_access_token')
      expect(token.refresh_token).to eq('test_refresh_token')
      expect(token.expires_at).to be_within(5).of(Time.now + 3600)
    end

    it 'sends correct parameters in token exchange request' do
      expect(mock_request).to receive(:body=).with(
        'client_id=b3fc8598-3357-4f5d-ac0a-969016f6bb24&code=test_auth_code&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&grant_type=authorization_code'
      )

      token.exchange_code_for_tokens('test_auth_code')
    end

    context 'when token exchange fails' do
      before do
        allow(mock_response).to receive(:code).and_return('400')
        allow(mock_response).to receive(:read_body).and_return('{"error": "invalid_grant"}')
      end

      it 'raises an error with status code' do
        expect { token.exchange_code_for_tokens('invalid_code') }.to raise_error('Token exchange failed: 400')
      end
    end

    context 'when response is invalid JSON' do
      before do
        allow(mock_response).to receive(:read_body).and_return('invalid json')
      end

      it 'raises an error for invalid response' do
        expect { token.exchange_code_for_tokens('test_code') }.to raise_error(/Invalid token response/)
      end
    end
  end

  describe '#refresh_access_token' do
    let(:mock_response) { double('HTTPResponse') }
    let(:mock_http) { double('Net::HTTP') }
    let(:mock_request) { double('HTTPRequest') }

    before do
      token.instance_variable_set(:@refresh_token, 'test_refresh_token')
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:request).and_return(mock_response)
      allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:body=)
      allow(mock_request).to receive(:[]=)
      allow(mock_response).to receive(:code).and_return('200')
      allow(mock_response).to receive(:read_body).and_return(successful_refresh_response)
    end

    let(:successful_refresh_response) do
      {
        access_token: 'new_access_token',
        refresh_token: 'new_refresh_token',
        expires_in: 3600,
        token_type: 'Bearer'
      }.to_json
    end

    it 'successfully refreshes access token' do
      result = token.refresh_access_token

      expect(result).to be true
      expect(token.access_token).to eq('new_access_token')
      expect(token.refresh_token).to eq('new_refresh_token')
    end

    it 'sends correct parameters in refresh request' do
      expect(mock_request).to receive(:body=).with(
        'client_id=b3fc8598-3357-4f5d-ac0a-969016f6bb24&refresh_token=test_refresh_token&grant_type=refresh_token'
      )

      token.refresh_access_token
    end

    it 'returns false when no refresh token is available' do
      token.instance_variable_set(:@refresh_token, nil)
      expect(token.refresh_access_token).to be false
    end

    context 'when refresh fails' do
      before do
        allow(mock_response).to receive(:code).and_return('400')
        allow(mock_response).to receive(:read_body).and_return('{"error": "invalid_grant"}')
      end

      it 'raises an error with status code' do
        expect { token.refresh_access_token }.to raise_error('Token refresh failed: 400')
      end
    end
  end

  describe '#token' do
    it 'returns access token when valid' do
      token.instance_variable_set(:@access_token, 'test_token')
      token.instance_variable_set(:@expires_at, Time.now + 3600)

      expect(token.token).to eq('test_token')
    end

    it 'returns nil when token is expired' do
      token.instance_variable_set(:@access_token, 'test_token')
      token.instance_variable_set(:@expires_at, Time.now - 3600)

      expect(token.token).to be_nil
    end

    it 'attempts to refresh token when expired and refresh token available' do
      token.instance_variable_set(:@access_token, 'old_token')
      token.instance_variable_set(:@expires_at, Time.now - 3600)
      token.instance_variable_set(:@refresh_token, 'refresh_token')

      allow(token).to receive(:refresh_access_token).and_return(true)
      allow(token).to receive(:access_token).and_return('new_token')

      # Mock the token method to return the new token after refresh
      allow(token).to receive(:token).and_call_original
      allow(token).to receive(:token).and_return('new_token')

      result = token.token
      expect(result).to eq('new_token')
    end

    it 'returns nil when no tokens are available' do
      expect(token.token).to be_nil
    end
  end

  describe '#token_expired?' do
    it 'returns true when no expiration time is set' do
      expect(token.token_expired?).to be true
    end

    it 'returns true when token is expired' do
      token.instance_variable_set(:@expires_at, Time.now - 3600)
      expect(token.token_expired?).to be true
    end

    it 'returns false when token is not expired' do
      token.instance_variable_set(:@expires_at, Time.now + 3600)
      expect(token.token_expired?).to be false
    end
  end

  describe '#has_valid_tokens?' do
    it 'returns true when all tokens are valid' do
      token.instance_variable_set(:@access_token, 'test_token')
      token.instance_variable_set(:@refresh_token, 'refresh_token')
      token.instance_variable_set(:@expires_at, Time.now + 3600)

      expect(token.has_valid_tokens?).to be true
    end

    it 'returns false when access token is missing' do
      token.instance_variable_set(:@refresh_token, 'refresh_token')
      token.instance_variable_set(:@expires_at, Time.now + 3600)

      expect(token.has_valid_tokens?).to eq(false)
    end

    it 'returns false when refresh token is missing' do
      token.instance_variable_set(:@access_token, 'test_token')
      token.instance_variable_set(:@expires_at, Time.now + 3600)

      expect(token.has_valid_tokens?).to eq(false)
    end

    it 'returns false when token is expired' do
      token.instance_variable_set(:@access_token, 'test_token')
      token.instance_variable_set(:@refresh_token, 'refresh_token')
      token.instance_variable_set(:@expires_at, Time.now - 3600)

      expect(token.has_valid_tokens?).to be false
    end
  end

  describe '#save_tokens_to_file and #load_tokens_from_file' do
    let(:temp_file) { Tempfile.new(['tokens', '.json']) }

    after do
      temp_file.close
      temp_file.unlink
    end

    it 'saves and loads tokens correctly' do
      token.instance_variable_set(:@access_token, 'test_access_token')
      token.instance_variable_set(:@refresh_token, 'test_refresh_token')
      token.instance_variable_set(:@expires_at, Time.now + 3600)
      token.instance_variable_set(:@client_id, 'test_client_id')

      # Save tokens
      token.save_tokens_to_file(temp_file.path)

      # Create new token instance and load
      new_token = described_class.new
      result = new_token.load_tokens_from_file(temp_file.path)

      expect(result).to be true
      expect(new_token.access_token).to eq('test_access_token')
      expect(new_token.refresh_token).to eq('test_refresh_token')
      expect(new_token.client_id).to eq('test_client_id')
      expect(new_token.expires_at).to be_within(1).of(Time.now + 3600)
    end

    it 'returns false when file does not exist' do
      result = token.load_tokens_from_file('/nonexistent/file.json')
      expect(result).to be false
    end

    it 'returns false when file contains invalid JSON' do
      File.write(temp_file.path, 'invalid json')
      result = token.load_tokens_from_file(temp_file.path)
      expect(result).to be false
    end

    it 'returns false when file contains invalid date format' do
      token_data = {
        access_token: 'test_token',
        refresh_token: 'refresh_token',
        expires_at: 'invalid_date',
        client_id: 'test_client_id'
      }
      File.write(temp_file.path, token_data.to_json)

      result = token.load_tokens_from_file(temp_file.path)
      expect(result).to be false
    end
  end
end
