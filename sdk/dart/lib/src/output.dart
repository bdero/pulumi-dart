import 'dart:async';

/// Internal data structure holding the resolved value and metadata of an Output.
class OutputData<T> {
  /// The resolved value. Null if isKnown is false.
  /// Stored as Object? internally to handle non-nullable T types when unknown.
  final Object? _value;

  /// Whether the value is known. During preview, some values may be unknown.
  final bool isKnown;

  /// Whether this value should be treated as a secret.
  final bool isSecret;

  /// The set of resources this output depends on (by URN).
  final Set<String> dependencies;

  OutputData._({
    required Object? value,
    required this.isKnown,
    required this.isSecret,
    required this.dependencies,
  }) : _value = value;

  /// Creates OutputData with a known value.
  factory OutputData.known(
    T value, {
    bool isSecret = false,
    Set<String> dependencies = const {},
  }) {
    return OutputData._(
      value: value,
      isKnown: true,
      isSecret: isSecret,
      dependencies: dependencies,
    );
  }

  /// Creates OutputData with an unknown value.
  factory OutputData.unknown({
    bool isSecret = false,
    Set<String> dependencies = const {},
  }) {
    return OutputData._(
      value: null,
      isKnown: false,
      isSecret: isSecret,
      dependencies: dependencies,
    );
  }

  /// Gets the value. Throws if isKnown is false.
  T get value {
    if (!isKnown) {
      throw StateError('Cannot access value of unknown OutputData');
    }
    return _value as T;
  }

  /// Gets the value or null if unknown.
  T? get valueOrNull => isKnown ? _value as T : null;

  /// Creates a copy with modified properties.
  OutputData<T> copyWith({
    Object? value,
    bool valueProvided = false,
    bool? isKnown,
    bool? isSecret,
    Set<String>? dependencies,
  }) {
    return OutputData._(
      value: valueProvided ? value : _value,
      isKnown: isKnown ?? this.isKnown,
      isSecret: isSecret ?? this.isSecret,
      dependencies: dependencies ?? this.dependencies,
    );
  }

  /// Maps the value to a new type while preserving metadata.
  /// If unknown, returns unknown OutputData of the new type.
  OutputData<U> map<U>(U Function(T) transform) {
    if (!isKnown) {
      return OutputData.unknown(
        isSecret: isSecret,
        dependencies: dependencies,
      );
    }
    return OutputData.known(
      transform(_value as T),
      isSecret: isSecret,
      dependencies: dependencies,
    );
  }
}

/// Represents an asynchronously computed value with dependency tracking.
///
/// Outputs are central to Pulumi's programming model. They represent values
/// that may not be known until deployment time, and they track which resources
/// depend on which other resources.
///
/// ## Creating Outputs
///
/// ```dart
/// // From a known value
/// final output = Output.of('hello');
///
/// // From a Future
/// final asyncOutput = Output.fromFuture(fetchData());
///
/// // Unknown value (for preview)
/// final unknown = Output<String>.unknown();
/// ```
///
/// ## Transforming Outputs
///
/// ```dart
/// final bucket = Bucket('my-bucket', BucketArgs());
/// final bucketUrl = bucket.arn.apply((arn) => 'https://$arn');
/// ```
///
/// ## Combining Outputs
///
/// ```dart
/// final combined = Output.all([output1, output2])
///     .apply((values) => '${values[0]}-${values[1]}');
/// ```
class Output<T> {
  final Future<OutputData<T>> _dataFuture;

  Output._(this._dataFuture);

  /// Creates an Output from a known value.
  ///
  /// The resulting Output will be immediately resolved with [isKnown] = true.
  factory Output.of(T value) {
    return Output._(Future.value(OutputData<T>.known(value)));
  }

  /// Creates an Output from a Future.
  ///
  /// The Output will resolve when the Future completes. The value will be
  /// marked as known.
  factory Output.fromFuture(Future<T> future) {
    return Output._(future.then((value) => OutputData<T>.known(value)));
  }

  /// Creates an unknown Output.
  ///
  /// Unknown outputs are used during preview when the actual value cannot
  /// be determined until deployment. Operations on unknown values propagate
  /// the unknown state.
  factory Output.unknown() {
    return Output._(Future.value(OutputData<T>.unknown()));
  }

  /// Creates an Output from existing OutputData.
  ///
  /// This is primarily used internally for constructing outputs from
  /// resource registration responses.
  factory Output.fromData(OutputData<T> data) {
    return Output._(Future.value(data));
  }

  /// Creates an Output from a Future that resolves to OutputData.
  ///
  /// This is primarily used internally.
  factory Output.fromDataFuture(Future<OutputData<T>> dataFuture) {
    return Output._(dataFuture);
  }

  /// The resolved value as a Future.
  ///
  /// Note: This will throw if called on an unknown value during preview.
  /// Prefer using [apply] for transformations that should handle unknown values.
  Future<T> get future => _dataFuture.then((data) {
    if (!data.isKnown) {
      throw StateError('Cannot access the value of an unknown Output. '
          'Use apply() to transform Output values safely.');
    }
    return data.value;
  });

  /// The raw data future, for internal use.
  Future<OutputData<T>> get dataFuture => _dataFuture;

