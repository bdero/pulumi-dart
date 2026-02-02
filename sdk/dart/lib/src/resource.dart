import 'dart:async';

import 'package:meta/meta.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'input.dart';
import 'options.dart';
import 'output.dart';
import 'proto/pulumi/alias.pb.dart' as alias_pb;
import 'proto/pulumi/resource.pb.dart' as resource_pb;
import 'runtime/runtime.dart';
import 'runtime/serialization.dart';

// Re-export options for backward compatibility
export 'options.dart';

/// Base class for all Pulumi resources.
///
/// Resources represent cloud infrastructure components like virtual machines,
/// databases, or storage buckets. Each resource has:
/// - A unique type (e.g., 'aws:s3/bucket:Bucket')
/// - A name (user-provided identifier)
/// - A URN (automatically assigned globally unique identifier)
/// - Input properties (configuration) and output properties (results)
///
/// ## Async Initialization Pattern
///
/// Dart constructors cannot be async, but resource registration requires
/// async operations. This class uses a microtask-based pattern:
///
/// 1. The constructor stores arguments and schedules registration
/// 2. Registration runs asynchronously after the constructor returns
/// 3. The [registered] future completes when registration is done
/// 4. Late-initialized outputs become available after registration
///
/// ## Example
///
/// ```dart
/// class Bucket extends CustomResource {
///   late final Output<String> bucketName;
///
///   Bucket(String name, BucketArgs args, [CustomResourceOptions? opts])
///       : _args = args,
///         super('aws:s3/bucket:Bucket', name, opts);
///
///   final BucketArgs _args;
///
///   @override
///   Map<String, Input<Object?>> get inputs => {
///     'bucket': _args.bucket,
///   };
///
///   @override
///   void processOutputs(Struct properties) {
///     super.processOutputs(properties);
///     bucketName = Output.of(properties.fields['bucket']?.stringValue ?? '');
///   }
/// }
/// ```
abstract class Resource {
  /// The Pulumi type token for this resource (e.g., 'aws:s3/bucket:Bucket').
  final String _type;

  /// The user-provided name for this resource.
  final String _name;

  /// The resource options.
  final ResourceOptions? _opts;

  /// The unique resource name (URN) assigned by Pulumi.
  ///
  /// This is late-initialized because URN assignment happens asynchronously
  /// during resource registration. Access this only after [registered] completes.
  late final Output<String> urn;

  /// A completer that signals when the resource has been fully registered.
  final Completer<void> _registered = Completer<void>();

  /// The resource ID from registration (used by CustomResource).
  /// This is set by _register() before processOutputs() is called.
  @protected
  String? _registrationId;

  /// A future that completes when the resource has been fully registered.
  ///
  /// Await this future to ensure the resource is fully initialized before
  /// accessing its output properties.
  ///
  /// ```dart
  /// final bucket = Bucket('my-bucket', BucketArgs());
  /// await bucket.registered;
  /// print(await bucket.urn.future);
  /// ```
  Future<void> get registered => _registered.future;

  /// Creates a new resource.
  ///
  /// Subclasses should call this constructor with the appropriate type token
  /// and name. Registration is scheduled automatically.
  Resource(this._type, this._name, [this._opts]) {
    _scheduleRegistration();
  }

  /// The resource type token.
  String get type => _type;

  /// The resource name.
  String get name => _name;

  /// The resource options.
  ResourceOptions? get options => _opts;

  /// Schedules the async registration to run after the constructor.
  ///
  /// Using scheduleMicrotask ensures the registration runs after all
  /// synchronous constructor code (including subclass constructors) completes.
  void _scheduleRegistration() {
    scheduleMicrotask(() async {
      try {
        await _register();
        _registered.complete();
      } catch (e, stack) {
        _registered.completeError(e, stack);
      }
    });
  }

  /// The input properties for this resource.
  ///
  /// Subclasses must override this to provide their input properties.
  /// The map keys are property names, and values are [Input] objects.
  @protected
  Map<String, Input<Object?>?> get inputs;

