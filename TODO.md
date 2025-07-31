# Cleanbox TODO

This file tracks planned improvements, features, and tasks for the Cleanbox project.

## 🚀 High Priority

### Authentication Improvements
- [ ] **Add Classic OAuth2 Token Exchange for Microsoft 365**
  - Implement refresh token handling
  - Add token expiration and renewal logic
  - Update authentication documentation
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

### Performance Optimizations
- [ ] **Optimize Email Processing**
  - Profile current performance bottlenecks
  - Implement batch processing for large mailboxes
  - Add progress indicators for long operations
- [ ] **Improve Caching Strategy**
  - Implement smarter cache invalidation
  - Add cache size management
  - Optimize folder analysis caching

### User Experience
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

### Data Protection
- [ ] **Add Data Encryption**
  - Encrypt sensitive configuration
  - Add encrypted cache storage
  - Implement secure logging

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

### Monitoring & Observability
- [ ] **Add Metrics Collection**
  - Track processing performance
  - Monitor error rates
  - Add custom metrics
- [ ] **Improve Logging**
  - Structured logging
  - Log rotation and management
  - Add log aggregation support

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

### Web Interface (Future)
- [ ] **Add Web Dashboard**
  - Email statistics and analytics
  - Configuration management
  - Real-time monitoring
- [ ] **Add REST API**
  - Programmatic access
  - Integration with other tools
  - Webhook support

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

- [x] **Separate Authentication Setup** - Added standalone auth CLI commands with setup, test, show, and reset functionality
- [x] **Code Encapsulation Improvements** - Replaced all instance_variable_get usage with proper public readers
- [x] **Documentation Reorganization** - Split large README into focused docs
- [x] **Container Deployment** - Added comprehensive container support
- [x] **GitHub Integration** - Set up CI/CD with GitHub Actions
- [x] **Branch Management** - Renamed master to main
- [x] **Authentication Documentation** - Updated with Podman secrets
- [x] **Default Action Fix** - Corrected documentation about ./cleanbox behavior

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