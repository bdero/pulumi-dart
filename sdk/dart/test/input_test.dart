import 'dart:async';

import 'package:test/test.dart';
import 'package:pulumi/src/input.dart';
import 'package:pulumi/src/output.dart';

void main() {
  group('InputValue', () {
    test('creates input with value', () {
      final input = Input.value('hello');

      expect(input, isA<InputValue<String>>());
      expect((input as InputValue<String>).value, equals('hello'));
    });

    test('toOutput returns Output with value', () async {
      final input = Input.value(42);
      final output = input.toOutput();
      final data = await output.dataFuture;

      expect(data.value, equals(42));
      expect(data.isKnown, isTrue);
      expect(data.isSecret, isFalse);
    });

    test('equality works correctly', () {
      final input1 = Input.value('test');
      final input2 = Input.value('test');
      final input3 = Input.value('other');

      expect(input1, equals(input2));
      expect(input1, isNot(equals(input3)));
    });

    test('hashCode is consistent with equality', () {
      final input1 = Input.value('test');
      final input2 = Input.value('test');

      expect(input1.hashCode, equals(input2.hashCode));
    });

    test('toString provides useful representation', () {
      final input = Input.value('hello');

      expect(input.toString(), equals('InputValue(hello)'));
    });

    test('works with complex types', () async {
      final input = Input.value({'key': 'value', 'count': 5});
      final output = input.toOutput();

      expect(await output.future, equals({'key': 'value', 'count': 5}));
    });

    test('works with null values', () async {
      final input = Input<String?>.value(null);
      final output = input.toOutput();
      final data = await output.dataFuture;

      expect(data.value, isNull);
      expect(data.isKnown, isTrue);
    });
  });

  group('InputOutput', () {
    test('creates input with output', () {
      final output = Output.of('hello');
      final input = Input.output(output);

      expect(input, isA<InputOutput<String>>());
      expect((input as InputOutput<String>).output, same(output));
    });

    test('toOutput returns the wrapped output', () async {
      final output = Output.of(42);
      final input = Input.output(output);
      final resultOutput = input.toOutput();

      expect(await resultOutput.future, equals(42));
    });

    test('preserves output metadata', () async {
      final output = Output.of('secret').asSecret().withDependencies({'urn:1'});
      final input = Input.output(output);
      final resultOutput = input.toOutput();
      final data = await resultOutput.dataFuture;

      expect(data.isSecret, isTrue);
      expect(data.dependencies, contains('urn:1'));
    });

    test('preserves unknown state', () async {
      final output = Output<String>.unknown();
      final input = Input.output(output);
      final resultOutput = input.toOutput();
      final data = await resultOutput.dataFuture;

      expect(data.isKnown, isFalse);
    });

    test('toString provides useful representation', () {
      final output = Output.of('hello');
      final input = Input.output(output);

      expect(input.toString(), startsWith('InputOutput('));
    });
  });

  group('InputFuture', () {
    test('creates input with future', () {
      final future = Future.value('hello');
      final input = Input.future(future);

      expect(input, isA<InputFuture<String>>());
      expect((input as InputFuture<String>).future, same(future));
    });

    test('toOutput resolves future to output', () async {
      final future = Future.value(42);
      final input = Input.future(future);
      final output = input.toOutput();

      expect(await output.future, equals(42));
    });

    test('handles delayed futures', () async {
      final future = Future.delayed(
        const Duration(milliseconds: 10),
        () => 'delayed',
      );
      final input = Input.future(future);
      final output = input.toOutput();

      expect(await output.future, equals('delayed'));
    });

    test('propagates future errors', () async {
      final future = Future<String>.error(Exception('test error'));
      final input = Input.future(future);
      final output = input.toOutput();

      expect(output.future, throwsA(isA<Exception>()));
    });

    test('toString provides useful representation', () {
      final future = Future.value('hello');
      final input = Input.future(future);

      expect(input.toString(), startsWith('InputFuture('));
    });
  });

  group('Pattern matching', () {
    test('exhaustive switch on Input variants', () async {
      Future<T> resolveInput<T>(Input<T> input) async {
        return switch (input) {
          InputValue(:final value) => value,
          InputOutput(:final output) => await output.future,
          InputFuture(:final future) => await future,
        };
      }

      expect(await resolveInput(Input.value('value')), equals('value'));
      expect(
        await resolveInput(Input.output(Output.of('output'))),
        equals('output'),
      );
      expect(
        await resolveInput(Input.future(Future.value('future'))),
        equals('future'),
      );
    });

    test('type checking with is operator', () {
      final valueInput = Input.value('test');
      final outputInput = Input.output(Output.of('test'));
      final futureInput = Input.future(Future.value('test'));

      expect(valueInput is InputValue<String>, isTrue);
      expect(valueInput is InputOutput<String>, isFalse);
      expect(valueInput is InputFuture<String>, isFalse);

      expect(outputInput is InputOutput<String>, isTrue);
      expect(futureInput is InputFuture<String>, isTrue);
    });
  });

  group('InputExtension', () {
    test('toInput on value creates InputValue', () {
      final input = 'hello'.toInput();

      expect(input, isA<InputValue<String>>());
      expect((input as InputValue<String>).value, equals('hello'));
    });

    test('toInput on int creates InputValue', () async {
      final input = 42.toInput();
      final output = input.toOutput();

      expect(await output.future, equals(42));
    });

    test('toInput on complex type creates InputValue', () async {
      final map = {'key': 'value'};
      final input = map.toInput();
      final output = input.toOutput();

      expect(await output.future, equals({'key': 'value'}));
    });
  });

  group('InputOutputExtension', () {
    test('toInput on Output creates InputOutput', () {
      final output = Output.of('hello');
      final input = output.toInput();

      expect(input, isA<InputOutput<String>>());
      expect((input as InputOutput<String>).output, same(output));
    });
  });

  group('InputFutureExtension', () {
    test('toInput on Future creates InputFuture', () {
      final future = Future.value('hello');
      final input = future.toInput();

      expect(input, isA<InputFuture<String>>());
      expect((input as InputFuture<String>).future, same(future));
    });
  });

  group('InputUtils', () {
    group('resolve', () {
      test('resolves InputValue', () async {
        final input = Input.value('test');
        expect(await InputUtils.resolve(input), equals('test'));
      });

      test('resolves InputOutput', () async {
        final input = Input.output(Output.of('test'));
        expect(await InputUtils.resolve(input), equals('test'));
      });

      test('resolves InputFuture', () async {
        final input = Input.future(Future.value('test'));
        expect(await InputUtils.resolve(input), equals('test'));
      });
    });

    group('isKnown', () {
      test('returns true for InputValue', () async {
        final input = Input.value('test');
        expect(await InputUtils.isKnown(input), isTrue);
      });

      test('returns true for known InputOutput', () async {
        final input = Input.output(Output.of('test'));
        expect(await InputUtils.isKnown(input), isTrue);
      });

      test('returns false for unknown InputOutput', () async {
        final input = Input.output(Output<String>.unknown());
        expect(await InputUtils.isKnown(input), isFalse);
      });

      test('returns true for InputFuture', () async {
        final input = Input.future(Future.value('test'));
        expect(await InputUtils.isKnown(input), isTrue);
      });
    });

    group('map', () {
      test('maps InputValue', () async {
        final input = Input.value(5);
        final mapped = InputUtils.map(input, (v) => v * 2);

        expect(mapped, isA<InputValue<int>>());
        expect((mapped as InputValue<int>).value, equals(10));
      });

      test('maps InputOutput', () async {
        final input = Input.output(Output.of(5));
        final mapped = InputUtils.map(input, (v) => v * 2);

        expect(mapped, isA<InputOutput<int>>());
        final output = (mapped as InputOutput<int>).output;
        expect(await output.future, equals(10));
      });

      test('maps InputFuture', () async {
        final input = Input.future(Future.value(5));
        final mapped = InputUtils.map(input, (v) => v * 2);

        expect(mapped, isA<InputFuture<int>>());
        final future = (mapped as InputFuture<int>).future;
        expect(await future, equals(10));
      });

      test('changes type', () async {
        final input = Input.value(42);
        final mapped = InputUtils.map(input, (v) => 'Number: $v');

        expect(mapped, isA<InputValue<String>>());
        expect((mapped as InputValue<String>).value, equals('Number: 42'));
      });
    });
  });

  group('InputOrNull', () {
    test('can be null', () {
      InputOrNull<String> input;
      input = null;
      expect(input, isNull);
    });

    test('can hold InputValue', () {
      InputOrNull<String> input = Input.value('test');
      expect(input, isA<InputValue<String>>());
    });

    test('can hold InputOutput', () {
      InputOrNull<String> input = Input.output(Output.of('test'));
      expect(input, isA<InputOutput<String>>());
    });

    test('can hold InputFuture', () {
      InputOrNull<String> input = Input.future(Future.value('test'));
      expect(input, isA<InputFuture<String>>());
    });
  });
}
