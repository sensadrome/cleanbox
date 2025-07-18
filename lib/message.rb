# frozen_string_literal: true

require 'mail'

# Message data container - provides access to message properties
class CleanboxMessage < SimpleDelegator
  def initialize(object)
    super(object)
  end

  def from_address
    message.from.first.downcase
  end

  def from_domain
    from_address.split('@').last
  end

  def message
    @message ||= Mail.read_from_string(attr['BODY[HEADER]'])
  end

  def authentication_result
    @authentication_result ||= message.header_fields.detect do |f|
      f.name == 'Authentication-Results'
    end
  end

  def has_fake_headers?
    fake_header_fields.any? do |fake_field|
      message.header_fields.any? { |field| field.name == fake_field }
    end
  end

  private

  def fake_header_fields
    %w[X-Antiabuse]
  end
end