  /// Performs the actual resource registration with the Pulumi engine.
  ///
  /// This method:
  /// 1. Collects dependencies from input Output values
  /// 2. Serializes inputs to protobuf format
  /// 3. Calls RegisterResource on the ResourceMonitor
  /// 4. Processes the response to populate output properties
  Future<void> _register() async {
    // Collect dependencies from all inputs
    final deps = await _collectDependencies(inputs);

    // Check if Runtime is initialized (actual Pulumi execution)
    if (Runtime.isInitialized) {
      // Make the actual gRPC call to the ResourceMonitor
      final monitor = Runtime.instance.monitor;

      // Serialize inputs to protobuf format
      final serializedInputs = await PropertySerializer.serialize(inputs);

      // Add serialized dependencies to the collected dependencies
      deps.addAll(serializedInputs.dependencies);

      // Get parent URN if we have a parent
      String? parentUrn;
      if (_opts?.parent != null) {
        parentUrn = await (_opts!.parent as Resource).urn.future;
      }

      // Convert aliases to protobuf format
      final pbAliases = _convertAliases(_opts?.aliases ?? []);

      // Convert custom timeouts to protobuf format
      resource_pb.RegisterResourceRequest_CustomTimeouts? pbTimeouts;
      if (_opts?.customTimeouts != null) {
        pbTimeouts = resource_pb.RegisterResourceRequest_CustomTimeouts();
        if (_opts!.customTimeouts!.create != null) {
          pbTimeouts.create_1 = _opts!.customTimeouts!.create!;
        }
        if (_opts!.customTimeouts!.update != null) {
          pbTimeouts.update = _opts!.customTimeouts!.update!;
        }
        if (_opts!.customTimeouts!.delete != null) {
          pbTimeouts.delete = _opts!.customTimeouts!.delete!;
        }
      }

      // Get CustomResourceOptions-specific fields if applicable
      String? importId;
      bool deleteBeforeReplace = false;
      List<String> additionalSecretOutputs = [];
      if (_opts is CustomResourceOptions) {
        final customOpts = _opts as CustomResourceOptions;
        importId = customOpts.importId;
        deleteBeforeReplace = customOpts.deleteBeforeReplace;
        additionalSecretOutputs = customOpts.additionalSecretOutputs;
      }

      // Register the resource with the Pulumi engine
      final response = await monitor.registerResource(
        type: _type,
        name: _name,
        custom: this is CustomResource,
        inputs: serializedInputs.value.structValue,
        parent: parentUrn,
        protect: _opts?.protect ?? false,
        dependencies: deps.toList(),
        retainOnDelete: _opts?.retainOnDelete ?? false,
        deletedWith: _opts?.deletedWith,
        providerRef: _opts?.provider,
        aliases: pbAliases,
        ignoreChanges: _opts?.ignoreChanges ?? [],
        replaceOnChanges: _opts?.replaceOnChanges ?? [],
        customTimeouts: pbTimeouts,
        version: _opts?.version,
        pluginDownloadUrl: _opts?.pluginDownloadUrl,
        importId: importId,
        deleteBeforeReplace: deleteBeforeReplace,
        additionalSecretOutputs: additionalSecretOutputs,
      );

      // Set the URN from the response
      urn = Output.fromData(OutputData.known(
        response.urn,
        dependencies: deps,
      ));

      // Store the ID for CustomResource to use
      _registrationId = response.id;

      // Process the output properties from the response
      processOutputs(response.object);
    } else {
      // Mock implementation for testing when Runtime is not initialized
      final parentUrn = _opts?.parent != null
          ? await (_opts!.parent as Resource).urn.future
          : 'urn:pulumi:stack::project';
      final mockUrn = '$parentUrn::$_type::$_name';
      urn = Output.fromData(OutputData.known(
        mockUrn,
        dependencies: deps,
      ));

      // Call processOutputs with empty struct for subclasses that need initialization
      processOutputs(Struct());
    }
  }

  /// Converts SDK alias types to protobuf format.
  List<alias_pb.Alias> _convertAliases(List<Alias> aliases) {
    return aliases.map((a) {
      switch (a) {
        case AliasUrn(:final urn):
          return alias_pb.Alias(urn: urn);
        case AliasSpec(
            :final name,
            :final type,
            :final stack,
            :final project,
            :final parentUrn,
            :final noParent
          ):
          final spec = alias_pb.Alias_Spec();
          if (name != null) spec.name = name;
          if (type != null) spec.type = type;
          if (stack != null) spec.stack = stack;
          if (project != null) spec.project = project;
          if (parentUrn != null) spec.parentUrn = parentUrn;
          if (noParent == true) spec.noParent = true;
          return alias_pb.Alias(spec: spec);
      }
    }).toList();
  }

  /// Processes the output properties returned from registration.
  ///
  /// Subclasses should override this to extract and populate their
  /// late-initialized output properties from the response.
  @protected
  @mustCallSuper
  void processOutputs(Struct properties) {
    // Base implementation does nothing; subclasses override
  }

