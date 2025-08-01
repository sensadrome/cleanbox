# frozen_string_literal: true

# base class
class CleanboxConnection
  attr_accessor :imap_connection, :options
  def initialize(imap_connection, options)
    @imap_connection = imap_connection
    @options = options
  end

  def add_folder(folder)
    return if folders.include?(folder)

    imap_connection.create(folder)
    @folders.concat(folder)
  end

  protected

  def folders
    @folders ||= imap_folders.map(&:name)
  end

  def imap_folders
    @imap_folders ||= imap_connection.list('', '*')
  end

  def cleanbox_folders
    imap_folders.map do |folder|
      CleanboxFolder.new(folder, imap_connection.status(folder.name, %w[MESSAGES UNSEEN]))
    end
  end
end
