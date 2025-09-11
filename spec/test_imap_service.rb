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

  # disabled because this is the name of the imap method
  # rubocop:disable Naming/PredicateMethod
  def authenticate(_method, _username, _password_or_token)
    auth_data = @fixture_data['auth']

    raise Net::IMAP::NoResponseError, mock_imap_error_response(auth_data['error']) if auth_data['success'] == false

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

    raise Net::IMAP::NoResponseError, mock_imap_error_response("Folder not found: #{folder_name}") unless folder_data

    # Simulate successful folder selection
    true
  end
  # rubocop:enable Naming/PredicateMethod

  def search(criteria)
    confirm_authenticated!
    folder_data = find_folder(@current_folder)
    return [] unless folder_data

    # Check if this folder uses the old style (message_count) or new style (messages array)
    if folder_data.key?('message_count')
      # Old style: return range of sequence numbers based on message_count
      message_count = folder_data['message_count'] || 0
      (1..message_count).to_a
    else
      # New style: return sequence numbers from filtered messages
      messages = folder_data['messages'] || []
      filter_messages(messages, criteria)
    end
  end

  def filter_messages(messages, criteria)
    # If no SEEN criteria, return all (current behavior)
    return (1..messages.length).to_a unless criteria.include?('SEEN')
    
    # Filter messages that have \Seen flag
    filtered_indices = []
    messages.each_with_index do |message, index|
      if message['flags']&.include?('\\Seen')
        filtered_indices << index + 1  # Convert to 1-based sequence numbers
      end
    end
    
    filtered_indices
  end

  def fetch(sequence_numbers, data_items)
    confirm_authenticated!
    folder_data = find_folder(@current_folder)
    return [] unless folder_data

    messages = folder_data['messages'] || []
    seqnos = normalize_sequence_numbers(sequence_numbers)

    seqnos.map do |seqno|
      validate_sequence_number(seqno, messages.length)
      message_data = messages[seqno - 1]
      next unless message_data

      response = OpenStruct.new
      if data_items.include?('ENVELOPE')
        response.attr = { 'ENVELOPE' => build_envelope(message_data) }
      elsif data_items.include?('BODY.PEEK[HEADER]')
        response.attr = { 'BODY[HEADER]' => message_data['headers'] || build_headers(message_data) }
      end
      response.seqno = seqno
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

  def build_envelope(message_data)
    from = build_address(message_data, 'sender')
    to = build_address(message_data, 'recipient')

    Struct.new(:from, :to, :address, :subject, :date, keyword_init: true)
          .new(
            from: [from],
            to: [to],
            address: from,
            subject: message_data['subject'] || 'Test Subject',
            date: message_data['date'] || Time.now
          )
  end

  def build_address(message_data, part)
    Struct.new(:mailbox, :host, :name, keyword_init: true)
          .new(
            mailbox: message_data[part]&.split('@')&.first || part,
            host: message_data[part]&.split('@')&.last || 'example.com',
            name: nil
          )
  end

  def build_headers(message_data)
    headers = []

    # From header
    from_email = message_data['sender'] || 'unknown@example.com'
    headers << "From: #{from_email}"

    # To header
    to_email = message_data['recipient'] || 'recipient@example.com'
    headers << "To: #{to_email}"

    # Subject header
    subject = message_data['subject'] || 'Test Subject'
    headers << "Subject: #{subject}"

    # Date header
    date = message_data['date'] || Time.now
    formatted_date = date.is_a?(String) ? Time.parse(date) : date
    headers << "Date: #{formatted_date.strftime('%a, %d %b %Y %H:%M:%S %z')}"

    # Message-ID header
    message_id = message_data['id'] || 1
    headers << "Message-ID: <#{message_id}@#{from_email.split('@').last}>"

    # MIME-Version header
    headers << 'MIME-Version: 1.0'

    # Content-Type header
    headers << 'Content-Type: text/plain; charset=UTF-8'

    # Join with CRLF as per RFC 2822
    headers.join("\r\n") + "\r\n"
  end

  def confirm_authenticated!
    return if @authenticated

    raise Net::IMAP::NoResponseError, mock_imap_error_response('Not authenticated')
  end

  def mock_imap_response(status, text)
    OpenStruct.new(name: status, data: OpenStruct.new(text: text))
  end

  def mock_imap_error_response(text)
    OpenStruct.new(data: OpenStruct.new(text: text))
  end

  # Copy messages to another folder
  # set can be a number, array, or range of message sequence numbers
  def copy(set, mailbox)
    confirm_authenticated!

    target_folder_data = find_folder(mailbox)
    raise Net::IMAP::NoResponseError, "Folder #{mailbox} not found" unless target_folder_data

    # Get messages from current folder
    current_folder_data = find_folder(@current_folder)
    return mock_imap_response('OK', 'COPY completed') unless current_folder_data

    messages = current_folder_data['messages'] || []
    seqnos = normalize_sequence_numbers(set)

    copied_count = 0
    seqnos.each do |seqno|
      validate_sequence_number(seqno, messages.length)
      message_data = messages[seqno - 1]
      next unless message_data

      # Create a copy with the same ID (don't change the message ID)
      copied_message = message_data.dup

      target_folder_data['messages'] ||= []
      target_folder_data['messages'] << copied_message
      copied_count += 1
    end

    mock_imap_response('OK', "COPY completed (#{copied_count} messages copied)")
  end

  # Store flags on messages
  # set can be a number, array, or range of message sequence numbers
  # attr is the flag operation like '+FLAGS', '-FLAGS', 'FLAGS'
  def store(set, attr, flags)
    confirm_authenticated!

    current_folder_data = find_folder(@current_folder)
    return mock_imap_response('OK', 'STORE completed') unless current_folder_data

    messages = current_folder_data['messages'] || []
    seqnos = normalize_sequence_numbers(set)

    updated_count = 0
    seqnos.each do |seqno|
      validate_sequence_number(seqno, messages.length)
      message_data = messages[seqno - 1]
      next unless message_data

      case attr
      when '+FLAGS'
        message_data['flags'] ||= []
        message_data['flags'] = (message_data['flags'] + flags).uniq
      when '-FLAGS'
        message_data['flags'] ||= []
        message_data['flags'] -= flags
      when 'FLAGS'
        message_data['flags'] = flags.dup
      end
      updated_count += 1
    end

    mock_imap_response('OK', "STORE completed (#{updated_count} messages updated)")
  end

  # Remove messages marked for deletion
  def expunge
    confirm_authenticated!

    current_folder_data = find_folder(@current_folder)
    return mock_imap_response('OK', 'EXPUNGE completed') unless current_folder_data

    # Find messages marked for deletion
    deleted_ids = []
    current_folder_data['messages']&.reject! do |message|
      if message['flags']&.include?(:Deleted)
        deleted_ids << message['id']
        true
      else
        false
      end
    end

    mock_imap_response('OK', "EXPUNGE completed (#{deleted_ids.length} messages deleted)")
  end

  # Get the next available message ID for a folder
  def get_next_message_id(folder_data)
    messages = folder_data['messages'] || []
    return 1 if messages.empty?

    max_id = messages.map { |m| m['id'] }.max
    max_id + 1
  end

  # Get folder contents (for testing)
  def get_folder_contents(folder_name)
    folder_data = find_folder(folder_name)
    return [] unless folder_data

    folder_data['messages'] || []
  end

  private

  def normalize_sequence_numbers(sequence_numbers)
    case sequence_numbers
    when Integer
      [sequence_numbers]
    when Array
      sequence_numbers
    when Range
      sequence_numbers.to_a
    else
      raise ArgumentError, "Invalid sequence_numbers type: #{sequence_numbers.class}"
    end
  end

  def validate_sequence_number(seqno, message_count)
    return if seqno.between?(1, message_count)

    raise Net::IMAP::NoResponseError, "Invalid sequence number: #{seqno}"
  end
end
