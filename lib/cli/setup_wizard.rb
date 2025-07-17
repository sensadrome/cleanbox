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
      puts "  ./cleanbox clean --pretend  # Preview what will happen"
      puts "  ./cleanbox clean            # Start cleaning your inbox"
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
      
      # Get the raw folder data first
      raw_folders = analyzer.analyze_folders
      
      # Now do interactive categorization
      @analysis_results[:folders] = interactive_folder_categorization(raw_folders)
      
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

    def interactive_folder_categorization(folders)
      categorized_folders = []
      
      folders.each do |folder|
        name = folder[:name]
        message_count = folder[:message_count]
        
        puts ""
        puts "📁 Analyzing folder \"#{name}\" (#{message_count} messages)"
        
        # Use the FolderCategorizer to get initial categorization
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
        
        final_categorization = case response
        when '', 'y', 'yes'
          initial_categorization
        when 'n', 'no'
          puts "  How should this folder be categorized? (l=List, w=Whitelist, s=Skip): "
          choice = gets.chomp.strip.downcase
          case choice
          when 'l'
            :list
          when 'w'
            :whitelist
          when 's'
            :skip
          else
            puts "  Invalid choice, using default: #{initial_categorization}"
            initial_categorization
          end
        when 'l'
          :list
        when 'w'
          :whitelist
        when 's'
          :skip
        else
          puts "  Invalid choice, using default: #{initial_categorization}"
          initial_categorization
        end
        
        # Update the folder with the final categorization
        folder[:categorization] = final_categorization
        categorized_folders << folder
      end
      
      categorized_folders
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
        system("./cleanbox clean --pretend --verbose")
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