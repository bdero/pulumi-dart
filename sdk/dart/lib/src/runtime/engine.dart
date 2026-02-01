import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import '../proto/pulumi/engine.pb.dart';
import '../proto/pulumi/engine.pbgrpc.dart';

/// A client for the Pulumi Engine gRPC service.
///
/// The Engine service provides logging and root resource management for
/// Pulumi programs. It allows programs to:
/// - Log messages at various severity levels (debug, info, warning, error)
/// - Get and set the root resource URN
/// - Signal when debugging has started
/// - Check Pulumi version requirements
///
/// ## Example
///
/// ```dart
/// final engine = Engine.connect('localhost:50052');
/// try {
///   await engine.info('Starting deployment...');
///   await engine.warning('This is a preview only');
///
///   final rootUrn = await engine.getRootResource();
///   print('Root resource: $rootUrn');
/// } finally {
///   await engine.shutdown();
/// }
/// ```
class Engine {
  final ClientChannel _channel;
  final EngineClient _client;

  Engine._(this._channel, this._client);

  /// Creates an Engine client connected to the given address.
  ///
  /// The [address] should be in the format 'host:port'.
  /// Set [secure] to true to use TLS (defaults to false for local connections).
  factory Engine.connect(
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

    final client = EngineClient(channel, options: options);
    return Engine._(channel, client);
  }

  /// Creates an Engine client from an existing gRPC channel.
  ///
  /// This is useful when you want to share a channel across multiple clients.
  factory Engine.fromChannel(
    ClientChannel channel, {
    CallOptions? options,
  }) {
    final client = EngineClient(channel, options: options);
    return Engine._(channel, client);
  }

  /// Logs a message to the Pulumi engine.
  ///
  /// Parameters:
  /// - [severity]: The log level (DEBUG, INFO, WARNING, ERROR)
  /// - [message]: The message to log
  /// - [urn]: Optional resource URN to associate with the log message
  /// - [streamId]: Optional stream ID for grouping related log messages
  /// - [ephemeral]: Whether this is a status/ephemeral message
  ///
  /// ```dart
  /// await engine.log(LogSeverity.INFO, 'Creating bucket...');
  /// await engine.log(
  ///   LogSeverity.WARNING,
  ///   'Resource will be replaced',
  ///   urn: 'urn:pulumi:stack::project::aws:s3/bucket:Bucket::my-bucket',
  /// );
  /// ```
  Future<void> log(
    LogSeverity severity,
    String message, {
    String? urn,
    int? streamId,
    bool? ephemeral,
    CallOptions? options,
  }) async {
    final request = LogRequest(
      severity: severity,
      message: message,
    );

    if (urn != null && urn.isNotEmpty) {
      request.urn = urn;
    }
    if (streamId != null && streamId != 0) {
      request.streamId = streamId;
    }
    if (ephemeral != null) {
      request.ephemeral = ephemeral;
    }

    await _client.log(request, options: options);
  }

  /// Logs a debug message.
  ///
  /// Debug messages are only shown when verbose logging is enabled.
  ///
  /// ```dart
  /// await engine.debug('Computed hash: $hash');
  /// ```
  Future<void> debug(
    String message, {
    String? urn,
    int? streamId,
    bool? ephemeral,
    CallOptions? options,
  }) =>
      log(
        LogSeverity.DEBUG,
        message,
        urn: urn,
        streamId: streamId,
        ephemeral: ephemeral,
        options: options,
      );

  /// Logs an info message.
  ///
  /// Info messages are shown during normal operation.
  ///
  /// ```dart
  /// await engine.info('Deploying 5 resources...');
  /// ```
  Future<void> info(
    String message, {
    String? urn,
    int? streamId,
    bool? ephemeral,
    CallOptions? options,
  }) =>
      log(
        LogSeverity.INFO,
        message,
        urn: urn,
        streamId: streamId,
        ephemeral: ephemeral,
        options: options,
      );

  /// Logs a warning message.
  ///
  /// Warning messages indicate potential issues that don't prevent the
  /// operation from completing.
  ///
  /// ```dart
  /// await engine.warning('Deprecated property used');
  /// ```
  Future<void> warning(
    String message, {
    String? urn,
    int? streamId,
    bool? ephemeral,
    CallOptions? options,
  }) =>
      log(
        LogSeverity.WARNING,
        message,
        urn: urn,
        streamId: streamId,
        ephemeral: ephemeral,
        options: options,
      );

