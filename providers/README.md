# Pulumi Provider Packages

This directory contains generated Dart SDKs for Pulumi providers. Each provider is a separate publishable Dart package that depends on the core `pulumi` package.

## Directory Structure

```
providers/
├── pulumi_random/        # Random provider SDK
├── pulumi_aws/           # AWS provider SDK
├── pulumi_gcp/           # GCP provider SDK
├── pulumi_azure/         # Azure provider SDK
└── ...
```

## Package Structure

Each generated provider package follows this structure:

```
pulumi_<provider>/
├── pubspec.yaml              # Package metadata and dependencies
├── analysis_options.yaml     # Dart analysis configuration
├── lib/
│   ├── pulumi_<provider>.dart  # Main library export
│   └── src/
│       ├── resources/        # Resource classes
│       ├── functions/        # Function wrappers
│       ├── types/            # Type definitions
│       └── enums/            # Enum types
└── README.md                 # Provider-specific documentation
```

## Generating Provider SDKs

Provider SDKs are generated using the Pulumi CLI with the Dart language plugin:

```bash
# Build the language host first
cd cmd/pulumi-language-dart
go build

# Generate a provider SDK
pulumi package gen-sdk --language dart <provider-name>

# Example: Generate the random provider SDK
pulumi package gen-sdk --language dart pulumi-random
```

The generated files will be placed in the appropriate `providers/pulumi_<provider>/` directory.

## Using Provider Packages

In your Pulumi Dart project's `pubspec.yaml`, add the provider as a dependency:

```yaml
dependencies:
  pulumi: ^0.1.0
  pulumi_random:
    path: ../providers/pulumi_random
```

Then import and use the provider in your Dart code:

```dart
import 'package:pulumi/pulumi.dart';
import 'package:pulumi_random/pulumi_random.dart';

Future<void> main() async {
  await Pulumi.run((ctx) async {
    final randomString = RandomString(
      'my-random-string',
      RandomStringArgs(
        length: Input.value(16),
        special: Input.value(false),
      ),
    );

    ctx.export('result', randomString.result);
  });
}
```

## Publishing to pub.dev

Provider packages can be published to pub.dev once they are stable:

```bash
cd providers/pulumi_<provider>
dart pub publish
```

Ensure the `pubspec.yaml` has proper metadata including:
- `description`: A clear description of the provider
- `repository`: Link to the GitHub repository
- `homepage`: Link to Pulumi documentation
- `issue_tracker`: Link to issue tracking
