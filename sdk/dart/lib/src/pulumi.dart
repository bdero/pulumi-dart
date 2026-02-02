import 'dart:async';
import 'dart:io' show Platform;

import 'output.dart';
import 'resource.dart';
import 'runtime/engine.dart';
import 'runtime/runtime.dart';
import 'runtime/serialization.dart';

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

  /// The registered stack URN (populated after stack resource registration).
  String? _stackUrn;

  /// The Engine client for logging (may be null if not connected).
  final Engine? _engine;

  PulumiContext._({
    required this.project,
    required this.stack,
    required this.isDryRun,
    this.organization,
    Engine? engine,
  }) : _engine = engine;

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

  /// Logs a debug message to the Pulumi CLI output.
  ///
  /// Debug messages are only shown when verbose logging is enabled.
  /// Falls back to [print] when the Engine is not connected.
  ///
  /// ```dart
  /// await ctx.debug('Computed hash: $hash');
  /// ```
  Future<void> debug(String message) async {
    if (_engine != null) {
      await _engine.debug(message);
    } else {
      print('[DEBUG] $message');
    }
  }

  /// Logs an info message to the Pulumi CLI output.
  ///
  /// Info messages are shown during normal operation.
  /// Falls back to [print] when the Engine is not connected.
  ///
  /// ```dart
  /// await ctx.info('Deploying resources...');
  /// ```
  Future<void> info(String message) async {
    if (_engine != null) {
      await _engine.info(message);
    } else {
      print('[INFO] $message');
    }
  }

  /// Logs a warning message to the Pulumi CLI output.
  ///
  /// Warning messages indicate potential issues that don't prevent the
  /// operation from completing.
  /// Falls back to [print] when the Engine is not connected.
  ///
  /// ```dart
  /// await ctx.warning('Deprecated property used');
  /// ```
  Future<void> warning(String message) async {
    if (_engine != null) {
      await _engine.warning(message);
    } else {
      print('[WARNING] $message');
    }
  }

  /// Logs an error message to the Pulumi CLI output.
  ///
  /// Error messages indicate failures. Note that logging an error does not
  /// automatically fail the deployment - you should also throw an exception
  /// if the error should stop execution.
  /// Falls back to [print] when the Engine is not connected.
  ///
  /// ```dart
  /// await ctx.error('Failed to create resource: $reason');
  /// throw Exception('Deployment failed');
  /// ```
  Future<void> error(String message) async {
    if (_engine != null) {
      await _engine.error(message);
    } else {
      print('[ERROR] $message');
    }
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
    bool runtimeInitialized = false;
    Engine? standaloneEngine;

    try {
      // Initialize runtime if monitor address is provided
      if (monitorAddress != null && monitorAddress.isNotEmpty) {
        await Runtime.initialize(
          monitorAddress: monitorAddress,
          engineAddress: engineAddress,
          project: project,
          stack: stack,
          isDryRun: isDryRun,
          organization: organization,
        );
        runtimeInitialized = true;
      }

      // Get engine from Runtime if initialized, otherwise create standalone
      // if engine address was provided
      Engine? engine;
      if (runtimeInitialized) {
        engine = Runtime.instance.engine;
      } else if (engineAddress != null && engineAddress.isNotEmpty) {
        // Create standalone engine for logging-only mode
        standaloneEngine = Engine.connect(engineAddress);
        engine = standaloneEngine;
      }

      // Create context with engine reference for logging
      final context = PulumiContext._(
        project: project,
        stack: stack,
        isDryRun: isDryRun,
        organization: organization,
        engine: engine,
      );

      // Set as current context
      _currentContext = context;

      // Register the Stack resource with the Pulumi engine
      if (runtimeInitialized) {
        await _registerStackResource(context);
      }

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

        // Register stack exports on the previously registered Stack resource
        if (context._exports.isNotEmpty && context._stackUrn != null) {
          await _registerStackExports(context);
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
      // (This also shuts down the engine if connected)
      if (runtimeInitialized) {
        try {
          await Runtime.instance.shutdown();
        } catch (_) {
          // Ignore shutdown errors
          Runtime.reset();
        }
      }

      // Shutdown standalone engine if created
      if (standaloneEngine != null) {
        try {
          await standaloneEngine.shutdown();
        } catch (_) {
          // Ignore shutdown errors
        }
      }
    }
  }

  /// Registers the root Stack resource with the Pulumi engine.
  ///
  /// This is required before stack outputs can be registered. The Stack
  /// resource is a component resource that represents the root of the
  /// resource tree.
  static Future<void> _registerStackResource(PulumiContext context) async {
    final runtime = Runtime.instance;
    final monitor = runtime.monitor;

    // Register the Stack as a component resource (not custom)
    // The name follows the pattern: {project}-{stack}
    final response = await monitor.registerResource(
      type: 'pulumi:pulumi:Stack',
      name: '${runtime.project}-${runtime.stack}',
      custom: false,
    );

    // Store the URN for later use when registering outputs
    context._stackUrn = response.urn;
  }

  /// Registers stack exports with the Pulumi engine.
  ///
  /// Stack exports are registered as outputs on the root stack resource.
  static Future<void> _registerStackExports(PulumiContext context) async {
    final exports = context._exports;
    if (exports.isEmpty) return;

    final stackUrn = context._stackUrn;
    if (stackUrn == null) return;

    final monitor = Runtime.instance.monitor;

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
