# frozen_string_literal: true

module ImapFixtureHelper
  def mock_imap_with_fixture(fixture_name)
    # Create the test IMAP service
    test_imap = TestImapService.new(fixture_name)

    # Mock Net::IMAP.new to return our test service
    allow(Net::IMAP).to receive(:new).and_return(test_imap)

    # Mock the authentication manager to use our test service's auth methods
    allow(Auth::AuthenticationManager).to receive(:authenticate_imap) do |_imap, _options|
      raise Net::IMAP::NoResponseError, test_imap.auth_error unless test_imap.auth_success?

      # Simulate successful authentication by calling authenticate on the test service
      test_imap.authenticate('oauth2', 'test@example.com', 'token')
      true

      # Simulate authentication failure
    end

    test_imap
  end
end
