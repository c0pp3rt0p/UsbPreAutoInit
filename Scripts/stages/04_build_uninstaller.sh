#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Building Uninstaller App"

DERIVED_DATA="${BUILD_DIR}/DerivedData"
OUTPUT="${BUILD_DIR}/${UNINSTALLER_APP}"

log_info "Building Xcode project: ${XCODE_PROJECT}"
log_info "Scheme: ${XCODE_SCHEME}"

xcodebuild \
    -project "$XCODE_PROJECT" \
    -scheme "$XCODE_SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    clean build 2>&1 | tee "${BUILD_DIR}/logs/uninstaller_build.log"

if [ $? -eq 0 ]; then
    BUILT_APP="${DERIVED_DATA}/Build/Products/Release/${UNINSTALLER_APP}"

    if [ -d "$BUILT_APP" ]; then
        cp -R "$BUILT_APP" "$OUTPUT"
        log_success "Uninstaller built successfully: ${OUTPUT}"

        # Verify code signature
        log_info "Verifying code signature..."
        codesign --verify --deep --strict --verbose=2 "$OUTPUT" 2>&1
        if [ $? -eq 0 ]; then
            log_success "Code signature verified"
            log_info "Signature details:"
            codesign -dv --verbose=4 "$OUTPUT" 2>&1 | grep -E "(Identifier|Authority|Timestamp|Runtime)" || true
        else
            log_error "Code signature verification failed"
            exit 1
        fi
    else
        log_error "Built app not found at: ${BUILT_APP}"
        exit 1
    fi
else
    log_error "Xcode build failed - see ${BUILD_DIR}/logs/uninstaller_build.log"
    exit 1
fi
