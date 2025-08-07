# frozen_string_literal: true

require 'set'

# Handles execution of message decisions and tracks folder changes
class MessageActionRunner
  attr_reader :changed_folders

  def initialize(imap:, junk_folder: 'Junk', pretending: false, logger: nil)
    @imap = imap
    @junk_folder = junk_folder
    @pretending = pretending
    @logger = logger || Logger.new($stdout)
    @changed_folders = Set.new
  end

  def execute(decision, message)
    case decision[:action]
    when :move
      execute_move(decision[:folder], message)
    when :junk
      execute_junk(message)
    when :keep
      @logger.debug "Keeping message #{message.seqno} from '#{message.from_address}' in inbox"
    else
      raise ArgumentError, "Unknown action: #{decision[:action]}"
    end
  end

  private

  def execute_move(folder, message)
    if @pretending
      @logger.info "PRETEND: Would move message #{message.seqno} from '#{message.from_address}' to folder '#{folder}'"
    else
      @logger.info "Moving message #{message.seqno} from '#{message.from_address}' to folder '#{folder}'"
      @imap.add_folder(folder) if folder_needs_creation?(folder)
      @imap.copy(message.seqno, folder)
      @imap.store(message.seqno, '+FLAGS', [:Deleted])
    end
    @changed_folders.add(folder)
  end

  def execute_junk(message)
    if @pretending
      @logger.info "PRETEND: Would move message #{message.seqno} from '#{message.from_address}' to junk folder '#{@junk_folder}'"
    else
      @logger.info "Moving message #{message.seqno} from '#{message.from_address}' to junk folder '#{@junk_folder}'"
      @imap.add_folder(@junk_folder) if folder_needs_creation?(@junk_folder)
      @imap.copy(message.seqno, @junk_folder)
      @imap.store(message.seqno, '+FLAGS', [:Deleted])
    end
    @changed_folders.add(@junk_folder)
  end

  def folder_needs_creation?(_folder)
    # This would need to be implemented based on how folder creation works
    # For now, we'll assume the folder exists or IMAP will handle creation
    false
  end
end
