import 'dart:async';
import 'dart:io' show Platform;

import 'package:grpc/grpc.dart';

import 'output.dart';
import 'resource.dart';
import 'runtime/runtime.dart';
import 'runtime/serialization.dart';
import 'proto/pulumi/engine.pb.dart';
import 'proto/pulumi/engine.pbgrpc.dart';

/// The context passed to the user's Pulumi program callback.
///
/// Provides access to runtime information and methods for exporting stack outputs.
///
/// ## Example
///
/// ```dart
/// await Pulumi.run((ctx) async {
///   final bucket = Bucket('my-bucket', BucketArgs());
///   await bucket.registered;
///   ctx.export('bucketName', bucket.bucketName);
/// });
/// ```
class PulumiContext {
  /// The current project name.
  final String project;

  /// The current stack name.
  final String stack;

  /// Whether this is a dry run (preview).
  final bool isDryRun;

  /// The organization name (if any).
  final String? organization;

  /// Internal storage for exports.
  final Map<String, Output<Object?>> _exports = {};

  /// Internal list of tracked resource registrations.
  final List<Future<void>> _trackedRegistrations = [];

  PulumiContext._({
    required this.project,
    required this.stack,
    required this.isDryRun,
    this.organization,
  });

  /// Exports a stack output value.
  ///
  /// Exported values are displayed in the Pulumi CLI output and can be
  /// retrieved using `pulumi stack output` or referenced from other stacks
  /// using [StackReference].
  ///
  /// ```dart
  /// ctx.export('bucketName', bucket.bucketName);
  /// ctx.export('region', Output.of('us-east-1'));
  /// ```
  void export(String name, Output<Object?> value) {
    _exports[name] = value;
  }

  /// Exports a plain value as a stack output.
  ///
  /// This is a convenience method for exporting non-Output values.
  ///
  /// ```dart
  /// ctx.exportValue('version', '1.0.0');
  /// ```
  void exportValue<T>(String name, T value) {
    _exports[name] = Output.of(value);
  }

  /// Gets the current stack exports.
  ///
  /// This is primarily for internal use.
  Map<String, Output<Object?>> get exports => Map.unmodifiable(_exports);

  /// Tracks a resource registration for completion waiting.
  ///
  /// This is called automatically by resources when they register.
  /// Users don't typically need to call this directly.
  void trackResource(Resource resource) {
    _trackedRegistrations.add(resource.registered);
  }
}

/// A client for the Pulumi Engine gRPC service.
///
/// The Engine service provides logging and root resource management.
class EngineService {
  final ClientChannel _channel;
  final EngineClient _client;

  EngineService._(this._channel, this._client);

  /// Creates an EngineService connected to the given address.
  factory EngineService.connect(String address, {bool secure = false}) {
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

    final client = EngineClient(channel);
    return EngineService._(channel, client);
  }

  /// Logs a message to the Pulumi engine.
  Future<void> log(
    LogSeverity severity,
    String message, {
    String? urn,
    int? streamId,
    bool? ephemeral,
  }) async {
    final request = LogRequest(
      severity: severity,
      message: message,
      urn: urn,
      streamId: streamId,
      ephemeral: ephemeral,
    );
    await _client.log(request);
  }

  /// Logs a debug message.
  Future<void> debug(String message, {String? urn}) =>
      log(LogSeverity.DEBUG, message, urn: urn);

  /// Logs an info message.
  Future<void> info(String message, {String? urn}) =>
      log(LogSeverity.INFO, message, urn: urn);

  /// Logs a warning message.
  Future<void> warning(String message, {String? urn}) =>
      log(LogSeverity.WARNING, message, urn: urn);

  /// Logs an error message.
  Future<void> error(String message, {String? urn}) =>
      log(LogSeverity.ERROR, message, urn: urn);

  /// Gets the URN of the root resource.
  Future<String> getRootResource() async {
    final response = await _client.getRootResource(GetRootResourceRequest());
    return response.urn;
  }

