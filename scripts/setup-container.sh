#!/bin/bash

set -euo pipefail

echo "🚀 Cleanbox Container Setup"
echo "=========================="

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
    echo "❌ Error: Neither podman nor docker found. Please install one of them."
    exit 1
fi

CONTAINER_ENGINE=""
if command -v podman &> /dev/null; then
    CONTAINER_ENGINE="podman"
    echo "✅ Found podman"
elif command -v docker &> /dev/null; then
    CONTAINER_ENGINE="docker"
    echo "✅ Found docker"
fi

# Get user configuration
echo ""
echo "Configuration:"
read -p "Data directory path [~/cleanbox/data]: " DATA_PATH
DATA_PATH="${DATA_PATH:-~/cleanbox/data}"

read -p "Container image name [cleanbox:latest]: " IMAGE_NAME
IMAGE_NAME="${IMAGE_NAME:-cleanbox:latest}"

read -p "Container user ID [1000:1000]: " USER_ID
USER_ID="${USER_ID:-1000:1000}"

# Expand tilde in data path
DATA_PATH="${DATA_PATH/#\~/$HOME}"

echo ""
echo "Setting up Cleanbox container deployment..."

# Create data directory
echo "📁 Creating data directory: $DATA_PATH"
mkdir -p "$DATA_PATH"/{cache,log,config}

# Copy configuration if it exists
if [ -f ".cleanbox.yml" ]; then
    echo "📋 Copying configuration template"
    cp ".cleanbox.yml" "$DATA_PATH/cleanbox.yml"
    echo "   Edit $DATA_PATH/cleanbox.yml to configure your email settings"
else
    echo "⚠️  No .cleanbox.yml found. You'll need to create $DATA_PATH/cleanbox.yml"
fi

# Create utility scripts
echo "🔧 Creating utility scripts..."

# Create cleanbox-run script
cat > "$HOME/cleanbox-run" << 'EOF'
#!/bin/bash

set -euo pipefail

# Configuration - customize these for your environment
DATA_HOST_PATH="${CLEANBOX_DATA_PATH:-'$DATA_PATH'}"
DATA_CONTAINER_PATH="${CLEANBOX_CONTAINER_DATA_PATH:-/app/data}"
CONTAINER_IMAGE="${CLEANBOX_IMAGE:-'$IMAGE_NAME'}"
CONTAINER_USER="${CLEANBOX_USER:-'$USER_ID'}"

# Container engine - supports both podman and docker
CONTAINER_ENGINE="${CONTAINER_ENGINE:-'$CONTAINER_ENGINE'}"

# Build the container run command
RUN_CMD="${CONTAINER_ENGINE} run --rm"

# Add volume mount
RUN_CMD="${RUN_CMD} -v \"${DATA_HOST_PATH}:${DATA_CONTAINER_PATH}:Z\""

# Add user namespace for podman (not needed for docker)
if [ "${CONTAINER_ENGINE}" = "podman" ]; then
    RUN_CMD="${RUN_CMD} --userns=keep-id"
fi

# Add user specification
RUN_CMD="${RUN_CMD} --user ${CONTAINER_USER}"

# Add secrets (customize for your authentication method)
# For Microsoft 365 OAuth2:
if [ -n "${CLIENT_ID:-}" ] && [ -n "${CLIENT_SECRET:-}" ] && [ -n "${TENANT_ID:-}" ]; then
    RUN_CMD="${RUN_CMD} --secret client_id,type=env,target=CLIENT_ID"
    RUN_CMD="${RUN_CMD} --secret client_secret,type=env,target=CLIENT_SECRET"
    RUN_CMD="${RUN_CMD} --secret tenant_id,type=env,target=TENANT_ID"
fi

# For password authentication:
if [ -n "${IMAP_PASSWORD:-}" ]; then
    RUN_CMD="${RUN_CMD} --secret imap_password,type=env,target=IMAP_PASSWORD"
fi

