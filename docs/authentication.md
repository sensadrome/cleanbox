# Authentication

Cleanbox supports multiple authentication methods for connecting to your email server. This guide covers setting up each method securely.

## Supported Authentication Methods

- **OAuth2 (Microsoft 365)** - Recommended for Microsoft 365/Outlook accounts
- **Password-based IMAP** - Standard IMAP authentication for any email provider
- **OAuth2 (Gmail)** - Planned for future releases

## Microsoft 365 / Entra OAuth2 Setup

Cleanbox supports OAuth2 authentication with Microsoft 365, which is more secure than password-based authentication and doesn't require app passwords.

### 1. Register Application in Microsoft Entra

1. Go to [Microsoft Entra Admin Center](https://entra.microsoft.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Click **New registration**
4. Fill in the details:
   - **Name**: `Cleanbox Email Manager` (or your preferred name)
   - **Supported account types**: Choose based on your needs:
     - `Accounts in this organizational directory only` (single tenant)
     - `Accounts in any organizational directory` (multi-tenant)
   - **Redirect URI**: Leave blank for now
5. Click **Register**

### 2. Configure API Permissions

1. In your new app registration, go to **API permissions**
2. Click **Add a permission**
3. Select **Microsoft Graph**
4. Choose **Application permissions** (not Delegated)
5. Search for and select these permissions:
   - `IMAP.AccessAsUser.All` - Full access to user mailboxes via IMAP
   - `Mail.Read` - Read user mail
   - `Mail.ReadWrite` - Read and write user mail
6. Click **Add permissions**
7. Click **Grant admin consent** (requires admin privileges)

### 3. Create Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Add a description (e.g., "Cleanbox OAuth2 Secret")
4. Choose expiration period
5. Click **Add**
6. **Important**: Copy the secret value immediately - you won't be able to see it again!

### 4. Get Application Details

1. Go to **Overview** to find:
   - **Application (client) ID** - This is your `client_id`
   - **Directory (tenant) ID** - This is your `tenant_id`
2. Use the client secret you created in step 3

### 5. Configure Cleanbox

**Option A: Interactive Setup (Recommended)**
```bash
./cleanbox setup
```
This will analyze your email structure and create both configuration files automatically.

**Option B: Manual Configuration**

The setup wizard will create two files:

1. **`~/.cleanbox.yml`** - Main configuration (non-sensitive settings):
```yaml
host: outlook.office365.com
username: your-email@yourdomain.com
auth_type: oauth2_microsoft
# Sensitive credentials are stored in .env file
```

2. **`.env`** - Sensitive credentials (automatically created):
```bash
CLEANBOX_CLIENT_ID=your-application-client-id
CLEANBOX_CLIENT_SECRET=your-client-secret
CLEANBOX_TENANT_ID=your-tenant-id
```

**Security Note**: The `.env` file is automatically added to `.gitignore` to prevent accidental commits of sensitive data.

**Option C: Container Deployment**
For container deployments, use Podman secrets:

```bash
# Create secrets for container use
podman secret create client_id "your-application-client-id"
podman secret create client_secret "your-client-secret"
podman secret create tenant_id "your-tenant-id"

# Use with container scripts
export CLIENT_ID="your-application-client-id"
export CLIENT_SECRET="your-client-secret"
export TENANT_ID="your-tenant-id"
```

See the [Container Deployment Guide](../deploy/CONTAINER_DEPLOYMENT.md) for detailed setup instructions.

## Standard IMAP Configuration

For email providers that don't support OAuth2 or when you prefer password-based authentication.

### Configuration

**Option A: Interactive Setup**
```bash
./cleanbox setup
```

**Option B: Manual Configuration**

1. **`~/.cleanbox.yml`** - Main configuration:
```yaml
host: imap.gmail.com
username: your-email@gmail.com
auth_type: password
# Password is stored in .env file
```

2. **`.env`** - Sensitive credentials:
```bash
CLEANBOX_PASSWORD=your-imap-password
```

**Container Deployment Option:**
```bash
# Create Podman secret
podman secret create imap_password "your-imap-password"

# Or set environment variable for scripts
export IMAP_PASSWORD="your-imap-password"
```

### Common IMAP Server Settings

**Gmail:**
```yaml
host: imap.gmail.com
username: your-email@gmail.com
auth_type: password
```

**Outlook.com:**
```yaml
host: outlook.office365.com
username: your-email@outlook.com
auth_type: password
```

**Yahoo:**
```yaml
host: imap.mail.yahoo.com
username: your-email@yahoo.com
auth_type: password
```

**Custom IMAP Server:**
```yaml
host: mail.yourdomain.com
username: your-email@yourdomain.com
auth_type: password
```

### App Passwords

For email providers that support 2-factor authentication, you'll need to create an app password:

**Gmail:**
1. Go to [Google Account Settings](https://myaccount.google.com/)
2. Navigate to **Security** → **2-Step Verification**
3. Click **App passwords**
4. Generate a password for "Mail"
5. Use this password in your Cleanbox configuration

**Outlook.com:**
1. Go to [Microsoft Account Security](https://account.microsoft.com/security)
2. Navigate to **Security** → **Advanced security options**
3. Click **Create a new app password**
4. Use this password in your Cleanbox configuration

## Security Best Practices

### Credential Storage

1. **Use `.env` files** for sensitive credentials (automatically created by setup wizard)
2. **Never commit credentials** to version control
3. **Use Podman secrets** for container deployments (recommended)
4. **Use environment variables** for script-based deployments
5. **Rotate credentials regularly** for OAuth2 applications

### File Permissions

```bash
# Secure your configuration files
chmod 600 ~/.cleanbox.yml
chmod 600 .env
```

### Environment Variables (Production)

For production deployments, use Podman secrets for enhanced security:

```bash
# Create Podman secrets (one-time setup)
podman secret create client_id "your-client-id"
podman secret create client_secret "your-client-secret"
podman secret create tenant_id "your-tenant-id"

# For password authentication
podman secret create imap_password "your-password"

# Run Cleanbox with secrets
podman run --rm \
  --secret client_id,type=env,target=CLIENT_ID \
  --secret client_secret,type=env,target=CLIENT_SECRET \
  --secret tenant_id,type=env,target=TENANT_ID \
  cleanbox:latest
```

**Alternative: Environment Variables for Scripts**

If using the template scripts, you can set environment variables that the scripts will convert to secrets:

```bash
# Set environment variables for script processing
export CLIENT_ID="your-client-id"
export CLIENT_SECRET="your-client-secret"
export TENANT_ID="your-tenant-id"

# Scripts automatically handle secret creation and usage
./cleanbox-run
```

### Container Security (Podman)

When running in containers with Podman, use secrets for secure credential management:

#### Microsoft 365 OAuth2

```bash
# Create Podman secrets
podman secret create client_id <your-client-id>
podman secret create client_secret <your-client-secret>
podman secret create tenant_id <your-tenant-id>

# Run container with secrets
podman run --rm \
  --secret client_id,type=env,target=CLIENT_ID \
  --secret client_secret,type=env,target=CLIENT_SECRET \
  --secret tenant_id,type=env,target=TENANT_ID \
  cleanbox:latest
```

#### Password Authentication

```bash
# Create password secret
podman secret create imap_password <your-password>

# Run container with secret
podman run --rm \
  --secret imap_password,type=env,target=IMAP_PASSWORD \
  cleanbox:latest
```

#### Using Template Scripts

The provided template scripts (`scripts/cleanbox-run.template` and `scripts/cb.template`) automatically handle secrets when environment variables are set:

```bash
# Set environment variables for secrets
export CLIENT_ID="your-client-id"
export CLIENT_SECRET="your-client-secret"
export TENANT_ID="your-tenant-id"

# Scripts will automatically add --secret flags
./cleanbox-run
./cb config show
```

**Security Benefits:**
- Secrets are encrypted at rest
- Not visible in container inspection
- Automatically cleaned up when container stops
- Better isolation than environment variables

## Troubleshooting Authentication

### Common Issues

**"Authentication failed"**
- Check your OAuth2 credentials (client_id, client_secret, tenant_id)
- Ensure admin consent was granted for API permissions
- Verify your username matches the registered application
- For password auth, check if you need an app password

**"Permission denied"**
- Ensure IMAP is enabled in your email account
- Check that your OAuth2 app has the correct permissions
- Verify admin consent was granted
- For Gmail, ensure "Less secure app access" is enabled (if not using app passwords)

**"Invalid client"**
- Verify your client_id and client_secret are correct
- Check that your app registration is active
- Ensure you're using the correct tenant_id

**"Token expired"**
- OAuth2 tokens expire automatically
- Cleanbox will refresh tokens as needed
- If persistent issues occur, regenerate your client secret

### Debug Mode

```bash
# Enable debug logging for authentication issues
./cleanbox --verbose --level debug
```

## Next Steps

After setting up authentication:

1. **[Configuration](configuration.md)** - Set up your preferences and rules
2. **[Usage](usage.md)** - Learn how to use Cleanbox effectively
3. **[Troubleshooting](troubleshooting.md)** - Common issues and solutions 