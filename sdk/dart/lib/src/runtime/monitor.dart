import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as empty;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import '../proto/pulumi/alias.pb.dart' as alias;
import '../proto/pulumi/provider.pb.dart' as provider;
import '../proto/pulumi/resource.pb.dart' as resource;
import '../proto/pulumi/resource.pbgrpc.dart' as resource_grpc;
import '../proto/pulumi/source.pb.dart' as source;

/// A client for the Pulumi ResourceMonitor gRPC service.
///
/// The ResourceMonitor is the interface a Pulumi program uses to communicate
/// with the Pulumi deployment engine. It provides methods for:
/// - Registering resources and their outputs
/// - Reading existing resource state
/// - Invoking provider functions
/// - Calling resource methods
/// - Checking feature support
///
/// ## Example
///
/// ```dart
/// final monitor = ResourceMonitor.connect('localhost:50051');
/// try {
///   final response = await monitor.registerResource(
///     type: 'aws:s3/bucket:Bucket',
///     name: 'my-bucket',
///     inputs: Struct()..fields['bucket'] = (Value()..stringValue = 'my-bucket-name'),
///   );
///   print('Created resource with URN: ${response.urn}');
/// } finally {
///   await monitor.shutdown();
/// }
/// ```
class ResourceMonitor {
  final ClientChannel _channel;
  final resource_grpc.ResourceMonitorClient _client;

  ResourceMonitor._(this._channel, this._client);

