# Troubleshooting

This guide covers common issues you might encounter when using Cleanbox and how to resolve them.

## Authentication Issues

### "Authentication failed"

**Symptoms:**
- Cleanbox fails to connect to your email server
- Error messages about invalid credentials

**Solutions:**

1. **Check OAuth2 credentials (Microsoft 365):**
   ```bash
   # Verify your credentials are set
   ./cleanbox config show --all
   
   # Check environment variables
   echo $CLEANBOX_CLIENT_ID
   echo $CLEANBOX_CLIENT_SECRET
   echo $CLEANBOX_TENANT_ID
   ```

2. **Verify Microsoft app registration:**
   - Ensure admin consent was granted for API permissions
   - Check that your username matches the registered application
   - Verify the app registration is active

3. **Check password authentication:**
   ```bash
   # For password-based auth, check if you need an app password
   # Gmail users with 2FA need app passwords
   ```

4. **Test connection manually:**
   ```bash
   # Enable debug logging
   ./cleanbox --verbose --level debug
   ```

### "Permission denied"

**Symptoms:**
- Connection succeeds but operations fail
- Error messages about insufficient permissions

**Solutions:**

1. **Check IMAP settings:**
   - Ensure IMAP is enabled in your email account
   - For Gmail, check "Less secure app access" settings

2. **Verify OAuth2 permissions:**
   - Ensure your Microsoft app has the correct permissions
   - Check that admin consent was granted
   - Verify the permissions include `IMAP.AccessAsUser.All`

3. **Check folder permissions:**
   ```bash
   # List available folders
   ./cleanbox folders
   ```

### "Invalid client"

**Symptoms:**
- OAuth2 authentication fails with "invalid client" error

**Solutions:**

1. **Verify client credentials:**
   ```bash
   # Check your client_id and client_secret
   ./cleanbox config show --all
   ```

2. **Check app registration:**
   - Ensure your app registration is active
   - Verify you're using the correct tenant_id
   - Check that the client secret hasn't expired

3. **Regenerate client secret:**
   - Go to Microsoft Entra Admin Center
   - Navigate to your app registration
   - Create a new client secret
   - Update your configuration

### "Token expired"

**Symptoms:**
- OAuth2 authentication works initially but fails later

**Solutions:**

1. **This is normal behavior:**
   - OAuth2 tokens expire automatically
   - Cleanbox will refresh tokens as needed
   - If persistent issues occur, regenerate your client secret

2. **Check token refresh:**
   ```bash
   # Enable debug logging to see token refresh
   ./cleanbox --verbose --level debug
   ```

## Configuration Issues

### "Configuration not found"

**Symptoms:**
- Cleanbox can't find your configuration file
- Error messages about missing configuration

**Solutions:**

1. **Check configuration file location:**
   ```bash
   # Show current configuration
   ./cleanbox config show
   
   # Check if config file exists
   ls -la ~/.cleanbox.yml
   ```

2. **Initialize configuration:**
   ```bash
   # Create configuration file
   ./cleanbox config init
   ```

3. **Check data directory:**
   ```bash
   # If using --data-dir, check the correct location
   ls -la /path/to/data/config.yml
   ```

### "Invalid configuration"

**Symptoms:**
- Configuration validation fails
- Error messages about missing required fields

**Solutions:**

1. **Validate configuration:**
   ```bash
   # Check for configuration errors
   ./cleanbox config validate
   ```

2. **Check required fields:**
   - `host` - IMAP server hostname
   - `username` - Email username
   - `auth_type` - Authentication method

3. **Fix common issues:**
   ```bash
   # Set missing required fields
   ./cleanbox config set host "outlook.office365.com"
   ./cleanbox config set username "your-email@example.com"
   ./cleanbox config set auth_type "oauth2_microsoft"
   ```

### "Domain rules not working"

**Symptoms:**
- Domain mapping doesn't work as expected
- Related domains aren't being filed together

**Solutions:**

1. **Check domain rules file:**
   ```bash
   # Initialize domain rules if not exists
   ./cleanbox config init-domain-rules
   
   # Check domain rules file location
   ls -la ~/.cleanbox/domain_rules.yml
   ```

2. **Verify YAML syntax:**
   ```bash
   # Check for syntax errors
   ruby -e "require 'yaml'; YAML.load_file('~/.cleanbox/domain_rules.yml')"
   ```

3. **Enable verbose logging:**
   ```bash
   # See which domain rules file is being loaded
   ./cleanbox --verbose
   ```

## Processing Issues

### "Cleanbox moved important emails to spam"

**Symptoms:**
- Important emails are moved to junk/spam folder
- False positives in email classification

**Solutions:**

1. **This is normal initially:**
   - Cleanbox learns from your existing organization
   - Use `--pretend` flag to preview actions
   - Organize more emails into appropriate folders

2. **Add important senders to whitelist:**
   ```bash
   # Add important folders to whitelist
   ./cleanbox config add whitelist_folders "Important"
   ./cleanbox config add whitelist_folders "Family"
   ```

