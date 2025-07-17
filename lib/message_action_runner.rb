# frozen_string_literal: true

require 'set'

# Handles execution of message decisions and tracks folder changes
class MessageActionRunner
  attr_reader :changed_folders

  def initialize(imap:, junk_folder: 'Junk')
    @imap = imap
    @junk_folder = junk_folder
    @changed_folders = Set.new
  end

  def execute(decision, message)
    case decision[:action]
    when :move
      execute_move(decision[:folder], message)
    when :junk
      execute_junk(message)
    when :keep
      # No action needed
    else
      raise ArgumentError, "Unknown action: #{decision[:action]}"
    end
  end

  private

  def execute_move(folder, message)
    @imap.add_folder(folder) if folder_needs_creation?(folder)
    @imap.copy(message.seqno, folder)
    @imap.store(message.seqno, '+FLAGS', [:Deleted])
    @changed_folders.add(folder)
  end

  def execute_junk(message)
    @imap.add_folder(@junk_folder) if folder_needs_creation?(@junk_folder)
    @imap.copy(message.seqno, @junk_folder)
    @imap.store(message.seqno, '+FLAGS', [:Deleted])
    @changed_folders.add(@junk_folder)
  end

  def folder_needs_creation?(folder)
    # This would need to be implemented based on how folder creation works
    # For now, we'll assume the folder exists or IMAP will handle creation
    false
  end
end 