  /// Creates a ResourceMonitor connected to the given address.
  ///
  /// The [address] should be in the format 'host:port'.
  /// Set [secure] to true to use TLS (defaults to false for local connections).
  factory ResourceMonitor.connect(
    String address, {
    bool secure = false,
    CallOptions? options,
  }) {
    final parts = address.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? int.parse(parts[1]) : 50051;

    final channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: secure
            ? const ChannelCredentials.secure()
            : const ChannelCredentials.insecure(),
      ),
    );

    final client = resource_grpc.ResourceMonitorClient(
      channel,
      options: options,
    );

    return ResourceMonitor._(channel, client);
  }

  /// Creates a ResourceMonitor from an existing gRPC channel.
  ///
  /// This is useful when you want to share a channel across multiple clients.
  factory ResourceMonitor.fromChannel(
    ClientChannel channel, {
    CallOptions? options,
  }) {
    final client = resource_grpc.ResourceMonitorClient(
      channel,
      options: options,
    );
    return ResourceMonitor._(channel, client);
  }

  /// Checks whether the resource monitor supports a specific feature.
  ///
  /// This allows the SDK to gracefully handle differences between Pulumi
  /// engine versions.
  ///
  /// ```dart
  /// final supported = await monitor.supportsFeature('secrets');
  /// if (supported) {
  ///   // Use secret handling
  /// }
  /// ```
  Future<bool> supportsFeature(String feature, {CallOptions? options}) async {
    final request = resource.SupportsFeatureRequest()..id = feature;
    final response = await _client.supportsFeature(request, options: options);
    return response.hasSupport;
  }

  /// Registers a new resource with the Pulumi deployment engine.
  ///
  /// This is the core method for creating infrastructure resources. It sends
  /// the resource definition to the engine, which orchestrates the actual
  /// creation through the appropriate provider.
  ///
  /// Parameters:
  /// - [type]: The Pulumi type token (e.g., 'aws:s3/bucket:Bucket')
  /// - [name]: The logical name for this resource
  /// - [custom]: Whether this is a custom resource (true) or component (false)
  /// - [inputs]: The input properties as a protobuf Struct
  /// - [parent]: The URN of the parent resource (optional)
  /// - [protect]: Whether to protect this resource from deletion
  /// - [dependencies]: List of URNs this resource depends on
  /// - [provider]: Provider reference to use for this resource
  /// - [version]: Required provider version
  /// - [acceptSecrets]: Whether the SDK can handle secret outputs
  /// - [acceptResources]: Whether the SDK can handle resource references
  /// - [remote]: Whether this is a remote component
  ///
  /// Returns a [RegisterResourceResponse] containing the resource's URN, ID,
  /// and output properties.
  Future<resource.RegisterResourceResponse> registerResource({
    required String type,
    required String name,
    bool custom = true,
    Struct? inputs,
    String? parent,
    bool protect = false,
    List<String> dependencies = const [],
    String? providerRef,
    String? version,
    bool acceptSecrets = true,
    bool acceptResources = true,
    bool remote = false,
    Map<String, resource.RegisterResourceRequest_PropertyDependencies>?
        propertyDependencies,
    bool deleteBeforeReplace = false,
    bool retainOnDelete = false,
    List<String> ignoreChanges = const [],
    List<String> replaceOnChanges = const [],
    List<alias.Alias> aliases = const [],
    String? importId,
    resource.RegisterResourceRequest_CustomTimeouts? customTimeouts,
    String? pluginDownloadUrl,
    bool supportsResultReporting = true,
    String? deletedWith,
    source.SourcePosition? sourcePosition,
    String? packageRef,
    List<String> additionalSecretOutputs = const [],
    CallOptions? options,
  }) async {
    final request = resource.RegisterResourceRequest()
      ..type = type
      ..name = name
      ..custom = custom
      ..protect = protect
      ..dependencies.addAll(dependencies)
      ..deleteBeforeReplace = deleteBeforeReplace
      ..retainOnDelete = retainOnDelete
      ..acceptSecrets = acceptSecrets
      ..acceptResources = acceptResources
      ..remote = remote
      ..supportsResultReporting = supportsResultReporting;

    if (inputs != null) {
      request.object = inputs;
    }
    if (parent != null && parent.isNotEmpty) {
      request.parent = parent;
    }
    if (providerRef != null && providerRef.isNotEmpty) {
      request.provider = providerRef;
    }
    if (version != null && version.isNotEmpty) {
      request.version = version;
    }
    if (propertyDependencies != null) {
      request.propertyDependencies.addAll(propertyDependencies);
    }
    if (ignoreChanges.isNotEmpty) {
      request.ignoreChanges.addAll(ignoreChanges);
    }
    if (replaceOnChanges.isNotEmpty) {
      request.replaceOnChanges.addAll(replaceOnChanges);
    }
    if (aliases.isNotEmpty) {
      request.aliases.addAll(aliases);
    }
    if (importId != null && importId.isNotEmpty) {
      request.importId = importId;
    }
    if (customTimeouts != null) {
      request.customTimeouts = customTimeouts;
    }
    if (pluginDownloadUrl != null && pluginDownloadUrl.isNotEmpty) {
      request.pluginDownloadURL = pluginDownloadUrl;
    }
    if (deletedWith != null && deletedWith.isNotEmpty) {
      request.deletedWith = deletedWith;
    }
    if (sourcePosition != null) {
      request.sourcePosition = sourcePosition;
    }
    if (packageRef != null && packageRef.isNotEmpty) {
      request.packageRef = packageRef;
    }
    if (additionalSecretOutputs.isNotEmpty) {
      request.additionalSecretOutputs.addAll(additionalSecretOutputs);
    }

    return await _client.registerResource(request, options: options);
  }

  /// Registers outputs for a component resource.
  ///
  /// Component resources should call this after creating their child resources
  /// to advertise their outputs. This makes the outputs visible in the Pulumi
  /// CLI and available for stack references.
  ///
  /// ```dart
  /// await monitor.registerResourceOutputs(
  ///   urn: componentUrn,
  ///   outputs: Struct()
  ///     ..fields['bucketName'] = (Value()..stringValue = bucketName)
  ///     ..fields['instanceId'] = (Value()..stringValue = instanceId),
  /// );
  /// ```
  Future<void> registerResourceOutputs({
    required String urn,
    required Struct outputs,
    CallOptions? options,
  }) async {
    final request = resource.RegisterResourceOutputsRequest()
      ..urn = urn
      ..outputs = outputs;

    await _client.registerResourceOutputs(request, options: options);
  }

  /// Reads an existing resource's state.
  ///
  /// This is used to import existing infrastructure into Pulumi management.
  /// The provider reads the current state of the resource from the cloud.
  ///
  /// Parameters:
  /// - [type]: The Pulumi type token
  /// - [name]: The logical name for this resource
  /// - [id]: The provider ID of the existing resource
  /// - [parent]: The URN of the parent resource (optional)
  /// - [providerRef]: Provider reference to use
  /// - [version]: Required provider version
  /// - [inputs]: Known input properties
  ///
  /// Returns a [ReadResourceResponse] containing the resource's URN, ID,
  /// and current property values.
  Future<resource.ReadResourceResponse> readResource({
    required String type,
    required String name,
    required String id,
    String? parent,
    String? providerRef,
    String? version,
    Struct? inputs,
    List<String> dependencies = const [],
    bool acceptSecrets = true,
    bool acceptResources = true,
    List<String> additionalSecretOutputs = const [],
    source.SourcePosition? sourcePosition,
    String? packageRef,
    CallOptions? options,
  }) async {
    final request = resource.ReadResourceRequest()
      ..type = type
      ..name = name
      ..id = id
      ..acceptSecrets = acceptSecrets
      ..acceptResources = acceptResources;

    if (parent != null && parent.isNotEmpty) {
      request.parent = parent;
    }
    if (providerRef != null && providerRef.isNotEmpty) {
      request.provider = providerRef;
    }
    if (version != null && version.isNotEmpty) {
      request.version = version;
    }
    if (inputs != null) {
      request.properties = inputs;
    }
    if (dependencies.isNotEmpty) {
      request.dependencies.addAll(dependencies);
    }
    if (additionalSecretOutputs.isNotEmpty) {
      request.additionalSecretOutputs.addAll(additionalSecretOutputs);
    }
    if (sourcePosition != null) {
      request.sourcePosition = sourcePosition;
    }
    if (packageRef != null && packageRef.isNotEmpty) {
      request.packageRef = packageRef;
    }

    return await _client.readResource(request, options: options);
  }

  /// Invokes a provider function.
  ///
  /// Provider functions are operations that don't create resources but
  /// return data. For example, looking up an AMI ID or fetching availability
  /// zones.
  ///
  /// ```dart
  /// final response = await monitor.invoke(
  ///   token: 'aws:ec2/getAmi:getAmi',
  ///   args: Struct()
  ///     ..fields['owners'] = (Value()..listValue = (ListValue()
  ///       ..values.add(Value()..stringValue = 'amazon'))),
  /// );
  /// ```
  Future<provider.InvokeResponse> invoke({
    required String token,
    Struct? args,
    String? providerRef,
    String? version,
    bool acceptResources = true,
    String? pluginDownloadUrl,
    source.SourcePosition? sourcePosition,
    String? packageRef,
    CallOptions? options,
  }) async {
    final request = resource.ResourceInvokeRequest()
      ..tok = token
      ..acceptResources = acceptResources;

    if (args != null) {
      request.args = args;
    }
    if (providerRef != null && providerRef.isNotEmpty) {
      request.provider = providerRef;
    }
    if (version != null && version.isNotEmpty) {
      request.version = version;
    }
    if (pluginDownloadUrl != null && pluginDownloadUrl.isNotEmpty) {
      request.pluginDownloadURL = pluginDownloadUrl;
    }
    if (sourcePosition != null) {
      request.sourcePosition = sourcePosition;
    }
    if (packageRef != null && packageRef.isNotEmpty) {
      request.packageRef = packageRef;
    }

    return await _client.invoke(request, options: options);
  }

  /// Calls a method on a resource.
  ///
  /// Resource methods are operations that can be performed on an existing
  /// resource instance. For example, scaling a Kubernetes deployment.
  ///
  /// Parameters:
  /// - [token]: The method token (e.g., 'kubernetes:apps/v1:Deployment/scale')
  /// - [args]: Method arguments as a protobuf Struct
  /// - [providerRef]: Provider reference
  /// - [version]: Required provider version
  ///
  /// Returns a [CallResponse] containing the method's return values.
  Future<provider.CallResponse> call({
    required String token,
    Struct? args,
    String? providerRef,
    String? version,
    Map<String, resource.ResourceCallRequest_ArgumentDependencies>?
        argDependencies,
    String? pluginDownloadUrl,
    source.SourcePosition? sourcePosition,
    String? packageRef,
    CallOptions? options,
  }) async {
    final request = resource.ResourceCallRequest()..tok = token;

    if (args != null) {
      request.args = args;
    }
    if (providerRef != null && providerRef.isNotEmpty) {
      request.provider = providerRef;
    }
    if (version != null && version.isNotEmpty) {
      request.version = version;
    }
    if (argDependencies != null) {
      request.argDependencies.addAll(argDependencies);
    }
    if (pluginDownloadUrl != null && pluginDownloadUrl.isNotEmpty) {
      request.pluginDownloadURL = pluginDownloadUrl;
    }
    if (sourcePosition != null) {
      request.sourcePosition = sourcePosition;
    }
    if (packageRef != null && packageRef.isNotEmpty) {
      request.packageRef = packageRef;
    }

    return await _client.call(request, options: options);
  }

  /// Signals that the program has completed and waits for shutdown.
  ///
  /// This should be called after all resources have been registered. It tells
  /// the engine that no more events will be generated and blocks until the
  /// engine finishes processing all pending operations.
  Future<void> signalAndWaitForShutdown({CallOptions? options}) async {
    await _client.signalAndWaitForShutdown(
      empty.Empty(),
      options: options,
    );
  }

  /// Shuts down the gRPC channel.
  ///
  /// This releases the network resources used by the client. After calling
  /// this method, no further operations can be performed on this monitor.
  Future<void> shutdown() async {
    await _channel.shutdown();
  }

  /// Terminates the gRPC channel immediately.
  ///
  /// Unlike [shutdown], this does not wait for pending operations to complete.
  Future<void> terminate() async {
    await _channel.terminate();
  }
}
