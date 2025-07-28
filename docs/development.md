# Development

This guide covers development setup, project structure, and contributing guidelines for Cleanbox.

## Prerequisites

### Development Environment

- **Ruby 2.6 or higher**
- **Bundler** (for dependency management)
- **Git** (for version control)
- **Text editor** (VS Code, Vim, etc.)

### System Requirements

**macOS:**
```bash
# Install Ruby via Homebrew
brew install ruby

# Install Bundler
gem install bundler
```

**Ubuntu/Debian:**
```bash
# Install Ruby and development tools
sudo apt update
sudo apt install ruby ruby-bundler ruby-dev build-essential

# Install Bundler
gem install bundler
```

**Windows:**
- Download and install [RubyInstaller](https://rubyinstaller.org/)
- Install Bundler: `gem install bundler`

## Development Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd cleanbox
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Make the Script Executable

```bash
chmod +x cleanbox
```

### 4. Run Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/cleanbox_spec.rb

# Run tests with coverage
bundle exec rspec --format documentation
```

## Project Structure

```
cleanbox/
├── lib/                          # Main application code
│   ├── cli/                     # Command-line interface
│   │   ├── cleanbox_cli.rb     # Main CLI orchestrator
│   │   ├── config_manager.rb   # Configuration management
│   │   ├── cli_parser.rb       # Command-line argument parsing
│   │   ├── validator.rb        # Configuration validation
│   │   ├── secrets_manager.rb  # Secure credential management
│   │   ├── setup_wizard.rb     # Interactive setup wizard
│   │   ├── analyzer_cli.rb     # Analysis commands
│   │   └── sent_analysis_cli.rb # Sent analysis commands
│   ├── auth/                    # Authentication
│   │   └── authentication_manager.rb
│   ├── analysis/                # Email analysis
│   │   ├── email_analyzer.rb   # Email content analysis
│   │   ├── folder_categorizer.rb # Folder categorization
│   │   └── domain_mapper.rb    # Domain mapping
│   ├── cleanbox.rb             # Core business logic
│   ├── message.rb              # Individual message processing
│   ├── folder_checker.rb       # Folder analysis with caching
│   ├── connection.rb           # IMAP connection management
│   └── microsoft_365_application_token.rb
├── spec/                        # Test files
│   ├── cli/                    # CLI tests
│   ├── auth/                   # Authentication tests
│   ├── analysis/               # Analysis tests
│   ├── fixtures/               # Test data
│   └── spec_helper.rb          # Test configuration
├── config/                      # Configuration files
│   └── domain_rules.yml        # Default domain rules
├── docs/                        # Documentation
├── cleanbox                     # Main executable
├── Gemfile                      # Ruby dependencies
└── README.md                    # Project overview
```

## Key Components

### Core Classes

**`Cleanbox`** (`lib/cleanbox.rb`)
- Main business logic class
- Handles email processing and organization
- Inherits from `CleanboxConnection`

**`CLI::CleanboxCLI`** (`lib/cli/cleanbox_cli.rb`)
- Main command-line interface
- Orchestrates all CLI operations
- Handles option parsing and command routing

**`Auth::AuthenticationManager`** (`lib/auth/authentication_manager.rb`)
- Manages different authentication methods
- Supports OAuth2 and password-based auth
- Auto-detects auth type based on host

**`CLI::SetupWizard`** (`lib/cli/setup_wizard.rb`)
- Interactive setup process
- Analyzes email structure
- Generates configuration recommendations

### Analysis Components

**`Analysis::EmailAnalyzer`** (`lib/analysis/email_analyzer.rb`)
- Analyzes email content and headers
- Extracts sender information
- Identifies email patterns

**`Analysis::FolderCategorizer`** (`lib/analysis/folder_categorizer.rb`)
- Categorizes folders as whitelist or list
- Analyzes folder contents
- Generates recommendations

**`Analysis::DomainMapper`** (`lib/analysis/domain_mapper.rb`)
- Maps email domains to folders
- Handles domain relationships
- Processes domain rules

## Development Workflow

### Running the Application

```bash
# Run with debug logging
./cleanbox --verbose --level debug

# Run with custom data directory
./cleanbox --data-dir /tmp/cleanbox-test

# Run specific command
./cleanbox config show
```

### Testing

```bash
# Run all tests
bundle exec rspec

# Run tests with coverage
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/cli/cleanbox_cli_spec.rb

# Run tests in watch mode
bundle exec rspec --watch
```

### Code Quality

```bash
# Run RuboCop for code style
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Check for security vulnerabilities
bundle audit
```

## Adding New Features

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Implement the Feature

- Add new classes in appropriate directories
- Follow existing naming conventions
- Add comprehensive tests
- Update documentation

### 3. Add Tests

```bash
# Create test file
touch spec/your_new_feature_spec.rb

# Run tests
bundle exec rspec spec/your_new_feature_spec.rb
```

### 4. Update Documentation

- Update relevant documentation files in `docs/`
- Add examples and use cases
- Update README if needed

### 5. Submit Pull Request

```bash
git add .
git commit -m "feat: add your feature description"
git push origin feature/your-feature-name
```

## Common Development Tasks

### Adding a New CLI Command

1. **Add command to CLI parser:**
   ```ruby
   # lib/cli/cli_parser.rb
   def parse!
     # Add your new option
     @options[:your_option] = true
   end
   ```

2. **Add command handler:**
   ```ruby
   # lib/cli/cleanbox_cli.rb
   def handle_your_command
     return unless ARGV.first == 'your-command'
     # Implement command logic
   end
   ```

3. **Add tests:**
   ```ruby
   # spec/cli/cleanbox_cli_spec.rb
   describe 'your-command' do
     it 'handles your command correctly' do
       # Test implementation
     end
   end
   ```

### Adding a New Authentication Method

1. **Add auth type to authentication manager:**
   ```ruby
   # lib/auth/authentication_manager.rb
   def authenticate_your_auth(imap, options)
     # Implement authentication logic
   end
   ```

2. **Add auto-detection:**
   ```ruby
   def determine_auth_type(host, auth_type)
     case host
     when /your-provider\.com/
       'your_auth_type'
     # ... existing cases
     end
   end
   ```

3. **Add tests:**
   ```ruby
   # spec/auth/authentication_manager_spec.rb
   describe 'your auth type' do
     it 'authenticates correctly' do
       # Test implementation
     end
   end
   ```

### Adding Configuration Options

1. **Add to default options:**
   ```ruby
   # lib/cli/cleanbox_cli.rb
   def default_options
     {
       # ... existing options
       your_option: 'default_value'
     }
   end
   ```

2. **Add validation:**
   ```ruby
   # lib/cli/validator.rb
   def self.validate_your_option!(options)
     # Add validation logic
   end
   ```

3. **Add tests:**
   ```ruby
   # spec/cli/validator_spec.rb
   describe 'your option validation' do
     it 'validates correctly' do
       # Test validation
     end
   end
   ```

## Testing Strategy

### Test Structure

- **Unit tests**: Test individual classes and methods
- **Integration tests**: Test CLI commands and workflows
- **Fixtures**: Use VCR cassettes for external API calls

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/cli/cleanbox_cli_spec.rb

# Run tests with coverage
bundle exec rspec --format documentation

# Run tests in parallel (if supported)
bundle exec parallel_rspec spec/
```

### Test Data

- **VCR cassettes**: Record and replay HTTP interactions
- **Fixtures**: Use YAML files for test data
- **Mocks**: Mock external dependencies

## Code Style Guidelines

### Ruby Style

- Follow [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide)
- Use RuboCop for automated style checking
- Prefer explicit over implicit
- Use meaningful variable and method names

### Documentation

- Document public methods with YARD comments
- Keep README and docs up to date
- Add examples for complex features

### Git Workflow

- Use conventional commit messages
- Create feature branches for new work
- Squash commits before merging
- Write descriptive commit messages

## Contributing Guidelines

### Before Contributing

1. **Check existing issues** for similar work
2. **Discuss major changes** in an issue first
3. **Follow the existing code style**
4. **Add tests** for new features
5. **Update documentation** as needed

### Pull Request Process

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests** for new functionality
5. **Update documentation**
6. **Run the test suite**
7. **Submit a pull request**

### Commit Message Format

Use conventional commit messages:

```
type(scope): description

feat: add new authentication method
fix: resolve configuration loading issue
docs: update installation instructions
test: add tests for new feature
refactor: improve code organization
```

### Code Review Process

- All changes require review
- Address review comments promptly
- Keep discussions constructive
- Test changes thoroughly

## Deployment

### Release Process

1. **Update version** in appropriate files
2. **Update changelog** with new features/fixes
3. **Create release tag**
4. **Build and test** release artifacts
5. **Publish release**

### Docker Deployment

```dockerfile
# Example Dockerfile
FROM ruby:2.7-slim

WORKDIR /app
COPY . .

RUN bundle install
RUN chmod +x cleanbox

ENTRYPOINT ["./cleanbox"]
```

### Environment Variables

```bash
# Production environment variables
CLEANBOX_CLIENT_ID=your-client-id
CLEANBOX_CLIENT_SECRET=your-client-secret
CLEANBOX_TENANT_ID=your-tenant-id
```

## Troubleshooting Development Issues

### Common Issues

**"Bundle install fails"**
- Check Ruby version: `ruby --version`
- Update Bundler: `gem update bundler`
- Clear cache: `bundle clean --force`

**"Tests fail"**
- Check test dependencies: `bundle exec rspec --version`
- Update test gems: `bundle update rspec`
- Check test configuration

**"RuboCop errors"**
- Auto-fix: `bundle exec rubocop -a`
- Check style guide for manual fixes
- Update RuboCop configuration if needed

### Debug Mode

```bash
# Enable debug logging
./cleanbox --verbose --level debug

# Run with custom data directory
./cleanbox --data-dir /tmp/debug --verbose --level debug
```

## Next Steps

After setting up development:

1. **[Installation](installation.md)** - User installation guide
2. **[Authentication](authentication.md)** - Authentication setup
3. **[Configuration](configuration.md)** - Configuration options
4. **[Usage](usage.md)** - How to use Cleanbox 