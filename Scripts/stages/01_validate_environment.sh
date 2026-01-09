#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Validating Environment"

# Check required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is required but not installed"
        return 1
    fi
    log_info "✓ $1 found"
}

check_command gcc
check_command xcodebuild
check_command pkgbuild
check_command productbuild
check_command hdiutil

# Check source files exist
check_file() {
    if [ ! -f "$1" ]; then
        log_error "Required file not found: $1"
        return 1
    fi
    log_info "✓ $1 exists"
}

check_file "$DAEMON_SOURCE"
check_file "$PLIST_SOURCE"

# Check Xcode project
if [ ! -d "$XCODE_PROJECT" ]; then
    log_error "Xcode project not found: $XCODE_PROJECT"
    exit 1
fi
log_info "✓ Xcode project found"

# Check signing configuration (warning only)
if [ -z "$DEVELOPER_ID" ]; then
    log_warn "APPLE_DEVELOPER_ID not set - signing will be skipped"
fi

log_success "Environment validation complete"