  /// Sets the URN of the root resource.
  Future<void> setRootResource(String urn) async {
    await _client.setRootResource(SetRootResourceRequest(urn: urn));
  }

  /// Shuts down the gRPC channel.
  Future<void> shutdown() async {
    await _channel.shutdown();
  }

  /// Terminates the gRPC channel immediately.
  Future<void> terminate() async {
    await _channel.terminate();
  }
}

/// The main entry point for Pulumi programs.
///
/// Provides the [run] method which initializes the Pulumi runtime, executes
/// the user's program, and handles cleanup.
///
/// ## Example
///
/// ```dart
/// import 'package:pulumi/pulumi.dart';
///
/// Future<void> main() async {
///   await Pulumi.run((ctx) async {
///     // Define your infrastructure here
///     final bucket = Bucket('my-bucket', BucketArgs());
///
///     // Export stack outputs
///     ctx.export('bucketName', bucket.bucketName);
///   });
/// }
/// ```
class Pulumi {
  Pulumi._();

  /// The current context, if running inside [run].
  static PulumiContext? _currentContext;

  /// Gets the current Pulumi context.
  ///
  /// Returns `null` if not running inside [Pulumi.run].
  static PulumiContext? get currentContext => _currentContext;

  /// Runs a Pulumi program.
  ///
  /// This is the main entry point for user Pulumi programs. It:
  /// 1. Initializes the runtime with gRPC connections to the Pulumi engine
  /// 2. Executes the user's callback with a [PulumiContext]
  /// 3. Waits for all resource registrations to complete
  /// 4. Registers stack exports with the engine
  /// 5. Handles errors and reports them to the engine
  /// 6. Performs graceful shutdown
  ///
  /// The callback receives a [PulumiContext] that provides:
  /// - Runtime information (project, stack, isDryRun)
  /// - The [export] method for registering stack outputs
  ///
  /// ## Example
  ///
  /// ```dart
  /// await Pulumi.run((ctx) async {
  ///   print('Project: ${ctx.project}');
  ///   print('Stack: ${ctx.stack}');
  ///
  ///   final bucket = Bucket('my-bucket', BucketArgs());
  ///   await bucket.registered;
  ///
  ///   ctx.export('bucketArn', bucket.arn);
  /// });
  /// ```
  ///
  /// ## Environment Variables
  ///
  /// The runtime requires the following environment variables or CLI arguments:
  /// - `PULUMI_MONITOR`: Address of the ResourceMonitor gRPC service
  /// - `PULUMI_ENGINE`: Address of the Engine gRPC service (optional)
  /// - `PULUMI_PROJECT`: Current project name
  /// - `PULUMI_STACK`: Current stack name
  /// - `PULUMI_DRY_RUN`: Whether this is a preview (optional, defaults to false)
  /// - `PULUMI_ORGANIZATION`: Organization name (optional)
  ///
  /// ## Testing
  ///
  /// For testing, you can call [runWithOptions] to provide runtime settings
  /// directly, or run without initializing the runtime for mock behavior.
  static Future<void> run(
    FutureOr<void> Function(PulumiContext ctx) callback,
  ) async {
    // Get runtime settings from environment variables
    final monitorAddress = _getEnv('PULUMI_MONITOR');
    final engineAddress = _getEnv('PULUMI_ENGINE');
    final project = _getEnv('PULUMI_PROJECT') ?? 'unknown';
    final stack = _getEnv('PULUMI_STACK') ?? 'unknown';
    final isDryRun = _getEnv('PULUMI_DRY_RUN') == 'true';
    final organization = _getEnv('PULUMI_ORGANIZATION');

    await runWithOptions(
      callback,
      monitorAddress: monitorAddress,
      engineAddress: engineAddress,
      project: project,
      stack: stack,
      isDryRun: isDryRun,
      organization: organization,
    );
  }

