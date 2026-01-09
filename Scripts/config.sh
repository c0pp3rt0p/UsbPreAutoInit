#!/bin/bash

# Version (read from VERSION file or git tag)
VERSION="${VERSION:-$(cat VERSION 2>/dev/null || echo "1.0.0")}"

# Build directories
BUILD_DIR="build"
PKG_ROOT="${BUILD_DIR}/pkg-root"
DMG_STAGING="${BUILD_DIR}/dmg-staging"

# Artifact names
DAEMON_BINARY="usbpre_monitor_daemon"
CLI_BINARY="usbpre_init"
UNINSTALLER_APP="Uninstall USBPre.app"
COMPONENT_PKG="usbpre-component.pkg"
PRODUCT_PKG="USBPreAutoInit.pkg"
DMG_NAME="USBPreAutoInit-v${VERSION}.dmg"

# Identifiers
BUNDLE_ID="com.sounddevices.usbpre.monitor"
TEAM_ID="${APPLE_TEAM_ID:-}"

# Paths
DAEMON_SOURCE="Source/daemon/usbpre_monitor_daemon.c"
CLI_SOURCE="Source/cli/usbpre_init.c"
PLIST_SOURCE="Source/daemon/com.sounddevices.usbpre.monitor.plist"
XCODE_PROJECT="UninstallerApp/USBPreUninstaller.xcodeproj"
XCODE_SCHEME="USBPreUninstaller"

# Signing (read from environment)
DEVELOPER_ID="${APPLE_DEVELOPER_ID:-}"

# Notarization: Supports both keychain profile (local) and direct credentials (CI)
NOTARIZATION_PROFILE="${APPLE_NOTARIZATION_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_ID_PASSWORD="${APPLE_ID_PASSWORD:-}"

# Environment detection
IS_CI="${CI:-false}"
IS_GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"
