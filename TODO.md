# Cleanbox TODO

This file tracks planned improvements, features, and tasks for the Cleanbox project.

## 🚀 High Priority

### Authentication Improvements
- [x] **Add Classic OAuth2 Token Exchange for Microsoft 365** ✅
  - Implement refresh token handling
  - Add token expiration and renewal logic
  - Update authentication documentation
- [x] **Add User-based OAuth2 for Microsoft 365** ✅
  - Implement user-based OAuth2 authentication flow
  - Add authorization URL generation and manual code entry
  - Support token persistence with proper data directory handling
  - Enable sharing Cleanbox without domain admin privileges
- [ ] **Add Gmail OAuth2 Support**
  - Implement Gmail API integration
  - Handle label-based organization vs folder-based
  - Update authentication flow for Gmail

### Documentation Enhancements
- [ ] **Add API Documentation**
  - Document internal APIs and classes
  - Add code examples for developers
  - Create integration guides
- [ ] **Improve Troubleshooting Guide**
  - Add more common error scenarios
  - Include diagnostic commands
  - Add performance troubleshooting

## 🔧 Medium Priority

### Test Infrastructure Improvements ✅ **COMPLETED**
- [x] **Eliminate Class Variable Warnings** ✅
  - Removed top-level class variables from spec_helper.rb
  - Organized test helpers into focused files in `spec/helpers/`
  - Eliminated "class variable access from toplevel" warnings
- [x] **Improve Test Isolation** ✅
  - Each test now gets its own temporary configuration directories
  - Better Configuration management per test with `Configuration.configure(config_options)`
  - Flexible test configuration using `let` block overrides
- [x] **Organize Test Helpers** ✅
  - Created `spec/helpers/config_helpers.rb` for configuration-related test utilities
  - Created `spec/helpers/capture_output_helper.rb` for output capture
  - Improved test maintainability and organization
- [x] **Better Error Handling in Tests** ✅
  - Restored `warn` functionality by removing `$VERBOSE = nil` restrictions
  - Improved ConfigManager error handling with `exit_with_error` method
  - Better test output and debugging capabilities

### Performance Optimizations
- [ ] **Optimize Email Processing**
  - Profile current performance bottlenecks
  - Implement batch processing for large mailboxes
  - Add progress indicators for long operations
- [x] **Improve Caching Strategy** ✅
  - Implement smarter cache invalidation
  - Add cache size management
  - Optimize folder analysis caching
- [ ] **Abstract Data Storage and Caching**
  - **Phase 1: Core Infrastructure**
    - Create `Storage::Provider` interface with methods: `read_config`, `write_config`, `read_cache`, `write_cache`, `list_cache_keys`, `delete_cache`, `cache_exists?`
    - Implement `Storage::FileSystemProvider` (wraps current file operations)
    - Add `Storage::ProviderRegistry` for dynamic provider selection
    - Create `Storage::Config` class for provider configuration
    - Add storage provider selection via `--storage-backend` CLI option
    - Implement storage provider auto-detection based on data directory
  - **Phase 2: Database Providers**
    - Implement `Storage::SQLiteProvider` for local database storage
    - Implement `Storage::PostgreSQLProvider` for shared deployments
    - Add database schema migrations for config, cache, and domain rules
    - Create database connection pooling and optimization
    - Add database backup/restore functionality
  - **Phase 3: Cloud Storage Providers**
    - Implement `Storage::S3Provider` for AWS S3 compatibility
    - Implement `Storage::AzureProvider` for Azure Blob Storage
    - Implement `Storage::GCSProvider` for Google Cloud Storage
    - Add cloud storage authentication and credential management
    - Implement cloud storage caching layers for performance
  - **Migration and Compatibility**
    - Create `Storage::MigrationTool` for file-to-database migrations
    - Add `cleanbox storage migrate` command for user-initiated migrations
    - Implement automatic migration detection and prompting
    - Add rollback functionality for failed migrations
    - Create data validation tools for migration integrity
  - **Configuration and Management**
    - Add storage backend configuration to main config file
    - Implement `cleanbox storage` command group with subcommands:
      - `cleanbox storage show` - Display current storage configuration
      - `cleanbox storage test` - Test storage connectivity
      - `cleanbox storage migrate` - Migrate between backends
      - `cleanbox storage backup` - Create backup of current data
      - `cleanbox storage restore` - Restore from backup
    - Add storage performance metrics collection
    - Implement storage health checks and monitoring
  - **Documentation and Testing**
    - Update all documentation for multi-backend support
    - Add storage provider comparison guide
    - Create deployment guides for different storage backends
    - Add comprehensive test suite for all storage providers
    - Create performance benchmarks for different backends
    - Add storage troubleshooting documentation
  - **Advanced Features**
    - Implement storage provider fallback chains
    - Add storage encryption for sensitive data
    - Create storage provider plugins system
    - Add storage quota management and alerts
    - Implement storage provider auto-scaling for cloud backends