  /// Logs an error message.
  ///
  /// Error messages indicate failures. Note that logging an error does not
  /// automatically fail the deployment - you should also throw an exception
  /// if the error should stop execution.
  ///
  /// ```dart
  /// await engine.error('Failed to create resource: $reason');
  /// throw Exception('Deployment failed');
  /// ```
  Future<void> error(
    String message, {
    String? urn,
    int? streamId,
    bool? ephemeral,
    CallOptions? options,
  }) =>
      log(
        LogSeverity.ERROR,
        message,
        urn: urn,
        streamId: streamId,
        ephemeral: ephemeral,
        options: options,
      );

  /// Gets the URN of the root resource.
  ///
  /// The root resource is typically the stack resource that serves as the
  /// parent for all otherwise-unparented resources.
  ///
  /// Returns an empty string if no root resource has been set.
  ///
  /// ```dart
  /// final rootUrn = await engine.getRootResource();
  /// if (rootUrn.isNotEmpty) {
  ///   print('Root: $rootUrn');
  /// }
  /// ```
  Future<String> getRootResource({CallOptions? options}) async {
    final response = await _client.getRootResource(
      GetRootResourceRequest(),
      options: options,
    );
    return response.urn;
  }

  /// Sets the URN of the root resource.
  ///
  /// This is typically called by the SDK to register the stack resource
  /// as the root. User code normally doesn't need to call this directly.
  ///
  /// ```dart
  /// await engine.setRootResource(
  ///   'urn:pulumi:stack::project::pulumi:pulumi:Stack::my-stack',
  /// );
  /// ```
  Future<void> setRootResource(String urn, {CallOptions? options}) async {
    await _client.setRootResource(
      SetRootResourceRequest(urn: urn),
      options: options,
    );
  }

  /// Signals that the program has started under a debugger.
  ///
  /// This notifies the Pulumi engine that debugging is active and provides
  /// configuration for connecting to the debugger. The engine will display
  /// the provided message to the user.
  ///
  /// Parameters:
  /// - [config]: Debug configuration in DAP (Debug Adapter Protocol) format
  /// - [message]: Instructions for the user on how to connect to the debugger
  ///
  /// ```dart
  /// await engine.startDebugging(
  ///   config: Struct()..fields['port'] = (Value()..numberValue = 5005),
  ///   message: 'Connect debugger to localhost:5005',
  /// );
  /// ```
  Future<void> startDebugging({
    Struct? config,
    String? message,
    CallOptions? options,
  }) async {
    final request = StartDebuggingRequest();

    if (config != null) {
      request.config = config;
    }
    if (message != null && message.isNotEmpty) {
      request.message = message;
    }

    await _client.startDebugging(request, options: options);
  }

  /// Checks that the Pulumi engine version satisfies the given range.
  ///
  /// This allows programs to ensure they are running against a compatible
  /// version of the Pulumi CLI. If the version is not compatible, the engine
  /// will return an error.
  ///
  /// The [versionRange] uses semver range syntax:
  /// - `>=3.0.0` - at least version 3.0.0
  /// - `!3.1.2` - not exactly version 3.1.2
  /// - `>=3.5.0 !3.7.7` - at least 3.5.0 AND not 3.7.7
  /// - `<3.4.0 || >3.8.0` - less than 3.4.0 OR greater than 3.8.0
  ///
  /// ```dart
  /// // Require Pulumi 3.0 or higher
  /// await engine.requirePulumiVersion('>=3.0.0');
  ///
  /// // Require 3.5+ but not the buggy 3.7.7 release
  /// await engine.requirePulumiVersion('>=3.5.0 !3.7.7');
  /// ```
  Future<void> requirePulumiVersion(
    String versionRange, {
    CallOptions? options,
  }) async {
    await _client.requirePulumiVersion(
      RequirePulumiVersionRequest(pulumiVersionRange: versionRange),
      options: options,
    );
  }

  /// Shuts down the gRPC channel gracefully.
  ///
  /// This waits for pending operations to complete before closing.
  /// After calling this method, no further operations can be performed.
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
