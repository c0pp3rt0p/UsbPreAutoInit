# Building USBPreAutoInit

Developer documentation for building, signing, and releasing USBPreAutoInit.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Build Pipeline](#build-pipeline)
- [Local Development](#local-development)
- [Code Signing Setup](#code-signing-setup)
- [GitHub Actions Setup](#github-actions-setup)
- [Release Process](#release-process)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **macOS 11.0+** (build host)
- **Xcode 14.0+** with Command Line Tools
- **Apple Developer Account** (for signing and notarization)
- **Git** (for version control)
- **Bash 4.0+** (usually pre-installed)

### Verify Installation

```bash
# Check Xcode
xcodebuild -version

# Check command line tools
xcode-select -p

# Check gcc (for daemon build)
gcc --version
```

### Install Xcode Command Line Tools

If not installed:

```bash
xcode-select --install
```

## Project Structure

```
USBPreAutoInit/
├── Source/
│   └── daemon/
│       ├── usbpre_monitor_daemon.c         # Daemon source
│       └── com.sounddevices.usbpre.monitor.plist
├── UninstallerApp/
│   ├── USBPreUninstaller.xcodeproj/        # Xcode project
│   └── Uninstall USBPre/                   # Swift source files
├── Installer/
│   ├── scripts/                            # Pre/post-install scripts
│   ├── Resources/                          # HTML welcome/conclusion
│   └── Distribution.xml                    # Installer UI config
├── Scripts/
│   ├── pipeline.sh                         # Main build orchestrator
│   ├── config.sh                           # Shared configuration
│   ├── utils/logger.sh                     # Logging functions
│   └── stages/                             # Individual build stages
│       ├── 01_validate_environment.sh
│       ├── 02_clean_build.sh
│       ├── 03_build_daemon.sh
│       ├── 04_build_uninstaller.sh
│       ├── 05_create_pkg.sh
│       ├── 06_sign_pkg.sh
│       ├── 07_notarize_pkg.sh
│       ├── 08_create_dmg.sh
│       ├── 09_verify_artifacts.sh
│       └── 10_create_github_release.sh
├── .github/workflows/                      # GitHub Actions
├── VERSION                                 # Version string
├── LICENSE
├── README.md
└── BUILDING.md                             # This file
```

## Build Pipeline

The build system follows **SOLID principles** - single responsibility per script, orchestrated by `pipeline.sh`.

### Pipeline Stages

1. **Validate Environment** - Check tools, versions, certificates
2. **Clean Build** - Remove old artifacts
3. **Build Daemon** - Compile C daemon with gcc
4. **Build Uninstaller** - Compile Swift app with xcodebuild
5. **Create PKG** - Package components with pkgbuild/productbuild
6. **Sign PKG** - Code sign with productsign
7. **Notarize PKG** - Submit to Apple notarization service
8. **Create DMG** - Build distributable disk image
9. **Verify Artifacts** - Check signatures and integrity
10. **Create GitHub Release** - Upload to GitHub (CI only)

### Pipeline Options

```bash
./Scripts/pipeline.sh [OPTIONS]

Options:
  --stop-at=STAGE       Stop after stage N (1-10)
  --skip=STAGES         Skip stages (comma-separated, e.g., "6,7")
  --only=STAGE          Run only stage N
  --dry-run            Show what would run without executing
  --help               Show help message

Examples:
  # Full build without signing/notarization
  ./Scripts/pipeline.sh --stop-at=5

  # Build everything except GitHub release
  ./Scripts/pipeline.sh --stop-at=9

  # Skip signing and notarization (local testing)
  ./Scripts/pipeline.sh --skip=6,7

  # Only build the daemon
  ./Scripts/pipeline.sh --only=3

  # Dry run to see the plan
  ./Scripts/pipeline.sh --dry-run
```

## Local Development

### Quick Build (No Signing)

For rapid development and testing:

```bash
# Build everything except signing/notarization/release
./Scripts/pipeline.sh --stop-at=5

# Outputs:
# - build/usbpre_monitor_daemon
# - build/Uninstall USBPre.app
# - build/USBPreAutoInit-1.0.0.pkg (unsigned)
```

### Test Individual Components

```bash
# Build just the daemon
./Scripts/pipeline.sh --only=3

# Build just the uninstaller app
./Scripts/pipeline.sh --only=4

# Create unsigned PKG
./Scripts/pipeline.sh --only=5
```

### Manual Daemon Build

```bash
cd Source/daemon
gcc -o usbpre_monitor_daemon \
    -framework IOKit \
    -framework CoreFoundation \
    usbpre_monitor_daemon.c
```

### Manual Uninstaller Build

```bash
xcodebuild \
    -project UninstallerApp/USBPreUninstaller.xcodeproj \
    -scheme USBPreUninstaller \
    -configuration Release \
    clean build
```

### Test Locally

Install unsigned package (disable Gatekeeper temporarily):

```bash
# Disable Gatekeeper (BE CAREFUL)
sudo spctl --master-disable

# Install your unsigned pkg
sudo installer -pkg build/USBPreAutoInit-1.0.0.pkg -target /

# Re-enable Gatekeeper
sudo spctl --master-enable

# Test daemon
sudo launchctl list | grep usbpre
sudo tail -f /var/log/usbpre_monitor.log

# Plug in USBPre device to test
```

## Code Signing Setup

### Prerequisites

1. **Apple Developer Account** - Enroll at [developer.apple.com](https://developer.apple.com)
2. **Developer ID Installer Certificate** - Download from Apple Developer Portal
3. **App-Specific Password** - Generate at [appleid.apple.com](https://appleid.apple.com)

### Get Your Signing Identity

```bash
# List available signing identities
security find-identity -v -p codesigning

# Look for "Developer ID Installer: Your Name (TEAM_ID)"
# Copy the full identity string
```

### Configure Environment Variables

Create a `.env` file (DO NOT COMMIT):

```bash
# Code Signing
export SIGNING_IDENTITY="Developer ID Installer: Your Name (TEAM_ID)"

# Notarization
export APPLE_ID="your.email@example.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_ID_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password

# Version (optional, reads from VERSION file by default)
export VERSION="1.0.0"
```

Source before building:

```bash
source .env
./Scripts/pipeline.sh
```

### Store Credentials Securely

For repeated builds, store in keychain:

```bash
# Store notarization credentials
xcrun notarytool store-credentials "AC_PASSWORD" \
    --apple-id "your.email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "xxxx-xxxx-xxxx-xxxx"

# Then use in notarization:
xcrun notarytool submit --keychain-profile "AC_PASSWORD" ...
```

Update `Scripts/stages/07_notarize_pkg.sh` to use `--keychain-profile` instead of `--password`.

## GitHub Actions Setup

### Repository Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `SIGNING_IDENTITY` | Full Developer ID string | `security find-identity -v -p codesigning` |
| `APPLE_ID` | Apple ID email | Your Apple ID |
| `APPLE_TEAM_ID` | 10-character team ID | developer.apple.com → Membership |
| `APPLE_ID_PASSWORD` | App-specific password | appleid.apple.com → Security → App-Specific Passwords |
| `GH_TOKEN` | GitHub token (releases) | Settings → Developer settings → Personal access tokens |

### Certificate Installation (CI)

GitHub Actions needs your Developer ID certificate. Export it:

```bash
# Export certificate from Keychain (GUI method)
1. Open Keychain Access
2. Find "Developer ID Installer: Your Name"
3. Right-click → Export
4. Save as .p12 with a password

# Or via command line
security export -t identities -f pkcs12 \
    -o certificate.p12 \
    -P "EXPORT_PASSWORD"
```

Add to GitHub Secrets:
- `CERTIFICATE_P12`: Base64-encoded certificate
  ```bash
  base64 -i certificate.p12 | pbcopy
  ```
- `CERTIFICATE_PASSWORD`: The password you used when exporting

### Workflow Files

See `.github/workflows/` for:
- `release.yml` - Full build on version tags
- `pr-build.yml` - Build-only on pull requests (no signing)

### Trigger a Release

```bash
# Update VERSION file
echo "1.1.0" > VERSION

# Commit and tag
git add VERSION
git commit -m "chore: Bump version to 1.1.0"
git tag v1.1.0
git push origin main --tags

# GitHub Actions will:
# - Build signed and notarized .pkg
# - Create DMG
# - Create GitHub release
# - Upload artifacts
```

## Release Process

### Standard Release

1. **Update VERSION file**
   ```bash
   echo "1.1.0" > VERSION
   ```

2. **Update CHANGELOG.md** (if you have one)

3. **Commit changes**
   ```bash
   git add VERSION CHANGELOG.md
   git commit -m "chore: Release v1.1.0"
   ```

4. **Create Git tag**
   ```bash
   git tag -a v1.1.0 -m "Release version 1.1.0"
   ```

5. **Push to GitHub**
   ```bash
   git push origin main
   git push origin v1.1.0
   ```

6. **Wait for GitHub Actions** - Monitor at `https://github.com/OWNER/REPO/actions`

7. **Verify Release** - Check `https://github.com/OWNER/REPO/releases`

### Manual Release (Local Build)

If you prefer to build locally:

```bash
# Source your .env
source .env

# Run full pipeline
./Scripts/pipeline.sh --stop-at=9

# Manually create GitHub release
gh release create v1.1.0 \
    build/USBPreAutoInit-1.1.0.pkg \
    build/USBPreAutoInit-1.1.0.dmg \
    --title "v1.1.0" \
    --notes "Release notes here"
```

## Troubleshooting

### Build Failures

**Xcode command not found:**
```bash
xcode-select --install
sudo xcode-select --switch /Applications/Xcode.app
```

**Daemon compilation fails:**
```bash
# Check IOKit framework
ls /System/Library/Frameworks/IOKit.framework

# Try manual compile with verbose output
gcc -v -o test -framework IOKit Source/daemon/usbpre_monitor_daemon.c
```

**Uninstaller build fails:**
```bash
# Clean derived data
rm -rf build/DerivedData

# Verify project
xcodebuild -project UninstallerApp/USBPreUninstaller.xcodeproj -list

# Build manually
cd UninstallerApp
xcodebuild -project USBPreUninstaller.xcodeproj \
    -scheme USBPreUninstaller \
    -configuration Release
```

### Signing Issues

**No signing identity found:**
```bash
# List available identities
security find-identity -v -p codesigning

# If empty, install certificate from developer.apple.com
```

**Wrong certificate type:**
- Need "Developer ID Installer" (not "Developer ID Application")
- Download from developer.apple.com → Certificates, Identifiers & Profiles

**Signing fails with ambiguous identity:**
```bash
# Use full identity string in SIGNING_IDENTITY
export SIGNING_IDENTITY="Developer ID Installer: John Doe (ABC1234567)"
```

### Notarization Issues

**Invalid credentials:**
```bash
# Test credentials
xcrun notarytool history \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_ID_PASSWORD"
```

**Notarization rejected:**
```bash
# Get detailed rejection reason
xcrun notarytool log SUBMISSION_ID \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_ID_PASSWORD"
```

Common rejections:
- Unsigned binaries - Make sure daemon is included in PKG signing
- Invalid bundle structure - Check Info.plist in uninstaller
- Missing entitlements - Usually not needed for simple utilities

**Notarization times out:**
- Apple's service can take 5-30 minutes
- Check status: `xcrun notarytool info SUBMISSION_ID ...`
- If stuck >1 hour, resubmit

### GitHub Actions Failures

**Secret not found:**
- Verify secret name matches workflow YAML exactly (case-sensitive)
- Re-add secret in GitHub UI

**Certificate installation fails:**
- Verify base64 encoding: `echo "$CERTIFICATE_P12" | base64 -d > test.p12`
- Check password is correct
- Try re-exporting certificate

**Build succeeds but release fails:**
- Check `GH_TOKEN` has `repo` and `write:packages` scopes
- Verify tag format: `v1.0.0` (not `1.0.0`)

## Development Tips

### Fast Iteration

For UI development on uninstaller:

```bash
# Build only uninstaller, skip everything else
./Scripts/pipeline.sh --only=4

# Open in Xcode for live editing
open UninstallerApp/USBPreUninstaller.xcodeproj

# Or run directly
./build/Uninstall\ USBPre.app/Contents/MacOS/Uninstall\ USBPre
```

### Daemon Development

```bash
# Quick compile and test
cd Source/daemon
gcc -o test_daemon -framework IOKit -framework CoreFoundation usbpre_monitor_daemon.c

# Run in foreground (not as daemon)
./test_daemon

# In another terminal, plug in USBPre to trigger
```

### Testing Without Device

The daemon will run without a device, you'll just see:

```
Waiting for USBPre device...
```

To test initialization logic, you'd need the actual hardware.

### Logs

```bash
# Follow daemon logs
sudo tail -f /var/log/usbpre_monitor.log

# System logs
log show --predicate 'process == "usbpre_monitor_daemon"' --last 1h

# Build logs
cat build/logs/*.log
```

## Contributing

When submitting PRs:

1. **Test locally** - Run `./Scripts/pipeline.sh --stop-at=5`
2. **Update docs** - If changing build process, update this file
3. **Check CI** - Ensure GitHub Actions passes
4. **Follow conventions** - Match existing code style

## Support

- **Issues:** [GitHub Issues](https://github.com/yourusername/USBPreAutoInit/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/USBPreAutoInit/discussions)
- **Email:** your.email@example.com

## License

See [LICENSE](LICENSE) file.
