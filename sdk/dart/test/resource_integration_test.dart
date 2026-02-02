import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:test/test.dart';

import 'package:pulumi/src/input.dart';
import 'package:pulumi/src/output.dart';
import 'package:pulumi/src/resource.dart';
import 'package:pulumi/src/runtime/runtime.dart';

import 'mock_monitor_service.dart';

/// A test custom resource for integration testing.
class TestBucket extends CustomResource {
  late final Output<String> bucketName;
  late final Output<String> arn;

  final Map<String, Input<Object?>?> _inputs;

  TestBucket(
    String name, {
    required String bucketName,
    Map<String, String>? tags,
    ResourceOptions? options,
  })  : _inputs = {
          'bucketName': Input.value(bucketName),
          if (tags != null) 'tags': Input.value(tags),
        },
        super('aws:s3/bucket:Bucket', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => _inputs;

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    bucketName =
        Output.of(properties.fields['bucketName']?.stringValue ?? '');
    arn = Output.of(properties.fields['arn']?.stringValue ?? '');
  }
}

/// A test component resource for integration testing.
class TestComponent extends ComponentResource {
  late final Output<String> endpoint;

  TestComponent(String name, {ResourceOptions? options})
      : super('mycompany:components:TestComponent', name, options);

  void setEndpoint(String value) {
    endpoint = Output.of(value);
  }

  Future<void> registerAllOutputs() async {
    registerOutputs({'endpoint': endpoint});
  }
}

