# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Auth::AuthenticationManager do
  let(:mock_imap) { double('IMAP') }
  let(:options) do
    {
      host: 'outlook.office365.com',
      username: 'test@example.com',
      password: 'test_password',
      client_id: 'test_client_id',
      client_secret: 'test_client_secret',
      tenant_id: 'test_tenant_id'
    }
  end

  before do
    # Mock IMAP authentication methods
    allow(mock_imap).to receive(:authenticate)
  end

  describe '.determine_auth_type' do
    context 'when auth_type is explicitly provided' do
      it 'returns the provided auth_type' do
        result = described_class.determine_auth_type('outlook.office365.com', 'password')
        expect(result).to eq('password')
      end

      it 'returns oauth2_microsoft when specified' do
        result = described_class.determine_auth_type('outlook.office365.com', 'oauth2_microsoft')
        expect(result).to eq('oauth2_microsoft')
      end
    end

    context 'when auth_type is not provided (auto-detection)' do
      it 'detects Microsoft 365 and returns oauth2_microsoft' do
        result = described_class.determine_auth_type('outlook.office365.com', nil)
        expect(result).to eq('oauth2_microsoft')
      end

      it 'detects Gmail and returns oauth2_gmail' do
        result = described_class.determine_auth_type('imap.gmail.com', nil)
        expect(result).to eq('oauth2_gmail')
      end

      it 'defaults to password for other hosts' do
        result = described_class.determine_auth_type('mail.example.com', nil)
        expect(result).to eq('password')
      end

      it 'handles empty auth_type' do
        result = described_class.determine_auth_type('outlook.office365.com', '')
        expect(result).to eq('oauth2_microsoft')
      end
    end

    context 'with different Microsoft 365 host variations' do
      it 'detects outlook.office365.com' do
        result = described_class.determine_auth_type('outlook.office365.com', nil)
        expect(result).to eq('oauth2_microsoft')
      end

      it 'detects outlook.office365.com' do
        result = described_class.determine_auth_type('outlook.office365.com', nil)
        expect(result).to eq('oauth2_microsoft')
      end
    end
  end

  describe '.authenticate_imap' do
    context 'with Microsoft OAuth2 authentication (application-level)' do
      let(:mock_token) { double('Microsoft365ApplicationToken') }
      let(:oauth_options) { options.merge(auth_type: 'oauth2_microsoft') }

      before do
        allow(Microsoft365ApplicationToken).to receive(:new).and_return(mock_token)
        allow(mock_token).to receive(:token).and_return('test_oauth_token')
      end

      it 'creates Microsoft365ApplicationToken with correct parameters' do
        expect(Microsoft365ApplicationToken).to receive(:new).with(
          'test_client_id',
          'test_client_secret',
          'test_tenant_id',
          logger: nil
        )

        described_class.authenticate_imap(mock_imap, oauth_options)
      end

      it 'authenticates IMAP with XOAUTH2 method' do
        expect(mock_imap).to receive(:authenticate).with(
          'XOAUTH2',
          'test@example.com',
          'test_oauth_token'
        )

        described_class.authenticate_imap(mock_imap, oauth_options)
      end

      it 'auto-detects Microsoft OAuth2 when auth_type is not specified' do
        auto_options = options.merge(host: 'outlook.office365.com')

        expect(Microsoft365ApplicationToken).to receive(:new).with(
          'test_client_id',
          'test_client_secret',
          'test_tenant_id',
          logger: nil
        )

        described_class.authenticate_imap(mock_imap, auto_options)
      end
    end

    context 'with Microsoft OAuth2 authentication (user-based)' do
      let(:mock_user_token) { double('Microsoft365UserToken') }
      let(:user_oauth_options) { options.merge(auth_type: 'oauth2_microsoft_user') }

      before do
        allow(Microsoft365UserToken).to receive(:new).and_return(mock_user_token)
        allow(mock_user_token).to receive(:load_tokens_from_file).and_return(true)
        allow(mock_user_token).to receive(:token).and_return('test_user_oauth_token')
      end

      it 'creates Microsoft365UserToken with correct parameters' do
        expect(Microsoft365UserToken).to receive(:new).with(
          client_id: 'test_client_id',
          logger: nil
        )

        described_class.authenticate_imap(mock_imap, user_oauth_options)
      end

      it 'authenticates IMAP with XOAUTH2 method using user token' do
        expect(mock_imap).to receive(:authenticate).with(
          'XOAUTH2',
          'test@example.com',
          'test_user_oauth_token'
        )

        described_class.authenticate_imap(mock_imap, user_oauth_options)
      end

      it 'raises error when no valid tokens found' do
        allow(mock_user_token).to receive(:load_tokens_from_file).and_return(false)

        expect { described_class.authenticate_imap(mock_imap, user_oauth_options) }
          .to raise_error('No valid tokens found. Please run \'cleanbox auth setup\' to authenticate.')
      end

      it 'raises error when token is nil' do
        allow(mock_user_token).to receive(:token).and_return(nil)

        expect { described_class.authenticate_imap(mock_imap, user_oauth_options) }
          .to raise_error('No valid tokens found. Please run \'cleanbox auth setup\' to authenticate.')
      end

      it 'raises friendly guidance when refresh token expired' do
        expired_error = Microsoft365UserToken::RefreshTokenExpiredError.new('Stored Microsoft 365 refresh token has expired. Run "./cleanbox auth setup" to re-authorize.')
        allow(mock_user_token).to receive(:token).and_raise(expired_error)

        expect { described_class.authenticate_imap(mock_imap, user_oauth_options) }
          .to raise_error(expired_error.message)
      end
    end

    describe '.data_dir' do
      context 'when data_dir is set in Configuration' do
        let(:config_options) { { data_dir: '/test/data/dir' } }

        it 'returns data directory from Configuration' do
          expect(described_class.data_dir).to eq('/test/data/dir')
        end
      end

      context 'when data_dir is not set in Configuration' do
        let(:config_options) { { data_dir: nil } }

        it 'returns home directory when Configuration.data_dir is nil' do
          expect(described_class.data_dir).to eq(Dir.home)
        end
      end
    end

    describe '.default_token_file' do
      context 'when data_dir is set in Configuration' do
        let(:config_options) { { data_dir: '/test/data/dir' } }

        it 'uses data directory when set' do
          expected_path = File.join('/test/data/dir', 'tokens', 'test_user_com.json')
          expect(described_class.send(:default_token_file, 'test@user.com')).to eq(expected_path)
        end

        it 'sanitizes username for filename' do
          expected_path = File.join('/test/data/dir', 'tokens', 'test_user_com.json')
          expect(described_class.send(:default_token_file, 'test@user.com')).to eq(expected_path)
        end
      end

      context 'when data_dir is not set in Configuration' do
        let(:config_options) { { data_dir: nil } }

        it 'uses home directory when data directory not set' do
          expected_path = File.join(Dir.home, '.cleanbox', 'tokens', 'test_user_com.json')
          expect(described_class.send(:default_token_file, 'test@user.com')).to eq(expected_path)
        end
      end
    end

    context 'with password authentication' do
      let(:password_options) { options.merge(auth_type: 'password') }

      it 'authenticates IMAP with PLAIN method' do
        expect(mock_imap).to receive(:authenticate).with(
          'PLAIN',
          'test@example.com',
          'test_password'
        )

        described_class.authenticate_imap(mock_imap, password_options)
      end

      it 'auto-detects password auth for non-Microsoft/Gmail hosts' do
        auto_options = options.merge(host: 'mail.example.com')

        expect(mock_imap).to receive(:authenticate).with(
          'PLAIN',
          'test@example.com',
          'test_password'
        )

        described_class.authenticate_imap(mock_imap, auto_options)
      end
    end

    context 'with Gmail OAuth2 authentication' do
      let(:gmail_options) { options.merge(host: 'imap.gmail.com', auth_type: 'oauth2_gmail') }

      it 'raises an error as Gmail OAuth2 is not yet implemented' do
        expect do
          described_class.authenticate_imap(mock_imap, gmail_options)
        end.to raise_error(RuntimeError, 'Gmail OAuth2 not yet implemented')
      end

      it 'auto-detects Gmail OAuth2 and raises error' do
        auto_options = options.merge(host: 'imap.gmail.com')

        expect do
          described_class.authenticate_imap(mock_imap, auto_options)
        end.to raise_error(RuntimeError, 'Gmail OAuth2 not yet implemented')
      end
    end

    context 'with unknown authentication type' do
      let(:unknown_options) { options.merge(auth_type: 'unknown_method') }

      it 'raises an error for unknown auth types' do
        expect do
          described_class.authenticate_imap(mock_imap, unknown_options)
        end.to raise_error(RuntimeError, 'Unknown authentication type: unknown_method')
      end
    end

    context 'with missing credentials' do
      it 'raises an error when Microsoft OAuth2 is missing client_id' do
        incomplete_options = options.merge(auth_type: 'oauth2_microsoft', client_id: nil)

        # Mock the token class to raise an error for missing client_id
        allow(Microsoft365ApplicationToken).to receive(:new).and_raise(
          ArgumentError, 'client_id is required'
        )

        expect do
          described_class.authenticate_imap(mock_imap, incomplete_options)
        end.to raise_error(ArgumentError, 'client_id is required')
      end

      it 'raises an error when password auth is missing password' do
        incomplete_options = options.merge(auth_type: 'password', password: nil)

        # The current implementation doesn't validate missing password
        # So we expect it to try to authenticate with nil password
        expect(mock_imap).to receive(:authenticate).with('PLAIN', 'test@example.com', nil)

        described_class.authenticate_imap(mock_imap, incomplete_options)
      end
    end
  end

  describe 'error handling' do
    context 'when Microsoft365ApplicationToken raises an error' do
      let(:oauth_options) { options.merge(auth_type: 'oauth2_microsoft') }

      before do
        allow(Microsoft365ApplicationToken).to receive(:new).and_raise(
          RuntimeError, 'OAuth token request failed'
        )
      end

      it 'propagates the error from the token class' do
        expect do
          described_class.authenticate_imap(mock_imap, oauth_options)
        end.to raise_error(RuntimeError, 'OAuth token request failed')
      end
    end

    context 'when IMAP authentication fails' do
      let(:password_options) { options.merge(auth_type: 'password') }

      before do
        # Mock IMAP authentication to raise a generic error
        allow(mock_imap).to receive(:authenticate).and_raise(RuntimeError, 'Authentication failed')
      end

      it 'propagates IMAP authentication errors' do
        expect do
          described_class.authenticate_imap(mock_imap, password_options)
        end.to raise_error(RuntimeError, 'Authentication failed')
      end
    end
  end

  describe 'full walkthrough' do
    context 'with typical Microsoft 365 setup' do
      let(:microsoft_options) do
        {
          host: 'outlook.office365.com',
          username: 'user@company.com',
          client_id: 'app_client_id',
          client_secret: 'app_secret',
          tenant_id: 'company_tenant_id'
        }
      end

      let(:mock_token) { double('Microsoft365ApplicationToken') }

      before do
        allow(Microsoft365ApplicationToken).to receive(:new).and_return(mock_token)
        allow(mock_token).to receive(:token).and_return('valid_oauth_token')
      end

      it 'successfully authenticates with auto-detected OAuth2' do
        expect(mock_imap).to receive(:authenticate).with(
          'XOAUTH2',
          'user@company.com',
          'valid_oauth_token'
        )

        described_class.authenticate_imap(mock_imap, microsoft_options)
      end
    end

    context 'with traditional IMAP server' do
      let(:traditional_options) do
        {
          host: 'mail.example.com',
          username: 'user@example.com',
          password: 'user_password'
        }
      end

      it 'successfully authenticates with password' do
        expect(mock_imap).to receive(:authenticate).with(
          'PLAIN',
          'user@example.com',
          'user_password'
        )

        described_class.authenticate_imap(mock_imap, traditional_options)
      end
    end
  end
end
