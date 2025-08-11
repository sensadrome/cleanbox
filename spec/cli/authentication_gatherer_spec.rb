# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CLI::AuthenticationGatherer do
  let(:gatherer) { described_class.new }

  describe '#initialize' do
    it 'initializes with empty connection details and secrets' do
      expect(gatherer.connection_details).to eq({})
      expect(gatherer.secrets).to eq({})
    end
  end

  describe '#gather_authentication_details!' do
    context 'with OAuth2 Microsoft application authentication' do
      before do
        # Mock gets to return OAuth2 application flow inputs
        allow(gatherer).to receive(:gets).and_return(
          "outlook.office365.com\n",  # host
          "test@example.com\n",       # username
          "2\n",                      # auth_type choice (oauth2_microsoft)
          "client123\n",              # client_id
          "secret456\n",              # client_secret
          "tenant789\n"               # tenant_id
        )
      end

      it 'gathers all required details' do
        gatherer.gather_authentication_details!

        expect(gatherer.connection_details[:host]).to eq('outlook.office365.com')
        expect(gatherer.connection_details[:username]).to eq('test@example.com')
        expect(gatherer.connection_details[:auth_type]).to eq('oauth2_microsoft')
        expect(gatherer.secrets['CLEANBOX_CLIENT_ID']).to eq('client123')
        expect(gatherer.secrets['CLEANBOX_CLIENT_SECRET']).to eq('secret456')
        expect(gatherer.secrets['CLEANBOX_TENANT_ID']).to eq('tenant789')
      end
    end

    context 'with OAuth2 Microsoft user authentication' do
      before do
        # Mock gets to return OAuth2 user flow inputs
        allow(gatherer).to receive(:gets).and_return(
          "outlook.office365.com\n",  # host
          "test@example.com\n",       # username
          "1\n"                       # auth_type choice (oauth2_microsoft_user)
        )
      end

      it 'gathers connection details without secrets' do
        gatherer.gather_authentication_details!

        expect(gatherer.connection_details[:host]).to eq('outlook.office365.com')
        expect(gatherer.connection_details[:username]).to eq('test@example.com')
        expect(gatherer.connection_details[:auth_type]).to eq('oauth2_microsoft_user')
        expect(gatherer.secrets).to eq({})
      end
    end

    context 'with password authentication' do
      before do
        # Mock gets to return password flow inputs
        allow(gatherer).to receive(:gets).and_return(
          "imap.gmail.com\n",         # host
          "test@gmail.com\n",         # username
          "3\n",                      # auth_type choice (password)
          "password123\n"             # password
        )
      end

      it 'gathers connection details and password' do
        gatherer.gather_authentication_details!

        expect(gatherer.connection_details[:host]).to eq('imap.gmail.com')
        expect(gatherer.connection_details[:username]).to eq('test@gmail.com')
        expect(gatherer.connection_details[:auth_type]).to eq('password')
        expect(gatherer.secrets['CLEANBOX_PASSWORD']).to eq('password123')
      end
    end
  end

  describe '#prompt_for_host' do
    context 'with valid host input' do
      before do
        allow(gatherer).to receive(:gets).and_return("test.com\n")
      end

      it 'accepts valid host' do
        result = gatherer.send(:prompt_for_host)
        expect(result).to eq('test.com')
      end
    end

    context 'with invalid host input followed by valid' do
      before do
        allow(gatherer).to receive(:gets).and_return("invalid\n", "test.com\n")
      end

      it 'rejects invalid host and accepts valid one' do
        result = gatherer.send(:prompt_for_host)
        expect(result).to eq('test.com')
      end
    end

    context 'with default host' do
      before do
        allow(gatherer).to receive(:gets).and_return("\n") # Just press enter
      end

      it 'uses default host when no input provided' do
        result = gatherer.send(:prompt_for_host)
        expect(result).to eq('outlook.office365.com')
      end
    end
  end

  describe '#prompt_for_username' do
    context 'with valid email input' do
      before do
        allow(gatherer).to receive(:gets).and_return("test@example.com\n")
      end

      it 'accepts valid email address' do
        result = gatherer.send(:prompt_for_username)
        expect(result).to eq('test@example.com')
      end
    end

    context 'with invalid email input followed by valid' do
      before do
        allow(gatherer).to receive(:gets).and_return("invalid\n", "test@example.com\n")
      end

      it 'rejects invalid email and accepts valid one' do
        result = gatherer.send(:prompt_for_username)
        expect(result).to eq('test@example.com')
      end
    end
  end

  describe '#prompt_for_auth_type' do
    context 'with valid choice' do
      before do
        allow(gatherer).to receive(:gets).and_return("1\n")
      end

      it 'accepts valid choice' do
        result = gatherer.send(:prompt_for_auth_type)
        expect(result).to eq('oauth2_microsoft_user')
      end
    end

    context 'with invalid choice followed by valid' do
      before do
        allow(gatherer).to receive(:gets).and_return("99\n", "2\n")
      end

      it 'rejects invalid choice and accepts valid one' do
        result = gatherer.send(:prompt_for_auth_type)
        expect(result).to eq('oauth2_microsoft')
      end
    end
  end

  describe 'credential gathering' do
    context 'for OAuth2 Microsoft application' do
      before do
        gatherer.instance_variable_set(:@connection_details, { auth_type: 'oauth2_microsoft' })
        allow(gatherer).to receive(:gets).and_return(
          "client123\n",
          "secret456\n",
          "tenant789\n"
        )
      end

      it 'gathers client credentials' do
        gatherer.send(:gather_credentials_based_on_auth_type)

        expect(gatherer.secrets['CLEANBOX_CLIENT_ID']).to eq('client123')
        expect(gatherer.secrets['CLEANBOX_CLIENT_SECRET']).to eq('secret456')
        expect(gatherer.secrets['CLEANBOX_TENANT_ID']).to eq('tenant789')
      end
    end

    context 'for password authentication' do
      before do
        gatherer.instance_variable_set(:@connection_details, { auth_type: 'password' })
        allow(gatherer).to receive(:gets).and_return("password123\n")
      end

      it 'gathers password' do
        gatherer.send(:gather_credentials_based_on_auth_type)

        expect(gatherer.secrets['CLEANBOX_PASSWORD']).to eq('password123')
      end
    end
  end
end 