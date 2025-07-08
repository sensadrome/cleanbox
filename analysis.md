## What Cleanbox Does

**Cleanbox** is an intelligent email management tool that automatically organizes emails by learning from your existing folder structure and email patterns. It's designed to work with IMAP email servers (primarily Microsoft 365/Outlook and Gmail) and provides several key functions:

### Core Functionality:
1. **Email Cleaning**: Automatically moves new emails from the inbox to appropriate folders based on learned patterns
2. **Email Filing**: Reorganizes existing emails in the inbox based on sender patterns
3. **Unjunking**: Restores emails from junk/spam folders based on trusted sender patterns
4. **List Management**: Handles newsletters, notifications, and marketing emails by moving them to designated folders
5. **Whitelisting**: Keeps important emails in the inbox based on sender addresses and domains

## How It Works

### Architecture Overview:
- **CLI-based application** with comprehensive configuration management
- **Modular design** with separate classes for different responsibilities
- **Caching system** for performance optimization
- **Multiple authentication methods** (OAuth2 Microsoft, password-based)

### Key Components:

1. **CLI::CleanboxCLI** - Main entry point that orchestrates the application
2. **CLI::ConfigManager** - Handles YAML configuration with comprehensive defaults and comments
3. **CLI::CLIParser** - Command-line argument parsing
4. **CLI::Validator** - Validates required configuration options
5. **CLI::SecretsManager** - Manages sensitive credentials from environment variables or secrets
6. **Auth::AuthenticationManager** - Handles different authentication methods
7. **Cleanbox** - Core business logic for email processing
8. **CleanboxMessage** - Individual message processing and decision making
9. **CleanboxFolderChecker** - Folder analysis with intelligent caching
10. **Microsoft365ApplicationToken** - OAuth2 token management for Microsoft 365

### Processing Flow:
1. **Configuration Loading**: Loads settings from YAML file, environment variables, and command-line options
2. **Authentication**: Connects to IMAP server using appropriate auth method
3. **Learning Phase**: Analyzes existing folders to build whitelists and domain mappings
4. **Processing**: Applies learned patterns to new or existing emails
5. **Caching**: Stores folder analysis results for performance

## Strengths

1. **Comprehensive Configuration**: Excellent YAML-based config with helpful comments and examples
2. **Flexible Authentication**: Supports both OAuth2 and password-based auth
3. **Intelligent Caching**: Folder analysis is cached to avoid repeated processing
4. **Multiple Operation Modes**: Clean, file, unjunk, and list management
5. **Container-Ready**: Docker support for deployment
6. **Good Error Handling**: Validation and helpful error messages
7. **Performance Optimized**: Batch processing and caching strategies

## Areas for Improvement

### 1. **Security & Authentication**
- **Gmail OAuth2 not implemented** - Only Microsoft 365 OAuth2 is working
- **Token refresh handling** - No automatic token refresh for expired OAuth2 tokens
- **Credential validation** - Could validate credentials before processing
- **Rate limiting** - No protection against IMAP rate limits

### 2. **Error Handling & Resilience**
- **Network resilience** - No retry logic for IMAP connection failures
- **Partial failure handling** - If one message fails, entire operation might fail
- **Graceful degradation** - No fallback when cache is corrupted
- **Transaction safety** - No rollback if operations fail mid-process

### 3. **Performance & Scalability**
- **Memory usage** - Large folders could consume significant memory
- **Batch size limits** - Fixed 800-message batches might not be optimal for all servers
- **Parallel processing** - No concurrent processing of multiple folders
- **Cache invalidation** - Cache could become stale if folder changes aren't detected

### 4. **User Experience**
- **Progress reporting** - No progress indicators for long operations
- **Dry-run improvements** - Could show more detailed preview of actions
- **Interactive mode** - No interactive confirmation for risky operations
- **Better logging** - Could use structured logging with different levels

### 5. **Configuration & Flexibility**
- **Validation gaps** - Some configuration combinations might not be validated
- **Dynamic configuration** - No runtime configuration changes
- **Profile support** - No multiple configuration profiles
- **Import/export** - No way to share configurations between users

### 6. **Testing & Quality**
- **Test coverage** - No visible test suite
- **Integration tests** - No tests against real IMAP servers
- **Mock objects** - No testing infrastructure for IMAP operations
- **CI/CD** - No automated testing pipeline

### 7. **Monitoring & Observability**
- **Metrics collection** - No performance metrics or statistics
- **Health checks** - No way to verify system health
- **Audit logging** - Limited audit trail of operations
- **Alerting** - No notifications for failures or issues

### 8. **Documentation & Maintenance**
- **API documentation** - Limited documentation of internal APIs
- **Deployment guide** - No comprehensive deployment documentation
- **Troubleshooting guide** - No common issues and solutions
- **Version compatibility** - No clear version requirements

## Recommendations for Next Steps

1. **Implement Gmail OAuth2** - Complete the authentication system
2. **Add comprehensive testing** - Unit and integration tests
3. **Improve error handling** - Add retry logic and better error recovery
4. **Add progress reporting** - Show progress for long operations
5. **Implement token refresh** - Handle OAuth2 token expiration
6. **Add monitoring** - Basic metrics and health checks
7. **Create deployment documentation** - Clear setup and deployment guides
8. **Add configuration validation** - Validate all configuration combinations

The codebase shows good architectural decisions and is well-structured for a CLI tool. The main areas for improvement are around robustness, user experience, and operational concerns rather than fundamental design issues.