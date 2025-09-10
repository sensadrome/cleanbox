# frozen_string_literal: true

require 'yaml'
require_relative 'configuration'

# Utility class for checking folders
class CleanboxFolderChecker < CleanboxConnection
  def initialize(imap_connection, options)
    super
    imap_connection.select(folder) if folder_exists?
  end

  def email_addresses
    return [] unless folder_exists?

    # Try to use cache first
    cached_email_addresses ||
      # Cache miss - fetch and cache
      fetch_and_cache_email_addresses
  end

  def domains
    return [] unless folder_exists?

    # Use cached email addresses if available, otherwise fetch
    emails = email_addresses
    emails.map { |email| email.split('@').last }.uniq
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
    options[:logger] || Logger.new($stdout)
  end

  def cached_email_addresses
    return nil unless cache_enabled?

    cache = self.class.load_folder_cache(folder)
    return nil unless cache

    current_stats = folder_stats
    return nil unless self.class.cache_valid?(folder, current_stats)

    logger.debug "Using cached email addresses for folder #{folder}"
    cache['emails']
  end

  def fetch_and_cache_email_addresses
    logger.debug "Fetching email addresses for folder #{folder}"
    emails = found_addresses.map { |a| [a.mailbox, a.host].join('@').downcase }.sort.uniq

    # Cache the results
    cache_results(emails) if cache_enabled?

    emails
  end

  def cache_results(emails)
    current_stats = folder_stats
    cache_data = {
      'emails' => emails,
      'stats' => current_stats,
      'cached_at' => Time.now.iso8601
    }
    self.class.save_folder_cache(folder, cache_data)
    logger.debug "Cached #{emails.length} email addresses for folder #{folder}"
  end

  def folder_stats
    return { messages: 0, uidnext: 0, uidvalidity: 0 } unless folder_exists?

    # Get IMAP folder status - much faster than processing messages
    status = imap_connection.status(folder, %w[MESSAGES UIDNEXT UIDVALIDITY])

    {
      messages: status['MESSAGES'].to_i,
      uidnext: status['UIDNEXT'].to_i,
      uidvalidity: status['UIDVALIDITY'].to_i
    }
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
    return [] if all_messages?
    return [] unless since.present?

    ['SINCE', since]
  end

  def all_messages?
    options[:all_messages]
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
    def data_dir
      Configuration.data_dir || Dir.pwd
    end

    def cache_dir
      File.join(data_dir, 'cache', 'folder_emails')
    end

    def cache_file_for_folder(folder_name)
      File.join(cache_dir, "#{folder_name}.yml")
    end

    def load_folder_cache(folder_name)
      cache_file = cache_file_for_folder(folder_name)
      return nil unless File.exist?(cache_file)

      YAML.load_file(cache_file)
    rescue Psych::SyntaxError
      nil
    end

    def save_folder_cache(folder_name, cache_data)
      FileUtils.mkdir_p(cache_dir)
      cache_file = cache_file_for_folder(folder_name)
      File.write(cache_file, cache_data.to_yaml)
    end

    def cache_valid?(folder_name, current_stats)
      cache = load_folder_cache(folder_name)
      return false unless cache

      cached_stats = cache['stats']
      return false unless cached_stats

      # Check if any of the IMAP status values have changed
      return false unless cached_stats[:messages] == current_stats[:messages]
      return false unless cached_stats[:uidnext] == current_stats[:uidnext]
      return false unless cached_stats[:uidvalidity] == current_stats[:uidvalidity]

      true
    end

    def update_cache_stats(folder_name, imap_connection)
      cache = load_folder_cache(folder_name)
      return unless cache

      # Get current folder stats
      status = imap_connection.status(folder_name, %w[MESSAGES UIDNEXT UIDVALIDITY])
      current_stats = {
        messages: status['MESSAGES'].to_i,
        uidnext: status['UIDNEXT'].to_i,
        uidvalidity: status['UIDVALIDITY'].to_i
      }

      # Update cache with new stats (keep existing emails)
      cache['stats'] = current_stats
      cache['cached_at'] = Time.now.iso8601

      save_folder_cache(folder_name, cache)
    end
  end
end
