# frozen_string_literal: true

require 'net/imap'
require_relative 'config_manager'
require_relative 'secrets_manager'
require_relative '../auth/authentication_manager'
require_relative '../analysis/email_analyzer'
require_relative '../analysis/folder_categorizer'
require_relative '../analysis/domain_mapper'

module CLI
  class SetupWizard
    attr_reader :config_manager, :imap_connection, :provider

    def initialize(verbose: false)
      @config_manager = ConfigManager.new
      @analysis_results = {}
      @verbose = verbose
      @logger = Logger.new(STDOUT)
      @logger.level = verbose ? Logger::DEBUG : Logger::INFO
    end

    def run
      puts "🎉 Welcome to Cleanbox Setup Wizard!"
      puts "This will analyze your email organization and help configure Cleanbox."
      puts ""

      # Check for existing configuration
      if File.exist?(@config_manager.instance_variable_get(:@config_path))
        puts "⚠️  Configuration file already exists!"
        puts ""
        puts "What would you like to do?"
        puts "  1. Update folder analysis (keep existing credentials and settings)"
        puts "  2. Complete setup (overwrite everything)"
        puts "  3. Cancel"
        puts ""
        puts "Choice (1-3): "
        response = gets.chomp.strip
        
        case response
        when '1'
          @update_mode = true
          puts "✅ Will update folder analysis while preserving existing settings."
          puts ""
        when '2'
          @update_mode = false
          puts "⚠️  Will overwrite all settings."
          puts ""
        when '3'
          puts "Setup cancelled."
          return
        else
          puts "Invalid choice. Setup cancelled."
          return
        end
      else
        @update_mode = false
      end

      # Step 1: Get connection details
      connection_data = get_connection_details
      return unless connection_data

      connection_details = connection_data[:details]
      secrets = connection_data[:secrets]

      # Step 2: Connect and analyze
      begin
        connect_and_analyze(connection_details, secrets)
      rescue => e
        puts "❌ Connection failed: #{e.message}"
        puts "Please check your credentials and try again."
        return
      end

      # Step 3: Generate recommendations
      recommendations = generate_recommendations

      # Step 4: Interactive configuration
      final_config = interactive_configuration(recommendations)

      # Step 5: Save configuration
      save_configuration(final_config, connection_details, secrets)

      # Step 6: Validate and preview
      validate_and_preview(final_config)

      puts ""
      puts "🎉 Setup complete! You can now run:"
      puts "  ./cleanbox --pretend  # Preview what will happen"
      puts "  ./cleanbox            # Start cleaning your inbox"
    end

    private

    def get_connection_details
      puts "📧 Email Connection Setup"
      puts ""

      details = {}
      secrets = {}
      
      # Load existing config if in update mode
      existing_config = {}
      if @update_mode
        existing_config = @config_manager.load_config
        puts "Using existing connection settings..."
        puts ""
      end
      
      # Host
      default_host = existing_config[:host] || "outlook.office365.com"
      if @update_mode && existing_config[:host]
        details[:host] = existing_config[:host]
        puts "IMAP Host: #{existing_config[:host]} (from existing config)"
      else
        details[:host] = prompt_with_default("IMAP Host", default_host) do |host|
          host.match?(/\.(com|org|net|edu)$/) || host.include?('.')
        end
      end

      # Username
      default_username = existing_config[:username]
      if @update_mode && default_username
        details[:username] = default_username
        puts "Username: #{default_username} (from existing config)"
      else
        details[:username] = prompt("Email Address") do |email|
          email.include?('@')
        end
      end

      # Authentication type
      default_auth_type = existing_config[:auth_type]
      if @update_mode && default_auth_type
        details[:auth_type] = default_auth_type
        puts "Authentication: #{default_auth_type} (from existing config)"
      else
        auth_type = prompt_choice("Authentication Method", [
          { key: 'oauth2_microsoft', label: 'OAuth2 (Microsoft 365/Outlook)' },
          { key: 'password', label: 'Password (IMAP)' }
        ])
        details[:auth_type] = auth_type
      end

      # Credentials - in update mode, use existing .env file
      if @update_mode
        puts "Using existing credentials from .env file"
      else
        if details[:auth_type] == 'oauth2_microsoft'
          secrets['CLEANBOX_CLIENT_ID'] = prompt("OAuth2 Client ID") { |id| !id.empty? }
          secrets['CLEANBOX_CLIENT_SECRET'] = prompt("OAuth2 Client Secret", secret: true) { |id| !id.empty? }
          secrets['CLEANBOX_TENANT_ID'] = prompt("OAuth2 Tenant ID") { |id| !id.empty? }
        else
          secrets['CLEANBOX_PASSWORD'] = prompt("IMAP Password", secret: true) { |pwd| !pwd.empty? }
        end
      end

      puts ""
      puts "Testing connection..."
      
      { details: details, secrets: secrets }
    end

    def connect_and_analyze(connection_details, secrets)
      puts "🔍 Connecting to #{connection_details[:host]}..."
      
      # Temporarily set environment variables for authentication
      secrets.each { |key, value| ENV[key] = value }
      
      # Create options hash using the same pattern as CleanboxCLI
      options = default_options.merge(connection_details)
      
      # Create IMAP connection
      @imap_connection = Net::IMAP.new(connection_details[:host], ssl: true)
      Auth::AuthenticationManager.authenticate_imap(@imap_connection, options)
      
      puts "✅ Connected successfully!"
      puts ""

      # Analyze folders
      puts "📁 Analyzing your email folders..."
      puts ""
      puts "I'll examine each folder to understand how you organize your emails."
      puts "This helps Cleanbox learn what to do with new incoming emails:"
      puts ""
      puts "• WHITELIST folders: Emails from these senders stay in your inbox"
      puts "  (like Family, Work, Friends - emails you want to see immediately)"
      puts ""
      puts "• LIST folders: Emails from these senders get moved to folders"
      puts "  (like Newsletters, Shopping, Social media - emails you can read later)"
      puts ""
      puts "• System folders: Calendar, Drafts, etc. are automatically skipped"
      puts ""
      puts "For each folder, I'll show you my analysis and ask for confirmation."
      puts ""
      
      # Use the new EmailAnalyzer
      analyzer = Analysis::EmailAnalyzer.new(
        @imap_connection, 
        logger: @logger,
        folder_categorizer_class: Analysis::FolderCategorizer
      )
      
      @analysis_results[:folders] = analyzer.analyze_folders
      
      # Analyze sent items
      puts "📧 Analyzing your sent emails..."
      @analysis_results[:sent_items] = analyzer.analyze_sent_items
      
      # Analyze domain patterns
      puts "🔍 Analyzing domain patterns..."
      @analysis_results[:domain_patterns] = analyzer.analyze_domain_patterns
      
      puts "✅ Analysis complete!"
      puts ""
    end

    def default_options
      {
        host: '',
        username: nil,
        auth_type: nil,  # oauth2_microsoft, oauth2_gmail, password
        client_id: secret(:client_id),
        client_secret: secret(:client_secret),
        tenant_id: secret(:tenant_id),
        password: secret(:password)
      }
    end

    # Secret retrieval method (same as CleanboxCLI)
    def secret(name)
      CLI::SecretsManager.value_from_env_or_secrets(name)
    end

    def analyze_folders
      folders = []
      skipped_folders = []
      
      # Get all folders
      imap_folders = @imap_connection.list('', '*')
      total_folders = imap_folders.length
      
      puts "Found #{total_folders} folders to analyze..."
      puts ""
      
      imap_folders.each_with_index do |folder, index|
        next if folder.name == 'INBOX' # Skip inbox for now
        
        # Check if this is a system folder to skip silently
        if should_skip_folder?(folder.name.downcase)
          skipped_folders << folder.name
          next
        end
        
        # Show progress for non-system folders
        progress_msg = "📁 Analyzing folder \"#{folder.name}\" (#{index + 1}/#{total_folders})"
        print "\r#{progress_msg.ljust(80)}"
        
        begin
          # Get folder status
          status = @imap_connection.status(folder.name, %w[MESSAGES UNSEEN])
          message_count = status['MESSAGES']&.to_i || 0
          
          # Skip folders with very few messages
          if message_count < 5
            skipped_folders << "#{folder.name} (low volume: #{message_count} messages)"
            next
          end
          
          # Analyze senders in this folder (sample)
          senders = analyze_folder_senders(folder.name, message_count)
          
          folder_data = {
            name: folder.name,
            message_count: message_count,
            senders: senders,
            domains: senders.map { |s| s.split('@').last }.uniq,
            attributes: folder.attr
          }
          
          # Interactive categorization
          categorization = interactive_folder_categorization(folder_data)
          if categorization != :skip
            folder_data[:categorization] = categorization
            folders << folder_data
          else
            skipped_folders << folder.name
          end
          
        rescue => e
          # Skip folders we can't access
          progress_msg = "📁 Skipping folder \"#{folder.name}\" (access denied) (#{index + 1}/#{total_folders})"
          print "\r#{progress_msg.ljust(80)}"
          skipped_folders << "#{folder.name} (access denied)"
          next
        end
      end
      
      puts "\r" + " " * 80 + "\r" # Clear the progress line
      
      # Show summary in verbose mode
      if @verbose
        show_analysis_summary(folders, skipped_folders)
      end
      
      folders.sort_by { |f| -f[:message_count] }
    end

    def interactive_folder_categorization(folder)
      name = folder[:name]
      message_count = folder[:message_count]
      
      # Clear the progress line first
      print "\r" + " " * 80 + "\r"
      
      puts ""
      puts "📁 Analyzing folder \"#{name}\" (#{message_count} messages)"
      
      # Use the new FolderCategorizer
      categorizer = Analysis::FolderCategorizer.new(
        folder, 
        imap_connection: @imap_connection, 
        logger: @logger
      )
      
      initial_categorization = categorizer.categorization
      reason = categorizer.categorization_reason
      
      puts "  → Detected as #{initial_categorization.upcase} folder (#{reason})"
      
      # Interactive prompt
      puts "  Accept this categorization? (Y/n/l/w/s) [#{initial_categorization[0].upcase}]: "
      response = gets.chomp.strip.downcase
      
      case response
      when '', 'y', 'yes'
        return initial_categorization
      when 'n', 'no'
        puts "  How should this folder be categorized? (l=List, w=Whitelist, s=Skip): "
        choice = gets.chomp.strip.downcase
        case choice
        when 'l'
          return :list
        when 'w'
          return :whitelist
        when 's'
          return :skip
        else
          puts "  Invalid choice, using default: #{initial_categorization}"
          return initial_categorization
        end
      when 'l'
        return :list
      when 'w'
        return :whitelist
      when 's'
        return :skip
      else
        puts "  Invalid choice, using default: #{initial_categorization}"
        return initial_categorization
      end
    end

    def determine_folder_categorization(folder)
      name = folder[:name].downcase
      
      # Check email headers for bulk indicators (strongest signal)
      if analyze_folder_headers(folder[:name])
        return :list
      end
      
      # Identify list/newsletter folders by name patterns
      if is_list_folder?(name)
        return :list
      end
      
      # Identify whitelist folders by name patterns
      if is_whitelist_folder?(name)
        return :whitelist
      end
      
      # Default categorization based on sender patterns
      categorize_by_senders(folder)
    end

    def get_categorization_reason(folder, categorization)
      name = folder[:name].downcase
      
      case categorization
      when :list
        if analyze_folder_headers(folder[:name])
          return "found newsletter/bulk email headers"
        elsif is_list_folder?(name)
          return "folder name suggests list/newsletter content"
        else
          return "sender patterns suggest list/newsletter content"
        end
      when :whitelist
        if is_whitelist_folder?(name)
          return "folder name suggests personal/professional emails"
        else
          return "sender patterns suggest personal correspondence"
        end
      when :skip
        return "low volume or system folder"
      end
    end

    def show_analysis_summary(folders, skipped_folders)
      puts ""
      puts "📊 Analysis Summary:"
      puts "✅ Analyzed #{folders.length} folders interactively"
      
      if skipped_folders.any?
        puts "⏭️  Skipped #{skipped_folders.length} folders:"
        skipped_folders.each do |folder|
          puts "   - #{folder}"
        end
      end
      
      whitelist_count = folders.count { |f| f[:categorization] == :whitelist }
      list_count = folders.count { |f| f[:categorization] == :list }
      
      puts "📊 Final categorization: #{whitelist_count} whitelist folders, #{list_count} list folders"
      puts ""
    end

    def analyze_folder_senders(folder_name, message_count)
      return [] if message_count == 0
      
      begin
        @imap_connection.select(folder_name)
        
        # Sample up to 100 messages for analysis
        sample_size = [message_count, 100].min
        message_ids = @imap_connection.search(['ALL']).last(sample_size)
        
        return [] if message_ids.empty?
        
        # Fetch envelope data
        envelopes = @imap_connection.fetch(message_ids, 'ENVELOPE')
        
        senders = envelopes.map do |env|
          envelope = env.attr['ENVELOPE']
          next unless envelope&.from&.first
          
          mailbox = envelope.from.first.mailbox
          host = envelope.from.first.host
          "#{mailbox}@#{host}".downcase
        end.compact.uniq
        
        senders
      rescue => e
        # Return empty array if we can't analyze this folder
        []
      end
    end

    def analyze_sent_items
      sent_folder = detect_sent_folder
      return { frequent_correspondents: [], total_sent: 0 } unless sent_folder
      
      begin
        @imap_connection.select(sent_folder)
        message_count = @imap_connection.search(['ALL']).length
        
        # Sample recent sent emails
        sample_size = [message_count, 200].min
        message_ids = @imap_connection.search(['ALL']).last(sample_size)
        
        return { frequent_correspondents: [], total_sent: message_count } if message_ids.empty?
        
        # Fetch envelope data
        envelopes = @imap_connection.fetch(message_ids, 'ENVELOPE')
        
        # Extract recipients
        recipients = envelopes.map do |env|
          envelope = env.attr['ENVELOPE']
          next unless envelope&.to&.first
          
          mailbox = envelope.to.first.mailbox
          host = envelope.to.first.host
          "#{mailbox}@#{host}".downcase
        end.compact
        
        # Count frequency
        frequency = recipients.group_by(&:itself).transform_values(&:length)
        frequent_correspondents = frequency.sort_by { |_, count| -count }.first(20)
        
        {
          frequent_correspondents: frequent_correspondents,
          total_sent: message_count,
          sample_size: sample_size
        }
      rescue => e
        { frequent_correspondents: [], total_sent: 0 }
      end
    end

    def analyze_domain_patterns
      all_domains = @analysis_results[:folders].flat_map { |f| f[:domains] }.uniq
      
      patterns = {}
      
      all_domains.each do |domain|
        # Categorize domains
        category = categorize_domain(domain)
        patterns[domain] = category
      end
      
      patterns
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

    def generate_recommendations
      puts "🤖 Generating recommendations..."
      puts ""

      # Use the new EmailAnalyzer to generate recommendations
      analyzer = Analysis::EmailAnalyzer.new(
        @imap_connection, 
        logger: @logger,
        folder_categorizer_class: Analysis::FolderCategorizer
      )
      
      # Set the analysis results so the analyzer can use them
      analyzer.instance_variable_set(:@analysis_results, @analysis_results)
      
      recommendations = analyzer.generate_recommendations(domain_mapper_class: Analysis::DomainMapper)

      recommendations
    end

    def analyze_folder_for_recommendation(folder)
      name = folder[:name].downcase
      message_count = folder[:message_count]
      
      # Skip system/special folders
      return :skip if should_skip_folder?(name)
      
      # Skip folders with very few messages (likely not important)
      return :skip if message_count < 5
      
      # Check email headers for bulk indicators (strongest signal)
      if analyze_folder_headers(folder[:name])
        return :list  # Strong signal from headers
      end
      
      # Identify list/newsletter folders by name patterns
      if is_list_folder?(name)
        return :list
      end
      
      # Identify whitelist folders by name patterns
      if is_whitelist_folder?(name)
        return :whitelist
      end
      
      # Default categorization based on sender patterns
      categorize_by_senders(folder)
    end

    def analyze_folder_headers(folder_name, sample_size = 20)
      begin
        @imap_connection.select(folder_name)
        message_ids = @imap_connection.search(['ALL']).last(sample_size)
        
        return false if message_ids.empty?
        
        bulk_indicators = 0
        message_ids.each do |id|
          # Fetch specific headers that indicate bulk emails
          headers = @imap_connection.fetch(id, 'BODY.PEEK[HEADER]').first
          if has_bulk_headers?(headers)
            bulk_indicators += 1
          end
        end
        
        # If more than 30% of sampled emails have bulk headers, it's likely a list folder
        (bulk_indicators.to_f / message_ids.length) > 0.3
      rescue => e
        false # Default to false if we can't analyze
      end
    end

    def has_bulk_headers?(headers)
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

    def should_skip_folder?(name)
      # System and special folders that should never be suggested
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
      
      skip_patterns.any? { |pattern| name.match?(pattern) }
    end

    def is_list_folder?(name)
      # Patterns that indicate list/newsletter folders
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
      
      list_patterns.any? { |pattern| name.match?(pattern) }
    end

    def is_whitelist_folder?(name)
      # Patterns that indicate important personal/professional folders
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
      
      whitelist_patterns.any? { |pattern| name.match?(pattern) }
    end

    def categorize_by_senders(folder)
      # Analyze sender patterns to determine folder type
      senders = folder[:senders]
      return :skip if senders.empty?
      
      # Count unique domains
      domains = senders.map { |s| s.split('@').last }.uniq
      
      # If mostly single domain, likely a list folder
      if domains.length <= 2 && folder[:message_count] > 50
        return :list
      end
      
      # If diverse senders with personal names, likely whitelist
      personal_domains = senders.count { |s| s.split('@').first.match?(/^[a-z]+\.[a-z]+$/) }
      if personal_domains > senders.length * 0.3
        return :whitelist
      end
      
      # Default to list for high-volume folders
      folder[:message_count] > 100 ? :list : :skip
    end

    def generate_domain_mappings
      # Use the new DomainMapper class instead of hardcoded logic
      list_folders = @analysis_results[:folders].select { |f| f[:categorization] == :list }
      domain_mapper = Analysis::DomainMapper.new(list_folders, logger: @logger)
      domain_mapper.generate_mappings
    end

    def interactive_configuration(recommendations)
      puts "📋 Configuration Recommendations"
      puts ""

      final_config = {
        whitelist_folders: [],
        list_folders: [],
        domain_mappings: {}
      }

      # Sent items analysis
      if recommendations[:frequent_correspondents].any?
        puts "📧 Frequent Correspondents (from Sent Items):"
        recommendations[:frequent_correspondents].first(10).each do |email, count|
          puts "  👤 #{email} (#{count} emails sent)"
        end
        puts ""
      end

      # Whitelist folders
      puts "✅ Whitelist Folders (keep in inbox):"
      recommendations[:whitelist_folders].each do |folder_name|
        folder = @analysis_results[:folders].find { |f| f[:name] == folder_name }
        puts "  📂 #{folder_name} (#{folder[:message_count]} messages)"
      end
      
      puts ""
      puts "Add additional whitelist folders (comma-separated, or press Enter to skip):"
      additional_whitelist = gets.chomp.strip
      if additional_whitelist && !additional_whitelist.empty?
        final_config[:whitelist_folders] = recommendations[:whitelist_folders] + additional_whitelist.split(',').map(&:strip)
      else
        final_config[:whitelist_folders] = recommendations[:whitelist_folders]
      end

      # List folders
      puts ""
      puts "📬 List Folders (move to folders):"
      recommendations[:list_folders].each do |folder_name|
        folder = @analysis_results[:folders].find { |f| f[:name] == folder_name }
        puts "  📂 #{folder_name} (#{folder[:message_count]} messages)"
      end
      
      puts ""
      puts "Add additional list folders (comma-separated, or press Enter to skip):"
      additional_list = gets.chomp.strip
      if additional_list && !additional_list.empty?
        final_config[:list_folders] = recommendations[:list_folders] + additional_list.split(',').map(&:strip)
      else
        final_config[:list_folders] = recommendations[:list_folders]
      end

      # Domain mappings
      if recommendations[:domain_mappings].any?
        puts ""
        puts "🔗 Domain Mappings"
        puts ""
        puts "Sometimes emails come from addresses that don't match your existing folders."
        puts "For example, you might have a 'GitHub' folder, but get emails from:"
        puts "  • issue.12345.project@github.com"
        puts "  • noreply@githubusercontent.com"
        puts ""
        puts "Domain mappings tell Cleanbox: 'When you see emails from these domains,"
        puts "put them in this folder, even if the sender address looks different.'"
        puts ""
        puts "Suggested mappings:"
        recommendations[:domain_mappings].each do |domain, folder|
          puts "  🌐 #{domain} → #{folder}"
        end
        
        puts ""
        puts "Customize domain mappings (format: domain=folder,domain=folder or press Enter to skip):"
        custom_mappings = gets.chomp.strip
        if custom_mappings && !custom_mappings.empty?
          custom_mappings.split(',').each do |mapping|
            domain, folder = mapping.split('=')
            if domain && folder
              final_config[:domain_mappings][domain.strip] = folder.strip
            end
          end
        else
          final_config[:domain_mappings] = recommendations[:domain_mappings]
        end
      end

      final_config
    end

    def save_configuration(final_config, connection_details, secrets)
      puts ""
      puts "💾 Saving configuration..."
      
      # Create .env file for sensitive credentials (only if not in update mode)
      unless @update_mode
        CLI::SecretsManager.create_env_file(secrets)
      end
      
      # Load existing config or create new
      config = @update_mode ? @config_manager.load_config : {}
      
      # Update with new settings
      if @update_mode
        # In update mode, only update folder-related settings
        config.merge!({
          whitelist_folders: final_config[:whitelist_folders],
          list_folders: final_config[:list_folders],
          list_domain_map: final_config[:domain_mappings]
        })
        puts "✅ Updated folder analysis while preserving existing settings"
      else
        # In full setup mode, update everything
        config.merge!(connection_details)
        config.merge!({
          whitelist_folders: final_config[:whitelist_folders],
          list_folders: final_config[:list_folders],
          list_domain_map: final_config[:domain_mappings]
        })
        puts "✅ Created new configuration"
      end
      
      # Save configuration
      @config_manager.save_config(config)
      
      puts "Configuration saved to #{@config_manager.instance_variable_get(:@config_path)}"
      puts ""
      puts "🔐 Security Note:"
      puts "   - Sensitive credentials are stored in .env file"
      puts "   - .env file is already in .gitignore"
      puts "   - Keep your .env file secure and don't share it"
    end

    def validate_and_preview(final_config)
      puts ""
      puts "🔍 Validating configuration..."
      
      # Show summary
      puts "📋 Configuration Summary:"
      puts "  Whitelist folders: #{final_config[:whitelist_folders].join(', ')}"
      puts "  List folders: #{final_config[:list_folders].join(', ')}"
      puts "  Domain mappings: #{final_config[:domain_mappings].length} mappings"
      
      puts ""
      puts "Would you like to preview what Cleanbox would do? (y/N):"
      preview = gets.chomp.strip.downcase
      
      if preview == 'y' || preview == 'yes'
        puts ""
        puts "🔍 Running preview..."
        system("./cleanbox --pretend --verbose")
      end
    end

    # Helper methods for user input
    def prompt(message, default: nil, secret: false)
      loop do
        if default
          print "#{message} [#{default}]: "
        else
          print "#{message}: "
        end
        
        input = if secret
          system('stty -echo')
          result = gets.chomp
          system('stty echo')
          puts
          result
        else
          gets.chomp
        end
        
        input = default if input.empty? && default
        
        if block_given?
          if yield(input)
            return input
          else
            puts "❌ Invalid input. Please try again."
          end
        else
          return input
        end
      end
    end

    def prompt_with_default(message, default)
      prompt(message, default: default) { |input| !input.empty? }
    end

    def prompt_choice(message, choices)
      puts "#{message}:"
      choices.each_with_index do |choice, index|
        puts "  #{index + 1}. #{choice[:label]}"
      end
      
      loop do
        print "Choice (1-#{choices.length}): "
        choice = gets.chomp.to_i
        
        if choice >= 1 && choice <= choices.length
          return choices[choice - 1][:key]
        else
          puts "❌ Invalid choice. Please enter 1-#{choices.length}."
        end
      end
    end
  end
end 