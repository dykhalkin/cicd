#!/bin/bash
#
# Generic Python API Deployment Script
# Based on AnkiChat deployment approach
#

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error when substituting

# Required Environment Variables
: "${APP_NAME:?APP_NAME is required}"
: "${REPO_NAME:?REPO_NAME is required}"
: "${BRANCH:?BRANCH is required}"
: "${ENVIRONMENT:?ENVIRONMENT is required}"
: "${APP_DIR:?APP_DIR is required}"
: "${SERVER_HOST:?SERVER_HOST is required}"
: "${SERVER_USER:?SERVER_USER is required}"

# Optional Environment Variables
PYTHON_VERSION="${PYTHON_VERSION:-3.9}"
ENV_VARS="${ENV_VARS:-{}}"

# Derived Configuration
VENV_DIR="$APP_DIR/.venv"
SERVICE_NAME="${APP_NAME}-${ENVIRONMENT}.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
REPO_URL="https://github.com/${REPO_NAME}.git"
LOG_DIR="/var/log/${APP_NAME}-${ENVIRONMENT}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" >&2
}

# Function to execute commands on remote server
remote_exec() {
    ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" "$@"
}

# Function to copy files to remote server
remote_copy() {
    scp -o StrictHostKeyChecking=no -r "$1" "$SERVER_USER@$SERVER_HOST:$2"
}

log "Starting deployment of $APP_NAME to $ENVIRONMENT environment"
log "Repository: $REPO_NAME"
log "Branch: $BRANCH"
log "Target directory: $APP_DIR"

# Create application directory on remote server
log "Creating application directory structure"
remote_exec "sudo mkdir -p $APP_DIR $LOG_DIR"
remote_exec "sudo chown -R $SERVER_USER:$SERVER_USER $APP_DIR"

# Clone or update repository
log "Updating application code"
if remote_exec "[ -d $APP_DIR/.git ]"; then
    log "Updating existing repository"
    remote_exec "cd $APP_DIR && git fetch origin && git checkout $BRANCH && git pull origin $BRANCH"
else
    log "Cloning repository"
    remote_exec "git clone -b $BRANCH $REPO_URL $APP_DIR"
fi

# Setup Python virtual environment
log "Setting up Python virtual environment"
remote_exec "cd $APP_DIR && python$PYTHON_VERSION -m venv $VENV_DIR"

# Install dependencies
log "Installing Python dependencies"
remote_exec "cd $APP_DIR && $VENV_DIR/bin/pip install --upgrade pip"
remote_exec "cd $APP_DIR && $VENV_DIR/bin/pip install -r requirements.txt"

# Create .env file from environment variables
log "Configuring environment variables"
if [ "$ENV_VARS" != "{}" ]; then
    # Parse JSON and create .env file
    echo "$ENV_VARS" | remote_exec "python3 -c '
import json
import sys
env_vars = json.load(sys.stdin)
with open(\"$APP_DIR/.env\", \"w\") as f:
    for key, value in env_vars.items():
        f.write(f\"{key}={value}\\n\")
'"
    log "Environment variables configured"
else
    warning "No environment variables provided. You may need to configure .env manually."
fi

# Create systemd service file
log "Creating systemd service file"
SERVICE_CONTENT="[Unit]
Description=$APP_NAME ($ENVIRONMENT)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/python src/main.py
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=${APP_NAME}-${ENVIRONMENT}
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target"

echo "$SERVICE_CONTENT" | remote_exec "sudo tee $SERVICE_FILE > /dev/null"
log "Created systemd service file at $SERVICE_FILE"

# Set proper permissions
log "Setting proper file permissions"
remote_exec "sudo chown -R www-data:www-data $APP_DIR $LOG_DIR"
remote_exec "sudo chmod -R 755 $APP_DIR $LOG_DIR"

# Enable and start the service
log "Reloading systemd and starting service"
remote_exec "sudo systemctl daemon-reload"
remote_exec "sudo systemctl enable $SERVICE_NAME"

# Stop service if running, then start
remote_exec "sudo systemctl stop $SERVICE_NAME || true"
sleep 2
remote_exec "sudo systemctl start $SERVICE_NAME"

# Check service status
log "Checking service status"
if remote_exec "sudo systemctl is-active --quiet $SERVICE_NAME"; then
    log "✅ Deployment successful! Service $SERVICE_NAME is running."
    remote_exec "sudo systemctl status $SERVICE_NAME --no-pager -l"
else
    error "❌ Deployment failed! Service $SERVICE_NAME failed to start."
fi

log "🚀 Deployment of $APP_NAME to $ENVIRONMENT completed successfully!"