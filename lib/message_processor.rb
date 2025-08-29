# frozen_string_literal: true

require 'mail'

# Handles message decision making based on context
class MessageProcessor
  def initialize(context)
    @context = context
  end

  def decide_for_new_message(message)
    return { action: :junk } if blacklisted?(message)
    return { action: :keep } if whitelisted?(message)
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

  def valid_list_email?(message)
    return false if fake_headers?(message)

    @context[:list_domains].include?(message.from_domain) || valid_dkim_message?(message)
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
    @context[:list_domain_map][message.from_domain] || @context[:list_folder]
  end

  def destination_folder_for(message)
    # Check sender map first
    folder = @context[:sender_map][message.from_address]
    return folder if folder

    # Check list domain map
    @context[:list_domain_map][message.from_domain]
  end
end
