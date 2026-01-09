#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Creating DMG Distribution"

DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

log_info "Creating staging directory..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

log_info "Copying files to DMG..."
cp "${BUILD_DIR}/${PRODUCT_PKG}" "${DMG_STAGING}/Install USBPre.pkg"
cp -R "${BUILD_DIR}/${UNINSTALLER_APP}" "${DMG_STAGING}/"

# Copy README if it exists
if [ -f "Installer/Resources/README.html" ]; then
    cp "Installer/Resources/README.html" "${DMG_STAGING}/"
fi

log_info "Creating DMG..."
hdiutil create \
    -volname "USBPre Auto-Init" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

log_success "DMG created: ${DMG_PATH}"
log_info "Size: $(du -h "$DMG_PATH" | cut -f1)"
