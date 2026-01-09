#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Building Daemon"

OUTPUT="${BUILD_DIR}/${DAEMON_BINARY}"

log_info "Compiling: ${DAEMON_SOURCE}"
log_info "Output: ${OUTPUT}"

gcc -o "$OUTPUT" \
    "$DAEMON_SOURCE" \
    -framework IOKit \
    -framework CoreFoundation \
    -O2 \
    -Wall \
    -Wextra 2>&1 | tee "${BUILD_DIR}/logs/daemon_build.log"

if [ $? -eq 0 ]; then
    log_success "Daemon built successfully: ${OUTPUT}"
    log_info "Size: $(du -h "$OUTPUT" | cut -f1)"

    # Code sign the daemon binary
    if [ -n "$DEVELOPER_ID" ]; then
        log_info "Signing daemon with Developer ID Application certificate..."
        codesign --force \
            --options runtime \
            --sign "Developer ID Application: Craig Carrier (V2VC2UY8H4)" \
            --timestamp \
            "$OUTPUT"

        if [ $? -eq 0 ]; then
            log_success "Daemon signed successfully"
            # Verify signature
            codesign --verify --verbose "$OUTPUT"
        else
            log_error "Daemon signing failed"
            exit 1
        fi
    else
        log_warn "APPLE_DEVELOPER_ID not set - skipping daemon signing"
    fi
else
    log_error "Daemon compilation failed - see ${BUILD_DIR}/logs/daemon_build.log"
    exit 1
fi

# Build CLI tool
log_stage "Building CLI Tool"

CLI_OUTPUT="${BUILD_DIR}/${CLI_BINARY}"

log_info "Compiling: ${CLI_SOURCE}"
log_info "Output: ${CLI_OUTPUT}"

gcc -o "$CLI_OUTPUT" \
    "$CLI_SOURCE" \
    -framework IOKit \
    -framework CoreFoundation \
    -O2 \
    -Wall \
    -Wextra 2>&1 | tee "${BUILD_DIR}/logs/cli_build.log"

if [ $? -eq 0 ]; then
    log_success "CLI tool built successfully: ${CLI_OUTPUT}"
    log_info "Size: $(du -h "$CLI_OUTPUT" | cut -f1)"

    # Code sign the CLI binary
    if [ -n "$DEVELOPER_ID" ]; then
        log_info "Signing CLI tool with Developer ID Application certificate..."
        codesign --force \
            --options runtime \
            --sign "Developer ID Application: Craig Carrier (V2VC2UY8H4)" \
            --timestamp \
            "$CLI_OUTPUT"

        if [ $? -eq 0 ]; then
            log_success "CLI tool signed successfully"
            codesign --verify --verbose "$CLI_OUTPUT"
        else
            log_error "CLI tool signing failed"
            exit 1
        fi
    else
        log_warn "APPLE_DEVELOPER_ID not set - skipping CLI tool signing"
    fi
else
    log_error "CLI tool compilation failed - see ${BUILD_DIR}/logs/cli_build.log"
    exit 1
fi
