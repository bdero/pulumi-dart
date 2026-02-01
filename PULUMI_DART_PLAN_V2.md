# Pulumi Dart Language Backend Implementation Plan

**Version:** 2.0
**Date:** February 2026
**Status:** Draft
**Changes from V1:** Fixed Dart type system issues, clarified async patterns, added plugin distribution details, corrected proto file locations, added Besom as reference implementation

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Background and Context](#2-background-and-context)
3. [Architecture Overview](#3-architecture-overview)
4. [Component Breakdown](#4-component-breakdown)
5. [Implementation Phases](#5-implementation-phases)
6. [Technical Specifications](#6-technical-specifications)
7. [Testing Strategy](#7-testing-strategy)
8. [Distribution and Publishing](#8-distribution-and-publishing)
9. [Risks and Mitigations](#9-risks-and-mitigations)
10. [Resolved Design Decisions](#10-resolved-design-decisions)
11. [Open Questions](#11-open-questions)
12. [References](#12-references)

---

## Changelog from V1

| Issue | V1 Problem | V2 Resolution |
|-------|------------|---------------|
| Input<T> type | Used invalid `typedef Input<T> = FutureOr<T> \| Output<T>;` | Use sealed class hierarchy for type-safe union |
| Async constructors | Showed async code in constructors (not allowed in Dart) | Use static factory methods and late initialization |
| Proto file locations | Vague reference to proto directory | Clarified: `proto/pulumi/` contains all proto files |
| Plugin distribution | Missing distribution mechanism for community plugins | Added `pluginDownloadURL` and GitHub releases details |
| Program execution | Vague "dynamic loading" | Clarified: Use `Isolate.spawnUri()` for loading user programs |
| Reference implementation | No community implementation reference | Added Besom (Scala Pulumi) as reference |
| Build system support | Only mentioned Dart VM | Added multiple execution modes (pub run, AOT, pre-compiled) |

---

## 1. Executive Summary

This document outlines the implementation plan for a Dart language backend for Pulumi, enabling developers to write Infrastructure as Code (IaC) using the Dart programming language. The implementation consists of three main components:

1. **Language Host Plugin (`pulumi-language-dart`)**: A Go binary that implements the Pulumi language runtime gRPC interface and manages the execution of Dart programs.

2. **Dart SDK (`pulumi`)**: A Dart package published to pub.dev that provides the programming model for defining and managing cloud resources.

3. **Code Generator (`pulumi-gen-dart`)**: Generates Dart SDKs for Pulumi providers (AWS, Azure, GCP, Kubernetes, etc.) from Pulumi package schemas.

### Goals

- Enable Dart developers to write Pulumi programs using idiomatic Dart patterns
- Support async/await for handling resource outputs with proper dependency tracking
- Integrate with the Dart/pub.dev ecosystem
- Provide automated code generation for provider SDKs
- Maintain feature parity with other Pulumi language SDKs
- Support multiple execution modes (pub run, AOT compiled, pre-built binary)

---

## 2. Background and Context

### 2.1 Why Dart?

Dart is a modern, object-oriented language developed by Google with significant adoption through Flutter. Key strengths relevant to Pulumi:

- **Strong typing with null safety**: Provides compile-time safety and IDE support
- **First-class async/await**: Essential for Pulumi's Output model
- **Official gRPC support**: `grpc` and `protobuf` packages on pub.dev
- **AOT compilation**: `dart compile exe` creates fast-starting native executables
- **Sealed classes (Dart 3.0+)**: Enables proper union type representation
- **Pattern matching**: Exhaustive switch expressions for type-safe handling

### 2.2 Community Interest

- GitHub Issue [#15135](https://github.com/pulumi/pulumi/issues/15135): Dart language support request
- GitHub Issue [#11882](https://github.com/pulumi/pulumi/issues/11882): Community language plugin support

### 2.3 Reference Implementation: Besom

[Besom](https://github.com/VirtusLab/besom) is VirtusLab's Scala SDK for Pulumi that provides a valuable reference:
- Completely independent implementation (not based on Java SDK)
- Implements its own language plugin in Go
- Has its own codegen for provider SDKs
- Demonstrates community language plugin distribution patterns

### 2.4 Pulumi's Multi-Language Architecture

Pulumi separates language support from the deployment engine through a plugin architecture:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Pulumi CLI    │────▶│ Language Plugin │────▶│   User Program  │
│                 │     │ (Go binary)     │     │   (Dart code)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                      │                        │
         │                      │                        │
         ▼                      ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Deployment Engine                             │
│                 (ResourceMonitor gRPC Server)                    │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│ Provider Plugins │
│ (AWS, GCP, etc.) │
└─────────────────┘
```

---

## 3. Architecture Overview

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Pulumi CLI                                │
│                                                                  │
│  1. Reads Pulumi.yaml (runtime: dart)                           │
│  2. Locates pulumi-language-dart plugin                         │
│  3. Spawns plugin process, connects via gRPC                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ gRPC (LanguageRuntime service)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 pulumi-language-dart (Go)                        │
│            Implements LanguageRuntime gRPC Service               │
│                                                                  │
│  Methods:                                                        │
│  ├── GetPluginInfo() → returns plugin metadata                  │
│  ├── GetRequiredPlugins() → parses pubspec.yaml                 │
│  ├── InstallDependencies() → runs 'dart pub get'                │
│  ├── Run() → spawns Dart executor with user program             │
│  ├── GeneratePackage() → invokes Dart codegen                   │
│  ├── GenerateProject() → creates new project from template      │
│  └── Pack() → packages code for distribution                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Spawns process with CLI args:
                              │   --monitor=<address>
                              │   --engine=<address>
                              │   --project=<path>
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               Dart Executor                                      │
│                                                                  │
│  Execution modes:                                                │
│  ├── 'dart run' (development) - runs user's main.dart           │
│  ├── AOT snapshot (optimized) - dartaotruntime                  │
│  └── Pre-compiled binary (production) - native executable       │
│                                                                  │
│  On startup:                                                     │
│  1. Parse CLI args for gRPC addresses                           │
│  2. Initialize Pulumi runtime (connects to monitor/engine)      │
│  3. Execute user's main() function                              │
│  4. Wait for all resource registrations to complete             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Uses SDK
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Dart SDK (pulumi)                            │
│                    Published on pub.dev                          │
│                                                                  │
│  Core Classes:                                                   │
│  ├── Pulumi (entry point, manages context)                      │
│  ├── Output<T> (async value with dependency tracking)           │
│  ├── Input<T> (sealed class: T | Output<T> | Future<T>)         │
│  ├── Resource, CustomResource, ComponentResource                │
│  ├── Config (stack configuration access)                        │
│  └── StackReference (cross-stack references)                    │
│                                                                  │
│  Runtime:                                                        │
│  ├── ResourceMonitor gRPC client                                │
│  ├── Engine gRPC client (logging)                               │
│  └── Property serialization                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ gRPC (ResourceMonitor service)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Pulumi Deployment Engine                      │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 gRPC Interfaces

#### 3.2.1 LanguageRuntime Service (proto/pulumi/language.proto)

The language host must implement:

| Method | Purpose | Implementation Notes |
|--------|---------|---------------------|
| `GetPluginInfo` | Returns plugin metadata | Return name="dart", version |
| `GetRequiredPlugins` | Returns plugins needed by program | Parse pubspec.yaml for pulumi_* deps |
| `Run` | Executes the user's program | Spawn dart/dartaotruntime with args |
| `InstallDependencies` | Installs program dependencies | Run `dart pub get` |
| `About` | Returns runtime information | Dart SDK version, path |
| `GetProgramDependencies` | Lists package dependencies | Parse pubspec.lock |
| `GeneratePackage` | Generates SDK code | Invoke codegen |
| `GenerateProject` | Creates new project | Copy template, customize |
| `Pack` | Packages code | Create tarball/archive |
| `RuntimeOptionsPrompts` | Configuration prompts | Build tool selection, etc. |

#### 3.2.2 ResourceMonitor Service (proto/pulumi/resource.proto)

The SDK must implement a gRPC client for:

| Method | Purpose |
|--------|---------|
| `RegisterResource` | Register a new resource |
| `RegisterResourceOutputs` | Add outputs to component resource |
| `ReadResource` | Import existing resource state |
| `Invoke` | Call a provider function |
| `Call` | Call a resource method |
| `SupportsFeature` | Check feature availability |

### 3.3 Proto Files Location

All proto files are in the Pulumi repository at `proto/pulumi/`:

```
proto/pulumi/
├── alias.proto
├── analyzer.proto
├── callback.proto
├── converter.proto
├── engine.proto          # Engine service (logging, etc.)
├── errors.proto
├── events.proto
├── language.proto        # LanguageRuntime service
├── plugin.proto
├── provider.proto        # Provider service
├── resource.proto        # ResourceMonitor service
├── resource_status.proto
├── source.proto
├── codegen/
└── testing/
```

---

## 4. Component Breakdown

### 4.1 Language Host Plugin (`pulumi-language-dart`)

**Language:** Go
**Binary name:** `pulumi-language-dart`
**Location:** `cmd/pulumi-language-dart/`

#### 4.1.1 Responsibilities

1. **Runtime Detection**
   ```go
   func detectDartRuntime() (*DartRuntime, error) {
       // Check for 'dart' in PATH
       // Verify minimum version (3.0.0+)
       // Detect pub cache location
   }
   ```

2. **Dependency Management**
   - Parse `pubspec.yaml` to identify Pulumi provider dependencies
   - Map package names to plugin requirements: `pulumi_aws` → `aws` plugin
   - Run `dart pub get` for dependency installation

3. **Program Execution**
   - Support multiple execution modes based on `runtime.options`:
     - `dart run` (default, development)
     - `dartaotruntime` with AOT snapshot
     - Pre-compiled binary via `runtime.options.binary`

4. **Code Generation**
   - Invoke Dart codegen for `GeneratePackage`
   - Either shell out to a separate codegen binary or embed codegen logic

#### 4.1.2 File Structure

```
cmd/pulumi-language-dart/
├── main.go              # Entry point, plugin registration
├── language.go          # LanguageRuntime gRPC implementation
├── executor.go          # Dart program execution
├── dependencies.go      # pubspec.yaml parsing, plugin detection
└── codegen.go           # SDK generation dispatch
```

### 4.2 Dart Executor

**Language:** Dart
**Location:** `sdk/dart/bin/pulumi_executor.dart` (distributed with SDK)

The executor is responsible for:
1. Parsing command-line arguments (monitor address, engine address, project path)
2. Initializing the Pulumi runtime context
3. Executing the user's program
4. Handling graceful shutdown

#### 4.2.1 Execution Flow

```dart
// bin/pulumi_executor.dart
import 'dart:io';
import 'package:pulumi/runtime.dart';

Future<void> main(List<String> args) async {
  final config = ExecutorConfig.fromArgs(args);

  // Initialize runtime with gRPC connections
  await Runtime.initialize(
    monitorAddress: config.monitorAddress,
    engineAddress: config.engineAddress,
  );

  try {
    // The user's program is run via 'dart run' which executes their main.dart
    // The SDK intercepts resource creations through the Pulumi.run() entry point
    exit(0);
  } catch (e, stack) {
    await Runtime.instance.logError('Program failed: $e\n$stack');
    exit(1);
  } finally {
    await Runtime.shutdown();
  }
}
```

#### 4.2.2 Execution Modes

| Mode | Pulumi.yaml Config | How It Works |
|------|-------------------|--------------|
| Development | `runtime: dart` | Runs `dart run` on user's project |
| AOT Snapshot | `runtime.options.use-aot: true` | Compiles to AOT, runs with dartaotruntime |
| Pre-compiled | `runtime.options.binary: bin/app` | Runs specified executable directly |

### 4.3 Dart SDK (`pulumi`)

**Language:** Dart
**Package name:** `pulumi`
**Location:** `sdk/dart/`

#### 4.3.1 Core Types (Corrected from V1)

##### Input<T> - Sealed Class Hierarchy

**V1 Problem:** Used invalid `typedef Input<T> = FutureOr<T> | Output<T>;`

**V2 Solution:** Use sealed class for proper union type:

```dart
/// Represents a value that can be provided to a resource input.
/// Can be a plain value, an Output, or a Future.
sealed class Input<T> {
  const Input();

  /// Creates an Input from a plain value.
  factory Input.value(T value) = InputValue<T>;

  /// Creates an Input from an Output.
  factory Input.output(Output<T> output) = InputOutput<T>;

  /// Creates an Input from a Future.
  factory Input.future(Future<T> future) = InputFuture<T>;

  /// Resolves this input to an Output.
  Output<T> toOutput();
}

final class InputValue<T> extends Input<T> {
  final T value;
  const InputValue(this.value);

  @override
  Output<T> toOutput() => Output.of(value);
}

final class InputOutput<T> extends Input<T> {
  final Output<T> output;
  const InputOutput(this.output);

  @override
  Output<T> toOutput() => output;
}

final class InputFuture<T> extends Input<T> {
  final Future<T> future;
  const InputFuture(this.future);

  @override
  Output<T> toOutput() => Output.fromFuture(future);
}

/// Extension to allow implicit conversion from raw values.
extension InputExtension<T> on T {
  Input<T> toInput() => Input.value(this);
}
```

**Usage with pattern matching:**

```dart
Future<T> resolveInput<T>(Input<T> input) async {
  return switch (input) {
    InputValue(:final value) => value,
    InputOutput(:final output) => await output.future,
    InputFuture(:final future) => await future,
  };
}
```

##### Output<T> - Async Value with Dependency Tracking

```dart
/// Represents an asynchronously computed value with dependency tracking.
/// Outputs are central to Pulumi's programming model.
class Output<T> {
  final Future<_OutputData<T>> _data;

  Output._(this._data);

  /// Creates an Output from a known value.
  factory Output.of(T value) => Output._(
    Future.value(_OutputData(
      value: value,
      isKnown: true,
      isSecret: false,
      resources: {},
    )),
  );

  /// Creates an Output from a Future.
  factory Output.fromFuture(Future<T> future) => Output._(
    future.then((value) => _OutputData(
      value: value,
      isKnown: true,
      isSecret: false,
      resources: {},
    )),
  );

  /// Creates an unknown Output (value will be filled during deployment).
  factory Output.unknown() => Output._(
    Future.value(_OutputData(
      value: null as T,
      isKnown: false,
      isSecret: false,
      resources: {},
    )),
  );

  /// The resolved value as a Future.
  Future<T> get future => _data.then((d) => d.value);

  /// Transforms the output value while preserving dependencies.
  Output<U> apply<U>(FutureOr<U> Function(T) transform) {
    return Output._(_data.then((data) async {
      if (!data.isKnown) {
        return _OutputData<U>(
          value: null as U,
          isKnown: false,
          isSecret: data.isSecret,
          resources: data.resources,
        );
      }
      final newValue = await transform(data.value);
      return _OutputData(
        value: newValue,
        isKnown: true,
        isSecret: data.isSecret,
        resources: data.resources,
      );
    }));
  }

  /// Combines multiple outputs into a single output containing a list.
  static Output<List<T>> all<T>(Iterable<Output<T>> outputs) {
    final outputList = outputs.toList();
    return Output._(Future.wait(outputList.map((o) => o._data)).then((dataList) {
      return _OutputData(
        value: dataList.map((d) => d.value).toList(),
        isKnown: dataList.every((d) => d.isKnown),
        isSecret: dataList.any((d) => d.isSecret),
        resources: dataList.expand((d) => d.resources).toSet(),
      );
    }));
  }

  /// Marks this output as containing secret data.
  Output<T> asSecret() => Output._(_data.then((d) => _OutputData(
    value: d.value,
    isKnown: d.isKnown,
    isSecret: true,
    resources: d.resources,
  )));
}

class _OutputData<T> {
  final T value;
  final bool isKnown;
  final bool isSecret;
  final Set<Resource> resources;

  _OutputData({
    required this.value,
    required this.isKnown,
    required this.isSecret,
    required this.resources,
  });
}
```

##### Resource - Async Initialization Pattern

**V1 Problem:** Used async code in constructors (not allowed in Dart).

**V2 Solution:** Use late initialization with completer pattern:

```dart
/// Base class for all Pulumi resources.
abstract class Resource {
  final String _type;
  final String _name;
  final ResourceOptions? _opts;

  late final Output<String> urn;
  final Completer<void> _registered = Completer();

  /// Wait for this resource to be fully registered.
  Future<void> get registered => _registered.future;

  Resource(this._type, this._name, this._opts) {
    // Schedule registration - runs after constructor completes
    _scheduleRegistration();
  }

  void _scheduleRegistration() {
    // Use scheduleMicrotask to run after constructor
    scheduleMicrotask(() async {
      try {
        await _register();
        _registered.complete();
      } catch (e) {
        _registered.completeError(e);
      }
    });
  }

  /// Override in subclasses to provide input properties.
  @protected
  Map<String, dynamic> get inputs;

  /// Performs the actual resource registration.
  Future<void> _register() async {
    final monitor = Runtime.instance.monitor;

    // Collect all dependencies from input values
    final deps = await _collectDependencies(inputs);

    // Serialize inputs to protobuf format
    final serializedInputs = await PropertySerializer.serialize(inputs);

    final request = RegisterResourceRequest()
      ..type = _type
      ..name = _name
      ..custom = this is CustomResource
      ..object = serializedInputs
      ..parent = _opts?.parent?.urn ?? ''
      ..protect = _opts?.protect ?? false
      ..dependencies.addAll(deps);

    final response = await monitor.registerResource(request);

    // Wire up URN
    urn = Output.of(response.urn);

    // Let subclasses process outputs
    _processOutputs(response.object);
  }

  /// Override in subclasses to process response properties.
  @protected
  void _processOutputs(Struct properties);

  Future<List<String>> _collectDependencies(Map<String, dynamic> props) async {
    // Walk through properties, collect URNs from Output dependencies
    final urns = <String>[];
    // ... implementation
    return urns;
  }
}

/// A resource managed by a provider plugin.
abstract class CustomResource extends Resource {
  late final Output<String> id;

  CustomResource(super.type, super.name, [super.opts]);

  @override
  void _processOutputs(Struct properties) {
    id = Output.of(properties.fields['id']?.stringValue ?? '');
    // Subclasses override to process additional outputs
  }
}

/// A logical grouping of resources.
abstract class ComponentResource extends Resource {
  ComponentResource(super.type, super.name, [super.opts]);

  @override
  Map<String, dynamic> get inputs => {};

  @override
  void _processOutputs(Struct properties) {
    // Component resources don't have provider-assigned outputs
  }

  /// Register outputs for this component.
  Future<void> registerOutputs(Map<String, Output> outputs) async {
    final monitor = Runtime.instance.monitor;
    await monitor.registerResourceOutputs(
      RegisterResourceOutputsRequest()
        ..urn = await urn.future
        ..outputs = await PropertySerializer.serializeOutputMap(outputs),
    );
  }
}
```

#### 4.3.2 Module Structure

```
sdk/dart/
├── pubspec.yaml
├── lib/
│   ├── pulumi.dart                 # Main library export
│   └── src/
│       ├── resource.dart           # Resource, CustomResource, ComponentResource
│       ├── output.dart             # Output<T>
│       ├── input.dart              # Input<T> sealed class hierarchy
│       ├── config.dart             # Config class
│       ├── stack.dart              # StackReference
│       ├── invoke.dart             # Invoke helpers
│       ├── log.dart                # Logging utilities
│       ├── options.dart            # ResourceOptions, CustomResourceOptions
│       ├── pulumi.dart             # Pulumi.run() entry point
│       ├── runtime/
│       │   ├── runtime.dart        # Runtime singleton
│       │   ├── settings.dart       # Runtime settings
│       │   ├── monitor.dart        # ResourceMonitor gRPC client
│       │   ├── engine.dart         # Engine gRPC client
│       │   └── serialization.dart  # Property serialization
│       └── proto/                  # Generated protobuf code
│           ├── pulumi/
│           │   ├── resource.pb.dart
│           │   ├── resource.pbgrpc.dart
│           │   ├── provider.pb.dart
│           │   ├── engine.pb.dart
│           │   ├── plugin.pb.dart
│           │   └── ...
│           └── google/
│               └── protobuf/
│                   ├── struct.pb.dart
│                   └── ...
├── bin/
│   └── pulumi_executor.dart        # Executor entry point
└── test/
    ├── output_test.dart
    ├── input_test.dart
    ├── resource_test.dart
    └── serialization_test.dart
```

### 4.4 Code Generator (`pulumi-gen-dart`)

**Language:** Go
**Location:** `pkg/codegen/dart/`

The code generator follows the pattern established by other language codegen packages in the Pulumi repository.

#### 4.4.1 Generated Code Patterns

##### Resource Class

```dart
/// An AWS S3 Bucket resource.
///
/// Provides an S3 bucket resource.
class Bucket extends CustomResource {
  /// The name of the bucket.
  late final Output<String> bucket;

  /// The ARN of the bucket.
  late final Output<String> arn;

  /// The website endpoint.
  late final Output<String?> websiteEndpoint;

  final BucketArgs _args;

  Bucket(
    String name,
    BucketArgs args, {
    CustomResourceOptions? options,
  }) : _args = args,
       super('aws:s3/bucket:Bucket', name, options);

  @override
  Map<String, dynamic> get inputs => {
    'bucket': _args.bucket,
    'acl': _args.acl,
    'website': _args.website,
    'tags': _args.tags,
  };

  @override
  void _processOutputs(Struct properties) {
    super._processOutputs(properties);
    bucket = Output.of(properties.fields['bucket']?.stringValue ?? '');
    arn = Output.of(properties.fields['arn']?.stringValue ?? '');
    websiteEndpoint = properties.fields.containsKey('websiteEndpoint')
        ? Output.of(properties.fields['websiteEndpoint']?.stringValue)
        : Output.of(null);
  }
}

/// Arguments for creating a Bucket resource.
class BucketArgs {
  /// The name of the bucket. If omitted, a unique name will be generated.
  final Input<String>? bucket;

  /// The canned ACL to apply.
  final Input<String>? acl;

  /// Website configuration.
  final Input<BucketWebsiteArgs>? website;

  /// Tags to apply to the bucket.
  final Input<Map<String, String>>? tags;

  BucketArgs({
    this.bucket,
    this.acl,
    this.website,
    this.tags,
  });
}

/// Website configuration for a Bucket.
class BucketWebsiteArgs {
  final Input<String>? indexDocument;
  final Input<String>? errorDocument;

  BucketWebsiteArgs({this.indexDocument, this.errorDocument});
}
```

##### Enum Types

```dart
/// The ACL to apply to an S3 bucket.
enum BucketCannedAcl {
  private._('private'),
  publicRead._('public-read'),
  publicReadWrite._('public-read-write'),
  authenticatedRead._('authenticated-read');

  final String value;
  const BucketCannedAcl._(this.value);

  @override
  String toString() => value;
}
```

##### Function Invocation

```dart
/// Get information about an AWS availability zone.
Future<GetAvailabilityZoneResult> getAvailabilityZone({
  String? name,
  String? zoneId,
  GetAvailabilityZoneArgs? args,
  InvokeOptions? options,
}) async {
  final result = await Invoke.call(
    'aws:index/getAvailabilityZone:getAvailabilityZone',
    args ?? GetAvailabilityZoneArgs(name: name, zoneId: zoneId),
    options,
  );
  return GetAvailabilityZoneResult.fromProperties(result);
}
```

---

## 5. Implementation Phases

### Phase 0: Foundation (Priority 0 - Required)

**Goal:** Minimal viable implementation that can run basic Pulumi programs

**Duration estimate:** Research suggests 4-8 weeks for a dedicated developer

#### 5.0.1 Protocol Buffer Generation
- [ ] Clone Pulumi repo and locate proto files in `proto/pulumi/`
- [ ] Set up proto compilation script using `protoc` with `dart_out=grpc:` option
- [ ] Generate Dart code from: `resource.proto`, `provider.proto`, `engine.proto`, `plugin.proto`
- [ ] Add generated code to `sdk/dart/lib/src/proto/`
- [ ] Verify gRPC client functionality with simple test

#### 5.0.2 Core SDK Implementation
- [ ] Implement `Output<T>` with dependency tracking (see Section 4.3.1)
- [ ] Implement `Input<T>` sealed class hierarchy
- [ ] Implement base `Resource` class with async registration pattern
- [ ] Implement `CustomResource` with provider output handling
- [ ] Implement `ComponentResource` with `registerOutputs`
- [ ] Implement `ResourceOptions` and `CustomResourceOptions`
- [ ] Implement `Config` for stack configuration access
- [ ] Implement property serialization (Dart → protobuf Struct)
- [ ] Implement property deserialization (protobuf Struct → Dart)
- [ ] Implement `Runtime` singleton with gRPC clients
- [ ] Implement `Pulumi.run()` entry point with context management

#### 5.0.3 Language Host Implementation
- [ ] Create Go module at `cmd/pulumi-language-dart/`
- [ ] Implement basic `LanguageRuntime` gRPC server
- [ ] Implement `GetPluginInfo` (return name="dart", version)
- [ ] Implement `Run` with Dart executor spawning
- [ ] Implement `GetRequiredPlugins` (parse pubspec.yaml)
- [ ] Implement `InstallDependencies` (`dart pub get`)
- [ ] Implement `About` (Dart SDK version info)
- [ ] Build and test language host binary

#### 5.0.4 Integration Testing
- [ ] Set up test project structure
- [ ] Test resource registration flow end-to-end
- [ ] Test Output chaining and dependency collection
- [ ] Test basic CRUD operations with a test provider
- [ ] Test Config retrieval
- [ ] Test error handling and reporting

### Phase 1: Code Generation (Priority 1)

**Goal:** Generate provider SDKs from Pulumi schemas

#### 5.1.1 Code Generator Core
- [ ] Create Go package at `pkg/codegen/dart/`
- [ ] Implement Pulumi schema parsing (use existing `pkg/codegen/schema`)
- [ ] Implement Dart code emitter utilities
- [ ] Implement package structure generation (pubspec.yaml, lib/, etc.)

#### 5.1.2 Type Generation
- [ ] Map Pulumi primitives to Dart types (string→String, integer→int, etc.)
- [ ] Generate complex object types as classes
- [ ] Generate enum types
- [ ] Handle union types using sealed classes
- [ ] Generate array types (List<T>)
- [ ] Generate map types (Map<String, T>)

#### 5.1.3 Resource Generation
- [ ] Generate resource classes extending CustomResource/ComponentResource
- [ ] Generate *Args classes for resource inputs
- [ ] Generate output property declarations
- [ ] Handle resource options
- [ ] Generate dartdoc from schema descriptions

#### 5.1.4 Function Generation
- [ ] Generate async function wrappers
- [ ] Generate function argument types
- [ ] Generate function result types

#### 5.1.5 Integration
- [ ] Wire codegen into `pulumi package gen-sdk --language dart`
- [ ] Test SDK generation for `pulumi-random` (simple provider)
- [ ] Test SDK generation for `pulumi-aws` (complex provider)

### Phase 2: Ecosystem Integration (Priority 2)

**Goal:** Full integration with Pulumi and Dart ecosystems

#### 5.2.1 Plugin Distribution
- [ ] Set up GitHub releases for `pulumi-language-dart`
- [ ] Configure `pluginDownloadURL` for automatic plugin installation
- [ ] Document manual installation via `pulumi plugin install`
- [ ] Cross-compile for Windows, macOS, Linux (x64, arm64)

#### 5.2.2 Package Publishing
- [ ] Set up pub.dev publisher account
- [ ] Configure CI/CD for `pulumi` SDK publishing
- [ ] Create automation for provider SDK publishing
- [ ] Document versioning strategy

#### 5.2.3 Project Templates
- [ ] Create `dart` template for `pulumi new`
- [ ] Create `aws-dart` template
- [ ] Create `kubernetes-dart` template
- [ ] Register templates with Pulumi

#### 5.2.4 Testing Infrastructure
- [ ] Add Dart to integration test harness
- [ ] Create conformance test suite
- [ ] Set up CI/CD for automated testing

### Phase 3: Advanced Features (Priority 3)

**Goal:** Feature parity with other language SDKs

- [ ] Remote component resource support (Construct)
- [ ] Automation API for programmatic Pulumi operations
- [ ] Stack transforms
- [ ] Resource transforms
- [ ] Mock testing support

### Phase 4: Polish and Documentation (Priority 4)

**Goal:** Production-ready release

- [ ] API reference documentation (dartdoc)
- [ ] Getting started guide
- [ ] Example projects (AWS, Kubernetes, etc.)
- [ ] VS Code extension support
- [ ] Performance optimization

---

## 6. Technical Specifications

### 6.1 Version Requirements

| Component | Minimum Version | Rationale |
|-----------|-----------------|-----------|
| Dart SDK | 3.0.0 | Sealed classes, patterns, class modifiers |
| Pulumi CLI | 3.50.0+ | Community plugin support improvements |
| Go | 1.21+ | For language host compilation |
| protoc | 3.19+ | Proto3 support |

### 6.2 SDK Dependencies (pubspec.yaml)

```yaml
name: pulumi
version: 0.1.0
description: Pulumi SDK for Infrastructure as Code in Dart
repository: https://github.com/example/pulumi-dart
homepage: https://pulumi.com

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  grpc: ^4.0.0
  protobuf: ^3.1.0
  async: ^2.11.0
  collection: ^1.18.0
  meta: ^1.11.0
  path: ^1.9.0
  yaml: ^3.1.0
  args: ^2.4.0  # For CLI argument parsing

dev_dependencies:
  test: ^1.25.0
  lints: ^3.0.0
  build_runner: ^2.4.0
  protoc_plugin: ^21.1.0
```

### 6.3 Pulumi.yaml Runtime Configuration

```yaml
name: my-dart-project
description: A Pulumi program written in Dart
runtime:
  name: dart
  options:
    # Execution mode (optional)
    # - "run" (default): Use 'dart run'
    # - "aot": Compile to AOT snapshot
    # - "binary": Use pre-compiled executable
    mode: run

    # Path to pre-compiled binary (when mode: binary)
    binary: bin/myapp

    # Use pub workspace for dependencies (optional)
    use-workspace: false
```

### 6.4 Proto Generation Script

```bash
#!/bin/bash
# scripts/generate_proto.sh

PROTO_DIR="../pulumi/proto"
OUT_DIR="sdk/dart/lib/src/proto"

# Ensure output directory exists
mkdir -p "$OUT_DIR"

# Generate Dart code from proto files
protoc \
  --dart_out=grpc:"$OUT_DIR" \
  -I"$PROTO_DIR" \
  "$PROTO_DIR/pulumi/resource.proto" \
  "$PROTO_DIR/pulumi/provider.proto" \
  "$PROTO_DIR/pulumi/engine.proto" \
  "$PROTO_DIR/pulumi/plugin.proto" \
  "$PROTO_DIR/pulumi/alias.proto" \
  "$PROTO_DIR/pulumi/callback.proto"

echo "Proto generation complete"
```

---

## 7. Testing Strategy

### 7.1 Unit Tests

| Component | Test Focus |
|-----------|------------|
| `Output<T>` | apply(), all(), asSecret(), dependency tracking |
| `Input<T>` | Sealed class variants, toOutput() conversion |
| Serialization | Roundtrip Dart ↔ protobuf Struct |
| Config | Value retrieval, type coercion, defaults |

### 7.2 Integration Tests

```dart
// test/integration/basic_resource_test.dart
void main() {
  test('can create and register a resource', () async {
    await Pulumi.run((ctx) async {
      final bucket = Bucket('test-bucket', BucketArgs());
      await bucket.registered;

      expect(bucket.urn, isNotNull);
      expect(await bucket.id.future, isNotEmpty);
    });
  });
}
```

### 7.3 Conformance Tests

Based on Pulumi's language conformance requirements:
- Resource registration produces correct URNs
- Parent/child relationships are preserved
- Aliases work correctly
- Secrets are properly marked
- Dependencies are correctly tracked

### 7.4 End-to-End Tests

- Deploy real AWS resources (S3 bucket, EC2 instance)
- Deploy Kubernetes resources
- Test stack references across stacks
- Test `pulumi preview`, `pulumi up`, `pulumi destroy`

---

## 8. Distribution and Publishing

### 8.1 Language Host Plugin Distribution

#### GitHub Releases

The language host will be distributed via GitHub releases:

```
https://github.com/<org>/pulumi-dart/releases/download/v0.1.0/pulumi-language-dart-v0.1.0-<os>-<arch>.tar.gz
```

Supported platforms:
- `linux-amd64`
- `linux-arm64`
- `darwin-amd64`
- `darwin-arm64`
- `windows-amd64`

#### Plugin Download URL

Configure in provider schema and SDK to enable automatic installation:

```
github://api.github.com/<org>/pulumi-dart
```

Users can also manually install:

```bash
pulumi plugin install language dart v0.1.0 --server https://github.com/<org>/pulumi-dart/releases/download/v0.1.0
```

### 8.2 SDK Publishing (pub.dev)

| Package | Description |
|---------|-------------|
| `pulumi` | Core SDK |
| `pulumi_aws` | AWS provider SDK |
| `pulumi_azure` | Azure provider SDK |
| `pulumi_gcp` | GCP provider SDK |
| `pulumi_kubernetes` | Kubernetes provider SDK |
| `pulumi_random` | Random provider SDK |

### 8.3 Versioning Strategy

| Component | Version Policy |
|-----------|----------------|
| `pulumi` (core SDK) | Semantic versioning, independent releases |
| `pulumi_*` (providers) | Match upstream provider version |
| `pulumi-language-dart` | Semantic versioning, track Pulumi CLI compatibility |

---

## 9. Risks and Mitigations

### 9.1 Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dart gRPC performance issues | High | Low | Benchmark early; consider connection pooling |
| Proto generation issues | Medium | Medium | Test with multiple proto versions; pin protoc_plugin |
| Memory leaks from incomplete futures | High | Medium | Careful resource cleanup; use `Zone` for tracking |
| AOT compilation limitations | Medium | Low | Test `dart:mirrors` alternatives early |

### 9.2 Ecosystem Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pulumi protocol changes | High | Low | Pin to specific Pulumi version; monitor releases |
| Dart 4.0 breaking changes | Medium | Low | Follow Dart evolution; maintain compatibility |
| pub.dev publishing issues | Medium | Low | Set up verified publisher early |

### 9.3 Adoption Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Low community adoption | Medium | Medium | Good documentation; example projects; blog posts |
| Competition from other IaC tools | Low | Medium | Focus on Dart/Flutter developer experience |

---

## 10. Resolved Design Decisions

Based on research, the following design decisions have been made:

### 10.1 Input<T> Representation

**Decision:** Use sealed class hierarchy

**Rationale:** Dart doesn't support `typedef` union types. Sealed classes provide:
- Type-safe pattern matching
- Exhaustive switch expressions
- Clear API for users

### 10.2 Async Initialization

**Decision:** Use late initialization with `Completer` pattern

**Rationale:** Dart constructors cannot be async. The pattern:
1. Constructor stores arguments
2. `scheduleMicrotask` triggers async registration
3. `Completer<void>` signals completion
4. `await resource.registered` for explicit waiting

### 10.3 User Program Execution

**Decision:** Use `dart run` as the primary execution mode

**Rationale:**
- Simplest for development (no compilation step)
- Works with standard Dart project structure
- AOT compilation available as optimization

### 10.4 Plugin Distribution

**Decision:** Use GitHub releases with `pluginDownloadURL`

**Rationale:**
- Standard pattern for community plugins (see Besom)
- Automatic installation via Pulumi CLI
- Easy cross-platform binary distribution

### 10.5 Package Naming

**Decision:** Use `pulumi_<provider>` naming convention

**Rationale:**
- Follows Dart/pub.dev conventions (snake_case)
- Consistent with other Pulumi SDKs conceptually
- Clear namespace ownership

---

## 11. Open Questions

### 11.1 Remaining Design Questions

1. **Completer vs late Output pattern**
   - Should outputs be late-initialized `Output<T>` or use `Completer<Output<T>>`?
   - Need to test both patterns for ergonomics

2. **Error handling strategy**
   - Exceptions vs Result types for SDK errors?
   - How to surface provider errors clearly?

3. **Testing framework**
   - Should we provide mock testing utilities like other SDKs?
   - Integration with `package:test`?

### 11.2 Pulumi Team Coordination

1. **Language registration**
   - Process for adding `dart` to official language list?
   - Required conformance test coverage?

2. **Provider SDK generation automation**
   - Can we integrate with existing provider CI/CD?
   - Publishing credentials for pub.dev?

### 11.3 Community Input Needed

1. **API ergonomics**
   - Review Input<T> sealed class usage patterns
   - Feedback on Output<T>.apply() vs extension methods

2. **Build tool support**
   - Interest in `build_runner` integration?
   - Flutter project support priority?

---

## 12. References

### 12.1 Pulumi Documentation

- [How Pulumi Works](https://www.pulumi.com/docs/iac/concepts/how-pulumi-works/)
- [New Language Bring Up Guide](https://github.com/pulumi/pulumi/wiki/New-Language-Bring-Up)
- [Language Hosts Architecture](https://pulumi-developer-docs.readthedocs.io/latest/docs/architecture/languages.html)
- [Pulumi Package Schema](https://www.pulumi.com/docs/iac/guides/building-extending/packages/schema/)
- [Plugin Install Documentation](https://www.pulumi.com/docs/iac/cli/commands/pulumi_plugin_install/)

### 12.2 Pulumi Source Code

- [Main Repository](https://github.com/pulumi/pulumi)
- [Proto Files](https://github.com/pulumi/pulumi/tree/master/proto/pulumi)
- [Python SDK](https://github.com/pulumi/pulumi/tree/master/sdk/python)
- [Java SDK](https://github.com/pulumi/pulumi-java)
- [Codegen Package](https://pkg.go.dev/github.com/pulumi/pulumi/pkg/v3/codegen)

### 12.3 Reference Implementations

- [Besom (Scala SDK)](https://github.com/VirtusLab/besom) - Community implementation reference
- [Besom Documentation](https://virtuslab.github.io/besom/)

### 12.4 Dart Documentation

- [Dart gRPC Quick Start](https://grpc.io/docs/languages/dart/quickstart/)
- [protoc_plugin Package](https://pub.dev/packages/protoc_plugin)
- [Dart Sealed Classes](https://dart.dev/language/class-modifiers#sealed)
- [Dart Async Programming](https://dart.dev/libraries/async/async-await)
- [Dart Package Publishing](https://dart.dev/tools/pub/publishing)
- [dart compile](https://dart.dev/tools/dart-compile)
- [Isolate.spawnUri](https://api.dart.dev/dart-isolate/Isolate/spawnUri.html)

### 12.5 Related GitHub Issues

- [Dart Support Request (#15135)](https://github.com/pulumi/pulumi/issues/15135)
- [Community Language Plugin Support (#11882)](https://github.com/pulumi/pulumi/issues/11882)
- [Custom Plugin Sources (#9007)](https://github.com/pulumi/pulumi/issues/9007)

---

## Appendix A: Example Pulumi Dart Program

```dart
// bin/main.dart
import 'package:pulumi/pulumi.dart';
import 'package:pulumi_aws/pulumi_aws.dart' as aws;

Future<void> main() async {
  await Pulumi.run((ctx) async {
    // Get configuration
    final config = Config();
    final environment = config.require('environment');

    // Create an S3 bucket
    final bucket = aws.s3.Bucket('my-bucket',
      aws.s3.BucketArgs(
        tags: Input.value({'Environment': environment}),
        website: Input.value(aws.s3.BucketWebsiteArgs(
          indexDocument: Input.value('index.html'),
        )),
      ),
    );

    // Wait for bucket to be registered before using its outputs
    await bucket.registered;

    // Create an EC2 instance that depends on the bucket
    final instance = aws.ec2.Instance('web-server',
      aws.ec2.InstanceArgs(
        ami: Input.value('ami-0c55b159cbfafe1f0'),
        instanceType: Input.value('t2.micro'),
        tags: Input.value({
          'Name': 'WebServer',
          'BucketArn': await bucket.arn.future,
        }),
      ),
    );

    // Export stack outputs
    ctx.export('bucketName', bucket.bucket);
    ctx.export('bucketArn', bucket.arn);
    ctx.export('instanceId', instance.id);
    ctx.export('publicIp', instance.publicIp);
  });
}
```

---

## Appendix B: Project Structure

```
pulumi-dart/
├── README.md
├── CONTRIBUTING.md
├── LICENSE                          # Apache 2.0
├── PULUMI_DART_PLAN_V2.md           # This document
│
├── cmd/
│   └── pulumi-language-dart/        # Go language host
│       ├── main.go
│       ├── language.go              # LanguageRuntime implementation
│       ├── executor.go              # Dart program execution
│       ├── dependencies.go          # pubspec.yaml parsing
│       ├── codegen.go               # SDK generation dispatch
│       └── go.mod
│
├── pkg/
│   └── codegen/
│       └── dart/                    # Dart code generator
│           ├── gen.go               # Main generator
│           ├── gen_resource.go      # Resource generation
│           ├── gen_type.go          # Type generation
│           ├── gen_function.go      # Function generation
│           ├── gen_enum.go          # Enum generation
│           ├── utilities.go         # Dart naming, formatting
│           └── templates/           # Code templates
│
├── sdk/
│   └── dart/
│       ├── pubspec.yaml
│       ├── analysis_options.yaml
│       ├── lib/
│       │   ├── pulumi.dart          # Main export
│       │   └── src/
│       │       ├── resource.dart
│       │       ├── output.dart
│       │       ├── input.dart
│       │       ├── config.dart
│       │       ├── stack.dart
│       │       ├── invoke.dart
│       │       ├── log.dart
│       │       ├── options.dart
│       │       ├── pulumi.dart      # Pulumi.run() entry point
│       │       ├── runtime/
│       │       │   ├── runtime.dart
│       │       │   ├── settings.dart
│       │       │   ├── monitor.dart
│       │       │   ├── engine.dart
│       │       │   └── serialization.dart
│       │       └── proto/
│       │           └── pulumi/
│       │               ├── resource.pb.dart
│       │               ├── resource.pbgrpc.dart
│       │               └── ...
│       ├── bin/
│       │   └── pulumi_executor.dart
│       └── test/
│           ├── output_test.dart
│           ├── input_test.dart
│           ├── resource_test.dart
│           └── serialization_test.dart
│
├── templates/
│   ├── dart/
│   │   ├── Pulumi.yaml.template
│   │   ├── pubspec.yaml.template
│   │   └── bin/main.dart.template
│   ├── aws-dart/
│   └── kubernetes-dart/
│
├── scripts/
│   ├── generate_proto.sh
│   ├── build_language_host.sh
│   └── publish_sdk.sh
│
└── tests/
    ├── integration/
    │   ├── basic_resource_test.dart
    │   └── output_chaining_test.dart
    └── conformance/
        └── ... (Pulumi conformance tests)
```

---

*This document is a living specification and will be updated as implementation progresses and decisions are made.*

**Document History:**
- V1.0 (Feb 2026): Initial plan
- V2.0 (Feb 2026): Fixed Dart type system issues, added plugin distribution details, added Besom reference
