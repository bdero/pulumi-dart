#!/usr/bin/env bash
# Generate a Dart SDK for a Pulumi provider.
#
# Usage:
#   ./scripts/gen-provider.sh <provider-name> [version]
#
# Examples:
#   ./scripts/gen-provider.sh pulumi-random
#   ./scripts/gen-provider.sh pulumi-aws 6.0.0
#
# The generated SDK will be placed in providers/pulumi_<provider>/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <provider-name> [version]"
    echo "Example: $0 pulumi-random"
    exit 1
fi

PROVIDER_NAME="$1"
PROVIDER_VERSION="${2:-}"

# Extract the provider short name (e.g., "random" from "pulumi-random")
SHORT_NAME="${PROVIDER_NAME#pulumi-}"

# Output directory
OUTPUT_DIR="$ROOT_DIR/providers/pulumi_$SHORT_NAME"

echo "Generating Dart SDK for $PROVIDER_NAME..."
echo "Output directory: $OUTPUT_DIR"

# Build the language host if needed
LANGUAGE_HOST="$ROOT_DIR/cmd/pulumi-language-dart/pulumi-language-dart"
if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
    LANGUAGE_HOST="$LANGUAGE_HOST.exe"
fi

if [ ! -f "$LANGUAGE_HOST" ]; then
    echo "Building language host..."
    (cd "$ROOT_DIR/cmd/pulumi-language-dart" && go build)
fi

# Generate the SDK
if [ -n "$PROVIDER_VERSION" ]; then
    pulumi package gen-sdk --language dart --out "$OUTPUT_DIR" "$PROVIDER_NAME@$PROVIDER_VERSION"
else
    pulumi package gen-sdk --language dart --out "$OUTPUT_DIR" "$PROVIDER_NAME"
fi

echo "Done! Generated SDK at $OUTPUT_DIR"
echo ""
echo "To use the generated provider in a Pulumi Dart project, add this to pubspec.yaml:"
echo ""
echo "dependencies:"
echo "  pulumi_$SHORT_NAME:"
echo "    path: <path-to>/providers/pulumi_$SHORT_NAME"
