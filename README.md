# pulumi-dart

A Dart language backend for [Pulumi](https://pulumi.com), enabling Infrastructure as Code using Dart.

## Project Status

This project is in early development. See [PULUMI_DART_PLAN_V2.md](PULUMI_DART_PLAN_V2.md) for the implementation plan.

## Project Structure

```
pulumi-dart/
├── cmd/pulumi-language-dart/ # Go language host plugin
├── pkg/codegen/dart/         # Dart code generator for SDK generation
├── proto/                    # Pulumi proto files
├── providers/                # Generated provider SDKs
│   ├── pulumi_random/        # Random provider SDK
│   ├── pulumi_aws/           # AWS provider SDK (future)
│   └── pulumi_gcp/           # GCP provider SDK (future)
├── sdk/dart/                 # Dart SDK package
│   ├── lib/src/proto/        # Generated gRPC/protobuf code
│   └── test/                 # SDK tests
├── tests/integration/        # End-to-end integration tests
│   ├── test/                 # Integration test harness
│   └── testdata/             # Test Pulumi programs
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

### Unit Tests

Run the SDK unit tests:

```bash
cd sdk/dart
dart test
```

### Integration Tests

Run end-to-end integration tests that verify the full SDK workflow:

```bash
cd tests/integration
dart pub get
dart test
```

#### End-to-End Tests with Real Pulumi CLI

Run full end-to-end tests that use the actual Pulumi CLI and pulumi-random provider:

```bash
# First, build the language host
cd cmd/pulumi-language-dart
go build

# Run the E2E tests
cd tests/integration
PULUMI_DART_E2E=true dart test test/pulumi_cli_test.dart
```

These tests verify:
- `pulumi preview` correctly shows resources to be created
- `pulumi up` successfully creates resources with the random provider
- `pulumi destroy` successfully removes resources

### Language Host Tests

Run the Go language host tests:

```bash
cd cmd/pulumi-language-dart
go test -v
```

For integration tests that run actual Pulumi programs (requires Go):

```bash
cd cmd/pulumi-language-dart
go test -v -tags=integration -run TestIntegration
```

### Codegen Tests

Run the Dart code generator tests:

```bash
cd pkg/codegen/dart
go test -v
```

## Generating Provider SDKs

The Dart language host integrates with `pulumi package gen-sdk` to generate Dart SDKs for Pulumi providers.

### Building the Language Host

```bash
cd cmd/pulumi-language-dart
go build -o pulumi-language-dart .
```

### Generating an SDK

Once the language host is built and installed, you can generate Dart SDKs for any Pulumi provider:

```bash
# Using the helper script (recommended)
./scripts/gen-provider.sh pulumi-random
./scripts/gen-provider.sh pulumi-aws 6.0.0

# Or manually with pulumi CLI
pulumi package gen-sdk --language dart --out providers/pulumi_random pulumi-random
```

The generated SDK will include:
- `pubspec.yaml` - Package metadata and dependencies
- `lib/pulumi_<provider>.dart` - Main library export
- `lib/src/resources/` - Resource classes
- `lib/src/functions/` - Function wrappers
- `lib/src/types/` - Type definitions
- `lib/src/enums/` - Enum types

## Installation

### Installing the Language Plugin

The `pulumi-language-dart` plugin can be installed automatically via the plugin download URL or manually:

```bash
# Manual installation
pulumi plugin install language dart v0.1.0 --server github://api.github.com/bdero/pulumi-dart

# Or download directly from GitHub releases
# https://github.com/bdero/pulumi-dart/releases
```

The plugin supports the following platforms:
- `linux-amd64`
- `linux-arm64`
- `darwin-amd64`
- `darwin-arm64`
- `windows-amd64`

## Releases

This project uses GitHub Actions for automated releases. To create a new release:

1. Tag the commit with a version: `git tag v0.1.0`
2. Push the tag: `git push origin v0.1.0`
3. GitHub Actions will automatically build binaries for all platforms and create a release

## License

Apache 2.0
