import 'package:test/test.dart';

import 'package:pulumi/src/options.dart';

void main() {
  group('Alias', () {
    group('AliasUrn', () {
      test('stores urn correctly', () {
        final alias = Alias.urn('urn:pulumi:stack::project::type::name');
        expect(alias, isA<AliasUrn>());
        expect((alias as AliasUrn).urn,
            equals('urn:pulumi:stack::project::type::name'));
      });

      test('equality works correctly', () {
        final alias1 = AliasUrn('urn:pulumi:stack::project::type::name');
        final alias2 = AliasUrn('urn:pulumi:stack::project::type::name');
        final alias3 = AliasUrn('urn:pulumi:stack::project::type::other');

        expect(alias1, equals(alias2));
        expect(alias1, isNot(equals(alias3)));
        expect(alias1.hashCode, equals(alias2.hashCode));
      });

      test('toString returns readable representation', () {
        final alias = AliasUrn('urn:pulumi:stack::project::type::name');
        expect(alias.toString(),
            equals('AliasUrn(urn:pulumi:stack::project::type::name)'));
      });
    });

    group('AliasSpec', () {
      test('stores all properties correctly', () {
        final alias = Alias.spec(
          name: 'old-name',
          type: 'old:type:Token',
          stack: 'old-stack',
          project: 'old-project',
          parentUrn: 'urn:pulumi:stack::project::type::parent',
          noParent: false,
        );

        expect(alias, isA<AliasSpec>());
        final spec = alias as AliasSpec;
        expect(spec.name, equals('old-name'));
        expect(spec.type, equals('old:type:Token'));
        expect(spec.stack, equals('old-stack'));
        expect(spec.project, equals('old-project'));
        expect(spec.parentUrn,
            equals('urn:pulumi:stack::project::type::parent'));
        expect(spec.noParent, isFalse);
      });

      test('convenience methods create correct specs', () {
        final nameAlias = Alias.name('old-name');
        expect((nameAlias as AliasSpec).name, equals('old-name'));
        expect(nameAlias.type, isNull);

        final typeAlias = Alias.type('old:type:Token');
        expect((typeAlias as AliasSpec).type, equals('old:type:Token'));
        expect(typeAlias.name, isNull);

        final parentAlias =
            Alias.parent('urn:pulumi:stack::project::type::parent');
        expect((parentAlias as AliasSpec).parentUrn,
            equals('urn:pulumi:stack::project::type::parent'));

        final noParentAlias = Alias.noParent();
        expect((noParentAlias as AliasSpec).noParent, isTrue);
      });

      test('equality works correctly', () {
        final alias1 = AliasSpec(name: 'test', type: 'type');
        final alias2 = AliasSpec(name: 'test', type: 'type');
        final alias3 = AliasSpec(name: 'test', type: 'other');

        expect(alias1, equals(alias2));
        expect(alias1, isNot(equals(alias3)));
        expect(alias1.hashCode, equals(alias2.hashCode));
      });

      test('toString returns readable representation', () {
        final alias = AliasSpec(name: 'test', type: 'type');
        expect(
            alias.toString(),
            equals(
                'AliasSpec(name: test, type: type, stack: null, project: null, '
                'parentUrn: null, noParent: null)'));
      });
    });
  });

  group('CustomTimeouts', () {
    test('stores all timeout values correctly', () {
      final timeouts = CustomTimeouts(
        create: '30m',
        update: '1h',
        delete: '2h30m',
      );

      expect(timeouts.create, equals('30m'));
      expect(timeouts.update, equals('1h'));
      expect(timeouts.delete, equals('2h30m'));
    });

    test('allows partial specification', () {
      final timeouts = CustomTimeouts(create: '30m');

      expect(timeouts.create, equals('30m'));
      expect(timeouts.update, isNull);
      expect(timeouts.delete, isNull);
    });

    test('equality works correctly', () {
      final t1 = CustomTimeouts(create: '30m', update: '1h');
      final t2 = CustomTimeouts(create: '30m', update: '1h');
      final t3 = CustomTimeouts(create: '30m', update: '2h');

      expect(t1, equals(t2));
      expect(t1, isNot(equals(t3)));
      expect(t1.hashCode, equals(t2.hashCode));
    });

    test('toString returns readable representation', () {
      final timeouts = CustomTimeouts(create: '30m');
      expect(timeouts.toString(),
          equals('CustomTimeouts(create: 30m, update: null, delete: null)'));
    });
  });

  group('ResourceOptions', () {
    test('has correct default values', () {
      const opts = ResourceOptions();

      expect(opts.parent, isNull);
      expect(opts.protect, isFalse);
      expect(opts.dependsOn, isEmpty);
      expect(opts.provider, isNull);
      expect(opts.retainOnDelete, isFalse);
      expect(opts.deletedWith, isNull);
      expect(opts.aliases, isEmpty);
      expect(opts.ignoreChanges, isEmpty);
      expect(opts.replaceOnChanges, isEmpty);
      expect(opts.customTimeouts, isNull);
      expect(opts.version, isNull);
      expect(opts.pluginDownloadUrl, isNull);
    });

    test('all properties can be set', () {
      final parentMock = Object(); // Using Object as ResourceRef
      final depMock = Object();

      final opts = ResourceOptions(
        parent: parentMock,
        protect: true,
        dependsOn: [depMock],
        provider: 'custom-provider',
        retainOnDelete: true,
        deletedWith: 'urn:other:resource',
        aliases: [Alias.name('old-name')],
        ignoreChanges: ['prop1', 'prop2'],
        replaceOnChanges: ['prop3'],
        customTimeouts: CustomTimeouts(create: '30m'),
        version: '1.2.3',
        pluginDownloadUrl: 'https://example.com/plugin',
      );

      expect(opts.parent, equals(parentMock));
      expect(opts.protect, isTrue);
      expect(opts.dependsOn, contains(depMock));
      expect(opts.provider, equals('custom-provider'));
      expect(opts.retainOnDelete, isTrue);
      expect(opts.deletedWith, equals('urn:other:resource'));
      expect(opts.aliases, hasLength(1));
      expect(opts.ignoreChanges, equals(['prop1', 'prop2']));
      expect(opts.replaceOnChanges, equals(['prop3']));
      expect(opts.customTimeouts?.create, equals('30m'));
      expect(opts.version, equals('1.2.3'));
      expect(opts.pluginDownloadUrl, equals('https://example.com/plugin'));
    });

    test('copyWith creates copy with specified changes', () {
      final opts = ResourceOptions(
        protect: true,
        provider: 'original',
      );

      final copy = opts.copyWith(
        provider: 'updated',
        retainOnDelete: true,
      );

      // Changed values
      expect(copy.provider, equals('updated'));
      expect(copy.retainOnDelete, isTrue);

      // Preserved values
      expect(copy.protect, isTrue);

      // Original unchanged
      expect(opts.provider, equals('original'));
      expect(opts.retainOnDelete, isFalse);
    });

    test('copyWith preserves all values when no changes specified', () {
      final opts = ResourceOptions(
        protect: true,
        provider: 'test',
        aliases: [Alias.name('old')],
        ignoreChanges: ['prop1'],
      );

      final copy = opts.copyWith();

      expect(copy.protect, equals(opts.protect));
      expect(copy.provider, equals(opts.provider));
      expect(copy.aliases, equals(opts.aliases));
      expect(copy.ignoreChanges, equals(opts.ignoreChanges));
    });
  });

  group('CustomResourceOptions', () {
    test('has correct default values', () {
      const opts = CustomResourceOptions();

      // Base options defaults
      expect(opts.parent, isNull);
      expect(opts.protect, isFalse);
      expect(opts.dependsOn, isEmpty);

      // Custom resource specific defaults
      expect(opts.importId, isNull);
      expect(opts.deleteBeforeReplace, isFalse);
      expect(opts.additionalSecretOutputs, isEmpty);
    });

    test('all properties can be set', () {
      final opts = CustomResourceOptions(
        protect: true,
        provider: 'custom-provider',
        importId: 'existing-resource-id',
        deleteBeforeReplace: true,
        additionalSecretOutputs: ['password', 'apiKey'],
        aliases: [Alias.name('old-name')],
        ignoreChanges: ['tags'],
      );

      // Base options
      expect(opts.protect, isTrue);
      expect(opts.provider, equals('custom-provider'));
      expect(opts.aliases, hasLength(1));
      expect(opts.ignoreChanges, equals(['tags']));

      // Custom resource specific
      expect(opts.importId, equals('existing-resource-id'));
      expect(opts.deleteBeforeReplace, isTrue);
      expect(opts.additionalSecretOutputs, equals(['password', 'apiKey']));
    });

    test('copyWith creates copy with specified changes', () {
      final opts = CustomResourceOptions(
        protect: true,
        importId: 'original-id',
        deleteBeforeReplace: false,
      );

      final copy = opts.copyWith(
        importId: 'new-id',
        deleteBeforeReplace: true,
      );

      // Changed values
      expect(copy.importId, equals('new-id'));
      expect(copy.deleteBeforeReplace, isTrue);

      // Preserved values
      expect(copy.protect, isTrue);

      // Original unchanged
      expect(opts.importId, equals('original-id'));
      expect(opts.deleteBeforeReplace, isFalse);
    });

    test('copyWith returns CustomResourceOptions type', () {
      final opts = CustomResourceOptions(importId: 'test');
      final copy = opts.copyWith(protect: true);

      expect(copy, isA<CustomResourceOptions>());
      expect((copy as CustomResourceOptions).importId, equals('test'));
    });

    test('extends ResourceOptions properly', () {
      const CustomResourceOptions opts = CustomResourceOptions(
        protect: true,
        importId: 'test-id',
      );

      // Should be usable as ResourceOptions
      final ResourceOptions baseOpts = opts;
      expect(baseOpts.protect, isTrue);

      // But still have custom properties when cast back
      expect((baseOpts as CustomResourceOptions).importId, equals('test-id'));
    });
  });

  group('ComponentResourceOptions', () {
    test('is alias for ResourceOptions', () {
      const ComponentResourceOptions opts = ResourceOptions();
      expect(opts, isA<ResourceOptions>());
    });
  });
}
