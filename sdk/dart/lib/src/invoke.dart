import 'dart:async';

import 'input.dart';
import 'output.dart';
import 'runtime/runtime.dart';
import 'runtime/serialization.dart';

/// Options for controlling invoke behavior.
///
/// These options are used when calling provider functions (data sources).
///
/// ## Example
///
/// ```dart
/// final result = await invoke(
///   'aws:ec2/getAmi:getAmi',
///   {'owners': ['amazon']},
///   InvokeOptions(
///     provider: 'aws::us-east-1',
///     version: '5.0.0',
///   ),
/// );
/// ```
class InvokeOptions {
  /// An optional provider to use for this invoke.
  ///
  /// If not specified, the default provider for the function's package will be used.
  /// This is specified as a provider reference string (e.g., 'aws::default').
  final String? provider;

  /// The version of the provider plugin to use.
  ///
  /// If not specified, the latest version will be used.
  final String? version;

  /// A URL to download the provider plugin from.
  ///
  /// This is useful for using custom or pre-release provider versions.
  final String? pluginDownloadUrl;

  /// Creates invoke options.
  const InvokeOptions({
    this.provider,
    this.version,
    this.pluginDownloadUrl,
  });

  /// Creates a copy of this options with the given fields replaced.
  InvokeOptions copyWith({
    String? provider,
    String? version,
    String? pluginDownloadUrl,
  }) {
    return InvokeOptions(
      provider: provider ?? this.provider,
      version: version ?? this.version,
      pluginDownloadUrl: pluginDownloadUrl ?? this.pluginDownloadUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvokeOptions &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          version == other.version &&
          pluginDownloadUrl == other.pluginDownloadUrl;

  @override
  int get hashCode => Object.hash(provider, version, pluginDownloadUrl);

  @override
  String toString() =>
      'InvokeOptions(provider: $provider, version: $version, '
      'pluginDownloadUrl: $pluginDownloadUrl)';
}

/// Exception thrown when an invoke operation fails.
///
/// This is typically thrown when the provider returns validation errors
/// or when the function execution fails.
class InvokeException implements Exception {
  /// The function token that was invoked.
  final String token;

  /// The list of failures from the provider.
  final List<InvokeFailure> failures;

  InvokeException(this.token, this.failures);

  @override
  String toString() {
    final failureMessages =
        failures.map((f) => '  - ${f.property}: ${f.reason}').join('\n');
    return 'InvokeException: Invoke of "$token" failed:\n$failureMessages';
  }
}

/// Represents a single failure from an invoke operation.
class InvokeFailure {
  /// The property that caused the failure (may be empty).
  final String property;

  /// The reason for the failure.
  final String reason;

  InvokeFailure({required this.property, required this.reason});

  @override
  String toString() => 'InvokeFailure(property: $property, reason: $reason)';
}

/// Invokes a provider function and returns the result as an Output.
///
/// Provider functions are operations that don't create resources but return
/// data. For example, looking up an AMI ID or fetching availability zones.
///
/// The result is wrapped in an [Output] so it can be used as input to
/// resources and other functions, with proper dependency tracking.
///
/// ## Example
///
/// ```dart
/// // Look up an AMI
/// final ami = invoke<Map<String, dynamic>>(
///   'aws:ec2/getAmi:getAmi',
///   {
///     'owners': ['amazon'],
///     'mostRecent': true,
///     'filters': [
///       {'name': 'name', 'values': ['amzn2-ami-hvm-*']},
///     ],
///   },
/// );
///
/// // Use the result
/// final amiId = ami.apply((result) => result['id'] as String);
/// ```
///
/// Parameters:
/// - [token]: The function token (e.g., 'aws:ec2/getAmi:getAmi')
/// - [args]: The function arguments as a map of property names to values
/// - [options]: Optional invoke options (provider, version, etc.)
///
/// Returns an [Output] containing the function result as a [Map<String, dynamic>].
Output<Map<String, dynamic>> invoke(
  String token,
  Map<String, Input<Object?>?> args, [
  InvokeOptions? options,
]) {
  return Output.fromDataFuture(_invokeAsync(token, args, options));
}

/// Invokes a provider function and returns a Future with the raw result.
///
/// This is a lower-level API that returns a Future instead of an Output.
/// Use [invoke] instead if you need to chain the result with other Outputs.
///
/// ## Example
///
/// ```dart
/// final result = await invokeAsync(
///   'aws:ec2/getAmi:getAmi',
///   {'owners': ['amazon']},
/// );
/// print('AMI ID: ${result['id']}');
/// ```
///
/// Throws [InvokeException] if the invoke fails with validation errors.
/// Throws [StateError] if the Runtime has not been initialized.
Future<Map<String, dynamic>> invokeAsync(
  String token,
  Map<String, Input<Object?>?> args, [
  InvokeOptions? options,
]) async {
  final data = await _invokeAsync(token, args, options);
  if (!data.isKnown) {
    throw StateError(
      'Cannot access invoke result during preview when value is unknown.',
    );
  }
  return data.value;
}

/// Internal implementation of invoke that returns OutputData.
Future<OutputData<Map<String, dynamic>>> _invokeAsync(
  String token,
  Map<String, Input<Object?>?> args,
  InvokeOptions? options,
) async {
  final runtime = Runtime.instance;
  final monitor = runtime.monitor;

  // Serialize the arguments
  final serialized = await PropertySerializer.serialize(args);

  // If any input is unknown during preview, the result is also unknown
  if (!serialized.isKnown) {
    return OutputData<Map<String, dynamic>>.unknown(
      isSecret: serialized.containsSecrets,
      dependencies: serialized.dependencies,
    );
  }

  // Call the monitor's invoke method
  final response = await monitor.invoke(
    token: token,
    args: serialized.value.structValue,
    providerRef: options?.provider,
    version: options?.version,
    pluginDownloadUrl: options?.pluginDownloadUrl,
    acceptResources: true,
  );

  // Check for failures
  if (response.failures.isNotEmpty) {
    final failures = response.failures
        .map((f) => InvokeFailure(property: f.property, reason: f.reason))
        .toList();
    throw InvokeException(token, failures);
  }

  // Deserialize the result
  final result = PropertyDeserializer.deserializeStruct(response.return_1);

  // Determine if result contains secrets by checking the deserialized values
  final containsSecrets =
      serialized.containsSecrets || _containsSecrets(result);

  return OutputData<Map<String, dynamic>>.known(
    result,
    isSecret: containsSecrets,
    dependencies: serialized.dependencies,
  );
}

/// Checks if a deserialized value contains secrets.
bool _containsSecrets(dynamic value) {
  if (value is SecretValue) {
    return true;
  }
  if (value is Map) {
    return value.values.any(_containsSecrets);
  }
  if (value is List) {
    return value.any(_containsSecrets);
  }
  return false;
}

/// Invokes a provider function with typed result.
///
/// This is a convenience wrapper around [invoke] that allows you to specify
/// a transformer function to convert the raw result to a typed object.
///
/// ## Example
///
/// ```dart
/// class GetAmiResult {
///   final String id;
///   final String name;
///
///   GetAmiResult.fromMap(Map<String, dynamic> map)
///       : id = map['id'] as String,
///         name = map['name'] as String;
/// }
///
/// final ami = invokeTyped<GetAmiResult>(
///   'aws:ec2/getAmi:getAmi',
///   {'owners': ['amazon']},
///   (result) => GetAmiResult.fromMap(result),
/// );
/// ```
Output<T> invokeTyped<T>(
  String token,
  Map<String, Input<Object?>?> args,
  T Function(Map<String, dynamic>) transform, [
  InvokeOptions? options,
]) {
  return invoke(token, args, options).apply(transform);
}
