# frozen_string_literal: true

require 'i18n'

module CLI
  module SetupWizardModules
    # Orchestrates the main workflow and coordinates between all other modules
    module WorkflowOrchestrator
      def run
        puts I18n.t('setup_wizard.welcome')
        puts ''

        # Step 1: Check existing configuration
        return unless can_create_or_overwrite_configuration?

        # Step 2: Check authentication setup
        return unless authentication_setup?

        # Step 3: Get connection details
        return unless connection_details_valid?

        # Step 4: Connect
        begin
          display_testing_message
          establish_imap_connection
        rescue StandardError => e
          puts I18n.t('setup_wizard.connection.connection_failed', message: e.message)
          return
        end

        @blacklist_folder = determine_blacklist_folder

        # Step 5: Analyze
        run_analysis

        # Step 6: Generate recommendations
        recommendations = generate_recommendations

        # Step 7: Interactive configuration
        final_config = interactive_configuration(recommendations)

        # Step 8: Save configuration
        save_configuration(final_config)

        # Step 9: Validate and preview
        validate_and_preview(final_config)

        puts ''
        puts I18n.t('setup_wizard.completion.setup_complete')
      end

      def connection_details_valid?
        retrieve_connection_details
        connection_details_provided? && authentication_details_provided?
      rescue ArgumentError
        # Configuration is incomplete, return false to stop the wizard
        false
      end

      def connection_details_provided?
        return false unless @details.present?
        return false unless @details[:host].present?

        @details[:username].present?
      end

      def authentication_details_provided?
        return false unless @details[:auth_type].present?

        case @details[:auth_type]
        when 'oauth2_microsoft'
          microsoft_oauth2_details_provided?
        when 'oauth2_microsoft_user'
          # validate_microsoft_user_oauth2!(options)
          true
        when 'password'
          password_present?
        end
      end

      def microsoft_oauth2_details_provided?
        return true if @update_mode

        return false unless @secrets['CLEANBOX_CLIENT_ID'].present?
        return false unless @secrets['CLEANBOX_CLIENT_SECRET'].present?

        @secrets['CLEANBOX_TENANT_ID'].present?
      end

      def password_present?
        @update_mode || @secrets['CLEANBOX_PASSWORD'].present?
      end

      def determine_blacklist_folder
        if @update_mode && blacklist_folder_from_config
          blacklist_folder_from_config
        else
          prompt_for_blacklist_folder
        end
      end

      def blacklist_folder_from_config
        Configuration.options[:blacklist_folder]
      end

      def prompt_for_blacklist_folder
        # Get available folders for blacklist detection
        folders = imap_folders.map { |f| { name: f.name } }
        blacklist_candidates = possible_blacklist_folders(folders)

        puts ''
        puts I18n.t('setup_wizard.recommendations.blacklist_folder_detection')

        if blacklist_candidates.any?
          puts I18n.t('setup_wizard.recommendations.blacklist_folders_found')
          blacklist_candidates.each_with_index do |folder, _index|
            puts I18n.t('setup_wizard.recommendations.folder_entry', folder_name: folder[:name], message_count: '?')
          end
          puts ''

          # Use choice system for selection
          choices = blacklist_candidates.map { |folder| { key: folder[:name], label: folder[:name] } }
          choices << { key: nil, label: 'Skip blacklist folder' }

          selected_key = prompt_choice(I18n.t('setup_wizard.recommendations.blacklist_folder_choice_prompt'), choices)
          return selected_key if selected_key
        else
          handle_custom_blacklist_folder_creation
        end

        nil
      end

      def possible_blacklist_folders(folders)
        folders.select do |folder|
          blacklist_folder_patterns.any? { |pattern| folder[:name].downcase.match?(pattern) }
        end
      end

      def blacklist_folder_patterns
        [/unsubscribe/, /blacklist/, /blocked/]
      end

      def handle_custom_blacklist_folder_creation
        puts I18n.t('setup_wizard.recommendations.no_blacklist_folders')
        puts I18n.t('setup_wizard.recommendations.create_blacklist_folder_prompt')
        create_blacklist = gets.chomp.strip.downcase

        return nil unless %w[y yes].include?(create_blacklist)

        puts I18n.t('setup_wizard.recommendations.blacklist_folder_name_prompt')
        folder_name = gets.chomp.strip

        return nil if folder_name.empty?

        create_or_use_existing_folder(folder_name)
      end

      def create_or_use_existing_folder(folder_name)
        # Check if folder already exists
        if folder_exists?(folder_name)
          puts I18n.t('setup_wizard.recommendations.blacklist_folder_exists', folder: folder_name)
          return folder_name
        end

        # Create the folder on the IMAP server
        begin
          @imap_connection.create(folder_name)
          puts I18n.t('setup_wizard.recommendations.blacklist_folder_created', folder: folder_name)
          folder_name
        rescue StandardError => e
          puts I18n.t('setup_wizard.recommendations.blacklist_folder_creation_failed', folder: folder_name,
                                                                                       error: e.message)
          nil
        end
      end

      def folder_exists?(folder_name)
        imap_folders.any? { |f| f.name == folder_name }
      end
    end
  end
end
