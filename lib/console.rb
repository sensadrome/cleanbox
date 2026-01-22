# frozen_string_literal: true

require 'net/imap'
require_relative 'connection'
require_relative 'cleanbox'
require_relative 'cleanbox_folder'
require_relative 'configuration'
require_relative 'auth/authentication_manager'
require_relative '../lib/i18n_config'

# Monkey patch Cleanbox to add convenience methods
class Cleanbox
  # Enable pretend mode (don't actually move messages)
  def pretend!
    @options[:pretend] = true
    puts '✅ Pretend mode enabled - no messages will be moved'
  end

  # Disable pretend mode (actually move messages)
  def no_pretend!
    @options[:pretend] = false
    puts '✅ Pretend mode disabled - messages will be moved'
  end

  # Note: pretending? is already defined in lib/cleanbox.rb, no need to redefine here

  # Search for messages
  # @param query [Array, String] IMAP search query
  # @param folder [String] Folder to search in (default: current_folder)
  # @return [Array<Integer>] Array of message sequence numbers
  def search(query, folder: current_folder)
    imap_connection.select(folder)
    imap_connection.search(query)
  end

  # Fetch messages by sequence number
  # @param ids [Array<Integer>] Message sequence numbers
  # @param folder [String] Folder these messages are in (default: current_folder)
  # @param full [Boolean] Whether to fetch the full message body (default: false)
  # @return [Array<CleanboxMessage>]
  def get_messages(ids, folder: current_folder, full: false)
    return [] if ids.blank?

    imap_connection.select(folder)
    
    # Decide what to fetch based on full flag
    # BODY.PEEK[HEADER] gets just headers without marking as read
    # BODY.PEEK[] gets full message without marking as read (RFC822 is equivalent but sometimes clearer)
    fetch_attr = full ? 'BODY.PEEK[]' : 'BODY.PEEK[HEADER]'
    
    items = imap_connection.fetch(ids, fetch_attr)
    return [] unless items

    items.map do |data|
      CleanboxMessage.new(data)
    end
  end

  # Find messages matching query (search + fetch)
  # @param query [Array, String] IMAP search query
  # @param folder [String] Folder to search in (default: current_folder)
  # @param full [Boolean] Fetch full message body
  # @return [Array<CleanboxMessage>]
  def find(query, folder: current_folder, full: false)
    ids = search(query, folder: folder)
    puts "Found #{ids.size} messages"
    get_messages(ids, folder: folder, full: full)
  end

  def find_ids(query, folder: current_folder)
    query = build_search_query(query)
    search(query, folder: folder)
  end
  
  # Ruby-like search abstraction
  # @param folder [String] Folder to search in (default: current_folder)
  # @param full [Boolean] Fetch full message body
  # @param criteria [Hash] Search criteria (e.g. from: 'foo', seen: false)
  # @return [Array<CleanboxMessage>]
  def where(folder: current_folder, full: false, **criteria)
    query = build_search_query(criteria)
    find(query, folder: folder, full: full)
  end

  # Mark messages with flags
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param flags [Array<Symbol>] Flags to add (e.g. [:Seen, :Deleted])
  # @param folder [String] Folder to operate in (default: current_folder)
  def add_flags(ids, flags, folder: current_folder)
    return if ids.blank?

    imap_connection.select(folder)
    imap_connection.store(ids, '+FLAGS', flags)
    puts "Marked #{Array(ids).size} messages with #{flags}"
  end

  # Remove flags from messages
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param flags [Array<Symbol>] Flags to remove
  # @param folder [String] Folder to operate in (default: current_folder)
  def remove_flags(ids, flags, folder: current_folder)
    return if ids.blank?

    imap_connection.select(folder)
    imap_connection.store(ids, '-FLAGS', flags)
    puts "Removed #{flags} from #{Array(ids).size} messages"
  end

  # Mark messages as seen (read)
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param folder [String] Folder to operate in
  def mark_seen(ids, folder: current_folder)
    add_flags(ids, [:Seen], folder: folder)
  end

  # Mark messages as unseen (unread)
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param folder [String] Folder to operate in
  def mark_unseen(ids, folder: current_folder)
    remove_flags(ids, [:Seen], folder: folder)
  end

  # Mark messages as deleted
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param folder [String] Folder to operate in
  def mark_deleted(ids, folder: current_folder)
    add_flags(ids, [:Deleted], folder: folder)
  end

  # Undelete messages
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param folder [String] Folder to operate in
  def undelete(ids, folder: current_folder)
    remove_flags(ids, [:Deleted], folder: folder)
  end

  # Mark messages as flagged (starred)
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param folder [String] Folder to operate in
  def mark_flagged(ids, folder: current_folder)
    add_flags(ids, [:Flagged], folder: folder)
  end

  # Unflag messages
  # @param ids [Array<Integer>, Integer, Range] Message sequence numbers
  # @param folder [String] Folder to operate in
  def unflag(ids, folder: current_folder)
    remove_flags(ids, [:Flagged], folder: folder)
  end

  # Summarize folder status and unread messages by sender
  # @param folder [String] Folder to analyze (default: current_folder)
  # @param limit [Integer] Number of top senders to show (default: 20)
  def summarize(folder: current_folder, limit: 20)
    # 1. Folder Stats
    status = imap_connection.status(folder, %w[MESSAGES UNSEEN])
    puts "Folder: #{folder}"
    puts "Total messages: #{status['MESSAGES']}"
    puts "Unseen messages: #{status['UNSEEN']}"
    puts "-" * 40

    return if status['UNSEEN'].to_i.zero?

    # 2. Unread Analysis
    imap_connection.select(folder)
    ids = imap_connection.search(['UNSEEN'])

    puts "Analyzing #{ids.size} unread messages..."

    counts = Hash.new(0)

    # Fetch envelopes in batches to be memory efficient
    ids.each_slice(500) do |slice|
      imap_connection.fetch(slice, 'ENVELOPE').each do |data|
        env = data.attr['ENVELOPE']
        # Handle cases where from might be nil or empty
        next unless env.from&.first

        sender = env.from.first
        email = "#{sender.mailbox}@#{sender.host}".downcase
        counts[email] += 1
      end
    end

    puts "Found unread messages from #{counts.size} senders:\n\n"

    # Sort by count descending
    sorted = counts.sort_by { |_, c| -c }

    sorted.take(limit).each do |email, count|
      puts format("  (%d) %s", count, email)
    end

    remaining = sorted.size - limit
    puts "\n... and #{remaining} more senders." if remaining.positive?
  end

  # List messages in a table format
  # @param folder [String] Folder to search in (default: current_folder)
  # @param limit [Integer] Maximum messages to show (default: 20)
  # @param criteria [Hash] Search criteria (passed to where)
  def list_messages(folder: current_folder, limit: 20, **criteria)
    # Default to unread if no specific criteria (other than folder) provided,
    # but allow overriding it. If criteria are empty, show all.
    # Actually, let's just pass criteria through.

    msgs = where(folder: folder, **criteria)

    if msgs.empty?
      puts "No messages found in #{folder} matching criteria."
      return
    end

    show_messages(msgs, limit: limit, folder: folder)
  end

  # Render a table of messages
  # @param messages [Array<CleanboxMessage>] Messages to display
  # @param limit [Integer] Maximum messages to show (default: 20)
  # @param folder [String] Optional folder name for context
  def show_messages(messages, limit: 20, folder: nil)
    # Sort by ID descending (newest first) usually better for scanning
    sorted_msgs = messages.sort_by { |m| -m.seqno }
    
    shown_msgs = sorted_msgs.take(limit)

    context = folder ? " in #{folder}" : ""
    puts "Listing #{shown_msgs.size} of #{messages.size} messages#{context}:"
    puts format("%-8s %-12s %-25s %s", "ID", "Date", "From", "Subject")
    puts "-" * 80

    shown_msgs.each do |m|
      from = m.from_address
      # simple truncation
      from = "#{from[0..22]}.." if from.length > 25
      
      subject = m.message.subject.to_s
      # subject = "#{subject[0..40]}.." if subject.length > 43
      
      date = m.date ? m.date.strftime('%d-%b') : '??-???'

      puts format("%-8d %-12s %-25s %s", m.seqno, date, from, subject)
    end
    
    if messages.size > limit
      puts "... and #{messages.size - limit} more."
    end
    nil # Don't return the array to avoid double printing in console
  end

  # Read a specific message
  # @param id [Integer] Message sequence number
  # @param folder [String] Folder to read from (default: current_folder)
  # @param show_links [Boolean] Whether to show URLs in the body (default: false)
  def read_message(id, folder: current_folder, show_links: false)
    msg = get_messages([id], folder: folder, full: true).first
    unless msg
      puts "Message #{id} not found in #{folder}"
      return
    end

    puts "=" * 80
    puts "From:    #{msg.from_address}"
    puts "To:      #{msg.message.to&.join(', ')}"
    puts "Date:    #{msg.date}"
    puts "Subject: #{msg.message.subject}"
    puts "=" * 80
    puts
    
    body = msg.body_for_display
    body = strip_links(body) unless show_links
    puts body
    puts
    puts "=" * 80
    nil
  end

  def move_messages(ids, folder, expunge = false)
    return if ids.blank?
    raise "Folder #{folder} not found" unless folders.include?(folder)

    mids = ids.map { |m| m.respond_to?(:seqno) ? m.seqno : m }
    imap_connection.copy(mids, folder)
    imap_connection.store(mids, '+FLAGS', [:Deleted])
    imap_connection.expunge if expunge
  end

  def clear!
    imap_connection.expunge
  end

  private

  # Strip links from text for cleaner terminal display
  # Removes markdown links [text](url) -> text
  # Removes plain URLs
  def strip_links(text)
    return text if text.blank?

    # Remove markdown links: [text](url) -> text
    text = text.gsub(/\[([^\]]+)\]\([^\)]+\)/, '\1')
    
    # Remove plain URLs (http/https/ftp)
    text = text.gsub(%r{https?://[^\s]+}, '')
    text = text.gsub(%r{ftp://[^\s]+}, '')
    
    # Clean up extra whitespace that might result
    text.gsub(/\n\s*\n\s*\n+/, "\n\n")
  end

  def build_search_query(criteria)
    query = []
    criteria.each do |key, value|
      case key
      when :from, :to, :subject, :body, :text, :bcc, :cc
        query.push(key.to_s.upcase, value)
      when :since, :before, :on
        query.push(key.to_s.upcase, value.strftime('%d-%b-%Y'))
      when :seen, :answered, :deleted, :flagged, :draft
        prefix = value ? '' : 'UN'
        # Handle special cases where 'UN' prefix isn't standard or needs mapping
        term = case key
               when :deleted, :flagged, :draft
                 value ? key.to_s.upcase : "NOT #{key.to_s.upcase}"
               else
                 "#{prefix}#{key.to_s.upcase}"
               end
        # Handle split terms like "NOT DELETED"
        term.split.each { |t| query.push(t) }
      end
    end
    query
  end
end

# Improve CleanboxMessage display in console
class CleanboxMessage
  def summary
    "#{seqno}: #{from_address} - #{message.subject} (#{date})"
  end

  def inspect
    "#<CleanboxMessage #{summary}>"
  end

  def html_body
    message.html_part.body.raw_source
  end

  def text_body
    part = message.text_part or return ""

    raw = part.body.raw_source

    decoded =
      case part.content_transfer_encoding
      when 'base64'
        Base64.decode64(raw)
      when 'quoted-printable'
        raw.unpack1('M')
      else
        raw
      end

    charset = part.charset || message.charset || 'UTF-8'

    decoded
      .force_encoding(charset)
      .encode('UTF-8', invalid: :replace, undef: :replace)
  rescue => e
    "[unreadable message body: #{e.class}]"
  end

  def iso_date
    date.to_date.iso8601
  end

  def body_for_display
    if text_body.present?
      text_body
    elsif html_body.present?
      begin
        require 'html2markdown'
        HTMLPage.new(contents: html_body).markdown
      rescue LoadError, StandardError
        # Fallback if gem not present or conversion fails
        html_body
      end
    else
      message.body.decoded
    end
  end
end

# Console interface for Cleanbox
# Provides an easy way to interact with Cleanbox from irb/pry
module CleanboxConsole
  class << self
    # Initialize a new Cleanbox instance with the given configuration
    # @param config_file [String] Path to configuration file (optional)
    # @param options [Hash] Additional options to override config
    # @return [Cleanbox] Configured Cleanbox instance
    def connect(config_file: nil, **options)
      # Load configuration
      config_opts = config_file ? { config_file: config_file } : {}
      Configuration.configure(config_opts.merge(options))

      # Create IMAP connection
      imap = Net::IMAP.new(Configuration.options[:host], ssl: true)
      # Authenticate
      Auth::AuthenticationManager.authenticate_imap(imap, Configuration.options)

      # Create and return Cleanbox instance
      Cleanbox.new(imap, Configuration.options)
    end

    # Quick connection using environment variables or default config
    # @return [Cleanbox] Configured Cleanbox instance
    def quick_connect
      connect
    end

    # Store the current cleanbox instance

    # Get the current cleanbox instance
    attr_accessor :cleanbox
  end

  # DSL module to delegate methods to the cleanbox instance
  module DSL
    def method_missing(method_name, *args, &block)
      if CleanboxConsole.cleanbox&.respond_to?(method_name)
        CleanboxConsole.cleanbox.public_send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      (CleanboxConsole.cleanbox && CleanboxConsole.cleanbox.respond_to?(method_name)) || super
    end
  end
end

# Convenience method for quick access
def cb
  CleanboxConsole.cleanbox || CleanboxConsole.quick_connect
end

# Alias for shorter typing
def cleanbox
  cb
end

# Show help for available methods
def show_help
  puts <<~HELP
    Cleanbox Console - Available Commands:

    # Main instance
    cb                    - Quick access to Cleanbox instance
    cleanbox             - Same as cb

    # Cleanbox methods (use with cb.method_name):
    cb.show_folders!     - Show folder tree with message counts
    cb.show_lists!       - Show list domain mappings
    cb.clean!            - Process new messages in inbox
    cb.file_messages!    - File existing messages
    cb.unjunk!           - Unjunk messages from junk folder
    cb.show_blacklist!   - Show blacklisted email addresses
    cb.build_blacklist!  - Rebuild blacklist from folders

    # Convenience methods (monkey patched):
    cb.pretend!          - Enable pretend mode (no actual moves)
    cb.no_pretend!       - Disable pretend mode (actual moves)
    cb.pretending?       - Check if pretend mode is enabled
    cb.log_level('debug') - Set log level

    # Configuration
    cb.options           - Show current options
    cb.options[:pretend] = true   - Direct option setting

    # Search & Retrieval
    cb.search(query)     - Search for messages (returns IDs)
                           e.g. cb.search(['FROM', 'user@example.com'])
    cb.get_messages(ids) - Fetch messages by IDs (add full: true for body)
    cb.find(query)       - Search and fetch messages
                           e.g. cb.find('UNSEEN')
    cb.where(criteria)   - Ruby-style search
                           e.g. cb.where(from: 'amazon', seen: false)

    # Message Flags
    cb.mark_seen(ids)    - Mark messages as read
    cb.mark_unseen(ids)  - Mark messages as unread
    cb.mark_deleted(ids) - Mark messages for deletion
    cb.undelete(ids)     - Unmark messages for deletion
    cb.mark_flagged(ids) - Star/Flag messages
    cb.unflag(ids)       - Unstar/Unflag messages

    # Analysis
    cb.summarize         - Show folder stats & unread counts
    cb.list_messages     - List messages table (accepts search criteria)
                           e.g. cb.list_messages(from: 'amazon', limit: 10)
    cb.read_message(id) - Read a message (strips links by default)
                           e.g. cb.read_message(123, show_links: true)

    # Help
    help                 - Show this help message

    # Example Usage:
    # cb.pretend!                    # Test without moving messages
    # cb.clean!                     # See what would happen
    # cb.no_pretend!                # Actually do it
    # cb.clean!                     # Now actually move messages
  HELP
end
