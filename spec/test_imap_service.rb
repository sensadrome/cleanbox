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
    return "Authentication failed" if auth_data.nil?
    auth_data['error'] || "Authentication failed"
  end

  def authenticate(method, username, password_or_token)
    auth_data = @fixture_data['auth']
    
    if auth_data['success'] == false
      raise Net::IMAP::NoResponseError.new(auth_data['error'])
    end
    
    # Simulate successful authentication
    true
  end

  def list(prefix, pattern)
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
    @current_folder = folder_name
    folder_data = find_folder(folder_name)
    
    unless folder_data
      raise Net::IMAP::NoResponseError.new("Folder not found: #{folder_name}")
    end
    
    # Simulate successful folder selection
    true
  end

  def search(criteria)
    folder_data = find_folder(@current_folder)
    return [] unless folder_data
    
    message_count = folder_data['message_count'] || 0
    (1..message_count).to_a
  end

  def fetch(message_ids, data_items)
    folder_data = find_folder(@current_folder)
    return [] unless folder_data
    
    message_ids.map do |id|
      message_data = find_message(folder_data, id)
      next unless message_data
      
      # Create a mock fetch response
      response = Object.new
      
      if data_items.include?('ENVELOPE')
        response.define_singleton_method(:attr) do
          { 'ENVELOPE' => create_envelope(message_data) }
        end
      elsif data_items.include?('BODY.PEEK[HEADER]')
        response.define_singleton_method(:attr) do
          { 'BODY[HEADER]' => message_data['headers'] || '' }
        end
      end
      
      response
    end.compact
  end

  def status(folder_name, items)
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

  private

  def load_fixture(fixture_name)
    fixture_path = File.join(File.dirname(__FILE__), 'fixtures', 'imap', "#{fixture_name}.yml")
    
    unless File.exist?(fixture_path)
      raise "Fixture not found: #{fixture_path}"
    end
    
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

  def create_envelope(message_data)
    # Create a mock envelope object
    envelope = Object.new
    
    # Mock 'from' field
    from = Object.new
    from.define_singleton_method(:mailbox) { message_data['sender'].split('@').first }
    from.define_singleton_method(:host) { message_data['sender'].split('@').last }
    from.define_singleton_method(:name) { nil }
    
    # Mock 'to' field (for sent items)
    to = Object.new
    to.define_singleton_method(:mailbox) { message_data['recipient']&.split('@')&.first || 'recipient' }
    to.define_singleton_method(:host) { message_data['recipient']&.split('@')&.last || 'example.com' }
    to.define_singleton_method(:name) { nil }
    
    envelope.define_singleton_method(:from) { [from] }
    envelope.define_singleton_method(:to) { [to] }
    envelope.define_singleton_method(:subject) { message_data['subject'] || 'Test Subject' }
    envelope.define_singleton_method(:date) { message_data['date'] || Time.now }
    
    envelope
  end
end 