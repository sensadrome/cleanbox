  Key Project Characteristics

  1. NOT a Rails/ActiveSupport project
    - This is a standalone Ruby CLI tool
    - Don't assume .present?, .blank?, or other ActiveSupport methods are globally available
    - The project has lib/core_ext.rb that provides some Rails-like conveniences, but it must be explicitly required
    - Prefer writing small utility methods over adding heavy dependencies
  2. Core Extensions Pattern
    - Custom extensions live in lib/core_ext.rb
    - Must be explicitly required where needed (e.g., require_relative 'lib/core_ext')
    - Files that need these methods: check if core_ext is already required before using .present?, .blank?, etc.
  3. IMAP/Email Structure
    - Folders are hierarchical (e.g., "INBOX/Work/Projects")
    - CleanboxFolder wraps IMAP folder objects with status info (message counts, attributes)
    - Folder delimiters are typically '/' but can vary by server
    - Folder attributes like :Junk, :Sent, :Haschildren are important metadata
  4. Console Architecture
    - Uses method_missing to delegate to Cleanbox instance (user noted they're not fully happy with this)
    - CleanboxConsole module provides connection management
    - Methods are monkey-patched onto Cleanbox class in console.rb
    - Help text should be kept in sync when adding new features
  5. Testing Infrastructure
    - RSpec with extensive mocking
    - spec/helpers/ contains test utilities (like capture_output_helper.rb)
    - Tests use doubles for IMAP connections
    - SimpleCov for coverage reporting
    - Always update or add tests when modifying existing methods
  6. Development Philosophy
    - User is building toward MCP/chat integration
    - Console is meant to be both a productivity tool AND a "teaching interface" for learning user preferences
    - Keep implementation simple and focused - avoid over-engineering
    - The project is a work in progress, expect iteration

  Key Files

  Core Application:
  - lib/cleanbox.rb - Main orchestrator class (Cleanbox), inherits from CleanboxConnection
  - lib/message_processor.rb - Decision-making logic (MessageProcessor) - handles blacklist/whitelist/filing decisions
  - lib/message.rb - Email message wrapper (CleanboxMessage)
  - lib/connection.rb - Base class (CleanboxConnection) for IMAP operations
  - lib/cleanbox_folder.rb - Folder representation with stats (CleanboxFolder)
  - lib/folder_checker.rb - Analyzes folders to extract email addresses
  - lib/console.rb - Console/REPL interface with monkey patches for Cleanbox and CleanboxMessage
  - lib/core_ext.rb - Rails-like utility methods (.present?, .blank?, etc.)

  Configuration & Auth:
  - lib/configuration.rb - Configuration management
  - lib/auth/authentication_manager.rb - OAuth2 and password authentication
  - User config: ~/.cleanbox.yml (or custom path)
  - Data directory: ~/.cleanbox/ (cache, domain rules, etc.)

  CLI:
  - lib/cli/cleanbox_cli.rb - Command-line interface entry point
  - lib/cli/config_manager.rb - Config file management commands
  - lib/cli/secrets_manager.rb - Secrets handling
  - bin/console - Console REPL entry point

  Documentation:
  - README.md - Main documentation: overview, features, quick start, container deployment
  - docs/installation.md - Prerequisites and installation
  - docs/authentication.md - Microsoft 365 OAuth2 and IMAP setup
  - docs/configuration.md - Config files, domain rules, data directory
  - docs/usage.md - Commands, examples, advanced patterns
  - docs/console.md - Interactive REPL interface guide
  - docs/troubleshooting.md - Common issues and solutions

  Testing:
  - spec/spec_helper.rb - Test configuration, requires all dependencies
  - spec/helpers/ - Shared test utilities (capture_output_helper.rb, etc.)
  - spec/cleanbox_spec.rb - Main Cleanbox class tests
  - spec/console_spec.rb - Console functionality tests (newly added)
  - Uses: RSpec, WebMock, VCR, SimpleCov

