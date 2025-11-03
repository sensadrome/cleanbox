# frozen_string_literal: true

require 'uri'
require 'timeout'
require 'webrick'

module OAuth
  class LocalCallbackServer
    DEFAULT_TIMEOUT = 300
    SUCCESS_HTML = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <title>Cleanbox Authorization Complete</title>
          <style>
            body {
              background: #0b172a;
              color: #f4f6fa;
              font-family: Helvetica, Arial, sans-serif;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
              margin: 0;
            }
            .card {
              background: #13233f;
              padding: 2rem 3rem;
              border-radius: 12px;
              box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
              text-align: center;
            }
            h1 {
              margin-top: 0;
              font-size: 1.8rem;
            }
            p {
              color: #d5d9e6;
              line-height: 1.4;
            }
            .footer {
              margin-top: 1.5rem;
              font-size: 0.9rem;
              color: #9da7bb;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Authorization complete</h1>
            <p>You can return to Cleanbox to finish the setup.</p>
            <p class="footer">This window can be closed.</p>
          </div>
        </body>
      </html>
    HTML

    ERROR_HTML = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <title>Cleanbox Authorization Error</title>
          <style>
            body {
              font-family: Helvetica, Arial, sans-serif;
              background: #2d1b1b;
              color: #f6d7d7;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
              margin: 0;
            }
            .card {
              background: #3a2323;
              padding: 2rem 3rem;
              border-radius: 12px;
              box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
              text-align: center;
            }
            h1 {
              margin-top: 0;
            }
            p {
              line-height: 1.4;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Authorization failed</h1>
            <p>%{message}</p>
          </div>
        </body>
      </html>
    HTML

    class CallbackServerError < StandardError; end
    class CallbackTimeoutError < CallbackServerError; end
    class CallbackStateMismatchError < CallbackServerError; end
    class CallbackMissingCodeError < CallbackServerError; end
    class CallbackProviderError < CallbackServerError; end

    Result = Struct.new(:status, :code, :error, keyword_init: true)

    def initialize(redirect_uri:, expected_state:, logger: nil, timeout: DEFAULT_TIMEOUT)
      @uri = URI.parse(redirect_uri)
      raise ArgumentError, 'redirect_uri must include a host' unless @uri.host

      @expected_state = expected_state
      @logger = logger
      @timeout = timeout
      @path = @uri.path.empty? ? '/' : @uri.path
      @queue = Queue.new
    end

    def wait_for_authorization_code
      server = build_server
      server_thread = Thread.new { server.start }

      result = begin
        Timeout.timeout(@timeout) { @queue.pop }
      rescue Timeout::Error
        raise CallbackTimeoutError, "Timed out waiting for authorization on #{@uri}" 
      ensure
        shutdown_server(server, server_thread)
      end

      handle_result(result)
    rescue Interrupt
      shutdown_server(server, server_thread)
      raise
    end

    private

    def build_server
      webrick_logger = WEBrick::Log.new(nil, 0)
      server = WEBrick::HTTPServer.new(
        BindAddress: @uri.host,
        Port: @uri.port,
        Logger: webrick_logger,
        AccessLog: []
      )

      server.mount_proc(@path) do |request, response|
        process_callback(request, response)
      end

      server
    rescue Errno::EADDRINUSE => e
      raise CallbackServerError, "Port #{@uri.port} is unavailable for OAuth callback: #{e.message}"
    end

    def process_callback(request, response)
      params = request.query

      if params['error']
        provider_error(response, params)
        return
      end

      unless params['state'] == @expected_state
        state_mismatch(response)
        return
      end

      authorization_code = params['code']
      if authorization_code.to_s.empty?
        missing_code(response)
        return
      end

      response.status = 200
      response['Content-Type'] = 'text/html; charset=utf-8'
      response.body = SUCCESS_HTML

      @queue << Result.new(status: :ok, code: authorization_code)
    rescue StandardError => e
      @logger&.error("OAuth callback handling failed: #{e.class} - #{e.message}")
      @queue << Result.new(status: :error, error: e)
    end

    def provider_error(response, params)
      message = params['error_description'] || params['error']
      response.status = 400
      response['Content-Type'] = 'text/html; charset=utf-8'
      response.body = format(ERROR_HTML, message: message)

      @queue << Result.new(status: :error, error: CallbackProviderError.new(message))
    end

    def state_mismatch(response)
      message = 'State parameter did not match expected value.'
      response.status = 400
      response['Content-Type'] = 'text/html; charset=utf-8'
      response.body = format(ERROR_HTML, message: message)

      @queue << Result.new(status: :error, error: CallbackStateMismatchError.new(message))
    end

    def missing_code(response)
      message = 'Authorization code not found in callback parameters.'
      response.status = 400
      response['Content-Type'] = 'text/html; charset=utf-8'
      response.body = format(ERROR_HTML, message: message)

      @queue << Result.new(status: :error, error: CallbackMissingCodeError.new(message))
    end

    def shutdown_server(server, thread)
      return unless server

      server.shutdown rescue nil
      thread&.join
    end

    def handle_result(result)
      case result&.status
      when :ok
        result.code
      when :error
        raise(result.error || CallbackServerError.new('OAuth callback failed'))
      else
        raise CallbackServerError, 'Unexpected OAuth callback result'
      end
    end
  end
end


