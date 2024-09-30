# frozen_string_literal: true

# message processing class
class CleanboxMessage < SimpleDelegator
  attr_reader :cleanbox

  def initialize(object, cleanbox = nil)
    @cleanbox = cleanbox
    super(object)
  end

  def process!
    return keep! if whitelisted?
    return move!(list_folder) if valid_list_email?

    # return move!(junk_folder) if blacklisted?
    move!(junk_folder) unless cleanbox.unjunking?
  end

  def file!
    if destination_folder.present? || folder_from_map.present?
      move!(destination_folder)
    else
      keep!
    end
  end

  private

  def whitelisted?
    return false if cleanbox.unjunking?

    cleanbox.whitelisted_emails.include?(from_address) ||
      cleanbox.whitelisted_domains.include?(from_domain)
  end

  def from_address
    message.from.first.downcase
  end

  def message
    @message ||= Mail.read_from_string(attr['BODY[HEADER]'])
  end

  def from_domain
    from_address.split('@').last
  end

  def keep!
    cleanbox.logger.debug "Keeping mail from #{from_address}"
  end

  def blacklisted?
    cleanbox.blacklisted_emails.include?(from_address)
  end

  def move!(folder)
    cleanbox.logger.info "Moving mail from #{from_address} to #{folder}"
    return if pretend?

    move_message_to_folder(folder)
  end

  def move_message_to_folder(folder)
    imap_connection.create(folder) unless folder_exists?(folder)
    imap_connection.copy(seqno, folder)
    imap_connection.store(seqno, '+FLAGS', [:Deleted])
  end

  def pretend?
    cleanbox.pretending?
  end

  def imap_connection
    cleanbox.imap_connection
  end

  def folder_exists?(folder)
    cleanbox.send(:folders).include?(folder)
  end

  def junk_folder
    cleanbox.junk_folder
  end

  def valid_list_email?
    return false if fake_headers?

    cleanbox.list_domains.include?(from_domain) || valid_dkim_message?
  end

  def fake_headers?
    fake_header_fields.any? do |fake_field|
      message.header_fields.any? { |field| field == fake_field }
    end
  end

  def fake_header_fields
    %w[X-Antiabuse]
  end

  def valid_dkim_message?
    return false unless authentication_result

    !(authentication_result =~ /dkim=pass/).nil?
  end

  def authentication_result
    @authentication_result ||= message.header_fields.detect do |f|
      f.name == 'Authentication-Results'
    end
  end

  def list_folder
    folder_from_map || cleanbox.list_folder
  end

  def folder_from_map
    return unless domain_map.is_a?(Hash)

    domain_map[from_domain]
  end

  def domain_map
    cleanbox.domain_map
  end

  def destination_folder
    cleanbox.sender_map[from_address] || folder_from_map
  end
end