void main() {
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

  group('Resource integration with Runtime', () {
    test('CustomResource registers via gRPC when Runtime is initialized',
        () async {
      // Configure mock response
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::my-bucket';
      mockService.nextId = 'my-bucket-id-12345';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'my-bucket')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::my-bucket');

      // Initialize runtime
      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create resource
      final bucket = TestBucket(
        'my-bucket',
        bucketName: 'my-bucket',
        tags: {'env': 'test'},
      );

      // Wait for registration
      await bucket.registered;

      // Verify gRPC call was made
      expect(mockService.registeredResources, hasLength(1));

      final request = mockService.registeredResources.first;
      expect(request.type, equals('aws:s3/bucket:Bucket'));
      expect(request.name, equals('my-bucket'));
      expect(request.custom, isTrue);
      expect(request.object.fields['bucketName']?.stringValue,
          equals('my-bucket'));
      expect(request.object.fields['tags']?.structValue.fields['env']?.stringValue,
          equals('test'));

      // Verify resource properties from response
      expect(await bucket.urn.future,
          equals('urn:pulumi:stack::project::aws:s3/bucket:Bucket::my-bucket'));
      expect(await bucket.id.future, equals('my-bucket-id-12345'));
      expect(await bucket.arn.future, equals('arn:aws:s3:::my-bucket'));
    });

    test('CustomResource sends dependencies from Input outputs', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextId = 'bucket-a-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create a resource with an Output that has dependencies
      final depUrn = 'urn:pulumi:stack::project::aws:ec2/vpc:Vpc::my-vpc';
      final bucketNameOutput = Output.fromData(OutputData.known(
        'bucket-from-vpc',
        dependencies: {depUrn},
      ));

      final bucket = TestBucketWithOutputInput(
        'bucket-a',
        bucketNameOutput: bucketNameOutput,
      );

      await bucket.registered;

      // Verify dependencies were sent
      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.dependencies, contains(depUrn));
    });

    test('ComponentResource registers via gRPC with custom=false', () async {
      mockService.nextUrn =
          'urn:pulumi:stack::project::mycompany:components:TestComponent::my-component';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final component = TestComponent('my-component');
      await component.registered;

      expect(mockService.registeredResources, hasLength(1));

      final request = mockService.registeredResources.first;
      expect(request.type, equals('mycompany:components:TestComponent'));
      expect(request.name, equals('my-component'));
      expect(request.custom, isFalse);
    });

    test('ComponentResource.registerOutputs sends outputs via gRPC', () async {
      final componentUrn =
          'urn:pulumi:stack::project::mycompany:components:TestComponent::my-component';
      mockService.nextUrn = componentUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final component = TestComponent('my-component');
      await component.registered;
      component.setEndpoint('https://example.com');

      // Wait for the async registerOutputs call to complete
      await component.registerAllOutputs();

      // Give the gRPC call a moment to complete on the server side
      await Future.delayed(Duration(milliseconds: 50));

      expect(mockService.registeredOutputs, hasLength(1));

      final request = mockService.registeredOutputs.first;
      expect(request.urn, equals(componentUrn));
      expect(request.outputs.fields['endpoint']?.stringValue,
          equals('https://example.com'));
    });

    test('Resource sends parent URN when parent is specified', () async {
      mockService.nextUrn =
          'urn:pulumi:stack::project::mycompany:components:Parent::parent';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final parent = TestComponent('parent');
      await parent.registered;

      // Reset for child
      mockService.nextUrn =
          'urn:pulumi:stack::project::mycompany:components:Parent::parent::aws:s3/bucket:Bucket::child';
      mockService.nextId = 'child-id';
      mockService.nextProperties = Struct();

      final child = TestBucket(
        'child',
        bucketName: 'child-bucket',
        options: ResourceOptions(parent: parent),
      );
      await child.registered;

      // Verify parent was sent
      expect(mockService.registeredResources.last.parent,
          equals('urn:pulumi:stack::project::mycompany:components:Parent::parent'));
    });

    test('Resource sends protect flag when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::protected';
      mockService.nextId = 'protected-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'protected',
        bucketName: 'protected-bucket',
        options: ResourceOptions(protect: true),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      expect(mockService.registeredResources.first.protect, isTrue);
    });

    test('Resource sends aliases when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::new-name';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'new-name',
        bucketName: 'new-bucket',
        options: ResourceOptions(
          aliases: [
            Alias.urn('urn:pulumi:stack::project::aws:s3/bucket:Bucket::old-name'),
            Alias.name('old-name'),
            Alias.spec(
              name: 'legacy-name',
              type: 'aws:s3/bucket:Bucket',
              stack: 'old-stack',
              project: 'old-project',
            ),
            Alias.noParent(),
          ],
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));

      final request = mockService.registeredResources.first;
      expect(request.aliases, hasLength(4));

      // First alias: URN style
      expect(request.aliases[0].hasUrn(), isTrue);
      expect(request.aliases[0].urn,
          equals('urn:pulumi:stack::project::aws:s3/bucket:Bucket::old-name'));

      // Second alias: name only (spec style)
      expect(request.aliases[1].hasSpec(), isTrue);
      expect(request.aliases[1].spec.name, equals('old-name'));

      // Third alias: full spec style
      expect(request.aliases[2].hasSpec(), isTrue);
      expect(request.aliases[2].spec.name, equals('legacy-name'));
      expect(request.aliases[2].spec.type, equals('aws:s3/bucket:Bucket'));
      expect(request.aliases[2].spec.stack, equals('old-stack'));
      expect(request.aliases[2].spec.project, equals('old-project'));

      // Fourth alias: noParent style
      expect(request.aliases[3].hasSpec(), isTrue);
      expect(request.aliases[3].spec.noParent, isTrue);
    });

    test('Resource sends ignoreChanges when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: ResourceOptions(
          ignoreChanges: ['tags', 'acl'],
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.ignoreChanges, containsAll(['tags', 'acl']));
    });

    test('Resource sends replaceOnChanges when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: ResourceOptions(
          replaceOnChanges: ['bucketName', 'region'],
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.replaceOnChanges, containsAll(['bucketName', 'region']));
    });

    test('Resource sends customTimeouts when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: ResourceOptions(
          customTimeouts: CustomTimeouts(
            create: '30m',
            update: '15m',
            delete: '1h',
          ),
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.hasCustomTimeouts(), isTrue);
      expect(request.customTimeouts.create_1, equals('30m'));
      expect(request.customTimeouts.update, equals('15m'));
      expect(request.customTimeouts.delete, equals('1h'));
    });

    test('Resource sends version when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: ResourceOptions(
          version: '5.0.0',
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.version, equals('5.0.0'));
    });

    test('Resource sends pluginDownloadUrl when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: ResourceOptions(
          pluginDownloadUrl: 'https://example.com/plugins',
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.pluginDownloadURL, equals('https://example.com/plugins'));
    });

    test('Resource sends retainOnDelete when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: ResourceOptions(
          retainOnDelete: true,
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.retainOnDelete, isTrue);
    });

    test('Resource sends deletedWith when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::mycompany:components:Parent::parent';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final parent = TestComponent('parent');
      await parent.registered;
      final parentUrn = await parent.urn.future;

      // Reset for child
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::child';
      mockService.nextId = 'child-id';

      final child = TestBucket(
        'child',
        bucketName: 'child-bucket',
        options: ResourceOptions(
          deletedWith: parentUrn,
        ),
      );
      await child.registered;

      expect(mockService.registeredResources, hasLength(2));
      final request = mockService.registeredResources.last;
      expect(request.deletedWith, equals(parentUrn));
    });
  });

  group('CustomResourceOptions integration', () {
    test('CustomResource sends importId when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::imported';
      mockService.nextId = 'existing-bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'imported',
        bucketName: 'imported-bucket',
        options: CustomResourceOptions(
          importId: 'existing-bucket-id',
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.importId, equals('existing-bucket-id'));
    });

    test('CustomResource sends deleteBeforeReplace when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: CustomResourceOptions(
          deleteBeforeReplace: true,
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.deleteBeforeReplace, isTrue);
    });

    test('CustomResource sends additionalSecretOutputs when specified', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: CustomResourceOptions(
          additionalSecretOutputs: ['connectionString', 'password'],
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.additionalSecretOutputs,
          containsAll(['connectionString', 'password']));
    });

    test('CustomResource sends multiple CustomResourceOptions fields together', () async {
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucket = TestBucket(
        'bucket',
        bucketName: 'my-bucket',
        options: CustomResourceOptions(
          protect: true,
          ignoreChanges: ['tags'],
          replaceOnChanges: ['bucketName'],
          customTimeouts: CustomTimeouts(create: '10m'),
          version: '4.0.0',
          deleteBeforeReplace: true,
          additionalSecretOutputs: ['secretValue'],
          retainOnDelete: true,
        ),
      );
      await bucket.registered;

      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.protect, isTrue);
      expect(request.ignoreChanges, contains('tags'));
      expect(request.replaceOnChanges, contains('bucketName'));
      expect(request.customTimeouts.create_1, equals('10m'));
      expect(request.version, equals('4.0.0'));
      expect(request.deleteBeforeReplace, isTrue);
      expect(request.additionalSecretOutputs, contains('secretValue'));
      expect(request.retainOnDelete, isTrue);
    });
  });

  group('Resource fallback without Runtime', () {
    test('CustomResource uses mock URN when Runtime not initialized', () async {
      // Don't initialize Runtime
      expect(Runtime.isInitialized, isFalse);

      final bucket = TestBucket(
        'test-bucket',
        bucketName: 'test-bucket',
      );

      await bucket.registered;

      // Should have mock URN with the resource type and name
      final urn = await bucket.urn.future;
      expect(urn, contains('aws:s3/bucket:Bucket'));
      expect(urn, contains('test-bucket'));

      // No gRPC calls should have been made
      expect(mockService.registeredResources, isEmpty);
    });
  });
}

/// A test resource that accepts an Output as input.
class TestBucketWithOutputInput extends CustomResource {
  final Output<String> bucketNameOutput;

  TestBucketWithOutputInput(
    String name, {
    required this.bucketNameOutput,
    ResourceOptions? options,
  }) : super('aws:s3/bucket:Bucket', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => {
        'bucketName': Input.output(bucketNameOutput),
      };

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
  }
}
