# frozen_string_literal: true

require 'spec_helper'
require 'climate_control'

RSpec.describe Microsoft365ApplicationToken do
  let(:client_id) { 'test-client-id' }
  let(:client_secret) { 'test-client-secret' }
  let(:tenant_id) { 'test-tenant-id' }
  let(:logger) { double('Logger') }
  let(:token_instance) { described_class.new(client_id, client_secret, tenant_id, logger: logger) }

  describe '#initialize' do
    it 'sets the required attributes' do
      expect(token_instance.client_id).to eq(client_id)
      expect(token_instance.client_secret).to eq(client_secret)
      expect(token_instance.tenant_id).to eq(tenant_id)
    end

    it 'uses provided logger' do
      expect(token_instance.logger).to eq(logger)
    end

    it 'uses default logger when none provided' do
      token_with_default_logger = described_class.new(client_id, client_secret, tenant_id)
      expect(token_with_default_logger.logger).to be_a(Logger)
    end
  end

  describe '#token' do
    let(:mock_response) { double('HTTPResponse') }
    let(:mock_https) { double('HTTPS') }
    let(:mock_request) { double('HTTPRequest') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(mock_https)
      allow(mock_https).to receive(:use_ssl=)
      allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:body=)
      allow(mock_request).to receive(:[]=)
      allow(mock_https).to receive(:request).and_return(mock_response)
    end

    context 'when token request is successful' do
      let(:success_response_body) do
        '{"access_token": "test-access-token", "expires_in": 3600, "token_type": "Bearer"}'
      end

      before do
        allow(mock_response).to receive(:code).and_return('200')
        allow(mock_response).to receive(:read_body).and_return(success_response_body)
        allow(logger).to receive(:debug)
      end

      it 'returns the access token' do
        expect(token_instance.token).to eq('test-access-token')
      end

      it 'logs debug information when CLEANBOX_DEBUG is set' do
        ClimateControl.modify(CLEANBOX_DEBUG: 'true') do
          expect(logger).to receive(:debug).with('Token response status: 200')
          expect(logger).to receive(:debug).with("Token response body: #{success_response_body}")
          token_instance.token
        end
      end

      it 'does not log debug information when CLEANBOX_DEBUG is not set' do
        ClimateControl.modify(CLEANBOX_DEBUG: nil) do
          expect(logger).not_to receive(:debug)
          token_instance.token
        end
      end

      it 'caches the token request result' do
        expect(token_instance).to receive(:token_request_response).once.and_call_original
        token_instance.token
        token_instance.token # Second call should use cached result
      end
    end

    context 'when token request fails with empty response' do
      before do
        allow(mock_response).to receive(:code).and_return('400')
        allow(mock_response).to receive(:read_body).and_return('')
        allow(logger).to receive(:debug)
      end

      it 'raises an error' do
        expect { token_instance.token }.to raise_error('Empty response from Microsoft OAuth endpoint')
      end
    end

    context 'when token request fails with invalid JSON' do
      before do
        allow(mock_response).to receive(:code).and_return('200')
        allow(mock_response).to receive(:read_body).and_return('invalid json')
        allow(logger).to receive(:debug)
        allow(logger).to receive(:error)
      end

      it 'raises an error with details' do
        expect { token_instance.token }.to raise_error(/Invalid OAuth response from Microsoft/)
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with(/Failed to parse OAuth response/)
        expect(logger).to receive(:error).with(/Response body: invalid json/)
        expect { token_instance.token }.to raise_error(/Invalid OAuth response from Microsoft/)
      end
    end

    context 'when token request fails with HTTP error' do
      before do
        allow(mock_response).to receive(:code).and_return('401')
        allow(mock_response).to receive(:read_body).and_return('{"error": "unauthorized"}')
        allow(logger).to receive(:debug)
      end

      it 'returns nil when response does not contain access_token' do
        expect(token_instance.token).to be_nil
      end
    end
  end

  describe 'HTTP request configuration' do
    let(:mock_response) { double('HTTPResponse') }
    let(:mock_https) { double('HTTPS') }
    let(:mock_request) { double('HTTPRequest') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(mock_https)
      allow(mock_https).to receive(:use_ssl=)
      allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:body=)
      allow(mock_request).to receive(:[]=)
      allow(mock_https).to receive(:request).and_return(mock_response)
      allow(mock_response).to receive(:code).and_return('200')
      allow(mock_response).to receive(:read_body).and_return('{"access_token": "test"}')
      allow(logger).to receive(:debug)
    end

    it 'configures HTTPS connection correctly' do
      expect(Net::HTTP).to receive(:new).with('login.microsoftonline.com', 443)
      expect(mock_https).to receive(:use_ssl=).with(true)
      token_instance.token
    end

    it 'sets request headers correctly' do
      expect(mock_request).to receive(:body=).with(instance_of(String))
      expect(mock_request).to receive(:[]=).with('Content-Type', 'application/x-www-form-urlencoded')
      token_instance.token
    end

    it 'sends request to correct URL' do
      expected_url = "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token"
      expect(Net::HTTP::Post).to receive(:new).with(URI(expected_url))
      token_instance.token
    end
  end

  describe 'request parameters' do
    let(:mock_response) { double('HTTPResponse') }
    let(:mock_https) { double('HTTPS') }
    let(:mock_request) { double('HTTPRequest') }

    before do
      allow(Net::HTTP).to receive(:new).and_return(mock_https)
      allow(mock_https).to receive(:use_ssl=)
      allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:body=)
      allow(mock_request).to receive(:[]=)
      allow(mock_https).to receive(:request).and_return(mock_response)
      allow(mock_response).to receive(:code).and_return('200')
      allow(mock_response).to receive(:read_body).and_return('{"access_token": "test"}')
      allow(logger).to receive(:debug)
    end

    it 'includes correct parameters in request body' do
      expect(mock_request).to receive(:body=) do |body|
        params = URI.decode_www_form(body).to_h
        expect(params['client_id']).to eq(client_id)
        expect(params['client_secret']).to eq(client_secret)
        expect(params['scope']).to eq('https://outlook.office365.com/.default')
        expect(params['grant_type']).to eq('client_credentials')
      end

      token_instance.token
    end
  end

  describe 'error handling' do
    context 'when Net::HTTP raises an error' do
      before do
        allow(Net::HTTP).to receive(:new).and_raise(ArgumentError, 'Connection failed')
      end

      it 'propagates the error' do
        expect { token_instance.token }.to raise_error(ArgumentError, 'Connection failed')
      end
    end

    context 'when URI parsing fails' do
      before do
        allow(URI).to receive(:parse).and_raise(URI::InvalidURIError, 'Invalid URI')
      end

      it 'propagates the error' do
        expect { token_instance.token }.to raise_error(URI::InvalidURIError, 'Invalid URI')
      end
    end
  end
end
