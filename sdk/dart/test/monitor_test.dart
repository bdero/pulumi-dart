import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as empty;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:test/test.dart';

import 'package:pulumi/src/proto/pulumi/provider.pb.dart' as provider;
import 'package:pulumi/src/proto/pulumi/resource.pb.dart' as resource;
import 'package:pulumi/src/proto/pulumi/resource.pbgrpc.dart' as resource_grpc;
import 'package:pulumi/src/runtime/monitor.dart';

/// A mock ResourceMonitor service for testing.
class MockResourceMonitorService extends resource_grpc.ResourceMonitorServiceBase {
  final List<resource.RegisterResourceRequest> registeredResources = [];
  final List<resource.RegisterResourceOutputsRequest> registeredOutputs = [];
  final List<resource.ReadResourceRequest> readRequests = [];
  final List<resource.ResourceInvokeRequest> invokeRequests = [];
  final List<resource.ResourceCallRequest> callRequests = [];
  final List<resource.SupportsFeatureRequest> featureRequests = [];

  final Map<String, bool> supportedFeatures = {};
  bool signalAndWaitCalled = false;

  // Configurable responses
  String nextUrn = 'urn:pulumi:stack::project::type::name';
  String nextId = 'test-id-123';
  Struct nextProperties = Struct();

  @override
  Future<resource.SupportsFeatureResponse> supportsFeature(
    ServiceCall call,
    resource.SupportsFeatureRequest request,
  ) async {
    featureRequests.add(request);
    return resource.SupportsFeatureResponse()
      ..hasSupport = supportedFeatures[request.id] ?? false;
  }

  @override
  Future<resource.RegisterResourceResponse> registerResource(
    ServiceCall call,
    resource.RegisterResourceRequest request,
  ) async {
    registeredResources.add(request);
    return resource.RegisterResourceResponse()
      ..urn = nextUrn
      ..id = nextId
      ..object = nextProperties;
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
    readRequests.add(request);
    return resource.ReadResourceResponse()
      ..urn = nextUrn
      ..properties = nextProperties;
  }

  @override
  Future<provider.InvokeResponse> invoke(
    ServiceCall call,
    resource.ResourceInvokeRequest request,
  ) async {
    invokeRequests.add(request);
    return provider.InvokeResponse()..return_1 = nextProperties;
  }