  /// Collects resource URN dependencies from the input properties.
  ///
  /// This walks through all input values and extracts URNs from any
  /// Output values that have resource dependencies.
  Future<Set<String>> _collectDependencies(
    Map<String, Input<Object?>?> props,
  ) async {
    final urns = <String>{};

    // Add explicit dependencies from options
    if (_opts != null) {
      for (final dep in _opts!.dependsOn) {
        final depResource = dep as Resource;
        final depUrn = await depResource.urn.dataFuture;
        if (depUrn.isKnown) {
          urns.add(depUrn.value);
        }
        urns.addAll(depUrn.dependencies);
      }
    }

    // Collect dependencies from input values
    for (final entry in props.entries) {
      final input = entry.value;
      if (input == null) continue;

      final deps = await _getDependenciesFromInput(input);
      urns.addAll(deps);
    }

    return urns;
  }

  /// Extracts dependencies from a single Input value.
  Future<Set<String>> _getDependenciesFromInput(Input<Object?> input) async {
    final urns = <String>{};

    switch (input) {
      case InputValue():
        // Plain values have no dependencies
        // But check if the value itself is an Output or contains nested Outputs
        urns.addAll(await _getDependenciesFromValue(input.value));
        break;

      case InputOutput(:final output):
        // Extract dependencies from the Output
        final data = await output.dataFuture;
        urns.addAll(data.dependencies);
        // Also check if the value contains nested Outputs
        if (data.isKnown) {
          urns.addAll(await _getDependenciesFromValue(data.value));
        }
        break;

      case InputFuture(:final future):
        // Futures don't have dependencies themselves, but their resolved
        // value might contain Outputs
        try {
          final value = await future;
          urns.addAll(await _getDependenciesFromValue(value));
        } catch (_) {
          // If future fails, we still continue (error will surface later)
        }
        break;
    }

    return urns;
  }

  /// Extracts dependencies from a value that might contain nested Outputs.
  Future<Set<String>> _getDependenciesFromValue(Object? value) async {
    final urns = <String>{};

    if (value is Output) {
      final data = await value.dataFuture;
      urns.addAll(data.dependencies);
    } else if (value is Map) {
      for (final v in value.values) {
        urns.addAll(await _getDependenciesFromValue(v));
      }
    } else if (value is List) {
      for (final v in value) {
        urns.addAll(await _getDependenciesFromValue(v));
      }
    }

    return urns;
  }
}

/// A resource managed by a provider plugin.
///
/// Custom resources are the most common type of Pulumi resource. They represent
/// infrastructure components that are created, updated, and deleted by a
/// provider plugin (e.g., AWS, Azure, GCP).
///
/// Each custom resource has:
/// - An [id] assigned by the provider (e.g., AWS resource ARN)
/// - Output properties populated from the provider response
///
/// ## Example
///
/// ```dart
/// class Bucket extends CustomResource {
///   late final Output<String> bucketArn;
///   late final Output<String?> websiteEndpoint;
///
///   final BucketArgs _args;
///
///   Bucket(String name, BucketArgs args, [CustomResourceOptions? opts])
///       : _args = args,
///         super('aws:s3/bucket:Bucket', name, opts);
///
///   @override
///   Map<String, Input<Object?>?> get inputs => {
///     'bucket': _args.bucket,
///     'acl': _args.acl,
///   };
///
///   @override
///   void processOutputs(Struct properties) {
///     super.processOutputs(properties);
///     bucketArn = Output.of(properties.fields['arn']?.stringValue ?? '');
///     websiteEndpoint = properties.fields.containsKey('websiteEndpoint')
///         ? Output.of(properties.fields['websiteEndpoint']?.stringValue)
///         : Output.of(null);
///   }
/// }
/// ```
abstract class CustomResource extends Resource {
  /// The provider-assigned unique identifier for this resource.
  ///
  /// For example, an AWS EC2 instance would have an ID like 'i-1234567890abcdef0'.
  /// This is late-initialized after registration completes.
  late final Output<String> id;

  /// Creates a new custom resource.
  CustomResource(super.type, super.name, [super.opts]);

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    // Extract ID - preferring the _registrationId from the actual response,
    // falling back to the 'id' field in properties for testing
    final resourceId = _registrationId ??
        properties.fields['id']?.stringValue ??
        '';
    id = Output.of(resourceId);
  }
}

/// A resource that represents an explicitly configured provider.
///
/// Provider resources are used to create explicit provider configurations
/// that can be passed to other resources via the `provider` option. This allows
/// you to manage resources with different configurations of the same provider
/// (e.g., AWS resources in different regions).
///
/// ## Provider Reference Format
///
/// Providers use the type token format `pulumi:providers:<package>`, where
/// `<package>` is the provider package name (e.g., 'aws', 'gcp', 'random').
///
/// When passed to [ResourceOptions.provider], the provider reference is the
/// provider's URN.
///
/// ## Example
///
/// ```dart
/// class AwsProvider extends ProviderResource {
///   final AwsProviderArgs _args;
///
///   AwsProvider(String name, AwsProviderArgs args, [CustomResourceOptions? opts])
///       : _args = args,
///         super('aws', name, opts);
///
///   @override
///   Map<String, Input<Object?>?> get inputs => {
///     'region': _args.region,
///     'profile': _args.profile,
///   };
/// }
///
/// // Usage
/// final usEastProvider = AwsProvider('us-east', AwsProviderArgs(region: 'us-east-1'));
/// final usWestProvider = AwsProvider('us-west', AwsProviderArgs(region: 'us-west-2'));
///
/// // Create a bucket in us-east-1
/// final bucket = Bucket('my-bucket', BucketArgs(),
///   CustomResourceOptions(provider: usEastProvider.providerRef),
/// );
/// ```
abstract class ProviderResource extends CustomResource {
  /// The provider package name (e.g., 'aws', 'gcp', 'random').
  final String _package;

