#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Signing Package"

if [ -z "$DEVELOPER_ID" ]; then
    log_warn "APPLE_DEVELOPER_ID not set - skipping signing"
    exit 0
fi

PKG_PATH="${BUILD_DIR}/${PRODUCT_PKG}"
SIGNED_PKG="${BUILD_DIR}/${PRODUCT_PKG%.pkg}-signed.pkg"

log_info "Signing with: ${DEVELOPER_ID}"

productsign \
    --sign "$DEVELOPER_ID" \
    "$PKG_PATH" \
    "$SIGNED_PKG"

if [ $? -eq 0 ]; then
    mv "$SIGNED_PKG" "$PKG_PATH"
    log_success "Package signed successfully"

    # Verify signature
    pkgutil --check-signature "$PKG_PATH" | tee "${BUILD_DIR}/logs/signature_verify.log"
else
    log_error "Package signing failed"
    exit 1
fi
