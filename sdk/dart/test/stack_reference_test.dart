import 'package:test/test.dart';

import 'package:pulumi/src/stack.dart';
import 'package:pulumi/src/output.dart';
import 'package:pulumi/src/input.dart';
import 'package:pulumi/src/options.dart';

void main() {
  group('StackReference', () {
    test('has correct type', () {
      final stackRef = StackReference('myorg/myproject/production');
      expect(stackRef.type, equals('pulumi:pulumi:StackReference'));
      expect(stackRef.name, equals('myorg/myproject/production'));
    });

    test('registered future completes', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;
      // Should complete without error
    });

    test('urn is available after registration', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final urnValue = await stackRef.urn.future;
      expect(urnValue, contains('pulumi:pulumi:StackReference'));
      expect(urnValue, contains('myorg/myproject/production'));
    });

    test('id is available after registration', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final idValue = await stackRef.id.future;
      expect(idValue, isA<String>());
    });

    test('uses resource name as stack name by default', () {
      final stackRef = StackReference('myorg/network/production');
      expect(stackRef.inputs['name'], isA<InputValue<Object?>>());

      final nameInput = stackRef.inputs['name'] as InputValue<Object?>;
      expect(nameInput.value, equals('myorg/network/production'));
    });

    test('uses explicit stack name from args when provided', () {
      final stackRef = StackReference(
        'network-ref',
        StackReferenceArgs(name: Input.value('myorg/network/production')),
      );

      final nameInput = stackRef.inputs['name'];
      // When we pass Input.value(...), it's still an InputValue, not InputOutput
      expect(nameInput, isA<InputValue<Object?>>());
      final inputValue = nameInput as InputValue<Object?>;
      expect(inputValue.value, equals('myorg/network/production'));
    });

    test('accepts CustomResourceOptions', () async {
      final stackRef = StackReference(
        'myorg/myproject/production',
        null,
        CustomResourceOptions(protect: true),
      );

      await stackRef.registered;
      expect(stackRef.options?.protect, isTrue);
    });

    test('outputs is initialized after registration', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      // outputs should be available (empty in mock mode)
      final outputsValue = await stackRef.outputs.future;
      expect(outputsValue, isA<Map<String, dynamic>>());
    });

    test('secretOutputNames is initialized after registration', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      // secretOutputNames should be available (empty in mock mode)
      final secretNames = await stackRef.secretOutputNames.future;
      expect(secretNames, isA<List<String>>());
    });
  });

  group('StackReference.getOutput', () {
    test('returns Output containing null for missing key', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final output = stackRef.getOutput<String>('nonexistent');
      final value = await output.future;
      expect(value, isNull);
    });

    test('returns typed Output', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final output = stackRef.getOutput<String>('vpcId');
      expect(output, isA<Output<String?>>());
    });
  });

  group('StackReference.requireOutput', () {
    test('throws StackReferenceOutputError for missing key', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final output = stackRef.requireOutput<String>('nonexistent');

      await expectLater(
        output.future,
        throwsA(isA<StackReferenceOutputError>()),
      );
    });

    test('error message includes stack and output names', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final output = stackRef.requireOutput<String>('missing');

      try {
        await output.future;
        fail('Expected StackReferenceOutputError');
      } on StackReferenceOutputError catch (e) {
        expect(e.stackName, equals('myorg/myproject/production'));
        expect(e.outputName, equals('missing'));
        expect(e.toString(), contains('myorg/myproject/production'));
        expect(e.toString(), contains('missing'));
        expect(e.toString(), contains('ctx.export()'));
      }
    });
  });

  group('StackReference.getOutputSecret', () {
    test('returns Output marked as secret', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final output = stackRef.getOutputSecret<String>('apiKey');
      final data = await output.dataFuture;

      // The output should be marked as secret
      expect(data.isSecret, isTrue);
    });
  });

  group('StackReference.requireOutputSecret', () {
    test('throws for missing key', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final output = stackRef.requireOutputSecret<String>('missing');

      await expectLater(
        output.future,
        throwsA(isA<StackReferenceOutputError>()),
      );
    });
  });

  group('StackReference.getOutputDetails', () {
    test('returns details for non-existent output', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final details = await stackRef.getOutputDetails<String>('nonexistent');

      expect(details.exists, isFalse);
      expect(details.isSecret, isFalse);
      expect(details.value, isNull);
      expect(details.secretValue, isNull);
    });

    test('returns StackReferenceOutputDetails type', () async {
      final stackRef = StackReference('myorg/myproject/production');
      await stackRef.registered;

      final details = await stackRef.getOutputDetails<String>('key');

      expect(details, isA<StackReferenceOutputDetails<String>>());
    });
  });

  group('StackReferenceOutputDetails', () {
    test('exists is false when both values are null', () {
      final details = StackReferenceOutputDetails<String>();

      expect(details.exists, isFalse);
      expect(details.isSecret, isFalse);
    });

    test('isSecret is true when secretValue is set', () {
      final details = StackReferenceOutputDetails<String>(
        secretValue: 'secret-value',
      );

      expect(details.exists, isTrue);
      expect(details.isSecret, isTrue);
      expect(details.secretValue, equals('secret-value'));
    });

    test('isSecret is false when regular value is set', () {
      final details = StackReferenceOutputDetails<String>(
        value: 'regular-value',
      );

      expect(details.exists, isTrue);
      expect(details.isSecret, isFalse);
      expect(details.value, equals('regular-value'));
    });

    test('toString handles different cases', () {
      final notFound = StackReferenceOutputDetails<String>();
      expect(notFound.toString(), contains('not found'));

      final secret = StackReferenceOutputDetails<String>(
        secretValue: 'secret',
      );
      expect(secret.toString(), contains('secret'));

      final regular = StackReferenceOutputDetails<String>(
        value: 'value',
      );
      expect(regular.toString(), contains('value'));
    });
  });

  group('StackReferenceArgs', () {
    test('can be constructed with no arguments', () {
      const args = StackReferenceArgs();
      expect(args.name, isNull);
    });

    test('can be constructed with name', () {
      final args = StackReferenceArgs(
        name: Input.value('myorg/myproject/production'),
      );
      expect(args.name, isA<InputValue<String>>());
    });
  });

  group('StackReferenceOutputError', () {
    test('stores stack and output names', () {
      final error = StackReferenceOutputError('myorg/project/stack', 'vpcId');

      expect(error.stackName, equals('myorg/project/stack'));
      expect(error.outputName, equals('vpcId'));
    });

    test('toString includes helpful message', () {
      final error = StackReferenceOutputError('myorg/project/stack', 'vpcId');
      final message = error.toString();

      expect(message, contains('myorg/project/stack'));
      expect(message, contains('vpcId'));
      expect(message, contains('ctx.export()'));
    });
  });

  group('Multiple stack references', () {
    test('can create multiple stack references', () async {
      final networkStack = StackReference('myorg/network/production');
      final dataStack = StackReference('myorg/data/production');

      await Future.wait([
        networkStack.registered,
        dataStack.registered,
      ]);

      final networkUrn = await networkStack.urn.future;
      final dataUrn = await dataStack.urn.future;

      expect(networkUrn, isNot(equals(dataUrn)));
      expect(networkUrn, contains('network'));
      expect(dataUrn, contains('data'));
    });

    test('stack references with different args', () async {
      final ref1 = StackReference('myorg/project/dev');
      final ref2 = StackReference(
        'prod-ref',
        StackReferenceArgs(name: Input.value('myorg/project/prod')),
      );

      await Future.wait([ref1.registered, ref2.registered]);

      // Both should complete without error
      expect(await ref1.urn.future, contains('dev'));
      expect(await ref2.urn.future, contains('prod-ref'));
    });
  });
}
