#!/bin/bash
# =============================================================================
# CERTBOT DEPLOY HOOK - NGINX RELOAD
# =============================================================================
# This script runs after certbot successfully renews SSL certificates
# It safely reloads nginx to use the new certificates
#
# Installation:
#   sudo cp scripts/certbot-hooks/deploy.sh /etc/letsencrypt/renewal-hooks/deploy/
#   sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/deploy.sh
#
# Certbot automatically runs all scripts in renewal-hooks/deploy/ after
# successful certificate renewal.
#
# =============================================================================

set -e  # Exit on error

# Configuration
NGINX_BIN="/usr/sbin/nginx"
SYSTEMCTL_BIN="/usr/bin/systemctl"
LOG_FILE="/var/log/nginx/certbot-reload.log"

# Colors for output (optional, works in logs too)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

log "========================================="
log "Certbot Deploy Hook Started"
log "========================================="

# Check if this script is running as root (required for nginx reload)
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Certbot provides these environment variables:
# RENEWED_DOMAINS - space-separated list of renewed domains
# RENEWED_LINEAGE - path to the live certificate directory
if [ -n "$RENEWED_DOMAINS" ]; then
    log_info "Renewed domains: $RENEWED_DOMAINS"
    log_info "Certificate path: $RENEWED_LINEAGE"
else
    log_info "No domain information from certbot (manual execution?)"
fi

# Test nginx configuration before reloading
log_info "Testing nginx configuration..."
if $NGINX_BIN -t 2>&1 | tee -a "$LOG_FILE"; then
    log_success "Nginx configuration test passed"
else
    log_error "Nginx configuration test FAILED"
    log_error "NOT reloading nginx - please fix configuration errors"
    exit 1
fi

# Reload nginx to use new certificates
log_info "Reloading nginx..."
if $SYSTEMCTL_BIN reload nginx 2>&1 | tee -a "$LOG_FILE"; then
    log_success "Nginx reloaded successfully"

    # Optional: Send notification (uncomment and configure as needed)
    # Example with curl to a webhook:
    # curl -X POST https://your-webhook.com/notify \
    #   -H "Content-Type: application/json" \
    #   -d "{\"text\":\"SSL certificates renewed and nginx reloaded: $RENEWED_DOMAINS\"}"

else
    log_error "Nginx reload FAILED"
    exit 1
fi

# Optional: Verify nginx is still running
sleep 2
if $SYSTEMCTL_BIN is-active --quiet nginx; then
    log_success "Nginx is running and healthy"
else
    log_error "Nginx is NOT running after reload!"
    exit 1
fi

log "========================================="
log "Certbot Deploy Hook Completed Successfully"
log "========================================="

exit 0
