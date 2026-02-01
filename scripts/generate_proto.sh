#!/bin/bash
# Proto generation script for Pulumi Dart SDK
# Usage: ./scripts/generate_proto.sh
#
# This script generates Dart code from proto files using protoc.
# It must be run from the project root directory.

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory and use relative paths
# This avoids issues with path separators on Windows/msys
cd "$PROJECT_DIR"

PROTO_DIR="./proto"
OUT_DIR="./sdk/dart/lib/src/proto"

# Add Dart pub cache to PATH for protoc-gen-dart
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
    export PATH="$PATH:$LOCALAPPDATA/Pub/Cache/bin"
    # On Windows, we need to specify the plugin explicitly
    PROTOC_GEN_DART="--plugin=protoc-gen-dart=$LOCALAPPDATA/Pub/Cache/bin/protoc-gen-dart.bat"
else
    export PATH="$PATH:$HOME/.pub-cache/bin"
    PROTOC_GEN_DART=""
fi

# Ensure output directory exists
mkdir -p "$OUT_DIR/pulumi"
mkdir -p "$OUT_DIR/pulumi/codegen"
mkdir -p "$OUT_DIR/google/protobuf"

echo "Generating Dart code from proto files..."
echo "Working dir: $(pwd)"
echo "Proto dir: $PROTO_DIR"
echo "Output dir: $OUT_DIR"

# Generate Dart code from proto files
protoc \
    $PROTOC_GEN_DART \
    "--dart_out=grpc:$OUT_DIR" \
    "-I$PROTO_DIR" \
    "$PROTO_DIR/pulumi/resource.proto" \
    "$PROTO_DIR/pulumi/provider.proto" \
    "$PROTO_DIR/pulumi/engine.proto" \
    "$PROTO_DIR/pulumi/plugin.proto" \
    "$PROTO_DIR/pulumi/alias.proto" \
    "$PROTO_DIR/pulumi/callback.proto" \
    "$PROTO_DIR/pulumi/source.proto" \
    "$PROTO_DIR/pulumi/language.proto" \
    "$PROTO_DIR/pulumi/codegen/hcl.proto"

echo "Proto generation complete!"
echo "Generated files:"
ls "$OUT_DIR/pulumi/"*.dart 2>/dev/null | wc -l | xargs echo "  pulumi/: files"
ls "$OUT_DIR/pulumi/codegen/"*.dart 2>/dev/null | wc -l | xargs echo "  pulumi/codegen/: files"
