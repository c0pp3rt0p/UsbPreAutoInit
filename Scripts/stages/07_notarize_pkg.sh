#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Notarizing Package"

PKG_PATH="${BUILD_DIR}/${PRODUCT_PKG}"

# Determine notarization method: keychain profile (local) or credentials (CI)
if [ -n "$NOTARIZATION_PROFILE" ]; then
    # Local: Use keychain profile
    log_info "Using keychain profile: $NOTARIZATION_PROFILE"
    NOTARY_ARGS="--keychain-profile $NOTARIZATION_PROFILE"
elif [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$APPLE_ID_PASSWORD" ]; then
    # CI: Use direct credentials
    log_info "Using direct credentials for CI"
    NOTARY_ARGS="--apple-id $APPLE_ID --team-id $APPLE_TEAM_ID --password $APPLE_ID_PASSWORD"
else
    log_warn "No notarization credentials configured - skipping"
    log_info "Set either APPLE_NOTARIZATION_PROFILE (local) or APPLE_ID/APPLE_TEAM_ID/APPLE_ID_PASSWORD (CI)"
    exit 0
fi

log_info "Submitting to Apple for notarization..."
log_info "This may take several minutes..."

xcrun notarytool submit "$PKG_PATH" \
    $NOTARY_ARGS \
    --wait 2>&1 | tee "${BUILD_DIR}/logs/notarization.log"

if [ $? -eq 0 ]; then
    log_info "Stapling notarization ticket..."
    xcrun stapler staple "$PKG_PATH"

    log_success "Package notarized and stapled"

    # Verify staple
    xcrun stapler validate "$PKG_PATH"
else
    log_error "Notarization failed - see ${BUILD_DIR}/logs/notarization.log"
    exit 1
fi
