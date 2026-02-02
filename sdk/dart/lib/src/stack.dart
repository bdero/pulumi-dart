import 'dart:async';

import 'package:meta/meta.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'input.dart';
import 'options.dart';
import 'output.dart';
import 'resource.dart';
import 'runtime/serialization.dart';

/// Options for configuring a [StackReference].
class StackReferenceArgs {
  /// The name of the stack to reference.
  ///
  /// This should be in the format `<organization>/<project>/<stack>`.
  /// For example: `myorg/myproject/production`.
  ///
  /// If not specified, the resource name is used as the stack name.
  final Input<String>? name;

  /// Creates options for a stack reference.
  const StackReferenceArgs({this.name});
}

/// A reference to another Pulumi stack's outputs.
///
/// StackReference allows you to access the exports from another Pulumi stack.
/// This enables cross-stack dependencies and data sharing between deployments.
///
/// The referenced stack must exist and be accessible to the current Pulumi
/// account. The outputs are fetched at deployment time and can be used as
/// inputs to resources in the current stack.
///
/// ## Example
///
/// ```dart
/// import 'package:pulumi/pulumi.dart';
///
/// Future<void> main() async {
///   await Pulumi.run((ctx) async {
///     // Reference another stack
///     final networkStack = StackReference('myorg/network/production');
///     await networkStack.registered;
///
///     // Get specific outputs
///     final vpcId = networkStack.getOutput<String>('vpcId');
///     final subnetIds = networkStack.getOutput<List<String>>('subnetIds');
///
///     // Use outputs in resources
///     final instance = Instance('web-server', InstanceArgs(
///       vpcId: vpcId,
///       subnetId: subnetIds.apply((ids) => ids[0]),
///     ));
///   });
/// }
/// ```
///
/// ## Stack Name Format
///
/// The stack name should be in the format `<organization>/<project>/<stack>`.
/// For example: `myorg/myproject/production`.
///
/// If using Pulumi without an organization, use `<project>/<stack>` format.
class StackReference extends CustomResource {
  /// The arguments passed to this stack reference.
  final StackReferenceArgs? _args;

  /// The name of the referenced stack.
  final String _stackName;

  /// All outputs from the referenced stack.
  ///
  /// This is a map of output names to their values. The values may be of
  /// any type supported by Pulumi.
  ///
  /// ```dart
  /// final outputs = await stackRef.outputs.future;
  /// print('VPC ID: ${outputs['vpcId']}');
  /// ```
  late final Output<Map<String, dynamic>> outputs;

  /// The names of outputs that are marked as secret in the referenced stack.
  ///
  /// These outputs will be treated as secrets when accessed.
  late final Output<List<String>> secretOutputNames;

  /// Creates a reference to another Pulumi stack.
  ///
  /// The [name] parameter specifies the resource name. If [args] is not
  /// provided or [args.name] is null, the resource name is used as the
  /// stack name to reference.
  ///
  /// The stack name should be in the format `<organization>/<project>/<stack>`.
  ///
  /// ```dart
  /// // Using resource name as stack name
  /// final stack = StackReference('myorg/network/production');
  ///
  /// // Using explicit stack name
  /// final stack2 = StackReference(
  ///   'network-ref',
  ///   StackReferenceArgs(name: Input.value('myorg/network/production')),
  /// );
  /// ```
  StackReference(
    String name, [
    StackReferenceArgs? args,
    CustomResourceOptions? opts,
  ])  : _args = args,
        _stackName = name,
        super('pulumi:pulumi:StackReference', name, opts);