  /// Creates a new provider resource.
  ///
  /// [package] is the provider package name (e.g., 'aws', 'gcp', 'random').
  /// The type token is automatically constructed as `pulumi:providers:<package>`.
  ProviderResource(String package, String name, [CustomResourceOptions? opts])
      : _package = package,
        super('pulumi:providers:$package', name, opts);

  /// The provider package name.
  String get package => _package;

  /// Returns a provider reference string that can be passed to
  /// [ResourceOptions.provider] or [CustomResourceOptions.provider].
  ///
  /// This is an [Output] because the provider's URN is not available until
  /// registration completes. Use this with [Input.output] when passing to
  /// resource options.
  ///
  /// ```dart
  /// final provider = MyProvider('my-provider', MyProviderArgs());
  /// final resource = MyResource('my-resource', MyResourceArgs(),
  ///   CustomResourceOptions(
  ///     provider: provider.providerRef,
  ///   ),
  /// );
  /// ```
  ///
  /// Note: For simple cases where you need to wait for the reference,
  /// you can use [providerRefFuture] to get the string directly.
  Output<String> get providerRef => urn;

  /// Returns a future that resolves to the provider reference string.
  ///
  /// This is a convenience method for cases where you need to await the
  /// provider reference directly rather than passing it as an Output.
  ///
  /// ```dart
  /// final provider = MyProvider('my-provider', MyProviderArgs());
  /// await provider.registered;
  /// final ref = await provider.providerRefFuture;
  /// ```
  Future<String> get providerRefFuture => urn.future;
}

/// A logical grouping of resources.
///
/// Component resources are used to create abstractions that group multiple
/// resources together. Unlike [CustomResource], component resources don't
/// correspond to a single cloud resource managed by a provider.
///
/// Component resources:
/// - Don't have a provider-assigned [id]
/// - Don't have input properties (they contain other resources instead)
/// - Can register outputs that aggregate values from their child resources
///
/// ## Example
///
/// ```dart
/// class WebApplication extends ComponentResource {
///   late final Output<String> url;
///
///   WebApplication(String name, WebApplicationArgs args, [ResourceOptions? opts])
///       : super('mycompany:components:WebApplication', name, opts) {
///     // Create child resources
///     final bucket = Bucket('$name-bucket', BucketArgs(/*...*/),
///         ResourceOptions(parent: this));
///     final instance = Instance('$name-instance', InstanceArgs(/*...*/),
///         ResourceOptions(parent: this));
///
///     // Set up the output URL
///     url = instance.publicIp.apply((ip) => 'http://$ip');
///
///     // Register outputs after all child resources are created
///     registerOutputs({'url': url});
///   }
/// }
/// ```
abstract class ComponentResource extends Resource {
  /// Creates a new component resource.
  ComponentResource(super.type, super.name, [super.opts]);

  /// Component resources don't have input properties.
  @override
  Map<String, Input<Object?>?> get inputs => {};

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    // Component resources don't have provider-assigned outputs beyond the base
  }

  /// Registers outputs for this component resource.
  ///
  /// This should be called after all child resources have been created to
  /// advertise the component's output values. The outputs will be displayed
  /// in the Pulumi CLI and can be referenced by other stacks.
  ///
  /// ```dart
  /// registerOutputs({
  ///   'bucketName': bucket.bucketName,
  ///   'instanceId': instance.id,
  /// });
  /// ```
  Future<void> registerOutputs(Map<String, Output<Object?>> outputs) async {
    // Wait for this resource to be registered first
    await registered;

    // Only make the gRPC call if Runtime is initialized
    if (Runtime.isInitialized) {
      final monitor = Runtime.instance.monitor;
      final resourceUrn = await urn.future;
      final serialized = await PropertySerializer.serializeOutputMap(outputs);

      await monitor.registerResourceOutputs(
        urn: resourceUrn,
        outputs: serialized.value.structValue,
      );
    }
    // When Runtime is not initialized (testing), this is a no-op
  }
}
