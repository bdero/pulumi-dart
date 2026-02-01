import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:test/test.dart';

import 'package:pulumi/src/input.dart';
import 'package:pulumi/src/output.dart';
import 'package:pulumi/src/pulumi.dart';
import 'package:pulumi/src/resource.dart';
import 'package:pulumi/src/runtime/runtime.dart';

import 'mock_monitor_service.dart';

/// A test custom resource for testing Pulumi.run().
class TestResource extends CustomResource {
  late final Output<String> outputValue;

  final Map<String, Input<Object?>?> _inputs;

  TestResource(
    String name, {
    String? inputValue,
    ResourceOptions? options,
  })  : _inputs = {
          if (inputValue != null) 'inputValue': Input.value(inputValue),
        },
        super('test:resource:TestResource', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => _inputs;

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    outputValue =
        Output.of(properties.fields['outputValue']?.stringValue ?? 'default');
  }
}

void main() {
  group('PulumiContext', () {
    test('stores exports correctly', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          ctx.export('key1', Output.of('value1'));
          ctx.export('key2', Output.of(42));

          expect(ctx.exports.keys, containsAll(['key1', 'key2']));
        },
        project: 'test-project',
        stack: 'test-stack',
      );
    });

    test('exportValue creates Output from plain value', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          ctx.exportValue('version', '1.0.0');
          ctx.exportValue('count', 10);

          final versionExport = ctx.exports['version']!;
          final countExport = ctx.exports['count']!;

          expect(await versionExport.future, equals('1.0.0'));
          expect(await countExport.future, equals(10));
        },
        project: 'test-project',
        stack: 'test-stack',
      );
    });

    test('exports is unmodifiable', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          ctx.export('key', Output.of('value'));

          expect(
            () => (ctx.exports as Map)['newKey'] = Output.of('newValue'),
            throwsUnsupportedError,
          );
        },
        project: 'test-project',
        stack: 'test-stack',
      );
    });

    test('provides runtime information', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          expect(ctx.project, equals('my-project'));
          expect(ctx.stack, equals('production'));
          expect(ctx.isDryRun, isTrue);
          expect(ctx.organization, equals('my-org'));
        },
        project: 'my-project',
        stack: 'production',
        isDryRun: true,
        organization: 'my-org',
      );
    });
  });

  group('Pulumi.runWithOptions', () {
    late Server server;
    late MockResourceMonitorService mockService;
    late int port;

    setUp(() async {
      mockService = MockResourceMonitorService();
      server = Server.create(services: [mockService]);
      await server.serve(address: 'localhost', port: 0);
      port = server.port!;
    });

    tearDown(() async {
      if (Runtime.isInitialized) {
        await Runtime.instance.monitor.terminate();
      }
      Runtime.reset();
      await server.shutdown();
    });

    test('executes callback with context', () async {
      String? capturedProject;
      String? capturedStack;

      await Pulumi.runWithOptions(
        (ctx) async {
          capturedProject = ctx.project;
          capturedStack = ctx.stack;
        },
        project: 'test-project',
        stack: 'test-stack',
      );

      expect(capturedProject, equals('test-project'));
      expect(capturedStack, equals('test-stack'));
    });

    test('provides isDryRun to context', () async {
      bool? capturedDryRun;

      await Pulumi.runWithOptions(
        (ctx) async {
          capturedDryRun = ctx.isDryRun;
        },
        project: 'test-project',
        stack: 'test-stack',
        isDryRun: true,
      );

      expect(capturedDryRun, isTrue);
    });

    test('provides organization to context', () async {
      String? capturedOrg;

      await Pulumi.runWithOptions(
        (ctx) async {
          capturedOrg = ctx.organization;
        },
        project: 'test-project',
        stack: 'test-stack',
        organization: 'my-org',
      );

      expect(capturedOrg, equals('my-org'));
    });

    test('sets currentContext during execution', () async {
      PulumiContext? capturedContext;

      expect(Pulumi.currentContext, isNull);

      await Pulumi.runWithOptions(
        (ctx) async {
          capturedContext = Pulumi.currentContext;
          expect(Pulumi.currentContext, same(ctx));
        },
        project: 'test-project',
        stack: 'test-stack',
      );

      expect(capturedContext, isNotNull);
      expect(Pulumi.currentContext, isNull);
    });

    test('clears currentContext after exception', () async {
      expect(Pulumi.currentContext, isNull);

      try {
        await Pulumi.runWithOptions(
          (ctx) async {
            throw Exception('Test error');
          },
          project: 'test-project',
          stack: 'test-stack',
        );
      } catch (_) {
        // Expected
      }

      expect(Pulumi.currentContext, isNull);
    });

    test('rethrows exceptions from callback', () async {
      expect(
        () => Pulumi.runWithOptions(
          (ctx) async {
            throw FormatException('Test error');
          },
          project: 'test-project',
          stack: 'test-stack',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('initializes runtime when monitorAddress provided', () async {
      mockService.nextUrn =
          'urn:pulumi:stack::project::test:resource:TestResource::test';
      mockService.nextId = 'test-id';

      await Pulumi.runWithOptions(
        (ctx) async {
          expect(Runtime.isInitialized, isTrue);
          expect(Runtime.instance.project, equals('test-project'));
          expect(Runtime.instance.stack, equals('test-stack'));

          final resource = TestResource('test', inputValue: 'hello');
          await resource.registered;
        },
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Verify resource was registered
      expect(mockService.registeredResources, hasLength(1));
    });

    test('runs in mock mode without monitorAddress', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          expect(Runtime.isInitialized, isFalse);

          // Resources still work in mock mode
          final resource = TestResource('test', inputValue: 'hello');
          await resource.registered;

          // URN is generated locally
          expect(await resource.urn.future, contains('test'));
        },
        project: 'test-project',
        stack: 'test-stack',
      );
    });

    test('shuts down runtime after execution', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          expect(Runtime.isInitialized, isTrue);
        },
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      expect(Runtime.isInitialized, isFalse);
    });

    test('shuts down runtime after exception', () async {
      try {
        await Pulumi.runWithOptions(
          (ctx) async {
            expect(Runtime.isInitialized, isTrue);
            throw Exception('Test error');
          },
          monitorAddress: 'localhost:$port',
          project: 'test-project',
          stack: 'test-stack',
        );
      } catch (_) {
        // Expected
      }

      expect(Runtime.isInitialized, isFalse);
    });

    test('handles exports correctly', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          ctx.export('key1', Output.of('value1'));
          ctx.exportValue('key2', 42);

          expect(ctx.exports.length, equals(2));
        },
        project: 'test-project',
        stack: 'test-stack',
      );
    });

    test('registers stack outputs when runtime is initialized', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          ctx.export('outputKey', Output.of('outputValue'));
        },
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Verify outputs were registered
      expect(mockService.registeredOutputs, hasLength(1));
      final outputRequest = mockService.registeredOutputs.first;
      expect(
        outputRequest.urn,
        equals(
            'urn:pulumi:test-stack::test-project::pulumi:pulumi:Stack::test-stack'),
      );
      expect(
        outputRequest.outputs.fields['outputKey']?.stringValue,
        equals('outputValue'),
      );
    });

    test('waits for tracked resource registrations', () async {
      mockService.nextUrn =
          'urn:pulumi:stack::project::test:resource:TestResource::test';
      mockService.nextId = 'test-id';

      bool resourceRegistered = false;

      await Pulumi.runWithOptions(
        (ctx) async {
          final resource = TestResource('test');
          ctx.trackResource(resource);

          // Mark when registration completes
          resource.registered.then((_) {
            resourceRegistered = true;
          });
        },
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // By the time runWithOptions completes, the tracked resource should be registered
      expect(resourceRegistered, isTrue);
    });

    test('supports synchronous callbacks', () async {
      String? capturedProject;

      await Pulumi.runWithOptions(
        (ctx) {
          // Note: no async here
          capturedProject = ctx.project;
        },
        project: 'sync-project',
        stack: 'sync-stack',
      );

      expect(capturedProject, equals('sync-project'));
    });

    test('handles multiple exports with different types', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          ctx.export('stringVal', Output.of('hello'));
          ctx.export('intVal', Output.of(42));
          ctx.export('boolVal', Output.of(true));
          ctx.export('listVal', Output.of([1, 2, 3]));
          ctx.export('mapVal', Output.of({'key': 'value'}));

          expect(ctx.exports.length, equals(5));
        },
        project: 'test-project',
        stack: 'test-stack',
      );
    });

    test('does not register outputs when no exports', () async {
      await Pulumi.runWithOptions(
        (ctx) async {
          // No exports
        },
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // No outputs should be registered
      expect(mockService.registeredOutputs, isEmpty);
    });
  });

  group('EngineService', () {
    // Engine service tests would require a mock engine server
    // For now, we just test that it can be created
    test('can be instantiated with connect', () {
      // This test just verifies the constructor doesn't throw
      // We don't actually connect since there's no server
      expect(() => EngineService.connect('localhost:50051'), returnsNormally);
    });
  });
}
