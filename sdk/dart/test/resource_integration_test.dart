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
    // Output properties from a resource should include the resource's URN as dependency.
    // This enables proper dependency tracking when these outputs are used as inputs elsewhere.
    final bucketNameValue =
        properties.fields['bucketName']?.stringValue ?? '';
    final arnValue = properties.fields['arn']?.stringValue ?? '';

    // Create outputs using fromDataFuture to lazily include the URN as a dependency
    bucketName = Output.fromDataFuture(
      urn.dataFuture.then((urnData) => OutputData.known(
        bucketNameValue,
        dependencies: {...urnData.dependencies, urnData.value},
      )),
    );
    arn = Output.fromDataFuture(
      urn.dataFuture.then((urnData) => OutputData.known(
        arnValue,
        dependencies: {...urnData.dependencies, urnData.value},
      )),
    );
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

  group('ComponentResource integration', () {
    test('ComponentResource with child CustomResources receives proper parent relationship', () async {
      final parentUrn =
          'urn:pulumi:stack::project::myapp:components:MyWebApp::my-web-app';
      mockService.nextUrn = parentUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create the parent component
      final webApp = TestWebAppComponent('my-web-app');
      await webApp.registered;

      // Create child resources with parent set to the component
      mockService.nextUrn =
          'urn:pulumi:stack::project::myapp:components:MyWebApp::my-web-app::aws:s3/bucket:Bucket::app-bucket';
      mockService.nextId = 'app-bucket-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'my-app-bucket')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::my-app-bucket');

      final bucket = TestBucket(
        'app-bucket',
        bucketName: 'my-app-bucket',
        options: ResourceOptions(parent: webApp),
      );
      await bucket.registered;

      mockService.nextUrn =
          'urn:pulumi:stack::project::myapp:components:MyWebApp::my-web-app::aws:s3/bucket:Bucket::log-bucket';
      mockService.nextId = 'log-bucket-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'my-log-bucket')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::my-log-bucket');

      final logBucket = TestBucket(
        'log-bucket',
        bucketName: 'my-log-bucket',
        options: ResourceOptions(parent: webApp),
      );
      await logBucket.registered;

      // Verify all resources were registered
      expect(mockService.registeredResources, hasLength(3));

      // Verify parent component
      final componentRequest = mockService.registeredResources[0];
      expect(componentRequest.type, equals('myapp:components:MyWebApp'));
      expect(componentRequest.custom, isFalse);

      // Verify first child bucket has parent set
      final bucketRequest = mockService.registeredResources[1];
      expect(bucketRequest.type, equals('aws:s3/bucket:Bucket'));
      expect(bucketRequest.parent, equals(parentUrn));

      // Verify second child bucket has parent set
      final logBucketRequest = mockService.registeredResources[2];
      expect(logBucketRequest.type, equals('aws:s3/bucket:Bucket'));
      expect(logBucketRequest.parent, equals(parentUrn));
    });

    test('ComponentResource aggregates outputs from child resources', () async {
      final componentUrn =
          'urn:pulumi:stack::project::myapp:components:MyWebApp::my-web-app';
      mockService.nextUrn = componentUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create component
      final webApp = TestWebAppComponent('my-web-app');
      await webApp.registered;

      // Create child bucket
      mockService.nextUrn =
          'urn:pulumi:stack::project::myapp:components:MyWebApp::my-web-app::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'app-bucket')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::app-bucket');

      final bucket = TestBucket(
        'bucket',
        bucketName: 'app-bucket',
        options: ResourceOptions(parent: webApp),
      );
      await bucket.registered;

      // Set component outputs from child resources
      webApp.setBucketOutputs(bucket);

      // Register outputs to aggregate child outputs
      await webApp.registerAllOutputs();
      await Future.delayed(Duration(milliseconds: 50));

      // Verify registerOutputs was called
      expect(mockService.registeredOutputs, hasLength(1));

      final outputRequest = mockService.registeredOutputs.first;
      expect(outputRequest.urn, equals(componentUrn));

      // Verify aggregated outputs
      final outputs = outputRequest.outputs.fields;
      expect(outputs['bucketName']?.stringValue, equals('app-bucket'));
      expect(outputs['bucketArn']?.stringValue, equals('arn:aws:s3:::app-bucket'));
    });

    test('ComponentResource with multiple child resources aggregates all outputs', () async {
      final componentUrn =
          'urn:pulumi:stack::project::myapp:components:StaticWebsite::my-site';
      mockService.nextUrn = componentUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create component
      final site = TestStaticWebsiteComponent('my-site');
      await site.registered;

      // Create content bucket
      mockService.nextUrn =
          'urn:pulumi:stack::project::myapp:components:StaticWebsite::my-site::aws:s3/bucket:Bucket::content';
      mockService.nextId = 'content-bucket-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'content-bucket')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::content-bucket');

      final contentBucket = TestBucket(
        'content',
        bucketName: 'content-bucket',
        options: ResourceOptions(parent: site),
      );
      await contentBucket.registered;

      // Create logs bucket
      mockService.nextUrn =
          'urn:pulumi:stack::project::myapp:components:StaticWebsite::my-site::aws:s3/bucket:Bucket::logs';
      mockService.nextId = 'logs-bucket-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'logs-bucket')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::logs-bucket');

      final logsBucket = TestBucket(
        'logs',
        bucketName: 'logs-bucket',
        options: ResourceOptions(parent: site),
      );
      await logsBucket.registered;

      // Set component outputs from multiple children
      site.setOutputs(
        contentBucket: contentBucket,
        logsBucket: logsBucket,
        websiteUrl: 'https://my-site.example.com',
      );

      // Register aggregated outputs
      await site.registerAllOutputs();
      await Future.delayed(Duration(milliseconds: 50));

      // Verify registerOutputs was called
      expect(mockService.registeredOutputs, hasLength(1));

      final outputRequest = mockService.registeredOutputs.first;
      expect(outputRequest.urn, equals(componentUrn));

      // Verify all aggregated outputs
      final outputs = outputRequest.outputs.fields;
      expect(outputs['contentBucketName']?.stringValue, equals('content-bucket'));
      expect(outputs['logsBucketName']?.stringValue, equals('logs-bucket'));
      expect(outputs['websiteUrl']?.stringValue, equals('https://my-site.example.com'));
    });

    test('Nested ComponentResources maintain proper hierarchy', () async {
      final outerUrn =
          'urn:pulumi:stack::project::myapp:components:Outer::outer';
      mockService.nextUrn = outerUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create outer component
      final outer = TestComponent('outer');
      await outer.registered;

      // Create inner component as child of outer
      final innerUrn =
          'urn:pulumi:stack::project::myapp:components:Outer::outer::myapp:components:Inner::inner';
      mockService.nextUrn = innerUrn;

      final inner = TestInnerComponent(
        'inner',
        options: ResourceOptions(parent: outer),
      );
      await inner.registered;

      // Create custom resource as child of inner
      mockService.nextUrn =
          'urn:pulumi:stack::project::myapp:components:Outer::outer::myapp:components:Inner::inner::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'nested-bucket');

      final bucket = TestBucket(
        'bucket',
        bucketName: 'nested-bucket',
        options: ResourceOptions(parent: inner),
      );
      await bucket.registered;

      // Verify hierarchy
      expect(mockService.registeredResources, hasLength(3));

      // Outer has no parent
      expect(mockService.registeredResources[0].parent, isEmpty);

      // Inner has outer as parent
      expect(mockService.registeredResources[1].parent, equals(outerUrn));

      // Bucket has inner as parent
      expect(mockService.registeredResources[2].parent, equals(innerUrn));
    });

    test('ComponentResource registerOutputs waits for registration before sending', () async {
      final componentUrn =
          'urn:pulumi:stack::project::mycompany:components:TestComponent::delayed';
      mockService.nextUrn = componentUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final component = TestComponent('delayed');
      component.setEndpoint('https://delayed.example.com');

      // Call registerOutputs immediately (before awaiting registered)
      // It should internally wait for registration
      final registerFuture = component.registerAllOutputs();

      // At this point, registration might not be complete
      // Wait for both registration and registerOutputs to complete
      await component.registered;
      await registerFuture;
      await Future.delayed(Duration(milliseconds: 50));

      // Verify both registration and outputs were sent
      expect(mockService.registeredResources, hasLength(1));
      expect(mockService.registeredOutputs, hasLength(1));
      expect(mockService.registeredOutputs.first.urn, equals(componentUrn));
    });

    test('ComponentResource with no outputs can skip registerOutputs', () async {
      final componentUrn =
          'urn:pulumi:stack::project::mycompany:components:TestComponent::no-outputs';
      mockService.nextUrn = componentUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final component = TestComponent('no-outputs');
      await component.registered;

      // Component can exist without calling registerOutputs
      expect(mockService.registeredResources, hasLength(1));
      expect(mockService.registeredResources.first.custom, isFalse);

      // No outputs registered
      expect(mockService.registeredOutputs, isEmpty);
    });

    test('ComponentResource registerOutputs with empty map sends empty outputs', () async {
      final componentUrn =
          'urn:pulumi:stack::project::mycompany:components:EmptyOutputs::empty';
      mockService.nextUrn = componentUrn;

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final component = TestEmptyOutputsComponent('empty');
      await component.registered;
      await component.registerOutputs({});
      await Future.delayed(Duration(milliseconds: 50));

      expect(mockService.registeredOutputs, hasLength(1));
      expect(mockService.registeredOutputs.first.outputs.fields, isEmpty);
    });
  });

  group('Output dependency tracking across resources', () {
    test('Dependencies from Output.apply are preserved and sent to monitor', () async {
      // Set up resource A
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create resource A
      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Create a transformed Output that preserves dependencies
      final transformedArn = bucketA.arn.apply((arn) => 'processed-$arn');

      // Set up resource B that uses the transformed output
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-b';
      mockService.nextId = 'bucket-b-id';
      mockService.nextProperties = Struct();

      final bucketB = TestBucketWithOutputInput(
        'bucket-b',
        bucketNameOutput: transformedArn,
      );
      await bucketB.registered;

      // Verify resource B has resource A as a dependency
      expect(mockService.registeredResources, hasLength(2));
      final requestB = mockService.registeredResources.last;
      expect(requestB.dependencies, contains(urnA));
    });

    test('Dependencies from Output.all are combined and sent to monitor', () async {
      // Set up resource A
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Set up resource B
      final urnB = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-b';
      mockService.nextUrn = urnB;
      mockService.nextId = 'bucket-b-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-b');

      final bucketB = TestBucket('bucket-b', bucketName: 'bucket-b');
      await bucketB.registered;

      // Combine outputs from both resources using Output.all
      final combined = Output.all([bucketA.bucketName, bucketB.bucketName])
          .apply((names) => names.join('-'));

      // Set up resource C that uses the combined output
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-c';
      mockService.nextId = 'bucket-c-id';
      mockService.nextProperties = Struct();

      final bucketC = TestBucketWithOutputInput(
        'bucket-c',
        bucketNameOutput: combined,
      );
      await bucketC.registered;

      // Verify resource C has both A and B as dependencies
      expect(mockService.registeredResources, hasLength(3));
      final requestC = mockService.registeredResources.last;
      expect(requestC.dependencies, contains(urnA));
      expect(requestC.dependencies, contains(urnB));
    });

    test('Dependencies from Output.tuple2 are merged and sent to monitor', () async {
      // Set up resource A
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Set up resource B
      final urnB = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-b';
      mockService.nextUrn = urnB;
      mockService.nextId = 'bucket-b-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-b')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::bucket-b');

      final bucketB = TestBucket('bucket-b', bucketName: 'bucket-b');
      await bucketB.registered;

      // Use tuple2 to combine outputs
      final tupleOutput = Output.tuple2(bucketA.arn, bucketB.arn)
          .apply((tuple) => '${tuple.$1}|${tuple.$2}');

      // Set up resource C
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-c';
      mockService.nextId = 'bucket-c-id';
      mockService.nextProperties = Struct();

      final bucketC = TestBucketWithOutputInput(
        'bucket-c',
        bucketNameOutput: tupleOutput,
      );
      await bucketC.registered;

      // Verify resource C has both A and B as dependencies
      expect(mockService.registeredResources, hasLength(3));
      final requestC = mockService.registeredResources.last;
      expect(requestC.dependencies, contains(urnA));
      expect(requestC.dependencies, contains(urnB));
    });

    test('Chained Output.apply operations accumulate dependencies', () async {
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Chain multiple apply operations
      final chainedOutput = bucketA.bucketName
          .apply((name) => 'first-$name')
          .apply((name) => 'second-$name')
          .apply((name) => 'third-$name');

      // Set up resource B
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-b';
      mockService.nextId = 'bucket-b-id';
      mockService.nextProperties = Struct();

      final bucketB = TestBucketWithOutputInput(
        'bucket-b',
        bucketNameOutput: chainedOutput,
      );
      await bucketB.registered;

      // Verify dependencies are preserved through the chain
      expect(mockService.registeredResources, hasLength(2));
      final requestB = mockService.registeredResources.last;
      expect(requestB.dependencies, contains(urnA));
    });

    test('Explicit dependsOn combined with Output dependencies', () async {
      // Set up resource A
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Set up resource B (will be an explicit dependency)
      final urnB = 'urn:pulumi:stack::project::mycompany:components:TestComponent::component-b';
      mockService.nextUrn = urnB;

      final componentB = TestComponent('component-b');
      await componentB.registered;

      // Set up resource C with both Output dependency (from A) and explicit dependsOn (B)
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-c';
      mockService.nextId = 'bucket-c-id';
      mockService.nextProperties = Struct();

      final bucketC = TestBucketWithOutputInputAndOptions(
        'bucket-c',
        bucketNameOutput: bucketA.bucketName,
        options: ResourceOptions(dependsOn: [componentB]),
      );
      await bucketC.registered;

      // Verify both explicit and implicit dependencies are sent
      expect(mockService.registeredResources, hasLength(3));
      final requestC = mockService.registeredResources.last;
      expect(requestC.dependencies, contains(urnA));
      expect(requestC.dependencies, contains(urnB));
    });

    test('Output.withDependencies adds dependencies that are sent to monitor', () async {
      final depUrn1 = 'urn:pulumi:stack::project::aws:ec2/vpc:Vpc::vpc-1';
      final depUrn2 = 'urn:pulumi:stack::project::aws:ec2/subnet:Subnet::subnet-1';

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      // Create an Output with explicit dependencies via withDependencies
      final outputWithDeps = Output.of('my-value')
          .withDependencies({depUrn1})
          .withDependencies({depUrn2});

      // Set up resource that uses this output
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket';
      mockService.nextId = 'bucket-id';
      mockService.nextProperties = Struct();

      final bucket = TestBucketWithOutputInput(
        'bucket',
        bucketNameOutput: outputWithDeps,
      );
      await bucket.registered;

      // Verify both dependencies are sent
      expect(mockService.registeredResources, hasLength(1));
      final request = mockService.registeredResources.first;
      expect(request.dependencies, contains(depUrn1));
      expect(request.dependencies, contains(depUrn2));
    });

    test('Dependencies flow through nested Output in map values', () async {
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Set up resource B with a map containing an Output value
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-b';
      mockService.nextId = 'bucket-b-id';
      mockService.nextProperties = Struct();

      final bucketB = TestBucketWithMapInput(
        'bucket-b',
        bucketName: 'bucket-b',
        tags: {
          'source': bucketA.bucketName, // Output value nested in map
        },
      );
      await bucketB.registered;

      // Verify dependencies from nested Outputs are tracked
      expect(mockService.registeredResources, hasLength(2));
      final requestB = mockService.registeredResources.last;
      expect(requestB.dependencies, contains(urnA));
    });

    test('Dependencies flow through nested Output in list values', () async {
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Set up resource B with a list containing an Output value
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-b';
      mockService.nextId = 'bucket-b-id';
      mockService.nextProperties = Struct();

      final bucketB = TestBucketWithListInput(
        'bucket-b',
        bucketName: 'bucket-b',
        prefixes: [bucketA.bucketName, Output.of('static-prefix')],
      );
      await bucketB.registered;

      // Verify dependencies from nested Outputs are tracked
      expect(mockService.registeredResources, hasLength(2));
      final requestB = mockService.registeredResources.last;
      expect(requestB.dependencies, contains(urnA));
    });

    test('Resource serialized as input adds its URN as dependency', () async {
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Set up resource B that takes resource A as input directly
      mockService.nextUrn = 'urn:pulumi:stack::project::myapp:LogConfig::log-config';
      mockService.nextId = 'log-config-id';
      mockService.nextProperties = Struct();

      final logConfig = TestLogConfigResource(
        'log-config',
        bucket: bucketA,
      );
      await logConfig.registered;

      // Verify resource A's URN is included as a dependency
      expect(mockService.registeredResources, hasLength(2));
      final requestB = mockService.registeredResources.last;
      expect(requestB.dependencies, contains(urnA));
    });

    test('Multiple resources in a dependency chain preserve transitive relationships', () async {
      // Create resource A
      final urnA = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-a';
      mockService.nextUrn = urnA;
      mockService.nextId = 'bucket-a-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-a');

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      final bucketA = TestBucket('bucket-a', bucketName: 'bucket-a');
      await bucketA.registered;

      // Create resource B that depends on A
      final urnB = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-b';
      mockService.nextUrn = urnB;
      mockService.nextId = 'bucket-b-id';
      mockService.nextProperties = Struct()
        ..fields['bucketName'] = (Value()..stringValue = 'bucket-b')
        ..fields['arn'] = (Value()..stringValue = 'arn:aws:s3:::bucket-b');

      final bucketB = TestBucketWithOutputInput(
        'bucket-b',
        bucketNameOutput: bucketA.bucketName,
      );
      await bucketB.registered;

      // Create resource C that depends on B's output (which derived from A)
      // Note: B's arn output should have B's URN as dependency
      mockService.nextUrn = 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::bucket-c';
      mockService.nextId = 'bucket-c-id';
      mockService.nextProperties = Struct();

      final bucketC = TestBucketWithOutputInput(
        'bucket-c',
        bucketNameOutput: bucketB.arn,
      );
      await bucketC.registered;

      // Verify:
      // - B depends on A
      // - C depends on B (not necessarily A, since B's outputs come from the response)
      expect(mockService.registeredResources, hasLength(3));

      final requestB = mockService.registeredResources[1];
      expect(requestB.dependencies, contains(urnA));

      final requestC = mockService.registeredResources[2];
      expect(requestC.dependencies, contains(urnB));
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
  late final Output<String> arn;

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
    final arnValue = properties.fields['arn']?.stringValue ?? '';
    // Output properties include the resource's URN as dependency
    arn = Output.fromDataFuture(
      urn.dataFuture.then((urnData) => OutputData.known(
        arnValue,
        dependencies: {...urnData.dependencies, urnData.value},
      )),
    );
  }
}

