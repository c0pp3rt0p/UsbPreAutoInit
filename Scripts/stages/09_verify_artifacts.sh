#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Verifying Artifacts"

verify_file() {
    local file="$1"
    local description="$2"

    if [ -f "$file" ]; then
        log_info "✓ ${description}: $(du -h "$file" | cut -f1)"
    else
        log_error "✗ ${description} not found: ${file}"
        return 1
    fi
}

verify_file "${BUILD_DIR}/${DAEMON_BINARY}" "Daemon binary"
verify_file "${BUILD_DIR}/${PRODUCT_PKG}" "Package installer"
verify_file "${BUILD_DIR}/${DMG_NAME}" "DMG distribution"

# Verify app bundle
if [ -d "${BUILD_DIR}/${UNINSTALLER_APP}" ]; then
    log_info "✓ Uninstaller app bundle"
else
    log_error "✗ Uninstaller app bundle not found"
    exit 1
fi

# Verify signatures if signed
if [ -n "$DEVELOPER_ID" ]; then
    log_info "Verifying package signature..."
    if pkgutil --check-signature "${BUILD_DIR}/${PRODUCT_PKG}" > /dev/null 2>&1; then
        log_info "✓ Package is signed"
    else
        log_warn "⚠ Package signature verification failed"
    fi
fi

log_success "All artifacts verified"
