#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Cleaning Build Directory"

if [ -d "$BUILD_DIR" ]; then
    log_info "Removing existing build directory..."
    rm -rf "$BUILD_DIR"
fi

log_info "Creating build directory structure..."
mkdir -p "$BUILD_DIR"
mkdir -p "${BUILD_DIR}/logs"

log_success "Build directory cleaned"
