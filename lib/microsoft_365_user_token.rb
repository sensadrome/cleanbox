# frozen_string_literal: true

require 'json'
require 'uri'
require 'securerandom'
require 'logger'
require 'time'

class Microsoft365UserToken
  DEFAULT_CLIENT_ID = 'b3fc8598-3357-4f5d-ac0a-969016f6bb24'
  # DEFAULT_REDIRECT_URI = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
  DEFAULT_REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'
  DEFAULT_SCOPE = 'https://outlook.office365.com/IMAP.AccessAsUser.All offline_access openid'
  TOKEN_ENDPOINT = 'https://login.microsoftonline.com/common/oauth2/v2.0/token'

  attr_accessor :client_id, :redirect_uri, :scope
  attr_reader :logger, :access_token, :refresh_token, :expires_at

  def initialize(client_id: nil, redirect_uri: nil, scope: nil, logger: nil)
    @client_id = client_id || DEFAULT_CLIENT_ID
    @redirect_uri = redirect_uri || DEFAULT_REDIRECT_URI
    @scope = scope || DEFAULT_SCOPE
    @logger = logger || Logger.new($stdout).tap { |l| l.level = Logger::INFO }
    @access_token = nil
    @refresh_token = nil
    @expires_at = nil
  end

  def authorization_url(state: nil)
    state ||= SecureRandom.hex(16)

    params = {
      client_id: @client_id,
      response_type: 'code',
      redirect_uri: @redirect_uri,
      scope: @scope,
      state: state
    }

    query_string = URI.encode_www_form(params)
    "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?#{query_string}"
  end

  def exchange_code_for_tokens(authorization_code)
    response_body = token_exchange_request(authorization_code)
    parse_token_response(response_body)
  end

  def refresh_access_token
    return false unless @refresh_token

    response_body = refresh_token_request
    parse_token_response(response_body)
  end

  def token
    return @access_token if @access_token && !token_expired?

    if @refresh_token
      refresh_access_token
      return @access_token if @access_token
    end

    nil
  end

  def token_expired?
    return true unless @expires_at

    @expires_at < Time.now
  end

  def has_valid_tokens?
    # Try to get a valid token (this will refresh if needed)
    return false if @refresh_token.nil?

    # If we have a valid access token, we're good
    return true if @access_token && !token_expired?

    # If access token is expired but we have a refresh token, try to refresh
    if @refresh_token
      begin
        refresh_access_token
        return @access_token && !token_expired?
      rescue StandardError => e
        @logger&.error "Failed to refresh token: #{e.message}"
        return false
      end
    end

    false
  end

  def save_tokens_to_file(file_path)
    token_data = {
      access_token: @access_token,
      refresh_token: @refresh_token,
      expires_at: @expires_at&.iso8601,
      client_id: @client_id
    }

    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, token_data.to_json)
  end

  def load_tokens_from_file(file_path)
    return false unless File.exist?(file_path)

    token_data = JSON.parse(File.read(file_path))
    @access_token = token_data['access_token']
    @refresh_token = token_data['refresh_token']
    @expires_at = Time.parse(token_data['expires_at']) if token_data['expires_at']
    @client_id = token_data['client_id'] if token_data['client_id']

    true
  rescue JSON::ParserError, ArgumentError => e
    @logger.error "Failed to load tokens from #{file_path}: #{e.message}"
    false
  end

  private

  def token_exchange_request(authorization_code)
    url = URI(TOKEN_ENDPOINT)
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request.body = token_exchange_params(authorization_code)
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    response = https.request(request)
    @response_code = response.code

    if response.code != '200'
      @logger.error "Token exchange failed with status #{response.code}"
      @logger.error "Response: #{response.read_body}"
      raise "Token exchange failed: #{response.code}"
    end

    response.read_body
  end

  def refresh_token_request
    url = URI(TOKEN_ENDPOINT)
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request.body = refresh_token_params
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    response = https.request(request)
    @response_code = response.code

    if response.code != '200'
      @logger.error "Token refresh failed with status #{response.code}"
      @logger.error "Response: #{response.read_body}"
      raise "Token refresh failed: #{response.code}"
    end

    response.read_body
  end

  def token_exchange_params(authorization_code)
    URI.encode_www_form({
                          client_id: @client_id,
                          code: authorization_code,
                          redirect_uri: @redirect_uri,
                          grant_type: 'authorization_code'
                        })
  end

  def refresh_token_params
    URI.encode_www_form({
                          client_id: @client_id,
                          refresh_token: @refresh_token,
                          grant_type: 'refresh_token'
                        })
  end

  def parse_token_response(response_body)
    return false if response_body.empty?

    begin
      token_data = JSON.parse(response_body)

      @access_token = token_data['access_token']
      @refresh_token = token_data['refresh_token'] if token_data['refresh_token']

      @expires_at = Time.now + token_data['expires_in'].to_i if token_data['expires_in']

      true
    rescue JSON::ParserError => e
      @logger.error "Failed to parse token response: #{e.message}"
      @logger.error "Response body: #{response_body}"
      raise "Invalid token response: #{e.message}"
    end
  end
end
