import 'dart:async';

import 'package:test/test.dart';
import 'package:pulumi/src/output.dart';

void main() {
  group('Output.of', () {
    test('creates output with known value', () async {
      final output = Output.of('hello');
      final data = await output.dataFuture;

      expect(data.value, equals('hello'));
      expect(data.isKnown, isTrue);
      expect(data.isSecret, isFalse);
      expect(data.dependencies, isEmpty);
    });

    test('future returns the value', () async {
      final output = Output.of(42);
      expect(await output.future, equals(42));
    });

    test('works with complex types', () async {
      final output = Output.of({'key': 'value', 'count': 5});
      final data = await output.dataFuture;

      expect(data.value, equals({'key': 'value', 'count': 5}));
      expect(data.isKnown, isTrue);
    });

    test('works with null values', () async {
      final output = Output<String?>.of(null);
      final data = await output.dataFuture;

      expect(data.value, isNull);
      expect(data.isKnown, isTrue);
    });
  });

  group('Output.fromFuture', () {
    test('creates output from future', () async {
      final future = Future.value('async-value');
      final output = Output.fromFuture(future);
      final data = await output.dataFuture;

      expect(data.value, equals('async-value'));
      expect(data.isKnown, isTrue);
      expect(data.isSecret, isFalse);
    });

    test('handles delayed futures', () async {
      final future = Future.delayed(
        const Duration(milliseconds: 10),
        () => 'delayed',
      );
      final output = Output.fromFuture(future);

      expect(await output.future, equals('delayed'));
    });

    test('propagates future errors', () async {
      final future = Future<String>.error(Exception('test error'));
      final output = Output.fromFuture(future);

      expect(output.future, throwsA(isA<Exception>()));
    });
  });

  group('Output.unknown', () {
    test('creates unknown output', () async {
      final output = Output<String>.unknown();
      final data = await output.dataFuture;

      expect(data.isKnown, isFalse);
      expect(data.isSecret, isFalse);
      expect(data.dependencies, isEmpty);
    });

    test('future throws on unknown value', () async {
      final output = Output<String>.unknown();

      expect(
        output.future,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('unknown'),
        )),
      );
    });
  });

  group('Output.apply', () {
    test('transforms known value', () async {
      final output = Output.of(5);
      final doubled = output.apply((v) => v * 2);

      expect(await doubled.future, equals(10));
    });

    test('preserves isKnown=false through transformation', () async {
      final output = Output<int>.unknown();
      final doubled = output.apply((v) => v * 2);
      final data = await doubled.dataFuture;

      expect(data.isKnown, isFalse);
    });

    test('preserves isSecret through transformation', () async {
      final output = Output.of('secret').asSecret();
      final transformed = output.apply((v) => v.toUpperCase());
      final data = await transformed.dataFuture;

      expect(data.isSecret, isTrue);
      expect(data.value, equals('SECRET'));
    });

    test('preserves dependencies through transformation', () async {
      final output = Output.of('value').withDependencies({'urn:res:1', 'urn:res:2'});
      final transformed = output.apply((v) => v.length);
      final data = await transformed.dataFuture;

      expect(data.dependencies, containsAll(['urn:res:1', 'urn:res:2']));
    });

    test('handles async transform function', () async {
      final output = Output.of(5);
      final asyncTransformed = output.apply((v) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return v * 3;
      });

      expect(await asyncTransformed.future, equals(15));
    });

    test('chains multiple apply calls', () async {
      final output = Output.of(2);
      final result = output
          .apply((v) => v + 3)
          .apply((v) => v * 2)
          .apply((v) => 'Result: $v');

      expect(await result.future, equals('Result: 10'));
    });
  });

  group('Output.all', () {
    test('combines multiple outputs', () async {
      final o1 = Output.of('a');
      final o2 = Output.of('b');
      final o3 = Output.of('c');

      final combined = Output.all([o1, o2, o3]);
      expect(await combined.future, equals(['a', 'b', 'c']));
    });

    test('returns empty list for empty input', () async {
      final combined = Output.all<String>([]);
      expect(await combined.future, isEmpty);
    });

    test('is known only if all inputs are known', () async {
      final o1 = Output.of('known');
      final o2 = Output<String>.unknown();

      final combined = Output.all([o1, o2]);
      final data = await combined.dataFuture;

      expect(data.isKnown, isFalse);
    });

    test('is secret if any input is secret', () async {
      final o1 = Output.of('public');
      final o2 = Output.of('secret').asSecret();
      final o3 = Output.of('public2');

      final combined = Output.all([o1, o2, o3]);
      final data = await combined.dataFuture;

      expect(data.isSecret, isTrue);
    });

    test('combines dependencies from all inputs', () async {
      final o1 = Output.of('a').withDependencies({'urn:1'});
      final o2 = Output.of('b').withDependencies({'urn:2', 'urn:3'});

      final combined = Output.all([o1, o2]);
      final data = await combined.dataFuture;

      expect(data.dependencies, containsAll(['urn:1', 'urn:2', 'urn:3']));
    });
  });

  group('Output.tuple2', () {
    test('combines two outputs', () async {
      final o1 = Output.of(1);
      final o2 = Output.of('two');

      final combined = Output.tuple2(o1, o2);
      final (v1, v2) = await combined.future;

      expect(v1, equals(1));
      expect(v2, equals('two'));
    });

    test('merges metadata correctly', () async {
      final o1 = Output.of(1).asSecret().withDependencies({'urn:1'});
      final o2 = Output.of(2).withDependencies({'urn:2'});

      final combined = Output.tuple2(o1, o2);
      final data = await combined.dataFuture;

      expect(data.isSecret, isTrue);
      expect(data.dependencies, containsAll(['urn:1', 'urn:2']));
    });
  });

  group('Output.tuple3', () {
    test('combines three outputs', () async {
      final o1 = Output.of(1);
      final o2 = Output.of('two');
      final o3 = Output.of(true);

      final combined = Output.tuple3(o1, o2, o3);
      final (v1, v2, v3) = await combined.future;

      expect(v1, equals(1));
      expect(v2, equals('two'));
      expect(v3, isTrue);
    });
  });

  group('Output.asSecret', () {
    test('marks output as secret', () async {
      final output = Output.of('password');
      final secret = output.asSecret();
      final data = await secret.dataFuture;

      expect(data.isSecret, isTrue);
      expect(data.value, equals('password'));
    });

    test('does not modify original output', () async {
      final output = Output.of('password');
      output.asSecret(); // create secret version

      final data = await output.dataFuture;
      expect(data.isSecret, isFalse);
    });

    test('idempotent - calling twice is same as once', () async {
      final output = Output.of('password').asSecret().asSecret();
      final data = await output.dataFuture;

      expect(data.isSecret, isTrue);
    });
  });

  group('Output.withDependencies', () {
    test('adds dependencies', () async {
      final output = Output.of('value').withDependencies({'urn:1', 'urn:2'});
      final data = await output.dataFuture;

      expect(data.dependencies, equals({'urn:1', 'urn:2'}));
    });

    test('accumulates dependencies', () async {
      final output = Output.of('value')
          .withDependencies({'urn:1'})
          .withDependencies({'urn:2'});
      final data = await output.dataFuture;

      expect(data.dependencies, containsAll(['urn:1', 'urn:2']));
    });
  });

  group('OutputData', () {
    test('copyWith creates modified copy', () {
      final data = OutputData<String>.known(
        'original',
        dependencies: {'urn:1'},
      );

      final modified = data.copyWith(isSecret: true);

      expect(modified.value, equals('original'));
      expect(modified.isKnown, isTrue);
      expect(modified.isSecret, isTrue);
      expect(modified.dependencies, equals({'urn:1'}));
    });

    test('map transforms value while preserving metadata', () {
      final data = OutputData<int>.known(
        5,
        isSecret: true,
        dependencies: {'urn:1'},
      );

      final mapped = data.map((v) => v * 2);

      expect(mapped.value, equals(10));
      expect(mapped.isKnown, isTrue);
      expect(mapped.isSecret, isTrue);
      expect(mapped.dependencies, equals({'urn:1'}));
    });

    test('map handles unknown values', () {
      final data = OutputData<int>.unknown();

      final mapped = data.map((v) => v * 2);

      expect(mapped.isKnown, isFalse);
    });
  });

  group('Extension methods', () {
    test('orElse provides default for null values', () async {
      final nullOutput = Output<String?>.of(null);
      final withDefault = nullOutput.orElse('default');

      expect(await withDefault.future, equals('default'));
    });

    test('orElse passes through non-null values', () async {
      final output = Output<String?>.of('actual');
      final withDefault = output.orElse('default');

      expect(await withDefault.future, equals('actual'));
    });

    test('concat combines string outputs', () async {
      final hello = Output.of('Hello, ');
      final world = Output.of('World!');
      final combined = hello.concat(world);

      expect(await combined.future, equals('Hello, World!'));
    });
  });
}