/// A test web application component that aggregates child resource outputs.
class TestWebAppComponent extends ComponentResource {
  late final Output<String> bucketName;
  late final Output<String> bucketArn;

  TestWebAppComponent(String name, {ResourceOptions? options})
      : super('myapp:components:MyWebApp', name, options);

  void setBucketOutputs(TestBucket bucket) {
    bucketName = bucket.bucketName;
    bucketArn = bucket.arn;
  }

  Future<void> registerAllOutputs() async {
    await registerOutputs({
      'bucketName': bucketName,
      'bucketArn': bucketArn,
    });
  }
}

/// A test static website component that aggregates multiple child outputs.
class TestStaticWebsiteComponent extends ComponentResource {
  late final Output<String> contentBucketName;
  late final Output<String> logsBucketName;
  late final Output<String> websiteUrl;

  TestStaticWebsiteComponent(String name, {ResourceOptions? options})
      : super('myapp:components:StaticWebsite', name, options);

  void setOutputs({
    required TestBucket contentBucket,
    required TestBucket logsBucket,
    required String websiteUrl,
  }) {
    contentBucketName = contentBucket.bucketName;
    logsBucketName = logsBucket.bucketName;
    this.websiteUrl = Output.of(websiteUrl);
  }

  Future<void> registerAllOutputs() async {
    await registerOutputs({
      'contentBucketName': contentBucketName,
      'logsBucketName': logsBucketName,
      'websiteUrl': websiteUrl,
    });
  }
}

