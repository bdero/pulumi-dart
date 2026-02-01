# pulumi-dart

A Dart language backend for [Pulumi](https://pulumi.com), enabling Infrastructure as Code using Dart.

## Project Status

This project is in early development. See [PULUMI_DART_PLAN_V2.md](PULUMI_DART_PLAN_V2.md) for the implementation plan.

## Project Structure

```
pulumi-dart/
├── proto/                    # Pulumi proto files
├── sdk/dart/                 # Dart SDK package
│   ├── lib/src/proto/        # Generated gRPC/protobuf code
│   └── test/                 # SDK tests
├── scripts/                  # Build scripts
└── PULUMI_DART_PLAN_V2.md    # Implementation plan
```

## Prerequisites

- Dart SDK 3.0.0+
- protoc (Protocol Buffers compiler)
- protoc-gen-dart (`dart pub global activate protoc_plugin`)

## Building

### Install Dependencies

```bash
cd sdk/dart
dart pub get
```

### Regenerate Proto Files

```bash
# On Windows (Git Bash/MSYS2)
export PATH="$PATH:$LOCALAPPDATA/Pub/Cache/bin"
protoc --plugin=protoc-gen-dart="$LOCALAPPDATA/Pub/Cache/bin/protoc-gen-dart.bat" \
    --dart_out=grpc:sdk/dart/lib/src/proto \
    -Iproto \
    proto/pulumi/*.proto

# On macOS/Linux
export PATH="$PATH:$HOME/.pub-cache/bin"
protoc --dart_out=grpc:sdk/dart/lib/src/proto \
    -Iproto \
    proto/pulumi/*.proto
```

## Testing

```bash
cd sdk/dart
dart test
```

## License

Apache 2.0
