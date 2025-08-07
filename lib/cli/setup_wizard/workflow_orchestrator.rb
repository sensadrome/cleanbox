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
        connection_data = retrieve_connection_details
        return unless connection_data

        connection_details = connection_data[:details]
        secrets = connection_data[:secrets]

        # Step 4: Connect and analyze
        begin
          connect_and_analyze(connection_details, secrets)
        rescue StandardError => e
          puts I18n.t('setup_wizard.connection.connection_failed', message: e.message)
          return
        end

        # Step 5: Generate recommendations
        recommendations = generate_recommendations

        # Step 6: Interactive configuration
        final_config = interactive_configuration(recommendations)

        # Step 7: Save configuration
        save_configuration(final_config, connection_details, secrets)

        # Step 8: Validate and preview
        validate_and_preview(final_config)

        puts ''
        puts I18n.t('setup_wizard.completion.setup_complete')
      end
    end
  end
end
