import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as empty;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:test/test.dart';

import 'package:pulumi/src/input.dart';
import 'package:pulumi/src/invoke.dart';
import 'package:pulumi/src/output.dart';
import 'package:pulumi/src/proto/pulumi/provider.pb.dart' as provider;
import 'package:pulumi/src/proto/pulumi/resource.pb.dart' as resource;
import 'package:pulumi/src/proto/pulumi/resource.pbgrpc.dart' as resource_grpc;
import 'package:pulumi/src/runtime/monitor.dart';
import 'package:pulumi/src/runtime/runtime.dart';
import 'package:pulumi/src/runtime/serialization.dart';

/// A mock ResourceMonitor service for testing invoke.
class MockResourceMonitorService
    extends resource_grpc.ResourceMonitorServiceBase {
  final List<resource.ResourceInvokeRequest> invokeRequests = [];

  // Configurable response
  Struct nextReturn = Struct();
  List<provider.CheckFailure> nextFailures = [];

  @override
  Future<resource.SupportsFeatureResponse> supportsFeature(
    ServiceCall call,
    resource.SupportsFeatureRequest request,
  ) async {
    return resource.SupportsFeatureResponse()..hasSupport = false;
  }

  @override
  Future<resource.RegisterResourceResponse> registerResource(
    ServiceCall call,
    resource.RegisterResourceRequest request,
  ) async {
    return resource.RegisterResourceResponse();
  }

  @override
  Future<empty.Empty> registerResourceOutputs(
    ServiceCall call,
    resource.RegisterResourceOutputsRequest request,
  ) async {
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
    invokeRequests.add(request);
    final response = provider.InvokeResponse()..return_1 = nextReturn;
    if (nextFailures.isNotEmpty) {
      response.failures.addAll(nextFailures);
    }
    return response;
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
}

void main() {
  late Server server;
  late ResourceMonitor monitor;
  late MockResourceMonitorService mockService;
  late int port;

  setUp(() async {
    mockService = MockResourceMonitorService();

    server = Server.create(services: [mockService]);
    await server.serve(address: 'localhost', port: 0);
    port = server.port!;

    monitor = ResourceMonitor.connect('localhost:$port');

    // Initialize the runtime
    Runtime.initializeWithMonitor(
      monitor: monitor,
      project: 'test-project',
      stack: 'test-stack',
      isDryRun: false,
    );
  });

  tearDown(() async {
    Runtime.reset();
    await monitor.shutdown();
    await server.shutdown();
  });

  group('InvokeOptions', () {
    test('creates with default values', () {
      const options = InvokeOptions();

      expect(options.provider, isNull);
      expect(options.version, isNull);
      expect(options.pluginDownloadUrl, isNull);
    });

    test('creates with all values', () {
      const options = InvokeOptions(
        provider: 'aws::default',
        version: '5.0.0',
        pluginDownloadUrl: 'https://example.com/plugins',
      );

      expect(options.provider, equals('aws::default'));
      expect(options.version, equals('5.0.0'));
      expect(options.pluginDownloadUrl, equals('https://example.com/plugins'));
    });

    test('copyWith creates a new instance with updated values', () {
      const original = InvokeOptions(provider: 'aws::default');
      final copied = original.copyWith(version: '5.0.0');

      expect(copied.provider, equals('aws::default'));
      expect(copied.version, equals('5.0.0'));
      expect(original.version, isNull);
    });

    test('equality works correctly', () {
      const options1 = InvokeOptions(provider: 'aws::default');
      const options2 = InvokeOptions(provider: 'aws::default');
      const options3 = InvokeOptions(provider: 'gcp::default');

      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
    });

    test('hashCode is consistent', () {
      const options1 = InvokeOptions(provider: 'aws::default');
      const options2 = InvokeOptions(provider: 'aws::default');

      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('toString returns readable representation', () {
      const options = InvokeOptions(
        provider: 'aws::default',
        version: '5.0.0',
      );

      final str = options.toString();
      expect(str, contains('provider: aws::default'));
      expect(str, contains('version: 5.0.0'));
    });
  });

  group('InvokeFailure', () {
    test('creates with property and reason', () {
      final failure = InvokeFailure(
        property: 'ownerId',
        reason: 'must be specified',
      );

      expect(failure.property, equals('ownerId'));
      expect(failure.reason, equals('must be specified'));
    });

    test('toString returns readable representation', () {
      final failure = InvokeFailure(
        property: 'ownerId',
        reason: 'must be specified',
      );

      final str = failure.toString();
      expect(str, contains('ownerId'));
      expect(str, contains('must be specified'));
    });
  });

  group('InvokeException', () {
    test('creates with token and failures', () {
      final failures = [
        InvokeFailure(property: 'ownerId', reason: 'must be specified'),
        InvokeFailure(property: 'filters', reason: 'invalid format'),
      ];
      final exception = InvokeException('aws:ec2/getAmi:getAmi', failures);

      expect(exception.token, equals('aws:ec2/getAmi:getAmi'));
      expect(exception.failures, hasLength(2));
    });

    test('toString includes all failure details', () {
      final failures = [
        InvokeFailure(property: 'ownerId', reason: 'must be specified'),
      ];
      final exception = InvokeException('aws:ec2/getAmi:getAmi', failures);

      final str = exception.toString();
      expect(str, contains('aws:ec2/getAmi:getAmi'));
      expect(str, contains('ownerId'));
      expect(str, contains('must be specified'));
    });
  });

  group('invoke', () {
    test('sends token and args to monitor', () async {
      mockService.nextReturn = Struct()
        ..fields['id'] = (Value()..stringValue = 'ami-12345')
        ..fields['name'] = (Value()..stringValue = 'my-ami');

      final result = invoke(
        'aws:ec2/getAmi:getAmi',
        {
          'owners': Input.value(['amazon']),
          'mostRecent': Input.value(true),
        },
      );

      final data = await result.dataFuture;
      expect(data.isKnown, isTrue);
      expect(data.value['id'], equals('ami-12345'));
      expect(data.value['name'], equals('my-ami'));

      expect(mockService.invokeRequests, hasLength(1));
      final request = mockService.invokeRequests.first;
      expect(request.tok, equals('aws:ec2/getAmi:getAmi'));
      expect(request.args.fields['mostRecent']?.boolValue, isTrue);
    });

    test('sends options to monitor', () async {
      mockService.nextReturn = Struct();

      final result = invoke(
        'aws:ec2/getAmi:getAmi',
        {},
        const InvokeOptions(
          provider: 'aws::us-east-1',
          version: '5.0.0',
          pluginDownloadUrl: 'https://example.com',
        ),
      );

      // Wait for the invoke to complete
      await result.dataFuture;

      expect(mockService.invokeRequests, hasLength(1));
      final request = mockService.invokeRequests.first;
      expect(request.provider, equals('aws::us-east-1'));
      expect(request.version, equals('5.0.0'));
      expect(request.pluginDownloadURL, equals('https://example.com'));
    });

    test('returns Output that resolves to result', () async {
      mockService.nextReturn = Struct()
        ..fields['availabilityZones'] = (Value()
          ..listValue = (ListValue()
            ..values.addAll([
              Value()..stringValue = 'us-east-1a',
              Value()..stringValue = 'us-east-1b',
            ])));

      final result = invoke(
        'aws:getAvailabilityZones:getAvailabilityZones',
        {},
      );

      expect(result, isA<Output<Map<String, dynamic>>>());

      final data = await result.dataFuture;
      final zones = data.value['availabilityZones'] as List;
      expect(zones, contains('us-east-1a'));
      expect(zones, contains('us-east-1b'));
    });

    test('handles nested objects in response', () async {
      final nestedStruct = Struct()
        ..fields['name'] = (Value()..stringValue = 'my-filter')
        ..fields['values'] = (Value()
          ..listValue = (ListValue()
            ..values.add(Value()..stringValue = 'value1')));

      mockService.nextReturn = Struct()
        ..fields['filters'] = (Value()
          ..listValue = (ListValue()..values.add(Value()..structValue = nestedStruct)));

      final result = invoke('aws:test/get:get', {});

      final data = await result.dataFuture;
      final filters = data.value['filters'] as List;
      expect(filters, hasLength(1));
      final filter = filters[0] as Map<String, dynamic>;
      expect(filter['name'], equals('my-filter'));
    });

    test('handles null values', () async {
      mockService.nextReturn = Struct()
        ..fields['optionalField'] = (Value()..nullValue = NullValue.NULL_VALUE);

      final result = invoke('aws:test/get:get', {});

      final data = await result.dataFuture;
      expect(data.value.containsKey('optionalField'), isTrue);
      expect(data.value['optionalField'], isNull);
    });

    test('handles numeric values', () async {
      mockService.nextReturn = Struct()
        ..fields['intValue'] = (Value()..numberValue = 42)
        ..fields['floatValue'] = (Value()..numberValue = 3.14);

      final result = invoke('aws:test/get:get', {});

      final data = await result.dataFuture;
      expect(data.value['intValue'], equals(42));
      expect(data.value['floatValue'], equals(3.14));
    });
  });

  group('invokeAsync', () {
    test('returns Future with result directly', () async {
      mockService.nextReturn = Struct()
        ..fields['id'] = (Value()..stringValue = 'ami-12345');

      final result = await invokeAsync(
        'aws:ec2/getAmi:getAmi',
        {'owners': Input.value(['amazon'])},
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['id'], equals('ami-12345'));
    });

    test('throws InvokeException on failures', () async {
      mockService.nextFailures = [
        provider.CheckFailure()
          ..property = 'ownerId'
          ..reason = 'must be specified',
      ];

      expect(
        () => invokeAsync('aws:ec2/getAmi:getAmi', {}),
        throwsA(isA<InvokeException>()),
      );
    });
  });

  group('invoke failures', () {
    test('throws InvokeException when provider returns failures', () async {
      mockService.nextFailures = [
        provider.CheckFailure()
          ..property = 'ownerId'
          ..reason = 'must be specified',
        provider.CheckFailure()
          ..property = 'filters'
          ..reason = 'invalid format',
      ];

      final result = invoke('aws:ec2/getAmi:getAmi', {});

      await expectLater(
        result.dataFuture,
        throwsA(
          allOf(
            isA<InvokeException>(),
            predicate<InvokeException>(
              (e) =>
                  e.token == 'aws:ec2/getAmi:getAmi' && e.failures.length == 2,
            ),
          ),
        ),
      );
    });
  });

  group('invokeTyped', () {
    test('transforms result using provided function', () async {
      mockService.nextReturn = Struct()
        ..fields['id'] = (Value()..stringValue = 'ami-12345')
        ..fields['name'] = (Value()..stringValue = 'my-ami');

      final result = invokeTyped<_TestAmiResult>(
        'aws:ec2/getAmi:getAmi',
        {},
        (map) => _TestAmiResult(
          id: map['id'] as String,
          name: map['name'] as String,
        ),
      );

      final data = await result.dataFuture;
      expect(data.value.id, equals('ami-12345'));
      expect(data.value.name, equals('my-ami'));
    });
  });

  group('invoke with Output inputs', () {
    test('waits for Output inputs to resolve', () async {
      mockService.nextReturn = Struct()
        ..fields['result'] = (Value()..stringValue = 'success');

      final outputInput = Output.of('resolved-value');
      final result = invoke(
        'test:func/get:get',
        {'inputValue': Input.output(outputInput)},
      );

      final data = await result.dataFuture;
      expect(data.isKnown, isTrue);

      expect(mockService.invokeRequests, hasLength(1));
      final request = mockService.invokeRequests.first;
      expect(
        request.args.fields['inputValue']?.stringValue,
        equals('resolved-value'),
      );
    });

    test('handles unknown Output inputs during preview', () async {
      // Reset runtime with isDryRun = true
      Runtime.reset();
      Runtime.initializeWithMonitor(
        monitor: monitor,
        project: 'test-project',
        stack: 'test-stack',
        isDryRun: true,
      );

      final unknownOutput = Output<String>.unknown();
      final result = invoke(
        'test:func/get:get',
        {'inputValue': Input.output(unknownOutput)},
      );

      final data = await result.dataFuture;
      expect(data.isKnown, isFalse);

      // The invoke should not have been called since the input is unknown
      expect(mockService.invokeRequests, isEmpty);
    });
  });

  group('invoke secret handling', () {
    test('propagates secret status from inputs', () async {
      mockService.nextReturn = Struct()
        ..fields['result'] = (Value()..stringValue = 'success');

      final secretOutput = Output.of('secret-value').asSecret();
      final result = invoke(
        'test:func/get:get',
        {'secretInput': Input.output(secretOutput)},
      );

      final data = await result.dataFuture;
      expect(data.isSecret, isTrue);
    });

    test('detects secrets in response', () async {
      // Create a response with a secret value
      final secretStruct = Struct()
        ..fields[PropertySignatures.sigKey] =
            (Value()..stringValue = PropertySignatures.secretSig)
        ..fields['value'] = (Value()..stringValue = 'secret-data');

      mockService.nextReturn = Struct()
        ..fields['password'] = (Value()..structValue = secretStruct);

      final result = invoke('test:func/get:get', {});

      final data = await result.dataFuture;
      expect(data.isSecret, isTrue);
      expect(data.value['password'], isA<SecretValue>());
    });
  });
}

/// Test class for invokeTyped tests.
class _TestAmiResult {
  final String id;
  final String name;

  _TestAmiResult({required this.id, required this.name});
}
