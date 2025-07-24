# frozen_string_literal: true

require 'logger'
require_relative 'message_processor'
require_relative 'message_action_runner'

# main class
# rubocop:disable Metrics/ClassLength
class Cleanbox < CleanboxConnection
  attr_accessor :blacklisted_emails, :whitelisted_emails, :list_domains
  attr_accessor :list_domain_map, :sender_map

  def initialize(imap_connection, options)
    super
    @list_domain_map = options.delete(:list_domain_map) || {}
    @sender_map = options.delete(:sender_map) || {}
  end

  def clean!
    # build_blacklist!
    build_whitelist!
    build_list_domains!
    clean_inbox!
    logger.info 'Finished cleaning'
  end

  def show_lists!
    build_list_domains!
    list_domain_map.sort.to_h.each_pair do |domain, folder|
      puts "'#{domain}' => '#{folder}',"
    end
  end



  def show_folders!
    cleanbox_folders.each { |folder| puts folder.to_s }
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
    build_list_domains! unless file_from_folders.present?
    build_sender_map!
    process_messages(all_messages, :decide_for_filing)
  end

  def unjunk!
    build_clean_sender_map!
    process_messages(junk_messages, :decide_for_filing)
  end

  private

  def clean_inbox!
    process_messages(new_messages, :decide_for_new_message)
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
    return Logger.new(STDOUT) unless options[:log_file]

    Logger.new(options[:log_file], 'monthly')
  end

  def build_blacklist!
    logger.info 'Building Junk List....'
    @blacklisted_emails = blacklist_folders.flat_map do |folder|
      CleanboxFolderChecker.new(imap_connection, folder: folder, logger: logger).email_addresses
    end.uniq
  end

  def blacklist_folders
    options[:blacklist_folders] || %w[Junk]
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

  def build_list_domains!
    logger.info 'Building list subscriptions....'
    @list_domains = (domains_from_folders + [*options[:list_domains]]).uniq
  end

  def domains_from_folders
    list_folders.flat_map do |folder|
      CleanboxFolderChecker.new(imap_connection,
                                folder: folder, logger: logger,
                                since: list_since_date).domains.tap do |domains|
        domains.each do |domain|
          list_domain_map[domain] ||= folder
        end
      end
    end
  end

  def list_folders
    [*options[:list_folders] || list_folder]
  end

  def process_messages(messages, decision_method)
    context = message_processing_context
    processor = MessageProcessor.new(context)
    runner = MessageActionRunner.new(imap: imap_connection, junk_folder: junk_folder)

    messages.each do |message|
      decision = processor.send(decision_method, message)
      runner.execute(decision, message)
    end

    runner.changed_folders.each do |folder|
      CleanboxFolderChecker.update_cache_stats(folder, imap_connection)
    end

    clear_deleted_messages!
  end

  def message_processing_context
    {
      whitelisted_emails: whitelisted_emails,
      whitelisted_domains: whitelisted_domains,
      list_domains: list_domains,
      list_domain_map: list_domain_map,
      sender_map: sender_map,
      list_folder: list_folder,
      unjunking: unjunking?
    }
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
        sender_map[email] ||= folder
      end
    end
  end

  def build_clean_sender_map!
    unjunk_folders.each do |folder|
      logger.info "Building sender maps for folder #{folder}"
      CleanboxFolderChecker.new(imap_connection,
                                folder: folder,
                                logger: logger,
                                since: valid_from(folder)).email_addresses.each do |email|
        sender_map[email] ||= folder
      end
    end
  end

  def unjunk_folders
    options[:unjunk_folders]
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