### Code Quality and Architecture ✅ **COMPLETED**
- [x] **Improve ConfigManager Error Handling** ✅
  - Added centralized `exit_with_error` method for consistent error handling
  - Improved variable naming consistency (`config_data` instead of mixing `config` and `load_config()`)
  - Better error messages with heredoc formatting
  - Consistent exit patterns throughout the class
- [x] **Eliminate Pry Auto-loading Warnings** ✅
  - Added `require: false` to pry gems in Gemfile
  - Prevents automatic loading and warning spam during normal operation
  - Gives developers control over when pry is loaded

### User Experience
- [ ] **Fix Main Help Text Completeness**
  - Add missing commands to help output:
    - `sent-analysis` command for analyzing sent vs folder patterns
    - `clean` as the default action command
  - Ensure all available options are listed with complete descriptions
  - Verify help text matches actual implemented functionality
  - Consider reorganizing help output for better clarity

- [ ] **Refactor Unjunk from Parameter to Command**
  - Convert `--unjunk FOLDER` to `./cleanbox unjunk [FOLDER]`
  - Make CLI more consistent with other commands
  - Update command handling logic and help text
  - Ensure folder argument is handled properly

- [ ] **Improve Setup Wizard UX and Clarity**
  - Redesign first menu options for existing config files:
    - **Option 1**: "Update existing configuration" - Runs through wizard with existing values as defaults, offers folder analysis options
    - **Option 2**: "Start Over / Overwrite Config" - Runs full wizard from scratch with only coded defaults (wording TBC)
    - **Option 3**: "Cancel" - Exit without changes
  - In update mode, pre-fill all interactive prompts with current configuration values
  - Make it clear what each option does when user already has a config file
  - Make it clear that update mode allows users to modify current settings, not just analyze folders
- [ ] **Add Interactive Mode**
  - Confirm actions before execution
  - Preview changes with user approval
  - Add undo functionality for recent actions
- [ ] **Improve Error Messages**
  - More descriptive error messages
  - Suggest solutions for common issues
  - Add context to authentication failures
- [ ] **Redesign Unjunk Command**
  - Convert `--unjunk` flag to proper `unjunk` command
  - Add better explanations of what unjunking does
  - Improve command-line interface consistency
  - Update documentation with clear examples
- [x] **Separate Authentication Setup** ✅
  - Create standalone authentication setup command (e.g., `./cleanbox auth setup`)
  - Add authentication test command (e.g., `./cleanbox auth test`) to verify credentials work
  - Add authentication status command (e.g., `./cleanbox auth show`) to display current auth configuration
  - Make setup wizard detect if authentication is configured
  - Offer to run authentication setup if not already configured
  - Allow users to run authentication setup independently of full setup wizard
  - Improve modularity and user experience

### Configuration Management
- [ ] **Add Configuration Validation**
  - Validate configuration file syntax
  - Check for missing required fields
  - Suggest configuration improvements
- [ ] **Add Configuration Migration**
  - Automatic migration between versions
  - Backup existing configuration
  - Handle deprecated options
- [ ] **Enhance Wildcard Domain Patterns**
  - Add support for `*domain.com` pattern to match both main domain and subdomains
  - Current patterns: `domain.com` (exact), `*.domain.com` (subdomains only)
  - New pattern: `*domain.com` (main domain + subdomains)
  - This would eliminate need for users to specify both `channel4.com` and `*.channel4.com`
  - Maintain backward compatibility with existing patterns
  - Update documentation and examples

## 📊 Features

### Advanced Analysis
- [ ] **Enhanced Sent Email Analysis**
  - Add email volume analysis
  - Track communication patterns over time
  - Generate reports on email habits
- [ ] **Smart Whitelist Suggestions**
  - Analyze sent emails to suggest whitelist candidates
  - Recommend folder organization based on patterns
  - Suggest domain rules based on usage
