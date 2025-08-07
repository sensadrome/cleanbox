# frozen_string_literal: true

require 'logger'
require_relative '../analysis/email_analyzer'
require_relative '../analysis/folder_categorizer'
require_relative '../analysis/domain_mapper'

module CLI
  class AnalyzerCLI
    attr_reader :options, :email_analyzer

    def initialize(imap_connection, options)
      @imap_connection = imap_connection
      @options = options
      @logger = Logger.new(STDOUT)
      @logger.level = options[:verbose] ? Logger::DEBUG : Logger::INFO

      # Initialize analyzer components
      @email_analyzer = Analysis::EmailAnalyzer.new(
        @imap_connection,
        logger: @logger,
        folder_categorizer_class: Analysis::FolderCategorizer
      )
    end

    def run
      subcommand = ARGV.first

      case subcommand
      when 'folders'
        analyze_folders
      when 'inbox'
        analyze_inbox
      when 'senders'
        analyze_senders
      when 'domains'
        analyze_domains
      when 'recommendations'
        analyze_recommendations
      when 'summary'
        analyze_summary
      when nil, ''
        show_help
      else
        show_help
      end
    end

    private

    def analyze_folders
      puts '📁 Folder Analysis'
      puts '=================='
      puts ''

      puts '🔍 Analyzing your email folders...'

      # Set logger level based on user preferences
      @email_analyzer.logger.level = if @options[:verbose]
                                       Logger::DEBUG
                                     else
                                       Logger::FATAL
                                     end

      # Show progress for folder analysis
      puts '  Scanning folders...'

      # Create progress callback for user-friendly updates
      progress_callback = lambda do |current, total, folder_name|
        show_progress("  Processing folder #{current} of #{total}: #{folder_name}")
      end

      # Get folder analysis
      folder_results = @email_analyzer.analyze_folders(progress_callback)
      folders = folder_results[:folders]

      # Clear progress and add a newline to ensure clean output
      clear_progress
      puts '' # Add newline after clearing
      puts "  Found #{folder_results[:total_analyzed]} folders to analyze"

      puts '📧 Checking your sent items...'
      sent_items = @email_analyzer.analyze_sent_items

      # Store results for other analyses
      @email_analyzer.instance_variable_set(:@analysis_results, {
                                              folders: folders,
                                              sent_items: sent_items
                                            })

      clear_progress # Final clear to ensure no artifacts
      puts ''
      puts '✅ Analysis complete!'
      puts ''

      if @options[:brief]
        show_brief_folder_analysis(folder_results)
      elsif @options[:detailed]
        show_detailed_folder_analysis(folders)
      else
        show_standard_folder_analysis(folders)
      end

      # Show date range impact
      show_date_range_impact(folders)
    end

    def analyze_inbox
      puts '📧 Inbox Analysis'
      puts '================='
      puts ''

      puts '🔍 Analyzing your inbox...'
      inbox_data = analyze_inbox_state

      puts '✅ Analysis complete!'
      puts ''

      if @options[:brief]
        show_brief_inbox_analysis(inbox_data)
      elsif @options[:detailed]
        show_detailed_inbox_analysis(inbox_data)
      else
        show_standard_inbox_analysis(inbox_data)
      end
    end

    def analyze_senders
      puts '👤 Sender Analysis'
      puts '=================='
      puts ''

      puts '🔍 Analyzing sender patterns...'
      # Get comprehensive sender analysis
      folder_results = @email_analyzer.analyze_folders
      folders = folder_results[:folders]
      sent_items = @email_analyzer.analyze_sent_items

      sender_analysis = analyze_sender_patterns(folders, sent_items)

      puts '✅ Analysis complete!'
      puts ''

      if @options[:brief]
        show_brief_sender_analysis(sender_analysis)
      elsif @options[:detailed]
        show_detailed_sender_analysis(sender_analysis)
      else
        show_standard_sender_analysis(sender_analysis)
      end
    end

    def analyze_domains
      puts '🌐 Domain Analysis'
      puts '=================='
      puts ''

      puts '🔍 Analyzing domain patterns...'
      folder_results = @email_analyzer.analyze_folders
      folders = folder_results[:folders]
      domain_patterns = @email_analyzer.analyze_domain_patterns

      domain_analysis = analyze_domain_patterns(folders, domain_patterns)

      puts '✅ Analysis complete!'
      puts ''

      if @options[:brief]
        show_brief_domain_analysis(domain_analysis)
      elsif @options[:detailed]
        show_detailed_domain_analysis(domain_analysis)
      else
        show_standard_domain_analysis(domain_analysis)
      end
    end

    def analyze_recommendations
      puts '🤖 Configuration Recommendations'
      puts '==============================='
      puts ''

      puts '🔍 Analyzing your email patterns...'
      # Get comprehensive analysis
      folder_results = @email_analyzer.analyze_folders
      folders = folder_results[:folders]
      sent_items = @email_analyzer.analyze_sent_items

      @email_analyzer.instance_variable_set(:@analysis_results, {
                                              folders: folders,
                                              sent_items: sent_items
                                            })

      puts '🤖 Generating recommendations...'
      recommendations = @email_analyzer.generate_recommendations(
        domain_mapper_class: Analysis::DomainMapper
      )

      puts '✅ Analysis complete!'
      puts ''

      show_recommendations(recommendations, folders)
    end

    def analyze_summary
      puts '📊 Comprehensive Analysis Summary'
      puts '================================'
      puts ''

      puts '🔍 Running comprehensive analysis...'
      # Run all analyses
      folder_results = @email_analyzer.analyze_folders
      folders = folder_results[:folders]
      sent_items = @email_analyzer.analyze_sent_items
      domain_patterns = @email_analyzer.analyze_domain_patterns

      @email_analyzer.instance_variable_set(:@analysis_results, {
                                              folders: folders,
                                              sent_items: sent_items,
                                              domain_patterns: domain_patterns
                                            })

      puts '🤖 Generating recommendations...'
      recommendations = @email_analyzer.generate_recommendations(
        domain_mapper_class: Analysis::DomainMapper
      )

      puts '✅ Analysis complete!'
      puts ''

      show_comprehensive_summary(folders, sent_items, domain_patterns, recommendations)
    end

    def show_help
      puts 'Cleanbox Analysis Commands'
      puts '=========================='
      puts ''
      puts 'Usage: ./cleanbox analyze [options] <subcommand>'
      puts ''
      puts 'Subcommands:'
      puts '  folders         - Analyze all folders or specific folders'
      puts '  inbox          - Analyze inbox state and patterns'
      puts '  senders        - Analyze sender patterns across folders'
      puts '  domains        - Analyze domain patterns and mappings'
      puts '  recommendations - Generate recommendations for configuration'
      puts '  summary        - Comprehensive analysis summary'
      puts ''
      puts 'Options:'
      puts '  --brief        - Show high-level summary only'
      puts '  --detailed     - Show detailed analysis with examples'
      puts '  --verbose      - Show very detailed analysis'
      puts '  --folder FOLDER - Analyze specific folder only'
      puts ''
      puts 'Examples:'
      puts '  ./cleanbox analyze folders'
      puts '  ./cleanbox analyze inbox --detailed'
      puts '  ./cleanbox analyze summary --brief'
      puts ''
    end

    # Analysis helper methods
    def analyze_inbox_state
      @imap_connection.select('INBOX')
      message_count = @imap_connection.search(['ALL']).length
      unread_count = @imap_connection.search(['UNSEEN']).length

      # Sample recent messages for analysis
      sample_size = [message_count, 50].min
      message_ids = @imap_connection.search(['ALL']).last(sample_size)

      envelopes = @imap_connection.fetch(message_ids, 'ENVELOPE')
      senders = extract_senders(envelopes)

      {
        total_messages: message_count,
        unread_messages: unread_count,
        senders: senders,
        domains: senders.map { |s| s.split('@').last }.uniq,
        sample_size: sample_size
      }
    end

    def analyze_sender_patterns(folders, sent_items)
      all_senders = {}

      # Collect senders from all folders
      folders.each do |folder|
        folder[:senders].each do |sender|
          all_senders[sender] ||= { folders: [], total_count: 0 }
          all_senders[sender][:folders] << folder[:name]
          all_senders[sender][:total_count] += 1
        end
      end

      # Add sent items analysis
      sent_items[:frequent_correspondents].each do |email, count|
        all_senders[email] ||= { folders: [], total_count: 0 }
        all_senders[email][:sent_count] = count
      end

      all_senders
    end

    def analyze_domain_patterns(folders, domain_patterns)
      domain_analysis = {}

      folders.each do |folder|
        folder[:domains].each do |domain|
          domain_analysis[domain] ||= { folders: [], total_messages: 0, categorization: nil }
          domain_analysis[domain][:folders] << folder[:name]
          domain_analysis[domain][:total_messages] += folder[:message_count]
          domain_analysis[domain][:categorization] = domain_patterns[domain]
        end
      end

      domain_analysis
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

    def show_progress(message)
      # Clear the line first, then show new message
      print "\r\033[K#{message}"
      $stdout.flush
    end

    def clear_progress
      # Use ANSI escape sequence to clear the line
      print "\r\033[K"
      $stdout.flush
    end

    # Display methods for different analysis levels
    def show_brief_folder_analysis(folder_results)
      puts '📊 Folder Summary:'
      puts "  Total folders analyzed: #{folder_results[:total_analyzed]}"
      puts "  Folders skipped: #{folder_results[:total_skipped]}"
      puts "  Total messages: #{folder_results[:folders].sum { |f| f[:message_count] }}"
      puts "  Whitelist folders: #{folder_results[:folders].count { |f| f[:categorization] == :whitelist }}"
      puts "  List folders: #{folder_results[:folders].count { |f| f[:categorization] == :list }}"
      puts ''
    end

    def show_standard_folder_analysis(folders)
      puts '📊 Folder Analysis:'
      puts ''

      folders.each do |folder|
        puts "📁 #{folder[:name]}"
        puts "   Messages: #{folder[:message_count]}"
        puts "   Categorization: #{folder[:categorization].to_s.upcase}"
        puts "   Senders: #{folder[:senders].length}"
        puts "   Domains: #{folder[:domains].length}"
        puts ''
      end
    end

    def show_detailed_folder_analysis(folders)
      show_standard_folder_analysis(folders)

      puts '📈 Detailed Statistics:'
      puts "  Average messages per folder: #{folders.sum { |f| f[:message_count] } / folders.length.to_f}"
      puts "  Most active folder: #{folders.max_by { |f| f[:message_count] }[:name]}"
      puts "  Least active folder: #{folders.min_by { |f| f[:message_count] }[:name]}"
      puts ''
    end

    def show_date_range_impact(folders)
      puts '📅 Date Range Impact Analysis:'
      puts ''

      # Show current date range settings
      valid_since_months = @options[:valid_since_months] || 12
      cutoff_date = Date.today << valid_since_months

      puts "  Current date range: #{valid_since_months} months (since #{cutoff_date.strftime('%Y-%m-%d')})"
      puts ''

      # Identify potential issues
      low_volume_folders = folders.select { |f| f[:message_count] < 10 }
      if low_volume_folders.any?
        puts '  ⚠️  Low volume folders that might miss patterns:'
        low_volume_folders.each do |folder|
          puts "     • #{folder[:name]} (#{folder[:message_count]} messages)"
        end
        puts ''
      end

      puts '  💡 Consider adjusting --valid-since-months for better pattern detection'
      puts ''
    end

    def show_brief_inbox_analysis(inbox_data)
      puts '📧 Inbox Summary:'
      puts "  Total messages: #{inbox_data[:total_messages]}"
      puts "  Unread messages: #{inbox_data[:unread_messages]}"
      puts "  Unique senders: #{inbox_data[:senders].length}"
      puts "  Unique domains: #{inbox_data[:domains].length}"
      puts ''
    end

    def show_standard_inbox_analysis(inbox_data)
      show_brief_inbox_analysis(inbox_data)

      puts '📊 Top Domains in Inbox:'
      domain_counts = inbox_data[:senders].map { |s| s.split('@').last }.group_by(&:itself).transform_values(&:length)
      domain_counts.sort_by { |_, count| -count }.first(10).each do |domain, count|
        puts "  • #{domain}: #{count} emails"
      end
      puts ''
    end

    def show_detailed_inbox_analysis(inbox_data)
      show_standard_inbox_analysis(inbox_data)

      puts '📈 Inbox Health Metrics:'
      read_rate = ((inbox_data[:total_messages] - inbox_data[:unread_messages]) / inbox_data[:total_messages].to_f * 100).round(1)
      puts "  Read rate: #{read_rate}%"
      puts "  Average senders per message: #{inbox_data[:senders].length / inbox_data[:sample_size].to_f}"
      puts ''
    end

    def show_brief_sender_analysis(sender_analysis)
      puts '👤 Sender Summary:'
      puts "  Total unique senders: #{sender_analysis.length}"
      puts "  Senders in multiple folders: #{sender_analysis.count { |_, data| data[:folders].length > 1 }}"
      puts "  Frequent correspondents: #{sender_analysis.count do |_, data|
        data[:sent_count] && data[:sent_count] > 5
      end}"
      puts ''
    end

    def show_standard_sender_analysis(sender_analysis)
      show_brief_sender_analysis(sender_analysis)

      puts '📊 Top Senders:'
      sender_analysis.sort_by { |_, data| -(data[:total_count] || 0) }.first(10).each do |sender, data|
        folders_str = data[:folders].join(', ')
        puts "  • #{sender}: #{data[:total_count]} emails in #{folders_str}"
      end
      puts ''
    end

    def show_detailed_sender_analysis(sender_analysis)
      show_standard_sender_analysis(sender_analysis)

      puts '🔍 Cross-Folder Senders:'
      cross_folder_senders = sender_analysis.select { |_, data| data[:folders].length > 1 }
      cross_folder_senders.first(10).each do |sender, data|
        puts "  • #{sender}: #{data[:folders].join(' → ')}"
      end
      puts ''
    end

    def show_brief_domain_analysis(domain_analysis)
      puts '🌐 Domain Summary:'
      puts "  Total unique domains: #{domain_analysis.length}"
      puts "  Domains in multiple folders: #{domain_analysis.count { |_, data| data[:folders].length > 1 }}"
      puts "  Most common category: #{domain_analysis.values.map do |d|
        d[:categorization]
      end.compact.group_by(&:itself).max_by { |_, v| v.length }&.first}"
      puts ''
    end

    def show_standard_domain_analysis(domain_analysis)
      show_brief_domain_analysis(domain_analysis)

      puts '📊 Top Domains:'
      domain_analysis.sort_by { |_, data| -data[:total_messages] }.first(10).each do |domain, data|
        puts "  • #{domain}: #{data[:total_messages]} messages (#{data[:categorization]})"
      end
      puts ''
    end

    def show_detailed_domain_analysis(domain_analysis)
      show_standard_domain_analysis(domain_analysis)

      puts '🔗 Domain Mappings Needed:'
      unmapped_domains = domain_analysis.select { |_, data| data[:folders].length > 1 }
      unmapped_domains.first(10).each do |domain, data|
        puts "  • #{domain}: appears in #{data[:folders].join(', ')}"
      end
      puts ''
    end

    def show_recommendations(recommendations, folders)
      puts '✅ Whitelist Folders:'
      recommendations[:whitelist_folders].each do |folder_name|
        folder = folders.find { |f| f[:name] == folder_name }
        puts "  • #{folder_name} (#{folder[:message_count]} messages)"
      end
      puts ''

      puts '📬 List Folders:'
      recommendations[:list_folders].each do |folder_name|
        folder = folders.find { |f| f[:name] == folder_name }
        puts "  • #{folder_name} (#{folder[:message_count]} messages)"
      end
      puts ''

      if recommendations[:domain_mappings].any?
        puts '🔗 Domain Mappings:'
        recommendations[:domain_mappings].each do |domain, folder|
          puts "  • #{domain} → #{folder}"
        end
        puts ''
      end

      puts '💡 Configuration Recommendations:'
      puts "  • Add whitelist_folders: #{recommendations[:whitelist_folders].inspect}"
      puts "  • Add list_folders: #{recommendations[:list_folders].inspect}"
      if recommendations[:domain_mappings].any?
        puts "  • Add list_domain_map: #{recommendations[:domain_mappings].inspect}"
      end
      puts ''
    end

    def show_comprehensive_summary(folders, sent_items, domain_patterns, recommendations)
      puts '📊 Overall Statistics:'
      puts "  Folders analyzed: #{folders.length}"
      puts "  Total messages: #{folders.sum { |f| f[:message_count] }}"
      puts "  Sent items analyzed: #{sent_items[:total_sent]}"
      puts "  Unique domains: #{domain_patterns.length}"
      puts ''

      puts '🎯 Key Findings:'

      # Most active folders
      top_folders = folders.sort_by { |f| -f[:message_count] }.first(3)
      puts "  • Most active folders: #{top_folders.map { |f| "#{f[:name]} (#{f[:message_count]})" }.join(', ')}"

      # Categorization breakdown
      whitelist_count = folders.count { |f| f[:categorization] == :whitelist }
      list_count = folders.count { |f| f[:categorization] == :list }
      puts "  • Folder categorization: #{whitelist_count} whitelist, #{list_count} list"

      # Frequent correspondents
      if sent_items[:frequent_correspondents].any?
        top_correspondent = sent_items[:frequent_correspondents].first
        puts "  • Most frequent correspondent: #{top_correspondent[0]} (#{top_correspondent[1]} emails)"
      end

      puts ''

      puts '🔧 Configuration Suggestions:'
      puts "  • Whitelist folders: #{recommendations[:whitelist_folders].join(', ')}"
      puts "  • List folders: #{recommendations[:list_folders].join(', ')}"
      if recommendations[:domain_mappings].any?
        puts "  • Domain mappings: #{recommendations[:domain_mappings].length} suggested"
      end
      puts ''

      puts '⚠️  Potential Issues:'

      # Check for low volume folders
      low_volume = folders.select { |f| f[:message_count] < 5 }
      puts "  • Low volume folders: #{low_volume.map { |f| f[:name] }.join(', ')}" if low_volume.any?

      # Check for unread messages
      inbox_data = analyze_inbox_state
      puts "  • Unread messages in inbox: #{inbox_data[:unread_messages]}" if inbox_data[:unread_messages] > 0

      puts ''
    end
  end
end
