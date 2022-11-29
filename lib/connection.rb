# frozen_string_literal: true

# base class
class CleanboxConnection
  attr_accessor :imap_connection, :options
  def initialize(imap_connection, options)
    @imap_connection = imap_connection
    @options = options
  end

  protected

  def folders
    @folders ||= imap_folders.map(&:name)
  end

  def imap_folders
    @imap_folders ||= imap_connection.list('', '*')
  end
end
