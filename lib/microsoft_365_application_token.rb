# frozen_string_literal: true

require 'json'
require 'uri'

class Microsoft365ApplicationToken
  attr_accessor :client_id, :client_secret, :tenant_id

  def initialize(client_id, client_secret, tenant_id)
    @client_id = client_id
    @client_secret = client_secret
    @tenant_id = tenant_id
  end

  def token
    return unless token_request_result.present?

    token_request_result['access_token']
  end

  private

  def token_request_result
    @token_request_result ||= JSON.parse(token_request_response)
  end

  def token_request_response
    url = URI("https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request.body = token_request_body

    response = https.request(request)
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