- [ ] **Improve Analysis Command**
  - Rename command to better name (e.g., `analyze` → `scan`, `inspect`, `review`, `examine`, `audit`)
  - Add interactive config updates based on analysis results
  - Offer to update whitelist_folders, list_folders, list_domain_map based on analysis
  - Address the "config file as source of truth" limitation
  - Make analysis actionable - not just informational
  - Add "apply suggestions" mode to automatically update config
- [ ] **Add Machine Learning Features**
  - Implement email classification using ML models
  - Add spam detection and filtering
  - Create intelligent folder suggestions
  - Implement email importance scoring
  - Add natural language processing for email content analysis
- [ ] **Add Advanced Analytics**
  - Create email processing dashboards
  - Add trend analysis and forecasting
  - Implement email volume optimization suggestions
  - Add communication pattern insights
  - Create automated reporting and alerts

### Email Management
- [ ] **Add Email Archiving**
  - Archive old emails automatically
  - Implement retention policies
  - Add archive search functionality
- [ ] **Add Email Templates**
  - Create response templates
  - Auto-reply functionality
  - Template management system
- [ ] **Add Folder Management Commands**
  - Summarize senders in a folder (e.g., `./cleanbox folder-summary Admin`)
  - Move emails from one folder to another (e.g., `./cleanbox move Admin Shopping --sender company.com`)
  - Bulk move emails based on sender patterns
  - Show folder contents and sender distribution
  - Help users reorganize existing folders before running clean
  - Make folder reorganization easier and more systematic
- [ ] **Implement Email Workflow Automation**
  - Add email processing rules and triggers
  - Implement conditional email routing
  - Create email processing pipelines
  - Add email approval workflows
  - Implement email escalation procedures
- [ ] **Add Email Collaboration Features**
  - Implement shared folder management
  - Add team email processing rules
  - Create collaborative filtering and organization
  - Add email delegation and sharing
  - Implement team analytics and reporting

## 🐛 Bug Fixes & Improvements

### Known Issues
- [ ] **Fix Ruby 3.x Compatibility**
  - Resolve gem compatibility issues
  - Update deprecated method calls
  - Test with newer Ruby versions
- [ ] **Improve Container Support**
  - Add health checks
  - Better logging configuration
  - Multi-stage Docker builds
- [ ] **Fix Command-Specific Help**
  - All commands (`setup`, `analyze`, `config`, `sent-analysis`, `file`, etc.) show main help instead of command-specific help
  - Users can't get help for specific commands like `./cleanbox config --help`
  - This affects usability and discoverability of command options
  - Need to implement proper subcommand help handling

### Code Quality
- [ ] **Increase Test Coverage**
  - Add more unit tests
  - Add integration tests
  - Add performance tests
- [ ] **Code Refactoring**
  - Improve code organization
  - Reduce code duplication
  - Add better error handling
- [ ] **Refactor SecretsManager for Better Separation of Concerns**
  - Extract token validation logic from `auth_secrets_available?` method
  - Create specialized classes for different auth types (OAuth2MicrosoftChecker, OAuth2MicrosoftUserChecker, PasswordChecker)
  - Remove tight coupling to AuthenticationManager and Microsoft365UserToken from SecretsManager
  - Implement Strategy pattern or delegate to specialized classes
  - Reduce "God Object" behavior in SecretsManager
  - Improve testability by separating concerns
- [ ] **Add Type Safety and Validation**
  - Implement runtime type checking for configuration
  - Add schema validation for YAML config files
  - Create configuration validation classes
  - Add input sanitization for user-provided data
- [ ] **Implement Dependency Injection**
  - Create service container for better testability
  - Abstract external dependencies (IMAP, storage, logging)
  - Add interface-based design for core components
  - Implement mock providers for testing
- [ ] **Add Code Quality Tools**
  - Integrate RuboCop for consistent code style
  - Add Reek for code smell detection
  - Implement Brakeman for security scanning
  - Add SimpleCov for test coverage reporting
  - Set up automated code quality checks in CI/CD

## 🔒 Security

### Authentication Security
- [ ] **Add Rate Limiting**
  - Prevent brute force attacks
  - Add request throttling
  - Implement backoff strategies
- [ ] **Improve Secret Management**
  - Add secret rotation support
  - Implement secure secret storage
  - Add audit logging for credential access
- [ ] **Implement Zero Trust Architecture**
  - Add identity verification for all operations
  - Implement least-privilege access controls
  - Add continuous authentication monitoring
  - Create security event logging and alerting

