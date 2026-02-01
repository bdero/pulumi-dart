/// Integration test Pulumi program using the random provider.
///
/// This creates a simple random string resource to verify the end-to-end
/// flow works correctly with the Dart SDK and language host.

import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:pulumi/pulumi.dart';

/// A custom resource representing a random string from the pulumi-random provider.
///
/// Type: random:index/randomString:RandomString
class RandomString extends CustomResource {
  late final Output<String> result;
  late final Output<int> length;

  final RandomStringArgs _args;

  RandomString(
    String name,
    RandomStringArgs args, {
    CustomResourceOptions? options,
  })  : _args = args,
        super('random:index/randomString:RandomString', name, options);

  @override
  Map<String, Input<Object?>?> get inputs => {
        'length': _args.length,
        if (_args.special != null) 'special': _args.special,
        if (_args.upper != null) 'upper': _args.upper,
        if (_args.lower != null) 'lower': _args.lower,
        if (_args.numeric != null) 'numeric': _args.numeric,
        if (_args.minLower != null) 'minLower': _args.minLower,
        if (_args.minUpper != null) 'minUpper': _args.minUpper,
        if (_args.minNumeric != null) 'minNumeric': _args.minNumeric,
        if (_args.minSpecial != null) 'minSpecial': _args.minSpecial,
        if (_args.overrideSpecial != null)
          'overrideSpecial': _args.overrideSpecial,
        if (_args.keepers != null) 'keepers': _args.keepers,
      };

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    result = Output.of(properties.fields['result']?.stringValue ?? '');
    length = Output.of(
        properties.fields['length']?.numberValue.toInt() ?? _args.lengthValue);
  }
}

/// Arguments for creating a RandomString resource.
class RandomStringArgs {
  /// The length of the random string.
  final Input<int> length;

  /// Include special characters in the result. Default is true.
  final Input<bool>? special;

  /// Include uppercase letters in the result. Default is true.
  final Input<bool>? upper;

  /// Include lowercase letters in the result. Default is true.
  final Input<bool>? lower;

  /// Include numeric characters in the result. Default is true.
  final Input<bool>? numeric;

  /// Minimum number of lowercase characters in the result.
  final Input<int>? minLower;

  /// Minimum number of uppercase characters in the result.
  final Input<int>? minUpper;

  /// Minimum number of numeric characters in the result.
  final Input<int>? minNumeric;

  /// Minimum number of special characters in the result.
  final Input<int>? minSpecial;

  /// Supply your own list of special characters.
  final Input<String>? overrideSpecial;

  /// Map of keepers that will trigger recreation when changed.
  final Input<Map<String, String>>? keepers;

  /// Helper to get the integer value from the length input.
  int get lengthValue {
    switch (length) {
      case InputValue<int>(:final value):
        return value;
      case InputOutput<int>():
      case InputFuture<int>():
        return 0; // Will be resolved later
    }
  }

  RandomStringArgs({
    required this.length,
    this.special,
    this.upper,
    this.lower,
    this.numeric,
    this.minLower,
    this.minUpper,
    this.minNumeric,
    this.minSpecial,
    this.overrideSpecial,
    this.keepers,
  });
}

Future<void> main() async {
  await Pulumi.run((ctx) async {
    // Create a simple random string
    final randomStr = RandomString(
      'test-random-string',
      RandomStringArgs(
        length: Input.value(16),
        special: Input.value(false),
        upper: Input.value(true),
        lower: Input.value(true),
        numeric: Input.value(true),
      ),
    );

    // Wait for registration to complete
    await randomStr.registered;

    // Export the result
    ctx.export('randomStringResult', randomStr.result);
    ctx.export('randomStringId', randomStr.id);
    ctx.export('randomStringUrn', randomStr.urn);
    ctx.export('randomStringLength', randomStr.length);
  });
}
