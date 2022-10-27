# frozen_string_literal: true

# Utility class for checking folders
class CleanboxFolderChecker < CleanboxConnection
  def initialize(imap_connection, options)
    super
    imap_connection.select(folder) if folder_exists?
  end

  def email_addresses
    return [] unless folder_exists?

    found_addresses.map { |a| [a.mailbox, a.host].join('@').downcase }.sort.uniq
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

  def found_addresses
    return [] unless message_ids.present?

    imap_connection.fetch(message_ids, 'ENVELOPE')
                   .flat_map { |m| m.attr['ENVELOPE'].send(address) }
  end

  def message_ids
    @message_ids ||= imap_connection.search(search_terms)
  end

  def search_terms
    %w[NOT DELETED] + date_search
  end

  def date_search
    return [] unless since

    ['SINCE', since]
  end

  def since
    options[:since]
  end

  def address
    options[:address] || :from
  end
end
