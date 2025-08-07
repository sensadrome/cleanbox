# frozen_string_literal: true

require 'json'
require 'uri'

class Microsoft365ApplicationToken
  attr_accessor :client_id, :client_secret, :tenant_id
  attr_reader :logger

  def initialize(client_id, client_secret, tenant_id, logger: nil)
    @client_id = client_id
    @client_secret = client_secret
    @tenant_id = tenant_id
    @logger = logger || Logger.new(STDOUT)
  end

  def token
    return unless token_request_result.present?

    token_request_result['access_token']
  end

  private

  def token_request_result
    @token_request_result ||= begin
      response_body = token_request_response
      @logger.debug "Token response status: #{@response_code}" if ENV['CLEANBOX_DEBUG']
      @logger.debug "Token response body: #{response_body}" if ENV['CLEANBOX_DEBUG']

      raise 'Empty response from Microsoft OAuth endpoint' if response_body.empty?

      JSON.parse(response_body)
    rescue JSON::ParserError => e
      @logger.error "Failed to parse OAuth response: #{e.message}"
      @logger.error "Response body: #{response_body}" if defined?(response_body)
      raise "Invalid OAuth response from Microsoft: #{e.message}"
    end
  end

  def token_request_response
    url = URI("https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request.body = token_request_body
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    response = https.request(request)
    @response_code = response.code
    response.read_body
  end

  def token_request_body
    URI.encode_www_form(token_request_params)
  end

  def token_request_params
    {
      client_id: client_id,
      client_secret: client_secret,
      scope: scope,
      grant_type: grant_type
    }
  end

  def scope
    'https://outlook.office365.com/.default'
  end

  def grant_type
    'client_credentials'
  end
end
