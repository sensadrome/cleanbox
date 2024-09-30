# frozen_string_literal: true

require 'forwardable'

# utility class to display info about imap folder
class CleanboxFolder
  attr_accessor :imap_folder, :status, :attrs

  extend Forwardable

  def_delegators :@imap_folder, :name, :delim

  def initialize(imap_folder, status)
    @imap_folder = imap_folder
    @status = status
    @attrs = imap_folder.attr.dup
    @children = attrs.delete(:Haschildren)
    @no_children = attrs.delete(:Hasnochildren)
  end

  def to_s
    "#{name}#{separator}#{extra_info}#{counts}"
  end

  private

  def separator
    delim if children?
  end

  def children?
    @children.present?
  end

  def extra_info
    return unless attrs.present?

    " [#{attrs.join ', '}]"
  end

  def counts
    " (Total: #{total}#{unseen_count})"
  end

  def total
    status['MESSAGES'].presence&.to_i
  end

  def unseen_count
    return unless unseen.positive?

    ", #{unseen} new"
  end

  def unseen
    status['UNSEEN'].to_i
  end
end
