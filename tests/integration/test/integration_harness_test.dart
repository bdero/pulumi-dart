/// Integration test harness for Pulumi Dart SDK.
///
/// This file provides utilities for running integration tests that verify
/// the end-to-end flow of the SDK with mock or real Pulumi services.
///
/// Run these tests with:
///   cd tests/integration && dart test

import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart'
    as empty;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:test/test.dart';

// Use the pulumi package imports
import 'package:pulumi/src/proto/pulumi/resource.pb.dart' as resource;
import 'package:pulumi/src/proto/pulumi/resource.pbgrpc.dart' as resource_grpc;
import 'package:pulumi/src/proto/pulumi/engine.pb.dart' as engine;
import 'package:pulumi/src/proto/pulumi/engine.pbgrpc.dart' as engine_grpc;
import 'package:pulumi/src/proto/pulumi/provider.pb.dart' as provider;

/// Mock ResourceMonitor service for integration testing.
///
/// Records all resource registrations and provides configurable responses.
class IntegrationMockResourceMonitor
    extends resource_grpc.ResourceMonitorServiceBase {
  final List<resource.RegisterResourceRequest> registeredResources = [];
  final List<resource.RegisterResourceOutputsRequest> registeredOutputs = [];

  int _nextId = 0;

  // Configurable behavior
  String Function(resource.RegisterResourceRequest)? onRegisterResource;
  Map<String, dynamic> Function(resource.RegisterResourceRequest)?
      generateOutputs;

  @override
  Future<resource.SupportsFeatureResponse> supportsFeature(
    ServiceCall call,
    resource.SupportsFeatureRequest request,
  ) async {
    return resource.SupportsFeatureResponse()..hasSupport = true;
  }

  @override
  Future<resource.RegisterResourceResponse> registerResource(
    ServiceCall call,
    resource.RegisterResourceRequest request,
  ) async {
    registeredResources.add(request);
    _nextId++;

    final urn =
        'urn:pulumi:test-stack::test-project::${request.type}::${request.name}';
    final id = 'mock-id-$_nextId';

    // Create output properties
    final props = Struct();

    // Copy inputs to outputs
    if (request.object.fields.isNotEmpty) {
      for (final entry in request.object.fields.entries) {
        props.fields[entry.key] = entry.value;
      }
    }

    // Generate provider-specific outputs
    if (request.type == 'random:index/randomString:RandomString') {
      final length =
          request.object.fields['length']?.numberValue.toInt() ?? 16;
      props.fields['result'] = Value()..stringValue = 'x' * length;
      props.fields['id'] = Value()..stringValue = id;
    }

    // Allow custom output generation
    if (generateOutputs != null) {
      final customOutputs = generateOutputs!(request);
      for (final entry in customOutputs.entries) {
        props.fields[entry.key] = _valueFromDynamic(entry.value);
      }
    }

    return resource.RegisterResourceResponse()
      ..urn = urn
      ..id = id
      ..object = props;
  }

  @override
  Future<empty.Empty> registerResourceOutputs(
    ServiceCall call,
    resource.RegisterResourceOutputsRequest request,
  ) async {
    registeredOutputs.add(request);
    return empty.Empty();
  }

  @override
  Future<resource.ReadResourceResponse> readResource(
    ServiceCall call,
    resource.ReadResourceRequest request,
  ) async {
    return resource.ReadResourceResponse();
  }

  @override
  Future<provider.InvokeResponse> invoke(
    ServiceCall call,
    resource.ResourceInvokeRequest request,
  ) async {
    return provider.InvokeResponse();
  }

  @override
  Future<provider.CallResponse> call(
    ServiceCall call,
    resource.ResourceCallRequest request,
  ) async {
    return provider.CallResponse();
  }

  @override
  Future<empty.Empty> registerStackTransform(
    ServiceCall call,
    dynamic request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<empty.Empty> registerStackInvokeTransform(
    ServiceCall call,
    dynamic request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<empty.Empty> registerResourceHook(
    ServiceCall call,
    resource.RegisterResourceHookRequest request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<empty.Empty> registerErrorHook(
    ServiceCall call,
    resource.RegisterErrorHookRequest request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<resource.RegisterPackageResponse> registerPackage(
    ServiceCall call,
    resource.RegisterPackageRequest request,
  ) async {
    return resource.RegisterPackageResponse();
  }

  @override
  Future<empty.Empty> signalAndWaitForShutdown(
    ServiceCall call,
    empty.Empty request,
  ) async {
    return empty.Empty();
  }

  Value _valueFromDynamic(dynamic value) {
    if (value is String) {
      return Value()..stringValue = value;
    } else if (value is int) {
      return Value()..numberValue = value.toDouble();
    } else if (value is double) {
      return Value()..numberValue = value;
    } else if (value is bool) {
      return Value()..boolValue = value;
    } else if (value is Map) {
      final struct = Struct();
      for (final entry in value.entries) {
        struct.fields[entry.key.toString()] = _valueFromDynamic(entry.value);
      }
      return Value()..structValue = struct;
    } else if (value is List) {
      final listValue = ListValue();
      for (final item in value) {
        listValue.values.add(_valueFromDynamic(item));
      }
      return Value()..listValue = listValue;
    } else {
      return Value()..nullValue = NullValue.NULL_VALUE;
    }
  }
}

/// Mock Engine service for integration testing.
class IntegrationMockEngine extends engine_grpc.EngineServiceBase {
  final List<engine.LogRequest> logs = [];

  @override
  Future<empty.Empty> log(
    ServiceCall call,
    engine.LogRequest request,
  ) async {
    logs.add(request);
    return empty.Empty();
  }

  @override
  Future<engine.GetRootResourceResponse> getRootResource(
    ServiceCall call,
    engine.GetRootResourceRequest request,
  ) async {
    return engine.GetRootResourceResponse()
      ..urn =
          'urn:pulumi:test-stack::test-project::pulumi:pulumi:Stack::test-stack';
  }

  @override
  Future<engine.SetRootResourceResponse> setRootResource(
    ServiceCall call,
    engine.SetRootResourceRequest request,
  ) async {
    return engine.SetRootResourceResponse();
  }

  @override
  Future<empty.Empty> startDebugging(
    ServiceCall call,
    engine.StartDebuggingRequest request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<engine.RequirePulumiVersionResponse> requirePulumiVersion(
    ServiceCall call,
    engine.RequirePulumiVersionRequest request,
  ) async {
    return engine.RequirePulumiVersionResponse();
  }
}

/// Integration test context that manages mock servers.
class IntegrationTestContext {
  late Server _monitorServer;
  late Server _engineServer;
  late int _monitorPort;
  late int _enginePort;

  final IntegrationMockResourceMonitor monitor;
  final IntegrationMockEngine engine;

  IntegrationTestContext()
      : monitor = IntegrationMockResourceMonitor(),
        engine = IntegrationMockEngine();

  /// Starts the mock servers and returns monitor/engine addresses.
  Future<(String monitorAddr, String engineAddr)> start() async {
    _monitorServer = Server.create(services: [monitor]);
    await _monitorServer.serve(address: 'localhost', port: 0);
    _monitorPort = _monitorServer.port!;

    _engineServer = Server.create(services: [engine]);
    await _engineServer.serve(address: 'localhost', port: 0);
    _enginePort = _engineServer.port!;

    return ('localhost:$_monitorPort', 'localhost:$_enginePort');
  }

  /// Stops the mock servers.
  Future<void> stop() async {
    await _monitorServer.shutdown();
    await _engineServer.shutdown();
  }
}

/// Runs a Dart Pulumi program with the given mock servers.
///
/// This spawns the program as a subprocess with the appropriate environment
/// variables set for connecting to the mock services.
Future<ProcessResult> runPulumiProgram({
  required String programDir,
  required String monitorAddress,
  required String engineAddress,
  String project = 'test-project',
  String stack = 'test-stack',
  bool dryRun = false,
  String? entryPoint,
}) async {
  // Build the dart run command
  // If an entry point is specified, run that file directly
  // Otherwise, run the default entry point (bin/<package_name>.dart)
  final args = entryPoint != null ? ['run', entryPoint] : ['run', 'bin/main.dart'];

  final result = await Process.run(
    'dart',
    args,
    workingDirectory: programDir,
    environment: {
      'PULUMI_MONITOR': monitorAddress,
      'PULUMI_ENGINE': engineAddress,
      'PULUMI_PROJECT': project,
      'PULUMI_STACK': stack,
      'PULUMI_DRY_RUN': dryRun.toString(),
      // Preserve existing PATH
      'PATH': Platform.environment['PATH'] ?? '',
    },
    includeParentEnvironment: true,
  );
  return result;
}

void main() {
  group('Integration tests with mock services', () {
    late IntegrationTestContext ctx;
    late String monitorAddr;
    late String engineAddr;

    setUp(() async {
      ctx = IntegrationTestContext();
      (monitorAddr, engineAddr) = await ctx.start();
    });

    tearDown(() async {
      await ctx.stop();
    });

    test('basic_random program registers RandomString resource', () async {
      // Get the testdata directory relative to the integration test directory
      // When running from tests/integration, testdata is at ./testdata/basic_random
      final scriptDir = Directory.current.path;
      final programDir = '$scriptDir/testdata/basic_random';

      // Skip if test data doesn't exist
      if (!Directory(programDir).existsSync()) {
        markTestSkipped('Test data directory not found: $programDir');
        return;
      }

      // Run dart pub get first
      final pubGetResult = await Process.run(
        'dart',
        ['pub', 'get'],
        workingDirectory: programDir,
      );
      expect(pubGetResult.exitCode, equals(0),
          reason: 'dart pub get failed: ${pubGetResult.stderr}');

      // Run the program
      final result = await runPulumiProgram(
        programDir: programDir,
        monitorAddress: monitorAddr,
        engineAddress: engineAddr,
      );

      // Print output for debugging
      if (result.exitCode != 0) {
        print('stdout: ${result.stdout}');
        print('stderr: ${result.stderr}');
      }

      expect(result.exitCode, equals(0),
          reason: 'Program exited with non-zero code: ${result.stderr}');

      // Verify the RandomString resource was registered
      expect(ctx.monitor.registeredResources, isNotEmpty,
          reason: 'No resources were registered');

      // Find the RandomString resource
      final randomString = ctx.monitor.registeredResources.firstWhere(
        (r) => r.type == 'random:index/randomString:RandomString',
        orElse: () => throw StateError('RandomString not found'),
      );

      expect(randomString.name, equals('test-random-string'));
      expect(randomString.custom, isTrue);

      // Verify input properties
      expect(randomString.object.fields['length']?.numberValue, equals(16));
      expect(randomString.object.fields['special']?.boolValue, equals(false));
      expect(randomString.object.fields['upper']?.boolValue, equals(true));

      // Verify stack outputs were registered
      expect(ctx.monitor.registeredOutputs, isNotEmpty,
          reason: 'Stack outputs were not registered');
    });

    test('program with Output dependencies tracks them correctly', () async {
      // This test would require a more complex test program
      // For now, mark as skipped
      markTestSkipped(
          'Complex dependency test requires additional test fixture');
    });
  });
}
