# frozen_string_literal: true

require 'logger'

module Analysis
  # Analyse patterns within email folders
  class EmailAnalyzer
    attr_reader :analysis_results, :imap_connection, :folder_categorizer_class, :analysis_mode
    attr_accessor :logger

    def initialize(imap_connection, logger: nil, folder_categorizer_class: FolderCategorizer, analysis_mode: :full,
                   blacklist_folder: nil)
      @imap_connection = imap_connection
      @logger = logger || Logger.new($stdout)
      @folder_categorizer_class = folder_categorizer_class
      @analysis_mode = analysis_mode
      @analysis_results = {}
      @analysis_results[:sent_items] = {}
      @blacklist_folder = blacklist_folder
    end

    def analyze_folders(progress_callback = nil)
      folders = []
      skipped_folders = []

      total_folders = imap_folders.length

      @logger.debug "Found #{total_folders} folders to analyze..."

      imap_folders.each_with_index do |folder, index|
        next if folder.name == 'INBOX'
        next if folder.name == @blacklist_folder

        # Call progress callback if provided
        progress_callback&.call(index + 1, total_folders, folder.name)

        @logger.debug "Analyzing folder #{index + 1}/#{total_folders}: #{folder.name}"

        folder_data = build_folder_data(folder)
        categorizer = @folder_categorizer_class.new(
          folder_data,
          imap_connection: @imap_connection,
          logger: @logger
        )

        if categorizer.skip?
          @logger.debug "  Skipping #{folder.name} (#{categorizer.categorization_reason})"
          skipped_folders << folder.name
          next
        end

        @logger.debug "  Categorized as #{categorizer.categorization} (#{categorizer.categorization_reason})"
        folder_data[:categorization] = categorizer.categorization
        folder_data[:categorization_reason] = categorizer.categorization_reason
        folders << folder_data
      end

      @logger.debug "Analysis complete: #{folders.length} folders analyzed, #{skipped_folders.length} skipped"
      @analysis_results[:folders] = folders
      @analysis_results[:skipped_folders] = skipped_folders

      # Return structured data for friendly display
      {
        folders: folders.sort_by { |f| -f[:message_count] },
        skipped_folders: skipped_folders,
        total_analyzed: folders.length,
        total_skipped: skipped_folders.length,
        total_folders: total_folders
      }
    end

    def analyze_sent_items
      sent_folder = detect_sent_folder
      return { frequent_correspondents: [], total_sent: 0, sample_size: 0 } unless sent_folder

      begin
        @logger.debug "Analyzing sent items from #{sent_folder}"
        @imap_connection.select(sent_folder)
        message_count = @imap_connection.search(['ALL']).length

        sample_size = [message_count, 200].min
        message_ids = @imap_connection.search(['ALL']).last(sample_size)

        return { frequent_correspondents: [], total_sent: message_count, sample_size: 0 } if message_ids.empty?

        @logger.debug "Analyzing #{sample_size} sent messages"
        envelopes = @imap_connection.fetch(message_ids, 'ENVELOPE')
        recipients = extract_recipients(envelopes)
        frequency = recipients.group_by(&:itself).transform_values(&:length)
        frequent_correspondents = frequency.sort_by { |_, count| -count }.first(20)

        @logger.debug "Found #{frequent_correspondents.length} frequent correspondents"
        {
          frequent_correspondents: frequent_correspondents,
          total_sent: message_count,
          sample_size: sample_size
        }
      rescue StandardError => e
        @logger.error "Could not analyze sent items: #{e.message}"
        { frequent_correspondents: [], total_sent: 0, sample_size: 0 }
      end
    end

    def analyze_domain_patterns
      all_domains = @analysis_results[:folders].flat_map { |f| f[:domains] }.uniq

      patterns = {}

      all_domains.each do |domain|
        category = categorize_domain(domain)
        patterns[domain] = category
      end

      patterns
    end

    def generate_recommendations(domain_mapper_class: DomainMapper)
      recommendations = {
        whitelist_folders: [],
        list_folders: [],
        domain_mappings: {},
        frequent_correspondents: @analysis_results[:sent_items][:frequent_correspondents] || []
      }

      @analysis_results[:folders].each do |folder|
        case folder[:categorization]
        when :whitelist
          recommendations[:whitelist_folders] << folder[:name]
        when :list
          recommendations[:list_folders] << folder[:name]
        end
      end

      domain_mapper = domain_mapper_class.new(@analysis_results[:folders])
      recommendations[:domain_mappings] = domain_mapper.generate_mappings
      recommendations
    end

    private

    def folders
      @folders ||= imap_folders.map(&:name)
    end

    def imap_folders
      @imap_folders ||= imap_connection.list('', '*')
    end

    def build_folder_data(folder)
      case @analysis_mode
      when :skip
        build_folder_data_from_config(folder)
      when :partial
        build_folder_data_partial(folder)
      else # :full
        build_folder_data_full(folder)
      end
    end

    def build_folder_data_from_config(folder)
      existing_data = existing_folder_data(folder.name)
      if existing_data
        @logger.debug "  Using existing config for #{folder.name}"
        existing_data.merge(
          name: folder.name,
          attributes: folder.attr
        )
      else
        @logger.debug "  No existing config for #{folder.name}, using defaults"
        {
          name: folder.name,
          message_count: 0,
          senders: [],
          domains: [],
          attributes: folder.attr
        }
      end
    end

    def build_folder_data_partial(folder)
      existing_data = existing_folder_data(folder.name)
      if existing_data
        @logger.debug "  Using existing config for #{folder.name}"
        existing_data.merge(
          name: folder.name,
          attributes: folder.attr
        )
      else
        @logger.debug "  Analyzing new folder #{folder.name}"
        build_folder_data_full(folder)
      end
    end

    def build_folder_data_full(folder)
      @logger.debug "  Selecting folder #{folder.name}"
      @imap_connection.select(folder.name)

      @logger.debug '  Getting folder status'
      status = @imap_connection.status(folder.name, %w[MESSAGES UNSEEN])
      message_count = status['MESSAGES'].to_i

      @logger.debug "  Analyzing #{message_count} messages in #{folder.name}"
      senders = analyze_folder_senders(folder.name, message_count)

      {
        name: folder.name,
        message_count: message_count,
        senders: senders,
        domains: senders.map { |s| s.split('@').last }.uniq,
        attributes: folder.attr
      }
    rescue StandardError => e
      @logger.error "Could not analyze folder #{folder.name}: #{e.message}"
      {
        name: folder.name,
        message_count: 0,
        senders: [],
        domains: [],
        attributes: folder.attr
      }
    end

    def existing_folder_data(folder_name)
      # Check if folder exists in whitelist or list folders
      categorization = if whitelist_folders.include?(folder_name)
                         :whitelist
                       elsif list_folders.include?(folder_name)
                         :list
                       else
                         return nil # Folder not in existing config
                       end

      {
        message_count: message_count_for_folder(folder_name),
        senders: cached_senders(folder_name),
        domains: cached_senders(folder_name).map { |s| s.split('@').last }.uniq,
        categorization: categorization,
        categorization_reason: 'from config file'
      }
    end

    def whitelist_folders
      @whitelist_folders ||= Configuration.options[:whitelist_folders] || []
    end

    def list_folders
      @list_folders ||= Configuration.options[:list_folders] || []
    end

    def cached_senders(_folder_name)
      # TODO: Implement actual cache lookup
      # For now, return empty array
      []
    end

    def message_count_for_folder(folder_name)
      @imap_connection.select(folder_name)
      status = @imap_connection.status(folder_name, %w[MESSAGES])
      status['MESSAGES'].to_i
    rescue StandardError => e
      @logger.warn "Could not get message count for #{folder_name}: #{e.message}"
      0
    end

    def analyze_folder_senders(folder_name, message_count)
      return [] if message_count.zero?

      begin
        sample_size = [message_count, 100].min
        @logger.debug "    Fetching #{sample_size} messages for sender analysis"
        @imap_connection.select(folder_name)
        message_ids = @imap_connection.search(['ALL']).last(sample_size)

        return [] if message_ids.empty?

        @logger.debug '    Fetching message envelopes'
        envelopes = @imap_connection.fetch(message_ids, 'ENVELOPE')
        senders = extract_senders(envelopes)
        @logger.debug "    Found #{senders.length} unique senders"
        senders
      rescue StandardError => e
        @logger.error "Could not analyze senders for #{folder_name}: #{e.message}"
        []
      end
    end

    def extract_senders(envelopes)
      envelopes.map do |env|
        envelope = env.attr['ENVELOPE']
        next unless envelope&.from&.first

        mailbox = envelope.from.first.mailbox
        host = envelope.from.first.host
        "#{mailbox}@#{host}".downcase
      end.compact.uniq
    end

    def extract_recipients(envelopes)
      envelopes.map do |env|
        envelope = env.attr['ENVELOPE']
        next unless envelope&.to&.first

        mailbox = envelope.to.first.mailbox
        host = envelope.to.first.host
        "#{mailbox}@#{host}".downcase
      end.compact
    end

    def detect_sent_folder
      sent_folders = ['Sent Items', 'Sent', '[Gmail]/Sent Mail', 'Sent Mail']

      sent_folders.find do |folder_name|
        @imap_connection.select(folder_name)
        true
      rescue StandardError
        false
      end
    end

    def categorize_domain(domain)
      case domain.downcase
      when /facebook\.com|twitter\.com|instagram\.com|linkedin\.com|tiktok\.com/
        'social'
      when /github\.com|gitlab\.com|bitbucket\.org|stackoverflow\.com/
        'development'
      when /newsletter|mailchimp|constantcontact|mailerlite|convertkit/
        'newsletter'
      when /amazon\.com|ebay\.com|etsy\.com|shopify\.com/
        'shopping'
      when /bank|paypal|stripe|square/
        'financial'
      when /google\.com|microsoft\.com|apple\.com|adobe\.com/
        'tech_company'
      else
        'other'
      end
    end
  end
end
