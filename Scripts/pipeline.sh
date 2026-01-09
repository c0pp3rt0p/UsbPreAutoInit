#!/bin/bash
set -e

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils/logger.sh"

# Pipeline stages
STAGES=(
    "01_validate_environment.sh"
    "02_clean_build.sh"
    "03_build_daemon.sh"
    "04_build_uninstaller.sh"
    "05_create_pkg.sh"
    "06_sign_pkg.sh"
    "07_notarize_pkg.sh"
    "08_create_dmg.sh"
    "09_verify_artifacts.sh"
    "10_create_github_release.sh"
)

# Default options
DRY_RUN=false
STOP_AT=""
SKIP_STAGES=""
ONLY_STAGE=""
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stop-at=*)
            STOP_AT="${1#*=}"
            shift
            ;;
        --skip=*)
            SKIP_STAGES="${1#*=}"
            shift
            ;;
        --only=*)
            ONLY_STAGE="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            cat <<EOF
USBPre Auto-Init Build Pipeline

Usage: $0 [OPTIONS]

Options:
    --stop-at=STAGE     Stop pipeline at specified stage
    --skip=STAGES       Skip comma-separated stages (e.g., sign-pkg,notarize-pkg)
    --only=STAGE        Run only the specified stage
    --dry-run           Show what would be done without executing
    --verbose, -v       Enable verbose output
    --help, -h          Show this help message

Stages:
    validate-environment
    clean-build
    build-daemon
    build-uninstaller
    create-pkg
    sign-pkg
    notarize-pkg
    create-dmg
    verify-artifacts
    create-github-release

Examples:
    # Full pipeline
    $0

    # Build without signing/notarization
    $0 --skip=sign-pkg,notarize-pkg

    # Build up to package creation
    $0 --stop-at=create-pkg

    # Run only daemon build
    $0 --only=build-daemon

    # Dry run to see what would happen
    $0 --dry-run
EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Convert stage names to script names
stage_to_script() {
    local stage_name="$1"
    for stage in "${STAGES[@]}"; do
        if [[ "$stage" == *"_${stage_name//-/_}.sh" ]] || [[ "$stage" == *"_${stage_name//-/_}" ]]; then
            echo "$stage"
            return 0
        fi
    done
    echo ""
}

# Check if stage should be skipped
should_skip_stage() {
    local stage="$1"
    IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_STAGES"
    for skip in "${SKIP_ARRAY[@]}"; do
        if [[ "$stage" == *"${skip//-/_}"* ]]; then
            return 0
        fi
    done
    return 1
}

# Main pipeline execution
log_banner "USBPre Auto-Init Build Pipeline"
log_info "Version: ${VERSION}"
log_info "Build Directory: ${BUILD_DIR}"
log_info "Environment: $([ "$IS_CI" = "true" ] && echo "CI" || echo "Local")"
echo ""

# Handle --only mode
if [ -n "$ONLY_STAGE" ]; then
    STAGE_SCRIPT=$(stage_to_script "$ONLY_STAGE")
    if [ -z "$STAGE_SCRIPT" ]; then
        log_error "Unknown stage: $ONLY_STAGE"
        exit 1
    fi

    log_info "Running only stage: ${ONLY_STAGE}"
    if [ "$DRY_RUN" = false ]; then
        "${SCRIPT_DIR}/stages/${STAGE_SCRIPT}"
    else
        log_info "[DRY RUN] Would execute: ${STAGE_SCRIPT}"
    fi
    exit 0
fi

# Run pipeline stages
for stage in "${STAGES[@]}"; do
    stage_name="${stage%.sh}"
    stage_name="${stage_name#[0-9][0-9]_}"

    # Check if we should skip this stage
    if should_skip_stage "$stage"; then
        log_info "⊘ Skipping stage: ${stage_name}"
        continue
    fi

    # Execute stage
    if [ "$DRY_RUN" = false ]; then
        "${SCRIPT_DIR}/stages/${stage}" || {
            log_error "Stage failed: ${stage_name}"
            exit 1
        }
    else
        log_info "[DRY RUN] Would execute: ${stage}"
    fi

    # Check if we should stop after this stage
    if [ -n "$STOP_AT" ] && [[ "$stage" == *"${STOP_AT//-/_}"* ]]; then
        log_info "Stopping at stage: ${stage_name}"
        break
    fi

    echo ""
done

# Pipeline complete
log_banner "Pipeline Complete!"
log_success "Artifacts available in: ${BUILD_DIR}"

if [ -f "${BUILD_DIR}/${DMG_NAME}" ]; then
    log_info "Distribution: ${BUILD_DIR}/${DMG_NAME}"
fi