  /// Runs a Pulumi program with explicit options.
  ///
  /// This is primarily for testing or advanced use cases where you want
  /// to provide runtime configuration directly rather than reading from
  /// environment variables.
  ///
  /// If [monitorAddress] is null, the runtime will operate in mock mode
  /// where resources are not actually registered with the Pulumi engine.
  static Future<void> runWithOptions(
    FutureOr<void> Function(PulumiContext ctx) callback, {
    String? monitorAddress,
    String? engineAddress,
    required String project,
    required String stack,
    bool isDryRun = false,
    String? organization,
  }) async {
    EngineService? engine;
    bool runtimeInitialized = false;

    try {
      // Initialize runtime if monitor address is provided
      if (monitorAddress != null && monitorAddress.isNotEmpty) {
        await Runtime.initialize(
          monitorAddress: monitorAddress,
          project: project,
          stack: stack,
          isDryRun: isDryRun,
          organization: organization,
        );
        runtimeInitialized = true;
      }

      // Connect to engine if address is provided
      if (engineAddress != null && engineAddress.isNotEmpty) {
        engine = EngineService.connect(engineAddress);
      }

      // Create context
      final context = PulumiContext._(
        project: project,
        stack: stack,
        isDryRun: isDryRun,
        organization: organization,
      );

      // Set as current context
      _currentContext = context;

      try {
        // Execute user callback
        await callback(context);

        // Wait a microtask to ensure all scheduled registrations have started
        await Future.microtask(() {});

        // Wait for all tracked resource registrations to complete
        if (context._trackedRegistrations.isNotEmpty) {
          await Future.wait(context._trackedRegistrations);
        }

        // If we have resources registered via Runtime, wait for any pending
        // registrations that weren't explicitly tracked
        if (runtimeInitialized) {
          // Give any pending microtasks a chance to complete
          await Future.delayed(Duration.zero);
        }

        // Register stack exports
        if (context._exports.isNotEmpty && runtimeInitialized) {
          await _registerStackExports(context._exports);
        }
      } catch (e, stackTrace) {
        // Report error to engine if available
        if (engine != null) {
          try {
            await engine.error('Pulumi program failed: $e\n$stackTrace');
          } catch (_) {
            // Ignore engine logging errors
          }
        }
        rethrow;
      }
    } finally {
      // Clear context
      _currentContext = null;

      // Shutdown runtime if we initialized it
      if (runtimeInitialized) {
        try {
          await Runtime.instance.shutdown();
        } catch (_) {
          // Ignore shutdown errors
          Runtime.reset();
        }
      }

      // Shutdown engine client
      if (engine != null) {
        try {
          await engine.shutdown();
        } catch (_) {
          // Ignore shutdown errors
        }
      }
    }
  }

  /// Registers stack exports with the Pulumi engine.
  ///
  /// Stack exports are registered as outputs on the root stack resource.
  static Future<void> _registerStackExports(
    Map<String, Output<Object?>> exports,
  ) async {
    if (exports.isEmpty) return;

    final runtime = Runtime.instance;
    final monitor = runtime.monitor;

    // Get the root resource URN (the stack itself)
    // The stack URN follows the pattern: urn:pulumi:stack::project::pulumi:pulumi:Stack::stackname
    final stackUrn =
        'urn:pulumi:${runtime.stack}::${runtime.project}::pulumi:pulumi:Stack::${runtime.stack}';

    // Serialize exports to protobuf format
    final serialized = await PropertySerializer.serializeOutputMap(exports);

    // Register the exports as stack outputs
    await monitor.registerResourceOutputs(
      urn: stackUrn,
      outputs: serialized.value.structValue,
    );
  }

  /// Gets an environment variable value.
  static String? _getEnv(String name) {
    // Check compile-time environment first (for Flutter/AOT)
    final compileTimeEnv = String.fromEnvironment(name, defaultValue: '');
    if (compileTimeEnv.isNotEmpty) return compileTimeEnv;

    // Fall back to runtime platform environment
    return Platform.environment[name];
  }
}