# Add container image and command
RUN_CMD="${RUN_CMD} ${CONTAINER_IMAGE}"
RUN_CMD="${RUN_CMD} bundle exec cleanbox clean -v -l log/cleanbox --data-dir \"${DATA_CONTAINER_PATH}\""

# Execute the command
eval "${RUN_CMD}"
EOF

# Create cb script
cat > "$HOME/cb" << 'EOF'
#!/bin/bash

set -euo pipefail

# Configuration - customize these for your environment
DATA_HOST_PATH="${CLEANBOX_DATA_PATH:-'$DATA_PATH'}"
DATA_CONTAINER_PATH="${CLEANBOX_CONTAINER_DATA_PATH:-/app/data}"
CONTAINER_IMAGE="${CLEANBOX_IMAGE:-'$IMAGE_NAME'}"
CONTAINER_USER="${CLEANBOX_USER:-'$USER_ID'}"

# Container engine - supports both podman and docker
CONTAINER_ENGINE="${CONTAINER_ENGINE:-'$CONTAINER_ENGINE'}"

# Build the container run command
RUN_CMD="${CONTAINER_ENGINE} run --rm"

# Add volume mount
RUN_CMD="${RUN_CMD} -v \"${DATA_HOST_PATH}:${DATA_CONTAINER_PATH}:Z\""

# Add user namespace for podman (not needed for docker)
if [ "${CONTAINER_ENGINE}" = "podman" ]; then
    RUN_CMD="${RUN_CMD} --userns=keep-id"
fi

# Add user specification
RUN_CMD="${RUN_CMD} --user ${CONTAINER_USER}"

# Add secrets (customize for your authentication method)
# For Microsoft 365 OAuth2:
if [ -n "${CLIENT_ID:-}" ] && [ -n "${CLIENT_SECRET:-}" ] && [ -n "${TENANT_ID:-}" ]; then
    RUN_CMD="${RUN_CMD} --secret client_id,type=env,target=CLIENT_ID"
    RUN_CMD="${RUN_CMD} --secret client_secret,type=env,target=CLIENT_SECRET"
    RUN_CMD="${RUN_CMD} --secret tenant_id,type=env,target=TENANT_ID"
fi

# For password authentication:
if [ -n "${IMAP_PASSWORD:-}" ]; then
    RUN_CMD="${RUN_CMD} --secret imap_password,type=env,target=IMAP_PASSWORD"
fi

# Add container image and command
RUN_CMD="${RUN_CMD} ${CONTAINER_IMAGE}"
RUN_CMD="${RUN_CMD} bundle exec cleanbox \"\$@\" --data-dir \"${DATA_CONTAINER_PATH}\""

# Execute the command
eval "${RUN_CMD}"
EOF

# Make scripts executable
chmod +x "$HOME/cleanbox-run" "$HOME/cb"

echo "✅ Created utility scripts:"
echo "   - $HOME/cleanbox-run (for automated cleaning)"
echo "   - $HOME/cb (for manual commands)"

# Build container image
echo ""
echo "🔨 Building container image..."
$CONTAINER_ENGINE build -t "$IMAGE_NAME" .

if [ $? -eq 0 ]; then
    echo "✅ Container image built successfully"
else
    echo "❌ Failed to build container image"
    exit 1
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure authentication:"
echo "   - For Microsoft 365: Set CLIENT_ID, CLIENT_SECRET, TENANT_ID"
echo "   - For password auth: Set IMAP_PASSWORD"
echo ""
echo "2. Edit configuration:"
echo "   nano $DATA_PATH/cleanbox.yml"
echo ""
echo "3. Test the setup:"
echo "   $HOME/cb config show"
echo "   $HOME/cb folders"
echo ""
echo "4. For automated cleaning, set up systemd timer:"
echo "   See deploy/CONTAINER_DEPLOYMENT.md for details"
echo ""
echo "📚 For more information, see:"
echo "   - deploy/CONTAINER_DEPLOYMENT.md"
echo "   - scripts/cleanbox-run.template"
echo "   - scripts/cb.template" 