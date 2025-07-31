# frozen_string_literal: true

require 'json'
require 'csv'
require 'logger'
require_relative '../analysis/email_analyzer'

module CLI
  class SentAnalysisCLI
    attr_reader :data_dir
    def initialize(imap_connection, options)
      @imap_connection = imap_connection
      @options = options
      @logger = Logger.new(STDOUT)
      @logger.level = options[:verbose] ? Logger::DEBUG : Logger::INFO
      @data_dir = options[:data_dir] || Dir.pwd
      
      # Initialize analyzer components
      @email_analyzer = Analysis::EmailAnalyzer.new(
        @imap_connection,
        logger: @logger,
        folder_categorizer_class: Analysis::FolderCategorizer
      )
    end

    def run
      subcommand = ARGV.first || 'collect'
      
      case subcommand
      when 'collect'
        collect_data
      when 'analyze'
        analyze_data
      when 'compare'
        compare_sent_with_folders
      when 'help'
        show_help
      else
        show_help
      end
    end

    private

    def collect_data
      puts "📊 Collecting sent email analysis data..."
      puts ""

      # Analyze sent items
      puts "📧 Analyzing sent emails..."
      sent_data = @email_analyzer.analyze_sent_items
      
      # Analyze all folders with progress
      puts "📁 Analyzing all folders..."
      progress_callback = lambda do |current, total, folder_name|
        percentage = (current.to_f / total * 100).round(1)
        # Clear the line and write progress
        print "\r\033[K  📈 Progress: #{percentage}% (#{current}/#{total}) - #{folder_name}"
        STDOUT.flush
      end
      
      folder_results = @email_analyzer.analyze_folders(progress_callback)
      puts "" # New line after progress
      
      # Collect detailed data with progress
      puts "📋 Collecting detailed sender/recipient data..."
      sent_recipients = collect_sent_recipients_with_progress
      folder_senders = collect_folder_senders_with_progress(folder_results[:folders])
      
      puts "  📊 Data collection summary:"
      puts "    sent_recipients collected: #{sent_recipients.length}"
      puts "    folder_senders collected: #{folder_senders.length}"
      
      detailed_data = {
        'timestamp' => Time.now.iso8601,
        'sent_analysis' => sent_data,
        'folder_analysis' => folder_results,
        'sent_recipients' => sent_recipients,
        'folder_senders' => folder_senders
      }
      
      # Save to files
      puts "💾 Saving data to files..."
      save_json_data(detailed_data, 'sent_analysis_data.json')
      save_csv_data(detailed_data)
      
      puts "✅ Data collection complete!"
      puts "📄 Files created:"
      puts "   - sent_analysis_data.json (complete data)"
      puts "   - sent_recipients.csv (sent email recipients)"
      puts "   - folder_senders.csv (folder sender analysis)"
      puts "   - sent_vs_folders.csv (comparison data)"
    end

    def analyze_data
      puts "📊 Analyzing collected data..."
      
      json_path = File.join(@data_dir, 'sent_analysis_data.json')
      unless File.exist?(json_path)
        puts "❌ No data file found. Run 'collect' first."
        return
      end
      
      data = JSON.parse(File.read(json_path))
      
      # Analyze sent recipients
      sent_recipients = data['sent_recipients']
      total_sent = data['sent_analysis']['total_sent']
      sample_size = data['sent_analysis']['sample_size']
      
      puts ""
      puts "📧 SENT EMAIL ANALYSIS"
      puts "=" * 50
      puts "Total sent emails: #{total_sent}"
      puts "Sample analyzed: #{sample_size}"
      puts "Unique recipients: #{sent_recipients.length}"
      puts ""
      
      # Show top recipients
      recipient_counts = sent_recipients.group_by { |r| r['recipient'] }
        .transform_values(&:length)
        .sort_by { |_, count| -count }
        .first(20)
      
      puts "Top 20 recipients:"
      recipient_counts.each_with_index do |(recipient, count), index|
        puts "  #{index + 1}. #{recipient} (#{count} emails)"
      end
      
      # Analyze folder data
      folders = data['folder_analysis']['folders']
      puts ""
      puts "📁 FOLDER ANALYSIS"
      puts "=" * 50
      puts "Total folders analyzed: #{folders.length}"
      
      # Categorize folders
      whitelist_folders = folders.select { |f| f['categorization'] == 'whitelist' }
      list_folders = folders.select { |f| f['categorization'] == 'list' }
      
      puts "Whitelist folders: #{whitelist_folders.length}"
      puts "List folders: #{list_folders.length}"
      puts ""
      
      puts "Whitelist folders:"
      whitelist_folders.each do |folder|
        puts "  - #{folder['name']} (#{folder['message_count']} messages, #{folder['senders'].length} senders)"
      end
      
      puts ""
      puts "List folders:"
      list_folders.each do |folder|
        puts "  - #{folder['name']} (#{folder['message_count']} messages, #{folder['senders'].length} senders)"
      end
    end

    def compare_sent_with_folders
      puts "🔍 Comparing sent emails with folder contents..."
      
      unless File.exist?('sent_analysis_data.json')
        puts "❌ No data file found. Run 'collect' first."
        return
      end
      
      data = JSON.parse(File.read('sent_analysis_data.json'))
      
      sent_recipients = data['sent_recipients'].map { |r| r['recipient'] }
      folders = data['folder_analysis']['folders']
      
      puts ""
      puts "📊 SENT vs FOLDER COMPARISON"
      puts "=" * 60
      
      # For each folder, check overlap with sent recipients
      folder_overlaps = []
      
      folders.each do |folder|
        folder_senders = folder['senders']
        overlap = sent_recipients & folder_senders
        overlap_percentage = folder_senders.empty? ? 0 : (overlap.length.to_f / folder_senders.length * 100).round(2)
        
        folder_overlaps << {
          folder_name: folder['name'],
          categorization: folder['categorization'],
          total_senders: folder_senders.length,
          overlap_count: overlap.length,
          overlap_percentage: overlap_percentage,
          overlap_emails: overlap
        }
      end
      
      # Sort by overlap percentage
      folder_overlaps.sort_by! { |f| -f[:overlap_percentage] }
      
      puts "Folders ranked by overlap with sent recipients:"
      puts ""
      
      folder_overlaps.each_with_index do |folder, index|
        puts "#{index + 1}. #{folder[:folder_name]} (#{folder[:categorization]})"
        puts "   Overlap: #{folder[:overlap_count]}/#{folder[:total_senders]} (#{folder[:overlap_percentage]}%)"
        if folder[:overlap_count] > 0
          puts "   Overlapping emails: #{folder[:overlap_emails].join(', ')}"
        end
        puts ""
      end
      
      # Summary statistics
      whitelist_overlaps = folder_overlaps.select { |f| f[:categorization] == 'whitelist' }
      list_overlaps = folder_overlaps.select { |f| f[:categorization] == 'list' }
      
      puts "SUMMARY STATISTICS"
      puts "=" * 30
      puts "Whitelist folders average overlap: #{average_overlap(whitelist_overlaps)}%"
      puts "List folders average overlap: #{average_overlap(list_overlaps)}%"
      puts ""
      
      # Recommendations
      puts "RECOMMENDATIONS"
      puts "=" * 20
      
      high_overlap_folders = folder_overlaps.select { |f| f[:overlap_percentage] > 50 }
      low_overlap_folders = folder_overlaps.select { |f| f[:overlap_percentage] < 10 }
      
      if high_overlap_folders.any?
        puts "Folders with high overlap (>50%) - consider whitelist:"
        high_overlap_folders.each do |folder|
          puts "  - #{folder[:folder_name]} (#{folder[:overlap_percentage]}%)"
        end
        puts ""
      end
      
      if low_overlap_folders.any?
        puts "Folders with low overlap (<10%) - consider list:"
        low_overlap_folders.each do |folder|
          puts "  - #{folder[:folder_name]} (#{folder[:overlap_percentage]}%)"
        end
      end
    end

    def collect_sent_recipients_with_progress
      sent_folder = detect_sent_folder
      return [] unless sent_folder
      
      begin
        puts "  📤 Analyzing sent folder: #{sent_folder}"
        @imap_connection.select(sent_folder)
        message_count = @imap_connection.search(['ALL']).length
        
        # Increase sample size to 1000 for better data
        sample_size = [message_count, 1000].min
        message_ids = @imap_connection.search(['ALL']).last(sample_size)
        
        return [] if message_ids.empty?
        
        puts "  📊 Processing #{sample_size} sent messages..."
        
        # Process in batches for progress
        batch_size = 100
        all_recipients = []
        
        message_ids.each_slice(batch_size).with_index do |batch, batch_index|
          progress = ((batch_index + 1) * batch_size.to_f / sample_size * 100).round(1)
          puts "  📈 Progress: #{progress}% (#{batch_index + 1}/#{(sample_size.to_f / batch_size).ceil} batches)"
          
          envelopes = @imap_connection.fetch(batch, 'ENVELOPE')
          
          batch_recipients = envelopes.map do |env|
            envelope = env.attr['ENVELOPE']
            next unless envelope&.to&.first
            
            mailbox = envelope.to.first.mailbox
            host = envelope.to.first.host
            recipient = "#{mailbox}@#{host}".downcase
            
                      {
            'recipient' => recipient,
            'message_id' => env.seqno,
            'date' => safe_date_format(envelope.date)
          }
          end.compact
          
          all_recipients.concat(batch_recipients)
        end
        
        puts "  ✅ Found #{all_recipients.length} sent recipients"
        all_recipients
      rescue => e
        @logger.error "Could not collect sent recipients: #{e.message}"
        []
      end
    end

    def collect_folder_senders_with_progress(folders = nil)
      folders ||= @email_analyzer.analyze_folders[:folders]
      
      folder_senders = []
      total_folders = folders.length
      
      puts "  📁 Processing #{total_folders} folders for sender analysis..."
      
      folders.each_with_index do |folder, index|
        begin
          progress = ((index + 1).to_f / total_folders * 100).round(1)
          puts "  📈 Progress: #{progress}% (#{index + 1}/#{total_folders}) - #{folder[:name]}"
          
          @imap_connection.select(folder[:name])
          message_count = folder[:message_count]
          
          # Increase sample size to 200 for better data
          sample_size = [message_count, 200].min
          message_ids = @imap_connection.search(['ALL']).last(sample_size)
          
          next if message_ids.empty?
          
          puts "    📊 Processing #{sample_size} messages from #{folder[:name]}..."
          
          # Process in batches
          batch_size = 50
          folder_senders_batch = []
          
          message_ids.each_slice(batch_size) do |batch|
            envelopes = @imap_connection.fetch(batch, 'ENVELOPE')
            
            batch_senders = envelopes.map do |env|
              envelope = env.attr['ENVELOPE']
              next unless envelope&.from&.first
              
              mailbox = envelope.from.first.mailbox
              host = envelope.from.first.host
              sender = "#{mailbox}@#{host}".downcase
              
              {
                'folder' => folder[:name],
                'categorization' => folder[:categorization],
                'sender' => sender,
                'message_id' => env.seqno,
                'date' => safe_date_format(envelope.date)
              }
            end.compact
            
            folder_senders_batch.concat(batch_senders)
          end
          
          folder_senders.concat(folder_senders_batch)
          puts "    ✅ Found #{folder_senders_batch.length} senders in #{folder[:name]}"
          
        rescue => e
          @logger.error "Could not collect senders for #{folder[:name]}: #{e.message}"
        end
      end
      
      puts "  ✅ Total senders collected: #{folder_senders.length}"
      folder_senders
    end

    def detect_sent_folder
      sent_folders = ['Sent Items', 'Sent', '[Gmail]/Sent Mail', 'Sent Mail']
      
      sent_folders.find do |folder_name|
        begin
          @imap_connection.select(folder_name)
          true
        rescue
          false
        end
      end
    end

    def safe_date_format(date_obj)
      return nil unless date_obj
      
      if date_obj.is_a?(String)
        # If it's already a string, return as is
        date_obj
      elsif date_obj.respond_to?(:strftime)
        # If it's a Date/Time object, format it
        date_obj.strftime('%Y-%m-%d %H:%M:%S')
      else
        # Fallback to string representation
        date_obj.to_s
      end
    rescue => e
      # If all else fails, return nil
      nil
    end

    def save_json_data(data, filename)
      filepath = File.join(@data_dir, filename)
      File.write(filepath, JSON.pretty_generate(data))
    end

    def save_csv_data(data)
      puts "  💾 Saving CSV files..."
      puts "    sent_recipients count: #{(data['sent_recipients'] || []).length}"
      puts "    folder_senders count: #{(data['folder_senders'] || []).length}"
      
      # Save sent recipients
      csv_path = File.join(@data_dir, 'sent_recipients.csv')
      CSV.open(csv_path, 'w') do |csv|
        csv << ['recipient', 'message_id', 'date']
        (data['sent_recipients'] || []).each do |recipient|
          csv << [recipient['recipient'], recipient['message_id'], recipient['date']]
        end
      end
      puts "    ✅ saved sent_recipients.csv (#{File.size(csv_path)} bytes)"
      
      # Save folder senders
      csv_path = File.join(@data_dir, 'folder_senders.csv')
      CSV.open(csv_path, 'w') do |csv|
        csv << ['folder', 'categorization', 'sender', 'message_id', 'date']
        (data['folder_senders'] || []).each do |sender|
          csv << [sender['folder'], sender['categorization'], sender['sender'], sender['message_id'], sender['date']]
        end
      end
      puts "    ✅ saved folder_senders.csv (#{File.size(csv_path)} bytes)"
      
      # Save comparison data
      sent_recipients = (data['sent_recipients'] || []).map { |r| r['recipient'] }
      folder_senders = data['folder_senders'] || []
      

      
      csv_path = File.join(@data_dir, 'sent_vs_folders.csv')
      CSV.open(csv_path, 'w') do |csv|
        csv << ['folder', 'categorization', 'sender', 'in_sent', 'sent_count']
        
        folder_senders.group_by { |s| [s['folder'], s['sender']] }.each do |(folder, sender), messages|
          in_sent = sent_recipients.include?(sender)
          sent_count = sent_recipients.count(sender)
          
          csv << [folder, messages.first['categorization'], sender, in_sent, sent_count]
        end
      end
      puts "    ✅ saved sent_vs_folders.csv (#{File.size(csv_path)} bytes)"
    end

    def average_overlap(folders)
      return 0 if folders.empty?
      
      total_percentage = folders.sum { |f| f[:overlap_percentage] }
      (total_percentage.to_f / folders.length).round(2)
    end

    def show_help
      puts "Sent Analysis CLI - Analyze sent emails vs folder contents"
      puts ""
      puts "Commands:"
      puts "  collect    - Collect data from IMAP server"
      puts "  analyze    - Analyze collected data"
      puts "  compare    - Compare sent emails with folder contents"
      puts "  help       - Show this help"
      puts ""
      puts "Usage:"
      puts "  cleanbox sent-analysis collect"
      puts "  cleanbox sent-analysis analyze"
      puts "  cleanbox sent-analysis compare"
    end
  end
end 