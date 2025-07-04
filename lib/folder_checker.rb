# frozen_string_literal: true

# Utility class for checking folders
class CleanboxFolderChecker < CleanboxConnection
  def initialize(imap_connection, options)
    super
    imap_connection.select(folder) if folder_exists?
  end

  def email_addresses
    return [] unless folder_exists?

    # Try to use cache first
    cached_emails = get_cached_email_addresses
    return cached_emails if cached_emails

    # Cache miss - fetch and cache
    fetch_and_cache_email_addresses
  end

  def domains
    return [] unless folder_exists?

    found_addresses.map(&:host)
  end

  private

  def folder
    options[:folder]
  end

  def folder_exists?
    folders.include?(folder)
  end

  def logger
    @logger ||= logger_object
  end

  def logger_object
    options[:logger] || Logger.new(STDOUT)
  end

  def get_cached_email_addresses
    return nil unless cache_enabled?
    
    cache = self.class.load_folder_cache(folder)
    return nil unless cache
    
    current_stats = get_folder_stats
    return nil unless self.class.cache_valid?(folder, current_stats[:email_count], current_stats[:last_message_date])
    
    logger.debug "Using cached email addresses for folder #{folder}"
    cache['emails']
  end

  def fetch_and_cache_email_addresses
    logger.debug "Fetching email addresses for folder #{folder}"
    
    emails = found_addresses.map { |a| [a.mailbox, a.host].join('@').downcase }.sort.uniq
    
    # Cache the results
    if cache_enabled?
      current_stats = get_folder_stats
      cache_data = {
        'emails' => emails,
        'email_count' => emails.length,
        'last_message_date' => current_stats[:last_message_date],
        'cached_at' => Time.now.iso8601
      }
      self.class.save_folder_cache(folder, cache_data)
      logger.debug "Cached #{emails.length} email addresses for folder #{folder}"
    end
    
    emails
  end

  def get_folder_stats
    return { email_count: 0, last_message_date: Time.now.iso8601 } unless message_ids.present?
    
    # Get the last message date
    last_message = imap_connection.fetch(message_ids.last, 'ENVELOPE').first
    last_date = last_message.attr['ENVELOPE'].date&.iso8601 || Time.now.iso8601
    
    # Count unique email addresses
    email_count = found_addresses.map { |a| [a.mailbox, a.host].join('@').downcase }.uniq.length
    
    { email_count: email_count, last_message_date: last_date }
  end

  def cache_enabled?
    # Can be overridden by options[:cache] or environment variable
    options[:cache] != false && ENV['CLEANBOX_CACHE'] != 'false'
  end

  def found_addresses
    return [] unless message_ids.present?

    logger.debug "Found #{message_ids.length} messages in folder #{folder}"

    all_envelopes.flat_map { |m| m.attr['ENVELOPE'].send(address) }
  end

  def message_ids
    @message_ids ||= imap_connection.search(search_terms)
  end

  def search_terms
    %w[NOT DELETED] + date_search
  end

  def date_search
    return [] unless since.present?

    ['SINCE', since]
  end

  def since
    options[:since]
  end

  def all_envelopes
    message_ids.each_slice(800).flat_map do |slice|
      imap_connection.fetch(slice, 'ENVELOPE')
    end
  end

  def address
    options[:address] || :from
  end

  # Class methods for cache management
  class << self
    def cache_dir
      File.join(Dir.pwd, 'cache', 'folder_emails')
    end

    def cache_file_for_folder(folder_name)
      File.join(cache_dir, "#{folder_name}.yml")
    end

    def load_folder_cache(folder_name)
      cache_file = cache_file_for_folder(folder_name)
      return nil unless File.exist?(cache_file)
      
      YAML.load_file(cache_file)
    rescue
      nil
    end

    def save_folder_cache(folder_name, cache_data)
      FileUtils.mkdir_p(cache_dir)
      cache_file = cache_file_for_folder(folder_name)
      File.write(cache_file, cache_data.to_yaml)
    end

    def cache_valid?(folder_name, current_email_count, current_last_message_date)
      cache = load_folder_cache(folder_name)
      return false unless cache
      
      # Check if email count matches
      return false unless cache['email_count'] == current_email_count
      
      # Check if last message date is the same or newer
      cached_date = Time.parse(cache['last_message_date']) rescue nil
      current_date = Time.parse(current_last_message_date) rescue nil
      
      return false unless cached_date && current_date
      return false unless current_date <= cached_date
      
      true
    end
  end
end
