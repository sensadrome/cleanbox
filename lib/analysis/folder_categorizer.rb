# frozen_string_literal: true

require 'logger'

module Analysis
  class FolderCategorizer
    attr_reader :folder, :message_count, :senders, :domains, :attributes

    def initialize(folder_data, imap_connection: nil, logger: nil)
      @folder = folder_data[:name]
      @message_count = folder_data[:message_count]
      @senders = folder_data[:senders] || []
      @domains = folder_data[:domains] || []
      @attributes = folder_data[:attributes] || {}
      @imap_connection = imap_connection
      @logger = logger || Logger.new(STDOUT)
    end

    def skip?
      should_skip_folder? || low_volume?
    end

    def categorization
      return :skip if skip?
      return :list if has_bulk_headers?
      return :list if list_folder_by_name?
      return :whitelist if whitelist_folder_by_name?

      categorize_by_senders
    end

    def categorization_reason
      case categorization
      when :list
        if has_bulk_headers?
          'found newsletter/bulk email headers'
        elsif list_folder_by_name?
          'folder name suggests list/newsletter content'
        else
          'sender patterns suggest list/newsletter content'
        end
      when :whitelist
        if whitelist_folder_by_name?
          'folder name suggests personal/professional emails'
        else
          'sender patterns suggest personal correspondence'
        end
      when :skip
        if low_volume?
          "low volume (#{message_count} messages)"
        else
          'system folder'
        end
      end
    end

    private

    def low_volume?
      message_count < 5
    end

    def has_bulk_headers?
      return false unless @imap_connection

      begin
        @imap_connection.select(@folder)
        message_ids = @imap_connection.search(['ALL']).last(20)

        return false if message_ids.empty?

        bulk_indicators = 0
        message_ids.each do |id|
          headers = @imap_connection.fetch(id, 'BODY.PEEK[HEADER]').first
          bulk_indicators += 1 if has_bulk_headers_pattern?(headers)
        end

        (bulk_indicators.to_f / message_ids.length) > 0.3
      rescue StandardError => e
        @logger.debug "Could not analyze headers for #{@folder}: #{e.message}"
        false
      end
    end

    def has_bulk_headers_pattern?(headers)
      header_text = headers.attr['BODY[HEADER]']

      bulk_patterns = [
        /^List-Unsubscribe:/i,
        /^Precedence:\s*bulk/i,
        /^X-Mailer:.*(mailing|newsletter|campaign)/i,
        /^X-Campaign:/i,
        /^X-Mailing-List:/i,
        /^Feedback-ID:/i,
        /^X-Auto-Response-Suppress:/i
      ]

      bulk_patterns.any? { |pattern| header_text.match?(pattern) }
    end

    def should_skip_folder?
      skip_patterns = [
        /^sent/i,           # Sent folders
        /^drafts?$/i,       # Drafts
        /^outbox$/i,        # Outbox
        /^trash$/i,         # Trash
        /^deleted/i,        # Deleted items
        /^junk/i,           # Junk/spam
        /^calendar/i,       # Calendar folders
        /^contacts$/i,      # Contacts
        /^notes$/i,         # Notes
        /^tasks$/i,         # Tasks
        /^templates$/i,     # Templates
        /^archive$/i,       # Archive
        /^conversation/i,   # Conversation history
        /^journal$/i,       # Journal
        /^apple mail to do$/i, # Apple Mail To Do
        /^notes_\d+$/i,     # Notes_0, Notes_1, etc.
        /^_unsubscribed$/i, # Unsubscribed
        /^old$/i,           # Old folders
        /^misc$/i           # Misc folders
      ]

      skip_patterns.any? { |pattern| @folder.downcase.match?(pattern) }
    end

    def list_folder_by_name?
      list_patterns = [
        # Major social media platforms
        /^facebook$/i, /^twitter$/i, /^linkedin$/i, /^instagram$/i,

        # Major e-commerce platforms
        /^amazon$/i, /^ebay$/i, /^paypal$/i,

        # Development and technology platforms
        /^github$/i, /^stackoverflow$/i, /^gitlab$/i,

        # Content categories that typically contain newsletters/notifications
        /^shopping/i, /^entertainment/i, /^movies/i, /^tv/i, /^streaming/i,
        /^lists?/i, /^newsletters?/i, /^notifications?/i, /^alerts/i,
        /^marketing/i, /^promotions/i, /^ads/i, /^deals/i,
        /^updates/i
      ]

      list_patterns.any? { |pattern| @folder.downcase.match?(pattern) }
    end

    def whitelist_folder_by_name?
      whitelist_patterns = [
        # Personal and family correspondence
        /^family/i, /^friends/i, /^personal/i, /^private/i,

        # Professional and business correspondence
        /^work/i, /^business/i, /^clients/i, /^customers/i,

        # High-priority and urgent communications
        /^important/i, /^urgent/i, /^priority/i, /^critical/i,

        # Professional project and meeting communications
        /^projects/i, /^meetings/i, /^appointments/i
      ]

      whitelist_patterns.any? { |pattern| @folder.downcase.match?(pattern) }
    end

    def categorize_by_senders
      return :skip if @senders.empty?

      # Count unique domains
      domains = @senders.map { |s| s.split('@').last }.uniq

      # If mostly single domain, likely a list folder
      return :list if domains.length <= 2 && @message_count > 50

      # If diverse senders with personal names, likely whitelist
      personal_domains = @senders.count { |s| s.split('@').first.match?(/^[a-z]+\.[a-z]+$/) }
      return :whitelist if personal_domains > @senders.length * 0.3

      # Default to list for high-volume folders
      @message_count > 100 ? :list : :skip
    end
  end
end
