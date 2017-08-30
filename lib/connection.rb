# base class
class CleanboxConnection
  attr_accessor :imap_connection, :options
  def initialize(imap_connection, options)
    @imap_connection = imap_connection
    @options = options
  end

  protected

  def folders
    @folders ||= imap_connection.list('', '*').map(&:name)
  end
end
