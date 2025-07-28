# Container Deployment Guide

This guide covers deploying Cleanbox using containers (Podman or Docker) with automated cleaning and manual command execution.

## Overview

Cleanbox can be deployed as a container for easy management and isolation. The deployment includes:

- **Automated cleaning**: Scheduled email processing using `cleanbox-run`
- **Manual commands**: Interactive commands using `cb` utility
- **Data persistence**: Configuration, cache, and logs stored in a data directory
- **Authentication**: Support for Microsoft 365 OAuth2 and password-based auth

## Prerequisites

- Container engine: Podman (recommended) or Docker
- Git repository access
- Email server credentials
- Data directory for persistent storage

## Quick Start

### 1. Build the Container Image

```bash
# Clone the repository
git clone <repository-url>
cd cleanbox

# Build the container image
podman build -t cleanbox:latest .
```

### 2. Set Up Data Directory

```bash
# Create data directory structure
mkdir -p ~/cleanbox/data/{cache,log,config}

# Copy configuration template
cp .cleanbox.yml ~/cleanbox/data/cleanbox.yml
```

### 3. Configure Authentication

#### Microsoft 365 OAuth2 (Recommended)

Set up secrets for OAuth2 authentication:

```bash
# Create secrets (Podman)
podman secret create client_id <your-client-id>
podman secret create client_secret <your-client-secret>
podman secret create tenant_id <your-tenant-id>

# Or set environment variables (Docker)
export CLIENT_ID="your-client-id"
export CLIENT_SECRET="your-client-secret"
export TENANT_ID="your-tenant-id"
```

#### Password Authentication

```bash
# Create password secret (Podman)
podman secret create imap_password <your-password>

# Or set environment variable (Docker)
export IMAP_PASSWORD="your-password"
```

### 4. Set Up Utility Scripts

Copy and customize the template scripts:

```bash
# Copy templates
cp scripts/cleanbox-run.template ~/cleanbox-run
cp scripts/cb.template ~/cb

# Make executable
chmod +x ~/cleanbox-run ~/cb

# Customize for your environment
export CLEANBOX_DATA_PATH="/home/user/cleanbox/data"
export CLEANBOX_CONTAINER_DATA_PATH="/app/data"
export CLEANBOX_IMAGE="cleanbox:latest"
export CLEANBOX_USER="1000:1000"
export CONTAINER_ENGINE="podman"
```

### 5. Test the Setup

```bash
# Test configuration
~/cb config show

# Test folder listing
~/cb folders

# Test cleaning (dry run)
~/cb clean -n
```

## Configuration

### Environment Variables

The scripts support these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CLEANBOX_DATA_PATH` | `/home/user/cleanbox/data` | Host path to data directory |
| `CLEANBOX_CONTAINER_DATA_PATH` | `/app/data` | Container path to data directory |
| `CLEANBOX_IMAGE` | `cleanbox:latest` | Container image name |
| `CLEANBOX_USER` | `1000:1000` | User ID for container |
| `CONTAINER_ENGINE` | `podman` | Container engine (podman/docker) |

### Authentication Variables

For Microsoft 365 OAuth2:
- `CLIENT_ID`: Azure app client ID
- `CLIENT_SECRET`: Azure app client secret  
- `TENANT_ID`: Azure tenant ID

For password authentication:
- `IMAP_PASSWORD`: IMAP password

## Automated Cleaning

### Systemd Timer Setup

Create a systemd timer for automated cleaning:

```bash
# Create service file
sudo tee /etc/systemd/system/cleanbox.service <<EOF
[Unit]
Description=Cleanbox Email Cleaning
After=network.target

[Service]
Type=oneshot
User=sbrook
ExecStart=/home/sbrook/cleanbox-run
Environment=CLEANBOX_DATA_PATH=/home/sbrook/cleanbox/data
Environment=CONTAINER_ENGINE=podman

[Install]
WantedBy=multi-user.target
EOF

# Create timer file
sudo tee /etc/systemd/system/cleanbox.timer <<EOF
[Unit]
Description=Run Cleanbox every 15 minutes
Requires=cleanbox.service

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start
sudo systemctl enable cleanbox.timer
sudo systemctl start cleanbox.timer
```

### Manual Testing

Test the automated cleaning:

```bash
# Test the service
sudo systemctl start cleanbox.service
sudo systemctl status cleanbox.service

# Check logs
journalctl -u cleanbox.service -f
```

## Manual Commands

Use the `cb` utility for interactive commands:

```bash
# Show help
~/cb --help

# List folders
~/cb folders

# Analyze email patterns
~/cb analyze

# File emails from inbox
~/cb file

# Show configuration
~/cb config show

# Run setup wizard
~/cb setup
```

## Troubleshooting

### Permission Issues

If you encounter permission errors:

```bash
# Check data directory permissions
ls -la ~/cleanbox/data/

# Fix permissions if needed
chmod 755 ~/cleanbox/data
chown -R $USER:$USER ~/cleanbox/data
```

### Container Engine Differences

**Podman** (recommended):
- Uses `--userns=keep-id` for user namespace mapping
- Supports `--secret` for secure credential storage
- Better security isolation

**Docker**:
- Remove `--userns=keep-id` flag
- Use environment variables instead of secrets
- May require different user mapping

### SELinux Issues

On systems with SELinux enabled:

```bash
# Check SELinux status
sestatus

# If needed, adjust SELinux context
sudo semanage fcontext -a -t container_file_t "/home/user/cleanbox/data(/.*)?"
sudo restorecon -Rv /home/user/cleanbox/data
```

### Log Analysis

Check logs for issues:

```bash
# Container logs
podman logs <container-id>

# Application logs
tail -f ~/cleanbox/data/log/cleanbox

# System service logs
journalctl -u cleanbox.service -f
```

## Security Considerations

1. **Secrets Management**: Use container secrets or environment variables for credentials
2. **Data Isolation**: Keep data directory separate from application code
3. **User Permissions**: Run container with minimal required permissions
4. **Network Access**: Ensure container can reach IMAP server
5. **Log Security**: Protect log files containing email metadata

## Advanced Configuration

### Custom Data Directory

```bash
export CLEANBOX_DATA_PATH="/opt/cleanbox/data"
export CLEANBOX_CONTAINER_DATA_PATH="/app/data"
```

### Multiple Instances

For multiple email accounts:

```bash
# Create separate data directories
mkdir -p ~/cleanbox/account1/data
mkdir -p ~/cleanbox/account2/data

# Create separate scripts
cp scripts/cb.template ~/cb-account1
cp scripts/cb.template ~/cb-account2

# Configure each instance
export CLEANBOX_DATA_PATH="/home/user/cleanbox/account1/data"
~/cb-account1 config show
```

### Production Deployment

For production environments:

1. Use a dedicated user account
2. Set up proper logging and monitoring
3. Configure backup for data directory
4. Use container registry for image distribution
5. Implement health checks and restart policies

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review application logs in `~/cleanbox/data/log/`
3. Test with `--verbose` flag for detailed output
4. Check systemd service status and logs 