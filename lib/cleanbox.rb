# main class
class Cleanbox < CleanboxConnection
  attr_accessor :blacklisted_emails, :whitelisted_emails, :list_domains
  attr_accessor :whitelisted_domains, :domain_map

  def initialize(imap_connection, options)
    super
    @domain_map = options.delete(:domain_map) || {}
  end

  def clean!
    build_whitelist!
    build_list_domains!
    clean_inbox!
  end

  def show_lists!
    build_list_domains!
    puts domain_map.inspect
  end

  def list_folder
    options[:list_folder] || 'Lists'
  end

  def junk_folder
    options[:junk_folder] || 'Junk'
  end

  def pretending?
    options[:pretend]
  end

  def whitelisted_domains
    [*options[:whitelisted_domains]]
  end

  def logger
    @logger ||= logger_object.tap do |l|
      l.level = log_level
    end
  end

  private

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

  def build_whitelist!
    logger.info 'Building White List....'
    @whitelisted_emails = (
      email_addresses_from_clean_folders + sent_emails
    ).uniq
  end

  def email_addresses_from_clean_folders
    whitelist_folders.flat_map do |folder|
      CleanboxFolderChecker.new(imap_connection, folder: folder).email_addresses
    end.uniq
  end

  def whitelist_folders
    options[:clean_folders] || []
  end

  def sent_emails
    CleanboxFolderChecker.new(imap_connection,
                              folder: sent_folder,
                              address: :to).email_addresses
  end

  def sent_folder
    options[:sent_folder] || 'Sent'
  end

  def build_list_domains!
    logger.info 'Building list subscriptions....'
    @list_domains = (domains_from_folders + [*options[:list_domains]]).uniq
  end

  def domains_from_folders
    list_folders.flat_map do |folder|
      CleanboxFolderChecker.new(imap_connection,
                                folder: folder).domains.tap do |domains|
        domains.each do |domain|
          domain_map[domain] = folder
        end
      end
    end
  end

  def list_folders
    [*options[:list_folders] || list_folder]
  end

  def clean_inbox!
    new_messages.each(&:process!)
  end

  def new_messages
    imap_connection.fetch(new_message_ids, 'BODY.PEEK[HEADER]').map do |m|
      CleanboxMessage.new(m, self)
    end
  end

  def new_message_ids
    imap_connection.select 'INBOX'
    imap_connection.search(%w[UNSEEN NOT DELETED])
  end
end