  @override
  Future<provider.CallResponse> call(
    ServiceCall call,
    resource.ResourceCallRequest request,
  ) async {
    callRequests.add(request);
    return provider.CallResponse()..return_1 = nextProperties;
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
    signalAndWaitCalled = true;
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
  });

  tearDown(() async {
    await monitor.shutdown();
    await server.shutdown();
  });

  group('ResourceMonitor', () {
    group('supportsFeature', () {
      test('returns true when feature is supported', () async {
        mockService.supportedFeatures['secrets'] = true;

        final result = await monitor.supportsFeature('secrets');

        expect(result, isTrue);
        expect(mockService.featureRequests, hasLength(1));
        expect(mockService.featureRequests.first.id, equals('secrets'));
      });

      test('returns false when feature is not supported', () async {
        final result = await monitor.supportsFeature('unknown-feature');

        expect(result, isFalse);
        expect(mockService.featureRequests, hasLength(1));
        expect(mockService.featureRequests.first.id, equals('unknown-feature'));
      });
    });

    group('registerResource', () {
      test('sends required fields correctly', () async {
        mockService.nextUrn = 'urn:pulumi:test::proj::aws:s3/bucket:Bucket::my-bucket';
        mockService.nextId = 'my-bucket-id';

        final response = await monitor.registerResource(
          type: 'aws:s3/bucket:Bucket',
          name: 'my-bucket',
        );

        expect(response.urn, equals('urn:pulumi:test::proj::aws:s3/bucket:Bucket::my-bucket'));
        expect(response.id, equals('my-bucket-id'));

        expect(mockService.registeredResources, hasLength(1));
        final request = mockService.registeredResources.first;
        expect(request.type, equals('aws:s3/bucket:Bucket'));
        expect(request.name, equals('my-bucket'));
        expect(request.custom, isTrue);  // default
        expect(request.protect, isFalse);  // default
      });

      test('sends optional fields correctly', () async {
        final inputs = Struct()
          ..fields['bucket'] = (Value()..stringValue = 'test-bucket');

        await monitor.registerResource(
          type: 'aws:s3/bucket:Bucket',
          name: 'my-bucket',
          custom: true,
          inputs: inputs,
          parent: 'urn:pulumi:stack::proj::parent::parent-name',
          protect: true,
          dependencies: ['urn:dep1', 'urn:dep2'],
          providerRef: 'aws::default',
          version: '5.0.0',
          deleteBeforeReplace: true,
          retainOnDelete: true,
          ignoreChanges: ['tags'],
          replaceOnChanges: ['bucket'],
          importId: 'existing-bucket-id',
        );

        expect(mockService.registeredResources, hasLength(1));
        final request = mockService.registeredResources.first;

        expect(request.object.fields['bucket']?.stringValue, equals('test-bucket'));
        expect(request.parent, equals('urn:pulumi:stack::proj::parent::parent-name'));
        expect(request.protect, isTrue);
        expect(request.dependencies, containsAll(['urn:dep1', 'urn:dep2']));
        expect(request.provider, equals('aws::default'));
        expect(request.version, equals('5.0.0'));
        expect(request.deleteBeforeReplace, isTrue);
        expect(request.retainOnDelete, isTrue);
        expect(request.ignoreChanges, contains('tags'));
        expect(request.replaceOnChanges, contains('bucket'));
        expect(request.importId, equals('existing-bucket-id'));
      });

      test('handles component resource (custom=false)', () async {
        await monitor.registerResource(
          type: 'my:component:WebApp',
          name: 'my-webapp',
          custom: false,
        );

        final request = mockService.registeredResources.first;
        expect(request.custom, isFalse);
      });
    });

    group('registerResourceOutputs', () {
      test('sends urn and outputs correctly', () async {
        final outputs = Struct()
          ..fields['bucketName'] = (Value()..stringValue = 'my-bucket')
          ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::my-bucket');

        await monitor.registerResourceOutputs(
          urn: 'urn:pulumi:stack::proj::my:component::name',
          outputs: outputs,
        );

        expect(mockService.registeredOutputs, hasLength(1));
        final request = mockService.registeredOutputs.first;
        expect(request.urn, equals('urn:pulumi:stack::proj::my:component::name'));
        expect(request.outputs.fields['bucketName']?.stringValue, equals('my-bucket'));
        expect(request.outputs.fields['arn']?.stringValue, equals('arn:aws:s3:::my-bucket'));
      });
    });

    group('readResource', () {
      test('sends required fields correctly', () async {
        final response = await monitor.readResource(
          type: 'aws:s3/bucket:Bucket',
          name: 'imported-bucket',
          id: 'existing-bucket-id',
        );

        expect(response.urn, equals(mockService.nextUrn));

        expect(mockService.readRequests, hasLength(1));
        final request = mockService.readRequests.first;
        expect(request.type, equals('aws:s3/bucket:Bucket'));
        expect(request.name, equals('imported-bucket'));
        expect(request.id, equals('existing-bucket-id'));
      });

      test('sends optional fields correctly', () async {
        final inputs = Struct()
          ..fields['acl'] = (Value()..stringValue = 'private');

        await monitor.readResource(
          type: 'aws:s3/bucket:Bucket',
          name: 'imported-bucket',
          id: 'existing-bucket-id',
          parent: 'urn:parent',
          providerRef: 'aws::default',
          version: '5.0.0',
          inputs: inputs,
          dependencies: ['urn:dep1'],
          additionalSecretOutputs: ['password'],
        );

        final request = mockService.readRequests.first;
        expect(request.parent, equals('urn:parent'));
        expect(request.provider, 'aws::default');
        expect(request.version, equals('5.0.0'));
        expect(request.properties.fields['acl']?.stringValue, equals('private'));
        expect(request.dependencies, contains('urn:dep1'));
        expect(request.additionalSecretOutputs, contains('password'));
      });
    });

    group('invoke', () {
      test('sends token and args correctly', () async {
        final args = Struct()
          ..fields['owners'] = (Value()
            ..listValue = (ListValue()
              ..values.add(Value()..stringValue = 'amazon')));

        final response = await monitor.invoke(
          token: 'aws:ec2/getAmi:getAmi',
          args: args,
        );

        expect(response, isNotNull);

        expect(mockService.invokeRequests, hasLength(1));
        final request = mockService.invokeRequests.first;
        expect(request.tok, equals('aws:ec2/getAmi:getAmi'));
        expect(request.args.fields['owners']?.listValue.values.first.stringValue,
            equals('amazon'));
      });

      test('sends optional fields correctly', () async {
        await monitor.invoke(
          token: 'aws:ec2/getAmi:getAmi',
          providerRef: 'aws::us-east-1',
          version: '5.0.0',
          pluginDownloadUrl: 'https://example.com/plugins',
        );

        final request = mockService.invokeRequests.first;
        expect(request.provider, 'aws::us-east-1');
        expect(request.version, equals('5.0.0'));
        expect(request.pluginDownloadURL, equals('https://example.com/plugins'));
      });
    });

    group('call', () {
      test('sends token and args correctly', () async {
        final args = Struct()
          ..fields['replicas'] = (Value()..numberValue = 3);

        final response = await monitor.call(
          token: 'kubernetes:apps/v1:Deployment/scale',
          args: args,
        );

        expect(response, isNotNull);

        expect(mockService.callRequests, hasLength(1));
        final request = mockService.callRequests.first;
        expect(request.tok, equals('kubernetes:apps/v1:Deployment/scale'));
        expect(request.args.fields['replicas']?.numberValue, equals(3));
      });

      test('sends optional fields correctly', () async {
        await monitor.call(
          token: 'kubernetes:apps/v1:Deployment/scale',
          providerRef: 'kubernetes::default',
          version: '4.0.0',
        );

        final request = mockService.callRequests.first;
        expect(request.provider, 'kubernetes::default');
        expect(request.version, equals('4.0.0'));
      });
    });

    group('signalAndWaitForShutdown', () {
      test('calls the server method', () async {
        await monitor.signalAndWaitForShutdown();

        expect(mockService.signalAndWaitCalled, isTrue);
      });
    });

    group('connection handling', () {
      test('can create monitor from existing channel', () async {
        final channel = ClientChannel(
          'localhost',
          port: port,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        );

        final channelMonitor = ResourceMonitor.fromChannel(channel);

        try {
          mockService.supportedFeatures['test'] = true;
          final result = await channelMonitor.supportsFeature('test');
          expect(result, isTrue);
        } finally {
          await channelMonitor.shutdown();
        }
      });

      test('shutdown closes the channel', () async {
        // Create a fresh monitor to test shutdown
        final testMonitor = ResourceMonitor.connect('localhost:$port');

        // Verify it works
        await testMonitor.supportsFeature('test');

        // Shutdown
        await testMonitor.shutdown();

        // Further calls should fail (channel is closed)
        expect(
          () => testMonitor.supportsFeature('test'),
          throwsA(isA<GrpcError>()),
        );
      });
    });
  });

  group('ResourceMonitor address parsing', () {
    test('parses host:port format', () async {
      // Using the already-started server
      final m = ResourceMonitor.connect('localhost:$port');
      try {
        await m.supportsFeature('test');
        // If we get here, connection worked
      } finally {
        await m.shutdown();
      }
    });
  });
}