### Data Protection
- [ ] **Add Data Encryption**
  - Encrypt sensitive configuration
  - Add encrypted cache storage
  - Implement secure logging
- [ ] **Implement Data Privacy Controls**
  - Add GDPR compliance features
  - Implement data retention policies
  - Add data anonymization for analytics
  - Create data export and deletion capabilities
- [ ] **Add Security Scanning**
  - Implement SAST (Static Application Security Testing)
  - Add DAST (Dynamic Application Security Testing)
  - Create security dependency scanning
  - Add runtime security monitoring

## 🚀 Infrastructure

### Deployment
- [ ] **Add Docker Compose Support**
  - Create docker-compose.yml for easy deployment
  - Add environment-specific configurations
  - Include monitoring and logging services
- [ ] **Add Kubernetes Support**
  - Create Kubernetes manifests
  - Add Helm charts
  - Implement proper resource management
- [ ] **Implement Infrastructure as Code**
  - Add Terraform configurations for cloud deployments
  - Create Ansible playbooks for server provisioning
  - Implement GitOps workflows for automated deployments
  - Add infrastructure testing and validation
- [ ] **Add Multi-Environment Support**
  - Implement environment-specific configurations
  - Add staging/production deployment pipelines
  - Create environment promotion workflows
  - Add environment-specific monitoring and alerting

### Monitoring & Observability
- [ ] **Add Metrics Collection**
  - Track processing performance
  - Monitor error rates
  - Add custom metrics
- [ ] **Improve Logging**
  - Structured logging
  - Log rotation and management
  - Add log aggregation support
- [ ] **Add Health Checks and Monitoring**
  - Implement health check endpoints for container deployments
  - Add system resource monitoring (CPU, memory, disk)
  - Create alerting for critical failures
  - Add performance profiling and bottleneck detection
- [ ] **Implement Distributed Tracing**
  - Add request tracing for multi-step operations
  - Track email processing pipeline performance
  - Implement correlation IDs for debugging
  - Add trace visualization for complex operations

## 📱 User Interface

### CLI Improvements
- [ ] **Add Interactive CLI**
  - Command-line wizard for setup
  - Interactive configuration editing
  - Progress bars and spinners
- [ ] **Add Shell Completions**
  - Bash completion
  - Zsh completion
  - Fish completion
- [ ] **Implement CLI Framework Upgrade**
  - Migrate to Thor or GLI for better CLI structure
  - Add command aliases and shortcuts
  - Implement command history and suggestions
  - Add interactive help system with examples
- [ ] **Add CLI Themes and Customization**
  - Implement color themes for different environments
  - Add progress indicators and animations
  - Create customizable output formats (JSON, YAML, table)
  - Add accessibility features (high contrast, screen reader support)

### Web Interface (Future)
- [ ] **Add Web Dashboard**
  - Email statistics and analytics
  - Configuration management
  - Real-time monitoring
- [ ] **Add REST API**
  - Programmatic access
  - Integration with other tools
  - Webhook support
- [ ] **Add GraphQL API**
  - Flexible data querying
  - Real-time subscriptions
  - Type-safe API with schema introspection
- [ ] **Implement WebSocket Support**
  - Real-time progress updates
  - Live email processing status
  - Interactive configuration updates
- [x] **Unknown Sender Handling Strategies** ✅ **COMPLETED**
  - **Retention Policy System** ✅ **COMPLETED**
    - Implemented comprehensive retention policy system with four options:
      - `:spammy` - Treats legitimate-looking unknown emails as list emails
      - `:hold` - Keeps unknown emails in inbox for configurable days before junking
      - `:quarantine` - Files unknown emails to configurable quarantine folder
      - `:paranoid` - Junks all unknown emails regardless of DKIM status
    - Added configuration options: `hold_days`, `quarantine_folder`, `retention_policy`
    - Integrated with setup wizard for interactive configuration
    - Added comprehensive test coverage for all retention policies
    - Updated configuration management and defaults
  - **Legitimacy Scoring System**
    - DKIM, SPF, DMARC validation
    - Header analysis for suspicious patterns
    - Sending infrastructure reputation checks
    - Configurable thresholds for "legit" vs "suspicious"
  - **User Preference Options** ✅ **COMPLETED**
    - Aggressive (junk unknown senders) - **Currently implemented as default**
    - Moderate (holding folder with retention) - **Implemented as :hold policy**
    - Lenient (file in preferred location if legit) - **Implemented as :spammy policy**
  - **Configuration Options** ✅ **COMPLETED**
    - `retention_policy`: "spammy" | "hold" | "quarantine" | "paranoid"
    - `quarantine_folder`: "Quarantine" (default)
    - `hold_days`: 7 (default)
    - **Note**: Retention policy system now provides flexible unknown sender handling

