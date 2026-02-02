import 'dart:async';

import 'package:test/test.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:pulumi/src/resource.dart';
import 'package:pulumi/src/options.dart';
import 'package:pulumi/src/output.dart';
import 'package:pulumi/src/input.dart';

/// A minimal test custom resource implementation.
class TestCustomResource extends CustomResource {
  final Map<String, Input<Object?>?> _inputs;

  late final Output<String> testOutput;

  TestCustomResource(
    String name, {
    Map<String, Input<Object?>?>? inputs,
    ResourceOptions? opts,
  })  : _inputs = inputs ?? {},
        super('test:resource:TestResource', name, opts);

  @override
  Map<String, Input<Object?>?> get inputs => _inputs;

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    testOutput =
        Output.of(properties.fields['testOutput']?.stringValue ?? 'default');
  }
}

/// A minimal test component resource implementation.
class TestComponentResource extends ComponentResource {
  late final Output<String> computedValue;

  TestComponentResource(String name, [ResourceOptions? opts])
      : super('test:component:TestComponent', name, opts);

  void setComputedValue(String value) {
    computedValue = Output.of(value);
  }
}

void main() {
  group('Resource', () {
    test('has correct type and name', () {
      final resource = TestCustomResource('my-resource');
      expect(resource.type, equals('test:resource:TestResource'));
      expect(resource.name, equals('my-resource'));
    });

    test('registered future completes', () async {
      final resource = TestCustomResource('my-resource');
      await resource.registered;
      // Should complete without error
    });

    test('urn is available after registration', () async {
      final resource = TestCustomResource('my-resource');
      await resource.registered;

      final urnValue = await resource.urn.future;
      expect(urnValue, contains('test:resource:TestResource'));
      expect(urnValue, contains('my-resource'));
    });

    test('options are preserved', () {
      final parent = TestCustomResource('parent');
      final opts = ResourceOptions(
        parent: parent,
        protect: true,
        retainOnDelete: true,
      );

      final child = TestCustomResource('child', opts: opts);

      expect(child.options?.parent, equals(parent));
      expect(child.options?.protect, isTrue);
      expect(child.options?.retainOnDelete, isTrue);
    });
  });

  group('CustomResource', () {
    test('id is available after registration', () async {
      final resource = TestCustomResource('my-resource');
      await resource.registered;

      // ID should be set (empty string from mock implementation)
      final idValue = await resource.id.future;
      expect(idValue, isA<String>());
    });

    test('processOutputs is called during registration', () async {
      final resource = TestCustomResource('my-resource');
      await resource.registered;

      // testOutput should be set by processOutputs
      final outputValue = await resource.testOutput.future;
      expect(outputValue, equals('default'));
    });

    test('inputs are accessible', () {
      final resource = TestCustomResource(
        'my-resource',
        inputs: {
          'prop1': Input.value('value1'),
          'prop2': Input.value(42),
        },
      );

      expect(resource.inputs, hasLength(2));
      expect(resource.inputs['prop1'], isA<InputValue<Object?>>());
      expect(resource.inputs['prop2'], isA<InputValue<Object?>>());
    });
  });

  group('ComponentResource', () {
    test('has empty inputs', () {
      final component = TestComponentResource('my-component');
      expect(component.inputs, isEmpty);
    });

    test('urn is available after registration', () async {
      final component = TestComponentResource('my-component');
      await component.registered;

      final urnValue = await component.urn.future;
      expect(urnValue, contains('test:component:TestComponent'));
      expect(urnValue, contains('my-component'));
    });

    test('registerOutputs can be called after registration', () async {
      final component = TestComponentResource('my-component');
      await component.registered;

      component.setComputedValue('computed');

      // Should not throw
      await component.registerOutputs({
        'value': component.computedValue,
      });
    });
  });

  group('Resource hierarchy', () {
    test('child resource includes parent in URN', () async {
      final parent = TestCustomResource('parent-resource');
      await parent.registered;

      final child = TestCustomResource(
        'child-resource',
        opts: ResourceOptions(parent: parent),
      );
      await child.registered;

      final parentUrn = await parent.urn.future;
      final childUrn = await child.urn.future;

      // Child URN should be based on parent URN
      expect(childUrn, startsWith(parentUrn));
    });

    test('deeply nested hierarchy works', () async {
      final grandparent = TestCustomResource('grandparent');
      await grandparent.registered;

      final parent = TestCustomResource(
        'parent',
        opts: ResourceOptions(parent: grandparent),
      );
      await parent.registered;

      final child = TestCustomResource(
        'child',
        opts: ResourceOptions(parent: parent),
      );
      await child.registered;

      final childUrn = await child.urn.future;
      expect(childUrn, contains('grandparent'));
    });
  });

  group('Dependency collection', () {
    test('collects dependencies from Input.output', () async {
      final dependency = TestCustomResource('dependency');
      await dependency.registered;

      // Create output with dependency
      final output = Output.of('value').withDependencies({
        await dependency.urn.future,
      });

      final resource = TestCustomResource(
        'dependent',
        inputs: {
          'prop': Input.output(output),
        },
      );
      await resource.registered;

      // The resource URN should contain the dependency information
      final urnData = await resource.urn.dataFuture;
      expect(urnData.dependencies, contains(await dependency.urn.future));
    });

    test('collects explicit dependencies from dependsOn', () async {
      final dep1 = TestCustomResource('dep1');
      final dep2 = TestCustomResource('dep2');
      await Future.wait([dep1.registered, dep2.registered]);

      final resource = TestCustomResource(
        'dependent',
        opts: ResourceOptions(dependsOn: [dep1, dep2]),
      );
      await resource.registered;

      final urnData = await resource.urn.dataFuture;
      expect(urnData.dependencies, contains(await dep1.urn.future));
      expect(urnData.dependencies, contains(await dep2.urn.future));
    });

    test('handles nested Output values in maps', () async {
      final dependency = TestCustomResource('dependency');
      await dependency.registered;

      final nestedOutput = Output.of('nested').withDependencies({
        await dependency.urn.future,
      });

      final resource = TestCustomResource(
        'dependent',
        inputs: {
          'tags': Input.value({
            'key': nestedOutput,
          }),
        },
      );
      await resource.registered;

      final urnData = await resource.urn.dataFuture;
      expect(urnData.dependencies, contains(await dependency.urn.future));
    });

    test('handles nested Output values in lists', () async {
      final dependency = TestCustomResource('dependency');
      await dependency.registered;

      final nestedOutput = Output.of('item').withDependencies({
        await dependency.urn.future,
      });

      final resource = TestCustomResource(
        'dependent',
        inputs: {
          'items': Input.value([nestedOutput, 'plain']),
        },
      );
      await resource.registered;

      final urnData = await resource.urn.dataFuture;
      expect(urnData.dependencies, contains(await dependency.urn.future));
    });

    test('handles Input.future', () async {
      final resource = TestCustomResource(
        'my-resource',
        inputs: {
          'asyncProp': Input.future(Future.value('async-value')),
        },
      );
      await resource.registered;

      // Should complete without error
      expect(await resource.urn.future, isNotEmpty);
    });

    test('handles null inputs', () async {
      final resource = TestCustomResource(
        'my-resource',
        inputs: {
          'nullProp': null,
          'validProp': Input.value('valid'),
        },
      );
      await resource.registered;

      // Should complete without error
      expect(await resource.urn.future, isNotEmpty);
    });
  });

  group('ResourceOptions', () {
    test('default values are correct', () {
      const opts = ResourceOptions();
      expect(opts.parent, isNull);
      expect(opts.protect, isFalse);
      expect(opts.dependsOn, isEmpty);
      expect(opts.provider, isNull);
      expect(opts.retainOnDelete, isFalse);
      expect(opts.deletedWith, isNull);
    });

    test('all properties can be set', () {
      final parent = TestCustomResource('parent');
      final dep = TestCustomResource('dep');

      final opts = ResourceOptions(
        parent: parent,
        protect: true,
        dependsOn: [dep],
        provider: 'custom-provider',
        retainOnDelete: true,
        deletedWith: 'urn:other:resource',
      );

      expect(opts.parent, equals(parent));
      expect(opts.protect, isTrue);
      expect(opts.dependsOn, contains(dep));
      expect(opts.provider, equals('custom-provider'));
      expect(opts.retainOnDelete, isTrue);
      expect(opts.deletedWith, equals('urn:other:resource'));
    });
  });

  group('Error handling', () {
    test('failing futures in inputs are handled gracefully', () async {
      // Create a resource with a failing future input
      // The error in dependency collection is caught and registration completes
      final failingResource = _FailingResource('failing');

      // Registration should complete (errors in futures are caught during dep collection)
      await failingResource.registered;
      expect(await failingResource.urn.future, isNotEmpty);
    });

    test('explicit dependency on failed resource propagates error', () async {
      // Create a resource with a dependency on a resource whose input future fails
      final failingDep = _FailingDependencyResource('failing-dep');

      // The registered future should fail because we await the failing future
      await expectLater(
        failingDep.registered,
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Concurrent resources', () {
    test('multiple resources can register concurrently', () async {
      final resources = List.generate(
        10,
        (i) => TestCustomResource('resource-$i'),
      );

      // Wait for all to complete
      await Future.wait(resources.map((r) => r.registered));

      // All should have unique URNs
      final urns = await Future.wait(resources.map((r) => r.urn.future));
      expect(urns.toSet().length, equals(10));
    });

    test('parent-child creation order is handled correctly', () async {
      // Create parent and child simultaneously
      final parent = TestCustomResource('parent');
      final child = TestCustomResource(
        'child',
        opts: ResourceOptions(parent: parent),
      );

      // Both should complete
      await Future.wait([parent.registered, child.registered]);

      final parentUrn = await parent.urn.future;
      final childUrn = await child.urn.future;

      expect(childUrn, startsWith(parentUrn));
    });
  });

  group('ProviderResource', () {
    test('has correct type token format', () {
      final provider = TestProvider('my-provider');
      expect(provider.type, equals('pulumi:providers:testprovider'));
      expect(provider.name, equals('my-provider'));
      expect(provider.package, equals('testprovider'));
    });

    test('registered future completes', () async {
      final provider = TestProvider('my-provider');
      await provider.registered;
      // Should complete without error
    });

    test('urn is available after registration', () async {
      final provider = TestProvider('my-provider');
      await provider.registered;

      final urnValue = await provider.urn.future;
      expect(urnValue, contains('pulumi:providers:testprovider'));
      expect(urnValue, contains('my-provider'));
    });

    test('providerRef returns the URN', () async {
      final provider = TestProvider('my-provider');
      await provider.registered;

      final providerRefValue = await provider.providerRef.future;
      final urnValue = await provider.urn.future;
      expect(providerRefValue, equals(urnValue));
    });

    test('providerRefFuture returns the URN string', () async {
      final provider = TestProvider('my-provider');
      await provider.registered;

      final providerRefValue = await provider.providerRefFuture;
      final urnValue = await provider.urn.future;
      expect(providerRefValue, equals(urnValue));
    });

    test('inputs are passed correctly', () {
      final provider = TestProvider(
        'my-provider',
        inputs: {
          'region': Input.value('us-east-1'),
          'profile': Input.value('default'),
        },
      );

      expect(provider.inputs, hasLength(2));
      expect(provider.inputs['region'], isA<InputValue<Object?>>());
      expect(provider.inputs['profile'], isA<InputValue<Object?>>());
    });

    test('realistic provider with typed args works', () async {
      final provider = AwsTestProvider(
        'us-east',
        AwsTestProviderArgs(
          region: Input.value('us-east-1'),
          profile: Input.value('production'),
        ),
      );

      await provider.registered;

      expect(provider.type, equals('pulumi:providers:aws'));
      expect(provider.package, equals('aws'));

      final urnValue = await provider.urn.future;
      expect(urnValue, contains('pulumi:providers:aws'));
    });

    test('provider can be used with custom resource options', () async {
      final provider = TestProvider('my-provider');
      await provider.registered;

      // Get the provider reference
      final providerRef = await provider.providerRefFuture;

      // Create a resource that uses this provider
      final resource = TestCustomResource(
        'my-resource',
        opts: CustomResourceOptions(provider: providerRef),
      );
      await resource.registered;

      // Verify the resource was created with the provider option set
      expect(resource.options?.provider, equals(providerRef));
    });

    test('multiple providers can coexist', () async {
      final usEast = AwsTestProvider(
        'us-east',
        AwsTestProviderArgs(region: Input.value('us-east-1')),
      );
      final usWest = AwsTestProvider(
        'us-west',
        AwsTestProviderArgs(region: Input.value('us-west-2')),
      );

      await Future.wait([usEast.registered, usWest.registered]);

      final usEastUrn = await usEast.urn.future;
      final usWestUrn = await usWest.urn.future;

      // Each provider should have a unique URN
      expect(usEastUrn, isNot(equals(usWestUrn)));
      expect(usEastUrn, contains('us-east'));
      expect(usWestUrn, contains('us-west'));
    });

    test('provider inherits CustomResource id behavior', () async {
      final provider = TestProvider('my-provider');
      await provider.registered;

      // Providers should have an id like any CustomResource
      final idValue = await provider.id.future;
      expect(idValue, isA<String>());
    });

    test('provider options are preserved', () {
      final parent = TestComponentResource('parent');
      final provider = TestProvider(
        'my-provider',
        options: CustomResourceOptions(
          parent: parent,
          protect: true,
        ),
      );

      expect(provider.options?.parent, equals(parent));
      expect(provider.options?.protect, isTrue);
    });

    test('different provider packages have different type tokens', () {
      final awsProvider = AwsTestProvider(
        'aws-provider',
        AwsTestProviderArgs(region: Input.value('us-east-1')),
      );
      final testProvider = TestProvider('test-provider');

      expect(awsProvider.type, equals('pulumi:providers:aws'));
      expect(testProvider.type, equals('pulumi:providers:testprovider'));
      expect(awsProvider.package, equals('aws'));
      expect(testProvider.package, equals('testprovider'));
    });
  });
}

/// A test resource that has a failing future in inputs (gracefully handled).
class _FailingResource extends CustomResource {
  _FailingResource(String name) : super('test:resource:Failing', name);

  @override
  Map<String, Input<Object?>?> get inputs => {
        'failing': Input.future(
          Future.error(Exception('Registration failed')),
        ),
      };
}

/// A test resource that has an input with an output that throws when accessed.
class _FailingDependencyResource extends CustomResource {
  _FailingDependencyResource(String name)
      : super('test:resource:FailingDep', name);

  @override
  Map<String, Input<Object?>?> get inputs => {
        // Create an output that will fail when the data future is awaited
        'broken': Input.output(Output.fromDataFuture(
          Future.error(StateError('Output data failed')),
        )),
      };
}

/// A test provider resource implementation.
class TestProvider extends ProviderResource {
  final Map<String, Input<Object?>?> _inputs;

  TestProvider(
    String name, {
    Map<String, Input<Object?>?>? inputs,
    CustomResourceOptions? options,
  })  : _inputs = inputs ?? {},
        super('testprovider', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => _inputs;
}

/// A more realistic provider with typed arguments.
class AwsTestProvider extends ProviderResource {
  final AwsTestProviderArgs _args;

  AwsTestProvider(String name, AwsTestProviderArgs args,
      [CustomResourceOptions? options])
      : _args = args,
        super('aws', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => {
        'region': _args.region,
        'profile': _args.profile,
      };
}

class AwsTestProviderArgs {
  final Input<String>? region;
  final Input<String>? profile;

  AwsTestProviderArgs({this.region, this.profile});
}
