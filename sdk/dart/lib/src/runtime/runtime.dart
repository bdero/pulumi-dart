import 'monitor.dart';

/// The singleton runtime context for Pulumi programs.
///
/// The Runtime singleton holds the gRPC connections and context needed for
/// Pulumi programs to communicate with the Pulumi engine. It is initialized
/// at program startup with connection addresses from CLI arguments.
///
/// ## Example
///
/// ```dart
/// // Initialize at program startup (typically in Pulumi.run)
/// await Runtime.initialize(
///   monitorAddress: 'localhost:50051',
///   project: 'my-project',
///   stack: 'dev',
/// );
///
/// // Access from anywhere in the program
/// final monitor = Runtime.instance.monitor;
/// ```
class Runtime {
  /// The ResourceMonitor gRPC client.
  final ResourceMonitor monitor;

  /// The current project name.
  final String project;

  /// The current stack name.
  final String stack;

  /// Whether this is a dry run (preview).
  final bool isDryRun;

  /// The organization name (if any).
  final String? organization;

  Runtime._({
    required this.monitor,
    required this.project,
    required this.stack,
    required this.isDryRun,
    this.organization,
  });

  static Runtime? _instance;

  /// Gets the current Runtime instance.
  ///
  /// Throws [StateError] if the Runtime has not been initialized.
  static Runtime get instance {
    if (_instance == null) {
      throw StateError(
        'Runtime has not been initialized. Call Runtime.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Returns true if the Runtime has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initializes the Runtime singleton.
  ///
  /// This must be called before any resources are created. It connects to
  /// the Pulumi engine's ResourceMonitor and sets up the runtime context.
  ///
  /// Parameters:
  /// - [monitorAddress]: The address of the ResourceMonitor gRPC service
  /// - [project]: The current project name
  /// - [stack]: The current stack name
  /// - [isDryRun]: Whether this is a preview (dry run) operation
  /// - [organization]: The organization name (optional)
  ///
  /// Throws [StateError] if the Runtime has already been initialized.
  static Future<Runtime> initialize({
    required String monitorAddress,
    required String project,
    required String stack,
    bool isDryRun = false,
    String? organization,
  }) async {
    if (_instance != null) {
      throw StateError(
        'Runtime has already been initialized. '
        'Call Runtime.reset() before re-initializing.',
      );
    }

    final monitor = ResourceMonitor.connect(monitorAddress);

    _instance = Runtime._(
      monitor: monitor,
      project: project,
      stack: stack,
      isDryRun: isDryRun,
      organization: organization,
    );

    return _instance!;
  }

  /// Initializes the Runtime with an existing ResourceMonitor.
  ///
  /// This is useful for testing or when you want to reuse a connection.
  static Runtime initializeWithMonitor({
    required ResourceMonitor monitor,
    required String project,
    required String stack,
    bool isDryRun = false,
    String? organization,
  }) {
    if (_instance != null) {
      throw StateError(
        'Runtime has already been initialized. '
        'Call Runtime.reset() before re-initializing.',
      );
    }

    _instance = Runtime._(
      monitor: monitor,
      project: project,
      stack: stack,
      isDryRun: isDryRun,
      organization: organization,
    );

    return _instance!;
  }

  /// Shuts down the Runtime and releases resources.
  ///
  /// This signals completion to the engine and closes gRPC connections.
  /// After calling this, the Runtime instance is no longer valid.
  Future<void> shutdown() async {
    await monitor.signalAndWaitForShutdown();
    await monitor.shutdown();
    _instance = null;
  }

  /// Resets the Runtime singleton without proper shutdown.
  ///
  /// This is primarily for testing. In production code, use [shutdown].
  static void reset() {
    _instance = null;
  }
}
