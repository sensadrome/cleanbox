# frozen_string_literal: true

require 'logger'
require 'set'
require_relative 'message_processor'

# main class
# rubocop:disable Metrics/ClassLength
class Cleanbox < CleanboxConnection
  attr_accessor :blacklisted_emails, :junk_emails, :whitelisted_emails, :list_domain_map, :sender_map
  attr_accessor :curr

  def initialize(imap_connection, initial_options)
    super
    @options = initial_options.dup
    @list_domain_map = options.delete(:list_domain_map) || {}
    @sender_map = options.delete(:sender_map) || {}
  end

  def clean!
    build_blacklist!
    build_whitelist!
    build_sender_map!(list_folders)
    clean_inbox!
    logger.info 'Finished cleaning'
  end

  def show_lists!
    list_domain_map.sort.to_h.each_pair do |domain, folder|
      puts "'#{domain}' => '#{folder}',"
    end
  end

  def show_blacklist!
    build_blacklist!
    if blacklisted_emails.any?
      puts "Blacklisted email addresses (#{blacklisted_emails.length}):"
      blacklisted_emails.sort.each { |email| puts "  #{email}" }
    else
      puts 'No blacklisted email addresses found'
    end
  end

  def show_folders!
    folders = cleanbox_folders
    tree = build_folder_tree(folders)
    print_folder_tree(tree)
    nil # Don't return the tree to avoid echo in console
  end

  def file_messages!
    @options[:filing] = true
    build_blacklist!
    build_sender_map!(folders_to_file)
    process_messages(all_messages, :decide_for_filing, 'filing existing messages')
  end

  def unjunk!
    @options[:unjunk] = true
    build_blacklist!
    build_sender_map!(folders_to_file)
    process_messages(junk_messages, :decide_for_filing, 'unjunking')
  end

  def list_folder
    options[:list_folder] || 'Lists'
  end

  def junk_folder
    options[:junk_folder] || imap_junk_folder || 'Junk'
  end

  def pretending?
    !!options[:pretend]
  end

  def whitelisted_domains
    [*options[:whitelisted_domains]]
  end

  def logger
    @logger ||= logger_object.tap do |l|
      l.level = log_level
    end
  end

  def unjunking?
    !!options[:unjunk]
  end

  def current_folder
    @current_folder || 'INBOX'
  end

  def select_folder(folder)
    @current_folder = folder
    imap_connection.select(folder)
  end

  private

  def clean_inbox!
    process_messages(new_messages, :decide_for_new_message, 'new inbox messages')
  end

  def log_level
    case options[:level]
    when 'debug'
      Logger::DEBUG
    when 'warn'
      Logger::WARN
    when 'error'
      Logger::ERROR
    else
      Logger::INFO
    end
  end

  def logger_object
    return Logger.new($stdout) unless options[:log_file]

    Logger.new(options[:log_file], 'monthly')
  end

  def build_blacklist!
    logger.info 'Building Blacklist....'

    # Build user blacklist from blacklist folder
    @blacklisted_emails = fetch_blacklisted_emails

    # Build junk folder blacklist
    @junk_emails = fetch_junk_emails

    logger.info "Found #{@blacklisted_emails.length} blacklisted emails and #{@junk_emails.length} junk folder emails"
  end

  def fetch_blacklisted_emails
    return [] unless options[:blacklist_folder].present?

    opts = { all_messages: true, folder: options[:blacklist_folder], logger: logger, cache: options[:cache] }

    CleanboxFolderChecker.new(imap_connection, opts).email_addresses
  rescue StandardError => e
    logger.warn "Blacklist folder '#{options[:blacklist_folder]}' not found or inaccessible: #{e.message}"
    []
  end

  def fetch_junk_emails
    return [] unless junk_folder

    opts = { folder: junk_folder, logger: logger, cache: options[:cache] }
    CleanboxFolderChecker.new(imap_connection, opts).email_addresses
  end

  def build_whitelist!
    logger.info 'Building White List....'
    @whitelisted_emails = (
      email_addresses_from_whitelist_folders + sent_emails
    ).uniq
  end

  def email_addresses_from_whitelist_folders
    whitelist_folders.flat_map do |folder|
      opts = { folder: folder, logger: logger, cache: options[:cache] }
      CleanboxFolderChecker.new(imap_connection, opts).email_addresses
    end.uniq
  end

  def whitelist_folders
    options[:whitelist_folders] || []
  end

  def sent_emails
    opts = {
      folder: sent_folder,
      logger: logger,
      address: :to,
      since: sent_since_date,
      cache: options[:cache]
    }
    CleanboxFolderChecker.new(imap_connection, opts).email_addresses
  end

  def sent_folder
    options[:sent_folder] || imap_sent_folder || 'Sent'
  end

  def sent_since_date
    months = options[:sent_since_months] || 24
    (Date.today << months).strftime('%d-%b-%Y')
  end

  def list_folders
    [*options[:list_folders] || list_folder]
  end

  def process_messages(messages, decision_method, context_name = nil)
    # Log context-specific message count
    logger.info "Processing #{messages.length} messages for #{context_name}"

    changed_folders = Set.new
    messages.each do |message|
      decision = message_processor.send(decision_method, message)
      execute_decision(decision, message, changed_folders)
    end

    log_processing_summary(changed_folders)

    changed_folders.each do |folder|
      CleanboxFolderChecker.update_cache_stats(folder, imap_connection)
    end

    clear_deleted_messages!
  end

  def message_processor
    @message_processor ||= MessageProcessor.new(message_processing_context)
  end

  def move_message(message, folder)
    if pretending?
      logger.info "PRETEND: Would move message #{message.seqno} from '#{message.from_address}' to folder '#{folder}'"
    else
      logger.info "Moving message #{message.seqno} from '#{message.from_address}' to folder '#{folder}'"
      add_folder(folder)
      imap_connection.copy(message.seqno, folder)
      imap_connection.store(message.seqno, '+FLAGS', [:Deleted])
    end
  end

  def junk_message(message)
    move_message(message, junk_folder)
  end

  def execute_decision(decision, message, changed_folders)
    case decision[:action]
    when :move
      move_message(message, decision[:folder])
      changed_folders.add(decision[:folder])
    when :junk
      junk_message(message)
      changed_folders.add(junk_folder)
    when :keep
      logger.debug "Keeping message #{message.seqno} from '#{message.from_address}' in inbox"
    else
      raise ArgumentError, "Unknown action: #{decision[:action]}"
    end
  end

  def log_processing_summary(changed_folders = nil)
    if changed_folders&.any?
      folders = changed_folders.to_a.join(', ')
      logger.info "Updated #{changed_folders.length} folders: #{folders}"
    else
      logger.info 'No messages were moved'
    end
  end

  def message_processing_context
    {
      whitelisted_emails: whitelisted_emails || [],
      whitelisted_domains: whitelisted_domains,
      list_domain_map: filtered_list_domain_map,
      sender_map: sender_map,
      list_folder: list_folder,
      unjunking: unjunking?,
      blacklisted_emails: blacklisted_emails,
      junk_emails: junk_emails,
      retention_policy: retention_policy.to_sym,
      hold_days: hold_days,
      quarantine_folder: quarantine_folder,
      blacklist_policy: blacklist_policy,
      junk_folder: junk_folder
    }
  end

  def filtered_list_domain_map
    return list_domain_map unless filing?

    valid_folders = folders_to_file
    list_domain_map.select { |_domain, folder| valid_folders.include?(folder) }
  end

  def filing?
    @options[:filing]
  end

  def retention_policy
    options[:retention_policy] || :spammy
  end

  def hold_days
    options[:hold_days] || 7
  end

  def quarantine_folder
    options[:quarantine_folder] || 'Quarantine'
  end

  def blacklist_policy
    options[:blacklist_policy] || :permissive
  end

  def new_messages
    return [] unless new_message_ids.present?

    imap_connection.fetch(new_message_ids, 'BODY.PEEK[HEADER]').map do |m|
      CleanboxMessage.new(m)
    end
  end

  def new_message_ids
    @new_message_ids ||= begin
      select_folder('INBOX')
      imap_connection.search(%w[UNSEEN NOT DELETED])
    end
  end

  def clear_deleted_messages!(folder = nil)
    return if pretending?
    select_folder(folder) if folder.present?
    imap_connection.expunge
  end

  def build_sender_map!(folders_to_map)
    logger.info 'Building sender maps....'
    folders_to_map.each do |folder|
      logger.debug "  adding addresses from #{folder}"
      CleanboxFolderChecker.new(imap_connection, sender_map_options(folder)).email_addresses.each do |email|
        @sender_map[email] ||= folder
      end
    end
  end

  def folders_to_file
    file_from_folders || (list_folders + whitelist_folders)
  end

  def file_from_folders
    options[:file_from_folders].presence
  end

  def sender_map_options(folder)
    {
      folder: folder,
      logger: logger,
      since: valid_from_date || list_since_date,
      cache: options[:cache]
    }.compact
  end

  def valid_from_date
    Date.parse(options[:valid_from]).strftime('%d-%b-%Y')
  rescue StandardError
    nil
  end

  def list_since_date
    months = options[:list_since_months] || 12
    (Date.today << months).strftime('%d-%b-%Y')
  end

  def all_messages
    fetch_all_messages.tap { puts }
  end

  def fetch_all_messages
    all_message_ids.each_slice_with_progress(100).flat_map do |slice, total, done, percent|
      show_progress "  Fetching: #{done}/#{total} (#{percent}%)"
      imap_connection.fetch(slice, 'BODY.PEEK[HEADER]').map do |m|
        CleanboxMessage.new(m)
      end
    end
  end

  def show_progress(message)
    # Clear the line first, then show new message
    print "\r\033[K#{message}"
    $stdout.flush
  end

  def filing_folder
    # Will change when we are able to specify the folder to file from...
    'INBOX'
  end

  def all_message_ids
    select_folder('INBOX')
    search_terms = %w[NOT DELETED] + date_search
    # If file_unread is false (default), only file read messages (add 'SEEN')
    search_terms << 'SEEN' unless options[:file_unread]
    imap_connection.search(search_terms)
  end

  def date_search
    return [] if operate_on_all_messages?

    ['SINCE', since_date.strftime('%d-%b-%Y')]
  end

  def operate_on_all_messages?
    options[:all_messages]
  end

  def since_date
    Date.parse(options[:since])
  rescue StandardError
    months = options[:since_months] || 24
    Date.today << months
  end

  def junk_messages
    imap_connection.fetch(junk_message_ids, 'BODY.PEEK[HEADER]').map do |m|
      CleanboxMessage.new(m)
    end
  end

  def junk_message_ids
    select_folder(imap_junk_folder)
    imap_connection.search(%w[NOT DELETED] + date_search)
  end

  def imap_junk_folder
    imap_folders.detect { |f| f.attr.include?(:Junk) }&.name
  end

  def imap_sent_folder
    imap_folders.detect { |f| f.attr.include?(:Sent) }&.name
  end

  # Build a hierarchical tree structure from flat folder list
  def build_folder_tree(folders)
    tree = {}

    folders.each do |folder|
      parts = folder.name.split(folder.delim || '/')
      current = tree

      parts.each_with_index do |part, idx|
        current[part] ||= {
          _folder: (idx == parts.length - 1 ? folder : nil),
          _children: {}
        }
        current = current[part][:_children]
      end
    end

    tree
  end

  # Print the folder tree with proper indentation and tree characters
  def print_folder_tree(tree, prefix = '', is_last = true, is_root = true)
    tree.each_with_index do |(name, data), idx|
      is_last_child = (idx == tree.size - 1)
      folder = data[:_folder]

      # Build the display line
      if is_root
        # Root level - no prefix
        line = name
      else
        # Use tree characters
        connector = is_last_child ? '└──' : '├──'
        line = "#{prefix}#{connector} #{name}"
      end

      # Colorize and add symbol for special folders
      if folder
        folder_type = determine_folder_type(folder)
        symbol = folder_symbol(folder_type)
        color = folder_color(folder_type)

        # Apply color to the folder name if we have a color
        if color && is_root
          line = line.send(color)
        elsif color
          # For non-root, only colorize the name part after the connector
          parts = line.split(' ', 2)
          line = parts[0] + ' ' + parts[1].send(color) if parts.size == 2
        end

        # Add symbol and folder info
        line += " #{symbol}" if symbol
        line += folder_info(folder)
      end

      puts line

      # Recurse for children
      unless data[:_children].empty?
        # Determine the prefix for children
        if is_root
          child_prefix = ''
        else
          extension = is_last_child ? '    ' : '│   '
          child_prefix = prefix + extension
        end

        print_folder_tree(data[:_children], child_prefix, is_last_child, false)
      end
    end
  end

  # Format folder information (counts and attributes)
  def folder_info(folder)
    info = ''

    # Add attributes if present (like [Junk], [Sent], etc.)
    if folder.attrs.present?
      info += " [#{folder.attrs.join(', ')}]"
    end

    # Add message counts
    total = folder.status['MESSAGES'].to_i
    unseen = folder.status['UNSEEN'].to_i

    if unseen.positive?
      info += " (#{total} total, #{unseen} unread)"
    elsif total.positive?
      info += " (#{total} total)"
    end

    info
  end

  # Determine the type of folder based on configuration
  def determine_folder_type(folder)
    name = folder.name

    # Check IMAP attributes first
    return :junk if folder.attrs.include?(:Junk)
    return :sent if folder.attrs.include?(:Sent)

    # Check configuration
    return :blacklist if options[:blacklist_folder] == name
    return :quarantine if quarantine_folder == name
    return :whitelist if whitelist_folders.include?(name)
    return :list if list_folders.include?(name)

    nil
  end

  # Get symbol for folder type
  def folder_symbol(folder_type)
    case folder_type
    when :whitelist
      '⭐'
    when :list
      '📋'
    when :blacklist, :junk
      '🚫'
    when :sent
      '📬'
    when :quarantine
      '⚠️'
    end
  end

  # Get color for folder type
  def folder_color(folder_type)
    case folder_type
    when :whitelist
      :green
    when :list
      :blue
    when :blacklist, :junk
      :red
    when :sent
      :magenta
    when :quarantine
      :yellow
    end
  end
end
# rubocop:enable Metrics/ClassLength
