# Pulumi SDK for Dart

[![pub package](https://img.shields.io/pub/v/pulumi.svg)](https://pub.dev/packages/pulumi)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

The official Pulumi SDK for Dart, enabling Infrastructure as Code using Dart with full type safety and IDE support.

## Overview

[Pulumi](https://pulumi.com) is a modern infrastructure as code platform that allows you to define, deploy, and manage cloud infrastructure using familiar programming languages. This SDK brings Pulumi's powerful infrastructure management capabilities to the Dart ecosystem.

## Features

- **Type-Safe Infrastructure**: Define cloud resources with full Dart type checking
- **IDE Support**: Get autocompletion, inline documentation, and refactoring support
- **Async/Await**: Natural async patterns for handling infrastructure outputs
- **Component Resources**: Create reusable infrastructure abstractions
- **Multi-Cloud**: Works with AWS, Azure, GCP, Kubernetes, and 100+ providers

## Installation

Add the SDK to your `pubspec.yaml`:

```yaml
dependencies:
  pulumi: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Prerequisites

- Dart SDK 3.0.0 or later
- [Pulumi CLI](https://www.pulumi.com/docs/install/) installed
- `pulumi-language-dart` plugin (installed automatically or via `pulumi plugin install`)

## Quick Start

Create a new Pulumi project with Dart:

```bash
mkdir my-infrastructure && cd my-infrastructure
pulumi new dart
```

Or add Pulumi to an existing Dart project by creating a `Pulumi.yaml`:

```yaml
name: my-infrastructure
runtime: dart
description: My infrastructure project
```

### Example Program

```dart
import 'package:pulumi/pulumi.dart';

Future<void> main() async {
  await Pulumi.run((ctx) async {
    // Create resources here
    // For example, with pulumi_random provider:
    // final randomStr = RandomString('my-string', RandomStringArgs(length: 16));

    // Export values
    ctx.export('message', Output.of('Hello from Pulumi Dart!'));
  });
}
```

## Core Concepts

### Resources

Resources are the fundamental building blocks of Pulumi programs. Each resource corresponds to a cloud infrastructure component:

```dart
class MyResource extends CustomResource {
  late final Output<String> result;

  MyResource(String name, MyResourceArgs args, [CustomResourceOptions? opts])
      : _args = args,
        super('provider:module:ResourceType', name, opts);

  final MyResourceArgs _args;

  @override
  Map<String, Input<Object?>?> get inputs => {
    'property': _args.property,
  };

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    result = Output.of(properties.fields['result']?.stringValue ?? '');
  }
}
```

### Outputs and Inputs

Outputs represent values that may not be known until the infrastructure is deployed:

```dart
// Create an output
final greeting = Output.of('Hello');

// Transform outputs
final message = greeting.apply((g) => '$g, World!');

// Combine multiple outputs
final combined = Output.all([output1, output2]).apply((values) {
  return '${values[0]} - ${values[1]}';
});
```

Inputs accept either plain values or Outputs:

```dart
Input<String> name = Input.value('my-resource');
Input<String> fromOutput = Input.output(someOutput);
```

### Component Resources

Create reusable infrastructure components:

```dart
class WebApplication extends ComponentResource {
  late final Output<String> url;

  WebApplication(String name, WebApplicationArgs args, [ResourceOptions? opts])
      : super('mycompany:components:WebApplication', name, opts) {
    // Create child resources with this as parent
    final bucket = Bucket('$name-bucket', BucketArgs(...),
        CustomResourceOptions(parent: this));

    url = bucket.websiteEndpoint;

    registerOutputs({'url': url});
  }
}
```

### Configuration

Read configuration values from your Pulumi stack:

```dart
await Pulumi.run((ctx) async {
  final config = Config();
  final region = config.require('region');
  final instanceSize = config.get('instanceSize') ?? 't2.micro';
});
```

## Documentation

- [Pulumi Documentation](https://www.pulumi.com/docs/)
- [API Reference](https://pub.dev/documentation/pulumi/latest/)
- [Examples](https://github.com/bdero/pulumi-dart/tree/master/examples)

## Contributing

Contributions are welcome! Please see our [GitHub repository](https://github.com/bdero/pulumi-dart) for:

- Reporting issues
- Submitting pull requests
- Development setup instructions

## License

Apache 2.0 - see [LICENSE](LICENSE) for details.
