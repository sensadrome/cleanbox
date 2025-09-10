# frozen_string_literal: true

require 'logger'
require 'set'
require_relative 'message_processor'

# main class
# rubocop:disable Metrics/ClassLength
class Cleanbox < CleanboxConnection
  attr_accessor :blacklisted_emails, :junk_emails, :whitelisted_emails, :list_domain_map, :sender_map

  def initialize(imap_connection, initial_options)
    super
    @options = initial_options.dup
    @list_domain_map = options.delete(:list_domain_map) || {}
    @sender_map = options.delete(:sender_map) || {}
  end

  def clean!
    build_blacklist!
    build_whitelist!
    build_sender_map!
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
    cleanbox_folders.each { |folder| puts folder }
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

  def file_messages!
    build_sender_map!
    process_messages(all_messages, :decide_for_filing, 'filing existing messages')
  end

  def unjunk!
    build_sender_map!
    process_messages(junk_messages, :decide_for_filing, 'unjunking')
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

    CleanboxFolderChecker.new(imap_connection, all_messages: true,
                                               folder: options[:blacklist_folder],
                                               logger: logger).email_addresses
  rescue StandardError => e
    logger.warn "Blacklist folder '#{options[:blacklist_folder]}' not found or inaccessible: #{e.message}"
    []
  end

  def fetch_junk_emails
    return [] unless junk_folder

    CleanboxFolderChecker.new(imap_connection, folder: junk_folder, logger: logger).email_addresses
  end

  def build_whitelist!
    logger.info 'Building White List....'
    @whitelisted_emails = (
      email_addresses_from_whitelist_folders + sent_emails
    ).uniq
  end

  def email_addresses_from_whitelist_folders
    whitelist_folders.flat_map do |folder|
      CleanboxFolderChecker.new(imap_connection, folder: folder, logger: logger).email_addresses
    end.uniq
  end

  def whitelist_folders
    options[:whitelist_folders] || []
  end

  def sent_emails
    CleanboxFolderChecker.new(imap_connection,
                              folder: sent_folder,
                              logger: logger,
                              address: :to,
                              since: sent_since_date).email_addresses
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
      whitelisted_emails: whitelisted_emails,
      whitelisted_domains: whitelisted_domains,
      list_domain_map: list_domain_map,
      sender_map: sender_map,
      list_folder: list_folder,
      unjunking: unjunking?,
      blacklisted_emails: blacklisted_emails,
      junk_emails: junk_emails,
      retention_policy: retention_policy.to_sym,
      hold_days: hold_days,
      quarantine_folder: quarantine_folder
    }
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

  def new_messages
    return [] unless new_message_ids.present?

    imap_connection.fetch(new_message_ids, 'BODY.PEEK[HEADER]').map do |m|
      CleanboxMessage.new(m)
    end
  end

  def new_message_ids
    @new_message_ids ||= begin
      imap_connection.select 'INBOX'
      imap_connection.search(%w[UNSEEN NOT DELETED])
    end
  end

  def clear_deleted_messages!(folder = nil)
    return if pretending?

    imap_connection.select(folder) if folder.present?

    imap_connection.expunge
  end

  def list_since_date
    months = options[:list_since_months] || 12
    (Date.today << months).strftime('%d-%b-%Y')
  end

  def build_sender_map!
    logger.info 'Building sender maps....'
    folders_to_file.each do |folder|
      logger.debug "  adding addresses from #{folder}"
      CleanboxFolderChecker.new(imap_connection,
                                folder: folder,
                                logger: logger,
                                since: valid_from).email_addresses.each do |email|
        @sender_map[email] ||= folder
      end
    end
  end

  def valid_from(folder = nil)
    return if whitelist_folders.include?(folder)

    valid_from_date.strftime('%d-%b-%Y')
  end

  def valid_from_date
    Date.parse(options[:valid_from])
  rescue StandardError
    months = options[:valid_since_months] || 12
    Date.today << months
  end

  def folders_to_file
    file_from_folders || all_folders
  end

  def file_from_folders
    options[:file_from_folders].presence
  end

  def all_folders
    whitelist_folders + list_folders
  end

  def all_messages
    all_message_ids.each_slice(800).flat_map do |slice|
      imap_connection.fetch(slice, 'BODY.PEEK[HEADER]').map do |m|
        CleanboxMessage.new(m)
      end
    end
  end

  def all_message_ids
    logger.debug date_search.inspect
    imap_connection.select 'INBOX'
    search_terms = %w[NOT DELETED] + date_search
    # If file_unread is false (default), only file read messages (add 'SEEN')
    search_terms << 'SEEN' unless options[:file_unread]
    imap_connection.search(search_terms)
  end

  def date_search
    ['SINCE', list_since_date]
  end

  def junk_messages
    imap_connection.fetch(junk_message_ids, 'BODY.PEEK[HEADER]').map do |m|
      CleanboxMessage.new(m)
    end
  end

  def junk_message_ids
    imap_connection.select imap_junk_folder
    imap_connection.search(%w[NOT DELETED] + date_search)
  end

  def imap_junk_folder
    imap_folders.detect { |f| f.attr.include?(:Junk) }&.name
  end

  def imap_sent_folder
    imap_folders.detect { |f| f.attr.include?(:Sent) }&.name
  end
end
# rubocop:enable Metrics/ClassLength