## 🔄 Maintenance

### Dependencies
- [ ] **Update Dependencies**
  - Regular gem updates
  - Security patches
  - Performance improvements
- [ ] **Add Dependency Scanning**
  - Automated vulnerability scanning
  - License compliance checking
  - Dependency health monitoring
- [ ] **Implement Dependency Management**
  - Add Bundler for dependency management
  - Implement dependency version pinning
  - Add dependency update automation
  - Create dependency compatibility matrix
- [ ] **Add Container Security**
  - Implement multi-stage Docker builds
  - Add container vulnerability scanning
  - Implement least-privilege container execution
  - Add container image signing and verification

### Documentation
- [ ] **Keep Documentation Updated**
  - Regular documentation reviews
  - Update examples and screenshots
  - Add video tutorials
- [ ] **Add Developer Documentation**
  - API documentation
  - Contributing guidelines
  - Architecture documentation
- [ ] **Add Detailed Command Documentation**
  - Create individual files for each command (e.g., `docs/commands/clean.md`, `docs/commands/file.md`)
  - Document all command-line options and flags
  - Add examples for each command
  - Document advanced usage patterns
  - Ensure no features are glossed over or undocumented
  - **Commands to document:**
    - `clean` - Main cleaning action with all options
    - `file` - Filing existing emails with `--file-from` options
    - `list` - Showing email-to-folder mappings
    - `folders` - Listing all folders
    - `setup` - Interactive setup wizard
    - `analyze` - Email pattern analysis with `--brief`, `--detailed`, `--folder` options
    - `sent-analysis` - Three subcommands: `collect`, `analyze`, `compare`
    - `config` - Seven subcommands: `show`, `get`, `set`, `add`, `remove`, `init`, `init-domain-rules`
    - `--unjunk` flag - Currently confusing, needs redesign (see separate TODO item)
  - **Advanced features to document:**
    - Time-based processing (`--since_months`, `--valid-from`)
    - Data directory usage (`--data-dir`)
    - Logging options (`--verbose`, `--level`, `--log-file`)
    - Authentication options (OAuth2 vs password)
    - Pretend mode (`--pretend`) for safe testing

## 🎯 Completed ✅

- [x] **Interactive Console** - Added REPL interface with Pry/IRB fallback, config file support, and convenience methods
- [x] **Separate Authentication Setup** - Added standalone auth CLI commands with setup, test, show, and reset functionality
- [x] **Code Encapsulation Improvements** - Replaced all instance_variable_get usage with proper public readers
- [x] **Documentation Reorganization** - Split large README into focused docs
- [x] **Container Deployment** - Added comprehensive container support
- [x] **GitHub Integration** - Set up CI/CD with GitHub Actions
- [x] **Branch Management** - Renamed master to main
- [x] **Authentication Documentation** - Updated with Podman secrets
- [x] **Default Action Fix** - Corrected documentation about ./cleanbox behavior
- [x] **Setup Wizard Performance Optimization** - Implemented selective analysis modes (:full, :partial, :skip) for efficient updates
- [x] **Blacklist Folder Management** - Added early blacklist folder detection and exclusion from analysis
- [x] **Folder Analysis Caching** - Implemented caching in FolderCategorizer to avoid redundant IMAP calls
- [x] **Analysis Mode Implementation** - Added config-aware analysis that reuses existing configuration data
- [x] **Retention Policy System** - Implemented comprehensive unknown sender handling with four retention policies (spammy, hold, quarantine, paranoid), configuration management, setup wizard integration, and full test coverage

---

## 📝 Notes

### Priority Guidelines
- **High Priority**: Security, critical bugs, user-facing issues
- **Medium Priority**: Performance, user experience, new features
- **Low Priority**: Nice-to-have features, documentation, infrastructure

### Contributing
When adding new items:
1. Use clear, descriptive titles
2. Add context and requirements
3. Assign appropriate priority level
4. Link to related issues or discussions

### Review Schedule
- Review and update priorities monthly
- Archive completed items quarterly
- Reassess roadmap annually 