  /// Transforms the output value while preserving dependencies and metadata.
  ///
  /// The transform function is only called if the value is known. If the
  /// output is unknown, the result will also be unknown.
  ///
  /// ```dart
  /// final greeting = name.apply((n) => 'Hello, $n!');
  /// ```
  ///
  /// The transform can return either a value or a Future:
  ///
  /// ```dart
  /// final asyncResult = input.apply((v) async {
  ///   final result = await someAsyncOperation(v);
  ///   return result;
  /// });
  /// ```
  Output<U> apply<U>(FutureOr<U> Function(T) transform) {
    return Output._(_dataFuture.then((data) async {
      if (!data.isKnown) {
        return OutputData<U>.unknown(
          isSecret: data.isSecret,
          dependencies: data.dependencies,
        );
      }
      final newValue = await transform(data.value);
      return OutputData<U>.known(
        newValue,
        isSecret: data.isSecret,
        dependencies: data.dependencies,
      );
    }));
  }

  /// Combines multiple outputs into a single output containing a list.
  ///
  /// The resulting output will:
  /// - Be known only if all inputs are known
  /// - Be secret if any input is secret
  /// - Depend on all resources that any input depends on
  ///
  /// ```dart
  /// final allValues = Output.all([output1, output2, output3]);
  /// final combined = allValues.apply((values) => values.join(', '));
  /// ```
  static Output<List<T>> all<T>(Iterable<Output<T>> outputs) {
    final outputList = outputs.toList();
    if (outputList.isEmpty) {
      return Output.of([]);
    }

    return Output._(Future.wait(outputList.map((o) => o._dataFuture))
        .then((dataList) {
      final allDeps = <String>{};
      for (final data in dataList) {
        allDeps.addAll(data.dependencies);
      }

      final allKnown = dataList.every((d) => d.isKnown);
      final anySecret = dataList.any((d) => d.isSecret);

      if (!allKnown) {
        return OutputData<List<T>>.unknown(
          isSecret: anySecret,
          dependencies: allDeps,
        );
      }

      return OutputData<List<T>>.known(
        dataList.map((d) => d.value).toList(),
        isSecret: anySecret,
        dependencies: allDeps,
      );
    }));
  }

  /// Combines two outputs into a tuple-like output.
  ///
  /// ```dart
  /// final combined = Output.tuple2(output1, output2)
  ///     .apply((t) => '${t.$1}-${t.$2}');
  /// ```
  static Output<(T1, T2)> tuple2<T1, T2>(Output<T1> o1, Output<T2> o2) {
    return Output._(Future.wait([o1._dataFuture, o2._dataFuture])
        .then((dataList) {
      final d1 = dataList[0] as OutputData<T1>;
      final d2 = dataList[1] as OutputData<T2>;

      final allKnown = d1.isKnown && d2.isKnown;
      final anySecret = d1.isSecret || d2.isSecret;
      final allDeps = {...d1.dependencies, ...d2.dependencies};

      if (!allKnown) {
        return OutputData<(T1, T2)>.unknown(
          isSecret: anySecret,
          dependencies: allDeps,
        );
      }

      return OutputData<(T1, T2)>.known(
        (d1.value, d2.value),
        isSecret: anySecret,
        dependencies: allDeps,
      );
    }));
  }

  /// Combines three outputs into a tuple-like output.
  static Output<(T1, T2, T3)> tuple3<T1, T2, T3>(
      Output<T1> o1, Output<T2> o2, Output<T3> o3) {
    return Output._(Future.wait([o1._dataFuture, o2._dataFuture, o3._dataFuture])
        .then((dataList) {
      final d1 = dataList[0] as OutputData<T1>;
      final d2 = dataList[1] as OutputData<T2>;
      final d3 = dataList[2] as OutputData<T3>;

      final allKnown = d1.isKnown && d2.isKnown && d3.isKnown;
      final anySecret = d1.isSecret || d2.isSecret || d3.isSecret;
      final allDeps = {...d1.dependencies, ...d2.dependencies, ...d3.dependencies};

      if (!allKnown) {
        return OutputData<(T1, T2, T3)>.unknown(
          isSecret: anySecret,
          dependencies: allDeps,
        );
      }

      return OutputData<(T1, T2, T3)>.known(
        (d1.value, d2.value, d3.value),
        isSecret: anySecret,
        dependencies: allDeps,
      );
    }));
  }

  /// Marks this output as containing secret data.
  ///
  /// Secret outputs are encrypted in the state file and their values are
  /// not shown in logs or the Pulumi console.
  ///
  /// ```dart
  /// final password = Output.of('my-secret-password').asSecret();
  /// ```
  Output<T> asSecret() {
    return Output._(_dataFuture.then((data) => data.copyWith(isSecret: true)));
  }

  /// Adds resource dependencies to this output.
  ///
  /// This is used internally to track which resources an output depends on.
  Output<T> withDependencies(Set<String> additionalDeps) {
    return Output._(_dataFuture.then((data) => data.copyWith(
      dependencies: {...data.dependencies, ...additionalDeps},
    )));
  }
}

/// Extension methods for working with nullable Output values.
extension OutputNullableExtension<T> on Output<T?> {
  /// Maps a nullable output to a non-nullable output with a default value.
  Output<T> orElse(T defaultValue) {
    return apply((value) => value ?? defaultValue);
  }
}

/// Extension methods for String outputs.
extension OutputStringExtension on Output<String> {
  /// Concatenates this string output with another.
  Output<String> concat(Output<String> other) {
    return Output.tuple2(this, other).apply((t) => '${t.$1}${t.$2}');
  }
}
