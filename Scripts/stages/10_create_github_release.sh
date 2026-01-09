#!/bin/bash
set -e

source "$(dirname "$0")/../config.sh"
source "$(dirname "$0")/../utils/logger.sh"

log_stage "Creating GitHub Release"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is required but not installed"
    log_info "Install with: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub"
    log_info "Run: gh auth login"
    exit 1
fi

DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
TAG="v${VERSION}"

log_info "Creating release: ${TAG}"

# Check if release already exists
if gh release view "$TAG" &> /dev/null 2>&1; then
    log_warn "Release ${TAG} already exists"

    # In CI, fail if release exists
    if [ "$IS_CI" = "true" ]; then
        log_error "Release already exists in CI mode"
        exit 1
    fi

    # In local mode, prompt user
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh release delete "$TAG" --yes
    else
        log_info "Skipping release creation"
        exit 0
    fi
fi

# Create release
gh release create "$TAG" \
    "$DMG_PATH" \
    --title "USBPre Auto-Init ${VERSION}" \
    --notes "Release ${VERSION}

## Installation
1. Download USBPreAutoInit-v${VERSION}.dmg
2. Open the DMG
3. Run 'Install USBPre.pkg'
4. Follow the installer prompts

## Uninstallation
Go to Applications → Utilities → Uninstall USBPre

## Changes
See [CHANGELOG.md](CHANGELOG.md) for details."

log_success "GitHub release created: ${TAG}"
log_info "View at: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/${TAG}"
