#!/bin/bash
# Proto generation script for Pulumi Dart SDK
# Usage: ./scripts/generate_proto.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROTO_DIR="$PROJECT_DIR/proto"
OUT_DIR="$PROJECT_DIR/sdk/dart/lib/src/proto"

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
mkdir -p "$OUT_DIR/google/protobuf"

echo "Generating Dart code from proto files..."
echo "Proto dir: $PROTO_DIR"
echo "Output dir: $OUT_DIR"

# Generate Dart code from proto files
protoc \
    $PROTOC_GEN_DART \
    --dart_out=grpc:"$OUT_DIR" \
    -I"$PROTO_DIR" \
    "$PROTO_DIR/pulumi/resource.proto" \
    "$PROTO_DIR/pulumi/provider.proto" \
    "$PROTO_DIR/pulumi/engine.proto" \
    "$PROTO_DIR/pulumi/plugin.proto" \
    "$PROTO_DIR/pulumi/alias.proto" \
    "$PROTO_DIR/pulumi/callback.proto" \
    "$PROTO_DIR/pulumi/source.proto"

echo "Proto generation complete!"
echo "Generated files:"
find "$OUT_DIR" -name "*.dart" -type f | head -20