3. **Check your junk folder regularly:**
   ```bash
   # Unjunk emails from spam
   ./cleanbox --unjunk Inbox
   ```

4. **Use sent analysis to optimize:**
   ```bash
   # Analyze your communication patterns
   ./cleanbox sent-analysis collect
   ./cleanbox sent-analysis compare
   ```

### "No emails processed"

**Symptoms:**
- Cleanbox runs but doesn't process any emails
- No output or very brief output

**Solutions:**

1. **Check for new emails:**
   ```bash
   # Verify you have new emails to process
   # Cleanbox only processes new emails by default
   ```

2. **Use file command for existing emails:**
   ```bash
   # Process existing emails in inbox
   ./cleanbox file
   ```

3. **Check time-based filtering:**
   ```bash
   # Process emails from last 3 months
   ./cleanbox --since_months 3
   ```

4. **Enable verbose output:**
   ```bash
   # See detailed processing information
   ./cleanbox --verbose
   ```

### "Folder not found"

**Symptoms:**
- Error messages about missing folders
- Cleanbox can't find specified folders

**Solutions:**

1. **List available folders:**
   ```bash
   # See all available folders
   ./cleanbox folders
   ```

2. **Check folder names:**
   - Ensure folder names match exactly (case-sensitive)
   - Check for extra spaces or special characters

3. **Update configuration:**
   ```bash
   # Update folder names in configuration
   ./cleanbox config set whitelist_folders "['Family', 'Work']"
   ```

## Performance Issues

### "Cleanbox is slow"

**Symptoms:**
- Cleanbox takes a long time to run
- Slow processing of emails

**Solutions:**

1. **Use caching effectively:**
   - Subsequent runs will be faster
   - Cache is automatically used for folder analysis

2. **Limit processing scope:**
   ```bash
   # Process only recent emails
   ./cleanbox --since_months 1
   
   # Process specific folders only
   ./cleanbox file --file-from Family --file-from Work
   ```

3. **Check cache size:**
   ```bash
   # Monitor cache directory size
   du -sh ~/.cleanbox/cache/
   ```

### "Memory issues"

**Symptoms:**
- Cleanbox uses too much memory
- Out of memory errors

**Solutions:**

1. **Process emails in smaller batches:**
   - Cleanbox processes emails in batches of 800
   - This is automatically handled

2. **Limit concurrent operations:**
   - Cleanbox is single-threaded by design
   - No additional configuration needed

3. **Monitor system resources:**
   ```bash
   # Check memory usage during processing
   ./cleanbox --verbose
   ```

## Sent Analysis Issues

### "No sent emails found"

**Symptoms:**
- Sent analysis fails to find sent emails
- Empty analysis results

**Solutions:**

1. **Check sent folder configuration:**
   ```bash
   # Verify sent folder name
   ./cleanbox config get sent_folder
   ```

2. **Check for sent emails:**
   - Ensure you have sent emails in the specified time period
   - Default is last 24 months

3. **Use verbose logging:**
   ```bash
   # See detailed collection process
   ./cleanbox sent-analysis collect --verbose
   ```

### "Data collection failed"

**Symptoms:**
- Sent analysis data collection fails
- Error messages during collection

**Solutions:**

1. **Check permissions:**
   - Ensure you have access to sent emails
   - Verify IMAP permissions

2. **Check authentication:**
   - Verify your credentials are correct
   - Test basic connection first

3. **Use debug mode:**
   ```bash
   # Enable debug logging
   ./cleanbox sent-analysis collect --verbose --level debug
   ```

## Debug Mode

### Enable Debug Logging

```bash
# Enable debug logging for all operations
./cleanbox --verbose --level debug

# Log to file for analysis
./cleanbox --log-file cleanbox.log --verbose --level debug

# Debug specific commands
./cleanbox sent-analysis collect --verbose --level debug
```

### Common Debug Information

**Authentication debugging:**
- OAuth2 token requests and responses
- IMAP connection details
- Permission checks

**Processing debugging:**
- Email analysis steps
- Folder mapping decisions
- Cache operations

**Configuration debugging:**
- File loading order
- Configuration validation
- Domain rules processing

## Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide**
2. **Enable debug logging** and check the output
3. **Verify your configuration** with `./cleanbox config show`
4. **Test with `--pretend`** to see what would happen

### Information to Include

When asking for help, include:

1. **Error message** (exact text)
2. **Debug output** (with `--verbose --level debug`)
3. **Configuration** (with `./cleanbox config show`)
4. **System information** (OS, Ruby version)
5. **Steps to reproduce** the issue

### Useful Commands for Diagnosis

```bash
# Check system information
ruby --version
./cleanbox --help

# Check configuration
./cleanbox config show
./cleanbox config validate

# Check connection
./cleanbox folders

# Test with dry run
./cleanbox clean --pretend --verbose
```

## Next Steps

After resolving issues:

1. **[Usage](usage.md)** - Learn how to use Cleanbox effectively
2. **[Configuration](configuration.md)** - Advanced configuration options
3. **[Sent Analysis](sent-analysis.md)** - Understand your email patterns 