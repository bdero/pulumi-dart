import 'dart:async';

import 'package:meta/meta.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'input.dart';
import 'output.dart';
import 'runtime/runtime.dart';
import 'runtime/serialization.dart';

/// Options for controlling resource behavior.
///
/// These options are shared by all resource types. Specific resource types
/// may have additional options (e.g., [CustomResourceOptions]).
class ResourceOptions {
  /// An optional parent resource. When set, this resource will be a child of
  /// the parent, affecting URN construction and default provider inheritance.
  final Resource? parent;

  /// When true, the resource will be protected from deletion. A protected
  /// resource cannot be deleted directly; the protection must be removed first.
  final bool protect;

  /// An optional list of explicit dependencies. The resource will not be
  /// created until all dependencies have been created.
  final List<Resource> dependsOn;

  /// An optional provider to use for this resource. If not specified, the
  /// default provider for the resource type will be used.
  final String? provider;

  /// When true, the resource will be retained when the stack is destroyed,
  /// instead of being deleted.
  final bool retainOnDelete;

  /// The URN of the resource that this resource was deleted with. This is
  /// used during delete operations.
  final String? deletedWith;

  /// Creates resource options.
  const ResourceOptions({
    this.parent,
    this.protect = false,
    this.dependsOn = const [],
    this.provider,
    this.retainOnDelete = false,
    this.deletedWith,
  });
}

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
        parentUrn = await _opts!.parent!.urn.future;
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
          ? await _opts!.parent!.urn.future
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
        final depUrn = await dep.urn.dataFuture;
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