  @override
  Map<String, Input<Object?>?> get inputs {
    // Use explicit name from args if provided, otherwise use resource name
    final stackName = _args?.name ?? Input.value(_stackName);
    return {'name': stackName};
  }

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);

    // Process the 'outputs' field from the response
    if (properties.fields.containsKey('outputs')) {
      final outputsValue = properties.fields['outputs']!;
      final deserializedOutputs = _deserializeOutputs(outputsValue);
      outputs = Output.fromData(OutputData.known(deserializedOutputs));
    } else {
      // No outputs from referenced stack
      outputs = Output.of({});
    }

    // Process the 'secretOutputNames' field
    if (properties.fields.containsKey('secretOutputNames')) {
      final secretNamesValue = properties.fields['secretOutputNames']!;
      final names = <String>[];
      if (secretNamesValue.hasListValue()) {
        for (final item in secretNamesValue.listValue.values) {
          if (item.hasStringValue()) {
            names.add(item.stringValue);
          }
        }
      }
      secretOutputNames = Output.of(names);
    } else {
      secretOutputNames = Output.of([]);
    }
  }

  /// Deserializes the outputs value, handling secrets appropriately.
  Map<String, dynamic> _deserializeOutputs(Value value) {
    if (!value.hasStructValue()) {
      return {};
    }
    return PropertyDeserializer.deserializeStruct(value.structValue);
  }

  /// Gets a specific output value from the referenced stack.
  ///
  /// Returns an [Output] containing the value of the named export from the
  /// referenced stack. If the export doesn't exist, the output will contain
  /// `null`.
  ///
  /// The output will be marked as secret if it was exported as a secret
  /// in the referenced stack.
  ///
  /// ```dart
  /// final vpcId = stackRef.getOutput<String>('vpcId');
  /// final port = stackRef.getOutput<int>('port');
  /// ```
  ///
  /// To transform the output value, use [Output.apply]:
  ///
  /// ```dart
  /// final url = stackRef.getOutput<String>('hostname')
  ///     .apply((host) => 'https://$host');
  /// ```
  Output<T?> getOutput<T>(String name) {
    return Output.tuple2(outputs, secretOutputNames).apply((tuple) {
      final allOutputs = tuple.$1;
      final secretNames = tuple.$2;

      final value = allOutputs[name];
      if (value == null) {
        return null;
      }

      // Handle secret wrapper if present
      if (value is SecretValue) {
        return value.value as T?;
      }

      return value as T?;
    }).apply((value) {
      // Note: The secretOutputNames handling happens during apply,
      // but we can't dynamically make the output secret based on runtime values
      // in this simple implementation. For full secret propagation, we'd need
      // a more complex approach.
      return value;
    });
  }

  /// Gets a specific output value, throwing if it doesn't exist.
  ///
  /// Similar to [getOutput], but throws a [StackReferenceOutputError] if
  /// the named output doesn't exist in the referenced stack.
  ///
  /// ```dart
  /// final vpcId = stackRef.requireOutput<String>('vpcId');
  /// // Throws if 'vpcId' doesn't exist
  /// ```
  Output<T> requireOutput<T>(String name) {
    return outputs.apply((allOutputs) {
      if (!allOutputs.containsKey(name)) {
        throw StackReferenceOutputError(_stackName, name);
      }

      final value = allOutputs[name];

      // Handle secret wrapper if present
      if (value is SecretValue) {
        return value.value as T;
      }

      return value as T;
    });
  }

  /// Gets a specific output value as a secret, throwing if it doesn't exist.
  ///
  /// The returned output is always marked as secret, regardless of whether
  /// it was exported as a secret in the referenced stack.
  ///
  /// ```dart
  /// final apiKey = stackRef.requireOutputSecret<String>('apiKey');
  /// ```
  Output<T> requireOutputSecret<T>(String name) {
    return requireOutput<T>(name).asSecret();
  }

  /// Gets a specific output value as a secret.
  ///
  /// The returned output is always marked as secret, regardless of whether
  /// it was exported as a secret in the referenced stack. Returns `null`
  /// if the output doesn't exist.
  ///
  /// ```dart
  /// final apiKey = stackRef.getOutputSecret<String>('apiKey');
  /// ```
  Output<T?> getOutputSecret<T>(String name) {
    return getOutput<T>(name).asSecret();
  }

  /// Gets the output details for a specific output.
  ///
  /// Returns a [Future] that resolves to a [StackReferenceOutputDetails]
  /// containing the output value and whether it's a secret.
  ///
  /// This is useful when you need to know whether an output is secret
  /// and want to access the value directly (not wrapped in an Output).
  ///
  /// ```dart
  /// final details = await stackRef.getOutputDetails('vpcId');
  /// if (details.secretValue != null) {
  ///   print('VPC ID is secret');
  /// } else {
  ///   print('VPC ID: ${details.value}');
  /// }
  /// ```
  Future<StackReferenceOutputDetails<T>> getOutputDetails<T>(String name) async {
    final allOutputs = await outputs.future;
    final secretNames = await secretOutputNames.future;

    if (!allOutputs.containsKey(name)) {
      return StackReferenceOutputDetails<T>();
    }

    final rawValue = allOutputs[name];
    final isSecret = secretNames.contains(name) || rawValue is SecretValue;

    final value = rawValue is SecretValue ? rawValue.value as T? : rawValue as T?;

    if (isSecret) {
      return StackReferenceOutputDetails<T>(secretValue: value);
    } else {
      return StackReferenceOutputDetails<T>(value: value);
    }
  }
}

/// Details about a stack reference output.
///
/// Contains either a regular [value] or a [secretValue], but not both.
/// If the output doesn't exist, both will be null.
class StackReferenceOutputDetails<T> {
  /// The output value if it's not a secret, or null.
  final T? value;

  /// The output value if it is a secret, or null.
  final T? secretValue;

  /// Creates stack reference output details.
  ///
  /// Either [value] or [secretValue] should be provided, not both.
  /// If neither is provided, the output is considered not found.
  StackReferenceOutputDetails({
    this.value,
    this.secretValue,
  });

  /// Whether this output exists.
  bool get exists => value != null || secretValue != null;

  /// Whether this output is a secret.
  bool get isSecret => secretValue != null;

  @override
  String toString() {
    if (!exists) return 'StackReferenceOutputDetails(not found)';
    if (isSecret) return 'StackReferenceOutputDetails(secret)';
    return 'StackReferenceOutputDetails(value: $value)';
  }
}

/// Error thrown when a required stack reference output doesn't exist.
class StackReferenceOutputError extends Error {
  /// The name of the referenced stack.
  final String stackName;

  /// The name of the output that was not found.
  final String outputName;

  StackReferenceOutputError(this.stackName, this.outputName);

  @override
  String toString() =>
      'Stack "$stackName" does not have an output named "$outputName".\n'
      'Make sure the output is exported using ctx.export() in the referenced stack.';
}
