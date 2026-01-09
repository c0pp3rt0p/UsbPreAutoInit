#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Creating Package Installer"

COMPONENT_PKG_PATH="${BUILD_DIR}/${COMPONENT_PKG}"
PRODUCT_PKG_PATH="${BUILD_DIR}/${PRODUCT_PKG}"

log_info "Creating package root structure..."
mkdir -p "${PKG_ROOT}/usr/local/bin"
mkdir -p "${PKG_ROOT}/Library/LaunchDaemons"
mkdir -p "${PKG_ROOT}/Applications/Utilities"

log_info "Copying files to package root..."
cp "${BUILD_DIR}/${DAEMON_BINARY}" "${PKG_ROOT}/usr/local/bin/"
cp "$PLIST_SOURCE" "${PKG_ROOT}/Library/LaunchDaemons/"
cp -R "${BUILD_DIR}/${UNINSTALLER_APP}" "${PKG_ROOT}/Applications/Utilities/"

log_info "Setting permissions..."
chmod 755 "${PKG_ROOT}/usr/local/bin/${DAEMON_BINARY}"
chmod 644 "${PKG_ROOT}/Library/LaunchDaemons/$(basename "$PLIST_SOURCE")"

log_info "Building component package..."
pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --scripts "Installer/scripts" \
    "$COMPONENT_PKG_PATH"

log_info "Building product package..."
productbuild \
    --distribution "Installer/Distribution.xml" \
    --resources "Installer/Resources" \
    --package-path "$BUILD_DIR" \
    "$PRODUCT_PKG_PATH"

log_success "Package created: ${PRODUCT_PKG_PATH}"
log_info "Size: $(du -h "$PRODUCT_PKG_PATH" | cut -f1)"
