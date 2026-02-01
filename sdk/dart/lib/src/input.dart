import 'dart:async';

import 'output.dart';

/// Represents a value that can be provided to a resource input.
///
/// Input values can be:
/// - A plain value ([InputValue])
/// - An [Output] from another resource ([InputOutput])
/// - A [Future] that will resolve to a value ([InputFuture])
///
/// This sealed class enables type-safe handling of all input variants using
/// Dart 3 pattern matching:
///
/// ```dart
/// Future<T> resolveInput<T>(Input<T> input) async {
///   return switch (input) {
///     InputValue(:final value) => value,
///     InputOutput(:final output) => await output.future,
///     InputFuture(:final future) => await future,
///   };
/// }
/// ```
sealed class Input<T> {
  const Input();

  /// Creates an Input from a plain value.
  factory Input.value(T value) = InputValue<T>;

  /// Creates an Input from an Output.
  factory Input.output(Output<T> output) = InputOutput<T>;

  /// Creates an Input from a Future.
  factory Input.future(Future<T> future) = InputFuture<T>;

  /// Resolves this input to an Output.
  ///
  /// This is the primary way to convert any Input variant to a unified
  /// Output type for resource registration.
  Output<T> toOutput();
}

/// An Input containing a plain value.
///
/// Use this when you have a known value at construction time:
///
/// ```dart
/// final bucket = Bucket('my-bucket', BucketArgs(
///   acl: Input.value('private'),
/// ));
/// ```
final class InputValue<T> extends Input<T> {
  /// The wrapped value.
  final T value;

  /// Creates an InputValue wrapping [value].
  const InputValue(this.value);

  @override
  Output<T> toOutput() => Output.of(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputValue<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'InputValue($value)';
}

/// An Input containing an Output from another resource.
///
/// Use this to chain resource outputs as inputs to other resources:
///
/// ```dart
/// final bucket = Bucket('my-bucket', BucketArgs());
/// final instance = Instance('my-instance', InstanceArgs(
///   userData: Input.output(bucket.arn.apply((arn) => 'bucket=$arn')),
/// ));
/// ```
final class InputOutput<T> extends Input<T> {
  /// The wrapped Output.
  final Output<T> output;

  /// Creates an InputOutput wrapping [output].
  const InputOutput(this.output);

  @override
  Output<T> toOutput() => output;

  @override
  String toString() => 'InputOutput($output)';
}

/// An Input containing a Future that will resolve to a value.
///
/// Use this for values that need async computation:
///
/// ```dart
/// final bucket = Bucket('my-bucket', BucketArgs(
///   tags: Input.future(fetchTagsFromApi()),
/// ));
/// ```
final class InputFuture<T> extends Input<T> {
  /// The wrapped Future.
  final Future<T> future;

  /// Creates an InputFuture wrapping [future].
  const InputFuture(this.future);

  @override
  Output<T> toOutput() => Output.fromFuture(future);

  @override
  String toString() => 'InputFuture($future)';
}

/// Extension methods for converting values to Input.
///
/// This allows for more ergonomic usage without explicitly wrapping values:
///
/// ```dart
/// // Instead of:
/// Input.value('private')
///
/// // You can write:
/// 'private'.toInput()
/// ```
extension InputExtension<T> on T {
  /// Converts this value to an [InputValue].
  Input<T> toInput() => Input.value(this);
}

/// Extension methods for converting Outputs to Input.
extension InputOutputExtension<T> on Output<T> {
  /// Converts this Output to an [InputOutput].
  Input<T> toInput() => Input.output(this);
}

/// Extension methods for converting Futures to Input.
extension InputFutureExtension<T> on Future<T> {
  /// Converts this Future to an [InputFuture].
  Input<T> toInput() => Input.future(this);
}

/// Utility functions for working with Input values.
class InputUtils {
  InputUtils._();

  /// Resolves an Input to its underlying value.
  ///
  /// This is useful when you need the actual value synchronously or
  /// asynchronously:
  ///
  /// ```dart
  /// final value = await InputUtils.resolve(input);
  /// ```
  static Future<T> resolve<T>(Input<T> input) async {
    return switch (input) {
      InputValue(:final value) => value,
      InputOutput(:final output) => await output.future,
      InputFuture(:final future) => await future,
    };
  }

  /// Checks if an Input contains a known value.
  ///
  /// Returns true for [InputValue], and checks the underlying Output
  /// for [InputOutput].
  static Future<bool> isKnown<T>(Input<T> input) async {
    return switch (input) {
      InputValue() => true,
      InputOutput(:final output) => (await output.dataFuture).isKnown,
      InputFuture() => true, // Futures always resolve to known values
    };
  }

  /// Transforms an Input value using the provided function.
  ///
  /// ```dart
  /// final uppercased = InputUtils.map(
  ///   Input.value('hello'),
  ///   (s) => s.toUpperCase(),
  /// );
  /// ```
  static Input<U> map<T, U>(Input<T> input, U Function(T) transform) {
    return switch (input) {
      InputValue(:final value) => Input.value(transform(value)),
      InputOutput(:final output) => Input.output(output.apply(transform)),
      InputFuture(:final future) => Input.future(future.then(transform)),
    };
  }
}

/// Type alias for optional inputs.
///
/// Many resource properties are optional. This typedef makes it clear
/// that a property can be omitted:
///
/// ```dart
/// class BucketArgs {
///   final InputOrNull<String> acl;
///   final InputOrNull<Map<String, String>> tags;
/// }
/// ```
typedef InputOrNull<T> = Input<T>?;
