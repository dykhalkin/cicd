#!/bin/bash
#
# Health Check Script for Python API Deployments
#

set -e

# Parameters
ENVIRONMENT="${1:-staging}"
APP_NAME="${2:-ankichat}"

# Configuration
SERVICE_NAME="${APP_NAME}-${ENVIRONMENT}.service"
MAX_RETRIES=30
RETRY_INTERVAL=5

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" >&2
}

# Function to execute commands on remote server
remote_exec() {
    ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" "$@"
}

log "Starting health check for $APP_NAME in $ENVIRONMENT environment"

# Check if service is active
log "Checking service status..."
retry_count=0
while [ $retry_count -lt $MAX_RETRIES ]; do
    if remote_exec "sudo systemctl is-active --quiet $SERVICE_NAME"; then
        log "✅ Service $SERVICE_NAME is active"
        break
    else
        retry_count=$((retry_count + 1))
        warning "Service not active yet. Retry $retry_count/$MAX_RETRIES"
        if [ $retry_count -eq $MAX_RETRIES ]; then
            error "❌ Service failed to become active after $MAX_RETRIES attempts"
            remote_exec "sudo systemctl status $SERVICE_NAME --no-pager -l" || true
            remote_exec "sudo journalctl -u $SERVICE_NAME --no-pager -l -n 50" || true
            exit 1
        fi
        sleep $RETRY_INTERVAL
    fi
done

# Check service status details
log "Getting service status details..."
remote_exec "sudo systemctl status $SERVICE_NAME --no-pager -l"

# Check recent logs
log "Checking recent logs..."
remote_exec "sudo journalctl -u $SERVICE_NAME --no-pager -l -n 20"

# Check if there are any recent errors in logs
log "Checking for errors in logs..."
if remote_exec "sudo journalctl -u $SERVICE_NAME --no-pager -l -n 50 | grep -i 'error\\|exception\\|failed'" > /dev/null 2>&1; then
    warning "⚠️  Found errors in recent logs:"
    remote_exec "sudo journalctl -u $SERVICE_NAME --no-pager -l -n 50 | grep -i 'error\\|exception\\|failed'" || true
else
    log "✅ No errors found in recent logs"
fi

# Check process information
log "Checking process information..."
if remote_exec "pgrep -f $SERVICE_NAME" > /dev/null 2>&1; then
    log "✅ Process is running:"
    remote_exec "ps aux | grep $SERVICE_NAME | grep -v grep" || true
else
    warning "⚠️  No process found for $SERVICE_NAME"
fi

# Check system resources
log "Checking system resources..."
remote_exec "echo 'Memory usage:' && free -h"
remote_exec "echo 'Disk usage:' && df -h | head -5"
remote_exec "echo 'Load average:' && uptime"

log "🎉 Health check completed for $APP_NAME in $ENVIRONMENT environment"