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
        begin
          retrieve_connection_details
          connection_details_provided? && authentication_details_provided?
        rescue ArgumentError => e
          # Configuration is incomplete, return false to stop the wizard
          false
        end
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
    end
  end
end
