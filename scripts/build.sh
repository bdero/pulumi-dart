#!/usr/bin/env bash
# Cross-platform build script for pulumi-language-dart
# Usage: ./scripts/build.sh [platform] [options]
#
# Platforms: local, linux-amd64, linux-arm64, darwin-amd64, darwin-arm64, windows-amd64, all
# Options:
#   -v, --version VERSION   Set version string (default: dev)
#   -o, --output DIR        Output directory (default: dist)
#   -h, --help              Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/cmd/pulumi-language-dart"

# Default values
VERSION="dev"
OUTPUT_DIR="$PROJECT_ROOT/dist"
PLATFORMS=()

# Build configuration
BINARY_NAME="pulumi-language-dart"
LDFLAGS_BASE="-s -w"

# Supported platforms
SUPPORTED_PLATFORMS=("linux-amd64" "linux-arm64" "darwin-amd64" "darwin-arm64" "windows-amd64")

show_help() {
    cat << EOF
Cross-platform build script for pulumi-language-dart

Usage: $(basename "$0") [platform...] [options]

Platforms:
  local          Build for current platform only (default)
  linux-amd64    Linux on x86_64
  linux-arm64    Linux on ARM64
  darwin-amd64   macOS on x86_64
  darwin-arm64   macOS on ARM64 (Apple Silicon)
  windows-amd64  Windows on x86_64
  all            Build for all supported platforms

Options:
  -v, --version VERSION   Set version string (default: dev)
  -o, --output DIR        Output directory (default: dist)
  -h, --help              Show this help message

Examples:
  $(basename "$0")                    # Build for current platform
  $(basename "$0") all                # Build for all platforms
  $(basename "$0") linux-amd64        # Build for Linux x86_64
  $(basename "$0") all -v v0.1.0      # Release build for all platforms
  $(basename "$0") darwin-arm64 darwin-amd64  # Build for macOS only
EOF
}

log() {
    echo "[build] $*" >&2
}

error() {
    echo "[error] $*" >&2
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            all)
                PLATFORMS=("${SUPPORTED_PLATFORMS[@]}")
                shift
                ;;
            local)
                PLATFORMS=("local")
                shift
                ;;
            linux-amd64|linux-arm64|darwin-amd64|darwin-arm64|windows-amd64)
                PLATFORMS+=("$1")
                shift
                ;;
            *)
                error "Unknown option or platform: $1"
                ;;
        esac
    done

    # Default to local build if no platform specified
    if [[ ${#PLATFORMS[@]} -eq 0 ]]; then
        PLATFORMS=("local")
    fi
}

get_binary_name() {
    local goos="$1"
    if [[ "$goos" == "windows" ]]; then
        echo "${BINARY_NAME}.exe"
    else
        echo "$BINARY_NAME"
    fi
}

build_binary() {
    local platform="$1"
    local goos goarch output_name output_path

    if [[ "$platform" == "local" ]]; then
        # Build for current platform
        goos=""
        goarch=""
        output_name="$BINARY_NAME"

        # Detect current platform for binary extension
        case "$(uname -s)" in
            MINGW*|MSYS*|CYGWIN*|Windows_NT)
                output_name="${BINARY_NAME}.exe"
                ;;
        esac

        output_path="$SRC_DIR/$output_name"
        log "Building for current platform..."
    else
        # Cross-compile for specified platform
        goos="${platform%-*}"
        goarch="${platform#*-}"
        output_name="$(get_binary_name "$goos")"

        mkdir -p "$OUTPUT_DIR/$platform"
        output_path="$OUTPUT_DIR/$platform/$output_name"
        log "Building for $platform..."
    fi

    local ldflags="$LDFLAGS_BASE"
    if [[ "$VERSION" != "dev" ]]; then
        ldflags="$ldflags -X main.Version=$VERSION"
    fi

    local build_cmd=(go build -ldflags="$ldflags" -o "$output_path" .)

    # Set environment for cross-compilation
    local env_vars=()
    if [[ -n "${goos:-}" ]]; then
        env_vars+=(GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0)
    fi

    (
        cd "$SRC_DIR"
        if [[ ${#env_vars[@]} -gt 0 ]]; then
            env "${env_vars[@]}" "${build_cmd[@]}"
        else
            "${build_cmd[@]}"
        fi
    )

    log "Built: $output_path"
}

create_archive() {
    local platform="$1"
    local goos="${platform%-*}"
    local archive_name="pulumi-language-dart-${VERSION}-${platform}.tar.gz"
    local binary_name="$(get_binary_name "$goos")"

    (
        cd "$OUTPUT_DIR/$platform"
        tar -czvf "../$archive_name" "$binary_name"
    )

    log "Created archive: $OUTPUT_DIR/$archive_name"
}

main() {
    parse_args "$@"

    log "Version: $VERSION"
    log "Output directory: $OUTPUT_DIR"
    log "Platforms: ${PLATFORMS[*]}"

    # Verify Go is installed
    if ! command -v go &> /dev/null; then
        error "Go is not installed. Please install Go 1.21 or later."
    fi

    # Verify source directory exists
    if [[ ! -d "$SRC_DIR" ]]; then
        error "Source directory not found: $SRC_DIR"
    fi

    for platform in "${PLATFORMS[@]}"; do
        build_binary "$platform"

        # Create archive for non-local builds
        if [[ "$platform" != "local" ]]; then
            create_archive "$platform"
        fi
    done

    log "Build complete!"

    if [[ "${PLATFORMS[*]}" != "local" ]]; then
        echo ""
        log "Build artifacts:"
        ls -la "$OUTPUT_DIR"/*.tar.gz 2>/dev/null || true
    fi
}

main "$@"
