# frozen_string_literal: true

require 'mail'
require 'date'

# Handles message decision making based on context
class MessageProcessor
  def initialize(context)
    @context = context
  end

  def decide_for_new_message(message)
    return { action: :junk } if blacklisted?(message)
    return { action: :keep } if whitelisted?(message)
    return { action: :keep } if hold_message?(message)
    return { action: :move, folder: list_folder_for(message) } if valid_list_email?(message)

    { action: :junk }
  end

  def decide_for_filing(message)
    folder = destination_folder_for(message)
    return { action: :move, folder: folder } if folder

    { action: :keep }
  end

  def decide_for_unjunking(message)
    # Same as filing but with clean sender map
    decide_for_filing(message)
  end

  private

  def blacklisted?(message)
    return false if @context[:unjunking]
    return true if @context[:blacklisted_emails]&.include?(message.from_address) # User blacklist always wins
    return false if whitelisted?(message) # Whitelist protects against junk folder false positives

    @context[:junk_emails]&.include?(message.from_address) # Junk folder as fallback
  end

  def whitelisted?(message)
    return false if @context[:unjunking]

    @context[:whitelisted_emails].include?(message.from_address) ||
      @context[:whitelisted_domains].include?(message.from_domain)
  end

  def hold_message?(message)
    # If we already know where it goes, don't hold it.
    return false if destination_folder_for(message).present?

    # If we running in strict mode don't keep anything we haven't already filed
    # Move messages from the Junk Folder to manage them
    return false if paranoid?

    # If it's probably spam don't hold it ;)
    return false unless valid_dkim_message?(message)

    # If we like spam, or quarantine it we will move it to the designated List folder
    return false if spammy? || quarantine?

    # Finally decide if we are going to leave it around or move it

    date_sent = message.date                # always a DateTime per your note
    return false unless date_sent           # if missing, don't hold

    cutoff = DateTime.now - hold_days       # subtracts in *days* (fractional preserved)
    cutoff < date_sent                      # => true means "hold"
  end

  def destination_folder_for(message)
    mapped_folder_from_address(message) || mapped_folder_from_domain(message)
  end

  def mapped_folder_from_address(message)
    sender_map[message.from_address]
  end

  def sender_map
    @context[:sender_map] || {}
  end

  def mapped_folder_from_domain(message)
    domain = message.from_domain
    
    # First try exact match (current behavior)
    return list_domain_map[domain] if list_domain_map.key?(domain)
    
    # Then try wildcard patterns
    wildcard_match = find_wildcard_match(domain)
    return list_domain_map[wildcard_match] if wildcard_match
    
    nil
  end

  def find_wildcard_match(domain)
    list_domain_map.keys.find do |pattern|
      next unless pattern.include?('*')
      
      # Convert wildcard pattern to regex
      # *.domain.com becomes ^[^.]+\.domain\.com$
      regex_pattern = pattern.gsub('*', '[^.]+').gsub('.', '\.')
      domain.match?(/^#{regex_pattern}$/)
    end
  end

  def list_domain_map
    @context[:list_domain_map] || {}
  end

  def paranoid?
    @context[:retention_policy] == :paranoid
  end

  def spammy?
    @context[:retention_policy] == :spammy
  end

  def quarantine?
    @context[:retention_policy] == :quarantine
  end

  def hold_days
    @context.fetch(:hold_days, 7)
  end

  def valid_list_email?(message)
    return false if fake_headers?(message)
    return true if mapped_folder_from_domain(message).present?
    return valid_dkim_message?(message) if spammy? || quarantine?

    false
  end

  def fake_headers?(message)
    fake_header_fields = %w[X-Antiabuse]

    fake_header_fields.any? do |fake_field|
      message.message.header_fields.any? { |field| field.name == fake_field }
    end
  end

  def valid_dkim_message?(message)
    auth_result = message.message.header_fields.detect { |f| f.name == 'Authentication-Results' }
    return false unless auth_result

    !(auth_result.to_s =~ /dkim=pass/).nil?
  end

  def list_folder_for(message)
    return quarantine_folder if quarantine?

    destination_folder_for(message) || @context[:list_folder]
  end

  def quarantine_folder
    @context[:quarantine_folder]
  end
end
