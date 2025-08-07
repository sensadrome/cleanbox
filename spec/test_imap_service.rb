# frozen_string_literal: true

require 'yaml'

class TestImapService
  def initialize(fixture_name)
    @fixture_name = fixture_name
    @current_folder = nil
    @fixture_data = load_fixture(@fixture_name)
  end

  def auth_success?
    auth_data = @fixture_data['auth']
    return true if auth_data.nil? || auth_data['success'].nil?

    auth_data['success'] != false
  end

  def auth_error
    auth_data = @fixture_data['auth']
    return 'Authentication failed' if auth_data.nil?

    auth_data['error'] || 'Authentication failed'
  end

  def authenticate(_method, _username, _password_or_token)
    auth_data = @fixture_data['auth']

    raise Net::IMAP::NoResponseError.new(mock_imap_error_response(auth_data['error'])) if auth_data['success'] == false

    # Simulate successful authentication
    @authenticated = true
    true
  end

  def list(_prefix, _pattern)
    confirm_authenticated!
    folders = @fixture_data['folders'] || []
    folders.map do |folder_data|
      # Create a mock folder object that responds to .name
      folder = Object.new
      folder.define_singleton_method(:name) { folder_data['name'] }
      folder.define_singleton_method(:attr) { folder_data['attributes'] || {} }
      folder
    end
  end

  def select(folder_name)
    confirm_authenticated!
    @current_folder = folder_name
    folder_data = find_folder(folder_name)

    unless folder_data
      raise Net::IMAP::NoResponseError.new(mock_imap_error_response("Folder not found: #{folder_name}"))
    end

    # Simulate successful folder selection
    true
  end

  def search(_criteria)
    confirm_authenticated!
    folder_data = find_folder(@current_folder)
    return [] unless folder_data

    message_count = folder_data['message_count'] || 0
    (1..message_count).to_a
  end

  def fetch(message_ids, data_items)
    confirm_authenticated!
    folder_data = find_folder(@current_folder)
    return [] unless folder_data

    message_ids.map do |id|
      message_data = find_message(folder_data, id)
      next unless message_data

      response = OpenStruct.new
      if data_items.include?('ENVELOPE')
        response.attr = { 'ENVELOPE' => build_envelope(message_data) }
      elsif data_items.include?('BODY.PEEK[HEADER]')
        response.attr = { 'BODY[HEADER]' => message_data['headers'] || '' }
      end
      response
    end.compact
  end

  def status(folder_name, items)
    confirm_authenticated!
    folder_data = find_folder(folder_name)
    return {} unless folder_data

    status_data = {}
    items.each do |item|
      case item
      when 'MESSAGES'
        status_data[item] = folder_data['message_count'] || 0
      when 'UNSEEN'
        status_data[item] = folder_data['unseen'] || 0
      end
    end

    status_data
  end

  def load_fixture(fixture_name)
    fixture_path = File.join(File.dirname(__FILE__), 'fixtures', 'imap', "#{fixture_name}.yml")

    raise "Fixture not found: #{fixture_path}" unless File.exist?(fixture_path)

    YAML.load_file(fixture_path)
  end

  def find_folder(folder_name)
    folders = @fixture_data['folders'] || []
    folders.find { |f| f['name'] == folder_name }
  end

  def find_message(folder_data, message_id)
    messages = folder_data['messages'] || []
    messages.find { |m| m['id'] == message_id }
  end

  private

  def build_envelope(message_data)
    from = OpenStruct.new(
      mailbox: message_data['sender'].split('@').first,
      host: message_data['sender'].split('@').last,
      name: nil
    )
    to = OpenStruct.new(
      mailbox: message_data['recipient']&.split('@')&.first || 'recipient',
      host: message_data['recipient']&.split('@')&.last || 'example.com',
      name: nil
    )
    OpenStruct.new(
      from: [from],
      to: [to],
      subject: message_data['subject'] || 'Test Subject',
      date: message_data['date'] || Time.now
    )
  end

  def confirm_authenticated!
    return if @authenticated

    raise Net::IMAP::NoResponseError.new(mock_imap_error_response('Not authenticated'))
  end
end