/// A test inner component for testing nested component hierarchies.
class TestInnerComponent extends ComponentResource {
  TestInnerComponent(String name, {ResourceOptions? options})
      : super('myapp:components:Inner', name, options);
}

/// A test component that can register empty outputs.
class TestEmptyOutputsComponent extends ComponentResource {
  TestEmptyOutputsComponent(String name, {ResourceOptions? options})
      : super('mycompany:components:EmptyOutputs', name, options);
}

/// A test resource that accepts an Output as input with ResourceOptions support.
class TestBucketWithOutputInputAndOptions extends CustomResource {
  final Output<String> bucketNameOutput;

  TestBucketWithOutputInputAndOptions(
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

/// A test resource that accepts a map with Output values for tags.
class TestBucketWithMapInput extends CustomResource {
  final String bucketName;
  final Map<String, dynamic> tags;

  TestBucketWithMapInput(
    String name, {
    required this.bucketName,
    required this.tags,
    ResourceOptions? options,
  }) : super('aws:s3/bucket:Bucket', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => {
        'bucketName': Input.value(bucketName),
        'tags': Input.value(tags),
      };

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
  }
}

/// A test resource that accepts a list with Output values.
class TestBucketWithListInput extends CustomResource {
  final String bucketName;
  final List<Output<String>> prefixes;

  TestBucketWithListInput(
    String name, {
    required this.bucketName,
    required this.prefixes,
    ResourceOptions? options,
  }) : super('aws:s3/bucket:Bucket', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => {
        'bucketName': Input.value(bucketName),
        'prefixes': Input.value(prefixes),
      };

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
  }
}

/// A test resource that accepts another resource as input.
class TestLogConfigResource extends CustomResource {
  final CustomResource bucket;

  TestLogConfigResource(
    String name, {
    required this.bucket,
    ResourceOptions? options,
  }) : super('myapp:LogConfig', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => {
        'bucket': Input.value(bucket),
      };

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
  }
}
