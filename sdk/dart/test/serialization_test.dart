import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:test/test.dart';

import 'package:pulumi/src/input.dart';
import 'package:pulumi/src/output.dart';
import 'package:pulumi/src/runtime/serialization.dart';

void main() {
  group('PropertySerializer', () {
    group('serialize primitives', () {
      test('serializes null', () async {
        final result = await PropertySerializer.serializeValue(null);
        expect(result.value.hasNullValue(), isTrue);
        expect(result.dependencies, isEmpty);
        expect(result.containsSecrets, isFalse);
        expect(result.isKnown, isTrue);
      });

      test('serializes bool true', () async {
        final result = await PropertySerializer.serializeValue(true);
        expect(result.value.hasBoolValue(), isTrue);
        expect(result.value.boolValue, isTrue);
      });

      test('serializes bool false', () async {
        final result = await PropertySerializer.serializeValue(false);
        expect(result.value.hasBoolValue(), isTrue);
        expect(result.value.boolValue, isFalse);
      });

      test('serializes int', () async {
        final result = await PropertySerializer.serializeValue(42);
        expect(result.value.hasNumberValue(), isTrue);
        expect(result.value.numberValue, 42.0);
      });

      test('serializes double', () async {
        final result = await PropertySerializer.serializeValue(3.14);
        expect(result.value.hasNumberValue(), isTrue);
        expect(result.value.numberValue, 3.14);
      });

      test('serializes string', () async {
        final result = await PropertySerializer.serializeValue('hello');
        expect(result.value.hasStringValue(), isTrue);
        expect(result.value.stringValue, 'hello');
      });
    });

    group('serialize collections', () {
      test('serializes empty list', () async {
        final result = await PropertySerializer.serializeValue(<dynamic>[]);
        expect(result.value.hasListValue(), isTrue);
        expect(result.value.listValue.values, isEmpty);
      });

      test('serializes list of primitives', () async {
        final result = await PropertySerializer.serializeValue([1, 'two', true]);
        expect(result.value.hasListValue(), isTrue);
        final list = result.value.listValue.values;
        expect(list, hasLength(3));
        expect(list[0].numberValue, 1.0);
        expect(list[1].stringValue, 'two');
        expect(list[2].boolValue, isTrue);
      });

      test('serializes nested list', () async {
        final result = await PropertySerializer.serializeValue([
          [1, 2],
          [3, 4]
        ]);
        expect(result.value.hasListValue(), isTrue);
        final outer = result.value.listValue.values;
        expect(outer, hasLength(2));
        expect(outer[0].listValue.values[0].numberValue, 1.0);
        expect(outer[1].listValue.values[1].numberValue, 4.0);
      });

      test('serializes empty map', () async {
        final result = await PropertySerializer.serializeValue(<String, dynamic>{});
        expect(result.value.hasStructValue(), isTrue);
        expect(result.value.structValue.fields, isEmpty);
      });

      test('serializes map of primitives', () async {
        final result = await PropertySerializer.serializeValue({
          'name': 'test',
          'count': 5,
          'enabled': true,
        });
        expect(result.value.hasStructValue(), isTrue);
        final struct = result.value.structValue;
        expect(struct.fields['name']?.stringValue, 'test');
        expect(struct.fields['count']?.numberValue, 5.0);
        expect(struct.fields['enabled']?.boolValue, isTrue);
      });

      test('serializes nested map', () async {
        final result = await PropertySerializer.serializeValue({
          'outer': {
            'inner': 'value',
          },
        });
        expect(result.value.hasStructValue(), isTrue);
        final outer = result.value.structValue.fields['outer']?.structValue;
        expect(outer?.fields['inner']?.stringValue, 'value');
      });

      test('serializes map with list values', () async {
        final result = await PropertySerializer.serializeValue({
          'items': [1, 2, 3],
        });
        expect(result.value.hasStructValue(), isTrue);
        final list = result.value.structValue.fields['items']?.listValue.values;
        expect(list, hasLength(3));
      });
    });

    group('serialize Input values', () {
      test('serializes InputValue', () async {
        final input = Input.value('test');
        final result = await PropertySerializer.serializeInput(input);
        expect(result.value.stringValue, 'test');
      });

      test('serializes InputFuture', () async {
        final input = Input.future(Future.value(42));
        final result = await PropertySerializer.serializeInput(input);
        expect(result.value.numberValue, 42.0);
      });

      test('serializes InputOutput with known value', () async {
        final output = Output.of('from-output');
        final input = Input.output(output);
        final result = await PropertySerializer.serializeInput(input);
        expect(result.value.stringValue, 'from-output');
      });
    });

    group('serialize Output values', () {
      test('serializes known Output', () async {
        final output = Output.of('known');
        final result = await PropertySerializer.serializeOutput(output);
        expect(result.value.stringValue, 'known');
        expect(result.isKnown, isTrue);
      });

      test('serializes unknown Output with signature', () async {
        final output = Output<String>.unknown();
        final result = await PropertySerializer.serializeOutput(output);
        expect(result.value.hasStructValue(), isTrue);
        final struct = result.value.structValue;
        expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
            PropertySignatures.outputSig);
        expect(result.isKnown, isFalse);
      });

      test('serializes secret Output with wrapper', () async {
        final output = Output.of('secret-value').asSecret();
        final result = await PropertySerializer.serializeOutput(output);
        expect(result.value.hasStructValue(), isTrue);
        expect(result.containsSecrets, isTrue);
        final struct = result.value.structValue;
        expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
            PropertySignatures.secretSig);
        expect(struct.fields['value']?.stringValue, 'secret-value');
      });

      test('tracks Output dependencies', () async {
        final output = Output.of('value').withDependencies({'urn:dep1', 'urn:dep2'});
        final result = await PropertySerializer.serializeOutput(output);
        expect(result.dependencies, containsAll(['urn:dep1', 'urn:dep2']));
      });
    });

    group('serialize method', () {
      test('serializes map of inputs', () async {
        final inputs = <String, Input<Object?>?>{
          'name': Input.value('test'),
          'count': Input.value(5),
        };
        final result = await PropertySerializer.serialize(inputs);
        expect(result.value.hasStructValue(), isTrue);
        final struct = result.value.structValue;
        expect(struct.fields['name']?.stringValue, 'test');
        expect(struct.fields['count']?.numberValue, 5.0);
      });

      test('skips null inputs', () async {
        final inputs = <String, Input<Object?>?>{
          'name': Input.value('test'),
          'optional': null,
        };
        final result = await PropertySerializer.serialize(inputs);
        final struct = result.value.structValue;
        expect(struct.fields.containsKey('name'), isTrue);
        expect(struct.fields.containsKey('optional'), isFalse);
      });

      test('aggregates dependencies from all inputs', () async {
        final output1 = Output.of('a').withDependencies({'urn:dep1'});
        final output2 = Output.of('b').withDependencies({'urn:dep2'});
        final inputs = <String, Input<Object?>?>{
          'field1': Input.output(output1),
          'field2': Input.output(output2),
        };
        final result = await PropertySerializer.serialize(inputs);
        expect(result.dependencies, containsAll(['urn:dep1', 'urn:dep2']));
      });

      test('tracks if any input is secret', () async {
        final secret = Output.of('pwd').asSecret();
        final inputs = <String, Input<Object?>?>{
          'password': Input.output(secret),
          'username': Input.value('user'),
        };
        final result = await PropertySerializer.serialize(inputs);
        expect(result.containsSecrets, isTrue);
      });

      test('tracks if any input is unknown', () async {
        final unknown = Output<String>.unknown();
        final inputs = <String, Input<Object?>?>{
          'knownField': Input.value('known'),
          'unknownField': Input.output(unknown),
        };
        final result = await PropertySerializer.serialize(inputs);
        expect(result.isKnown, isFalse);
      });
    });

    group('serializeOutputMap', () {
      test('serializes map of outputs', () async {
        final outputs = {
          'out1': Output.of('value1'),
          'out2': Output.of(42),
        };
        final result = await PropertySerializer.serializeOutputMap(outputs);
        expect(result.value.hasStructValue(), isTrue);
        final struct = result.value.structValue;
        expect(struct.fields['out1']?.stringValue, 'value1');
        expect(struct.fields['out2']?.numberValue, 42.0);
      });
    });
  });

  group('PropertyDeserializer', () {
    group('deserialize primitives', () {
      test('deserializes null', () {
        final value = Value()..nullValue = NullValue.NULL_VALUE;
        expect(PropertyDeserializer.deserializeValue(value), isNull);
      });

      test('deserializes bool true', () {
        final value = Value()..boolValue = true;
        expect(PropertyDeserializer.deserializeValue(value), isTrue);
      });

      test('deserializes bool false', () {
        final value = Value()..boolValue = false;
        expect(PropertyDeserializer.deserializeValue(value), isFalse);
      });

      test('deserializes whole number as int', () {
        final value = Value()..numberValue = 42.0;
        expect(PropertyDeserializer.deserializeValue(value), 42);
        expect(PropertyDeserializer.deserializeValue(value), isA<int>());
      });

      test('deserializes decimal as double', () {
        final value = Value()..numberValue = 3.14;
        expect(PropertyDeserializer.deserializeValue(value), 3.14);
        expect(PropertyDeserializer.deserializeValue(value), isA<double>());
      });

      test('deserializes string', () {
        final value = Value()..stringValue = 'hello';
        expect(PropertyDeserializer.deserializeValue(value), 'hello');
      });
    });

    group('deserialize collections', () {
      test('deserializes list', () {
        final listValue = ListValue()
          ..values.addAll([
            Value()..numberValue = 1.0,
            Value()..stringValue = 'two',
            Value()..boolValue = true,
          ]);
        final value = Value()..listValue = listValue;
        final result = PropertyDeserializer.deserializeValue(value) as List;
        expect(result, [1, 'two', true]);
      });

      test('deserializes struct to map', () {
        final struct = Struct()
          ..fields['name'] = (Value()..stringValue = 'test')
          ..fields['count'] = (Value()..numberValue = 5.0);
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value) as Map;
        expect(result['name'], 'test');
        expect(result['count'], 5);
      });

      test('deserializes nested structures', () {
        final inner = Struct()
          ..fields['value'] = (Value()..stringValue = 'inner');
        final outer = Struct()
          ..fields['nested'] = (Value()..structValue = inner);
        final result = PropertyDeserializer.deserializeStruct(outer);
        expect((result['nested'] as Map)['value'], 'inner');
      });
    });

    group('deserialize special signatures', () {
      test('deserializes secret value', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.secretSig)
          ..fields['value'] = (Value()..stringValue = 'secret-data');
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<SecretValue>());
        expect((result as SecretValue).value, 'secret-data');
      });

      test('deserializes unknown value', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.outputSig);
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<UnknownValue>());
      });

      test('deserializes resource reference', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.resourceSig)
          ..fields['urn'] = (Value()..stringValue = 'urn:pulumi:stack::project::type::name')
          ..fields['id'] = (Value()..stringValue = 'resource-id-123');
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<ResourceReference>());
        final ref = result as ResourceReference;
        expect(ref.urn, 'urn:pulumi:stack::project::type::name');
        expect(ref.id, 'resource-id-123');
      });

      test('deserializes file asset', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.assetSig)
          ..fields['path'] = (Value()..stringValue = '/path/to/file.txt');
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<FileAsset>());
        expect((result as FileAsset).path, '/path/to/file.txt');
      });

      test('deserializes string asset', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.assetSig)
          ..fields['text'] = (Value()..stringValue = 'asset content');
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<StringAsset>());
        expect((result as StringAsset).text, 'asset content');
      });

      test('deserializes remote asset', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.assetSig)
          ..fields['uri'] = (Value()..stringValue = 'https://example.com/file');
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<RemoteAsset>());
        expect((result as RemoteAsset).uri, 'https://example.com/file');
      });

      test('deserializes file archive', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.archiveSig)
          ..fields['path'] = (Value()..stringValue = '/path/to/archive.zip');
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<FileArchive>());
        expect((result as FileArchive).path, '/path/to/archive.zip');
      });

      test('deserializes remote archive', () {
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.archiveSig)
          ..fields['uri'] = (Value()..stringValue = 'https://example.com/archive.tar.gz');
        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<RemoteArchive>());
        expect((result as RemoteArchive).uri, 'https://example.com/archive.tar.gz');
      });

      test('deserializes asset archive', () {
        // Build inner asset struct
        final assetStruct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.assetSig)
          ..fields['text'] = (Value()..stringValue = 'content');

        // Build assets map struct
        final assetsStruct = Struct()
          ..fields['file.txt'] = (Value()..structValue = assetStruct);

        // Build archive struct
        final struct = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.archiveSig)
          ..fields['assets'] = (Value()..structValue = assetsStruct);

        final value = Value()..structValue = struct;
        final result = PropertyDeserializer.deserializeValue(value);
        expect(result, isA<AssetArchive>());
        final archive = result as AssetArchive;
        expect(archive.assets.length, 1);
        expect(archive.assets['file.txt'], isA<StringAsset>());
        expect((archive.assets['file.txt'] as StringAsset).text, 'content');
      });
    });

    group('toOutputData', () {
      test('converts value to OutputData', () {
        final value = Value()..stringValue = 'test';
        final data = PropertyDeserializer.toOutputData<String>(value);
        expect(data.value, 'test');
        expect(data.isKnown, isTrue);
        expect(data.isSecret, isFalse);
      });

      test('preserves dependencies', () {
        final value = Value()..stringValue = 'test';
        final data = PropertyDeserializer.toOutputData<String>(
          value,
          dependencies: {'urn:dep1'},
        );
        expect(data.dependencies, contains('urn:dep1'));
      });

      test('detects secrets in nested values', () {
        final inner = Struct()
          ..fields[PropertySignatures.sigKey] =
              (Value()..stringValue = PropertySignatures.secretSig)
          ..fields['value'] = (Value()..stringValue = 'secret');
        final outer = Struct()..fields['nested'] = (Value()..structValue = inner);
        final value = Value()..structValue = outer;
        final data = PropertyDeserializer.toOutputData<Map<String, dynamic>>(value);
        expect(data.isSecret, isTrue);
      });
    });
  });

  group('Asset serialization', () {
    test('serializes FileAsset', () async {
      final asset = FileAsset('/path/to/file.txt');
      final result = await PropertySerializer.serializeValue(asset);
      expect(result.value.hasStructValue(), isTrue);
      final struct = result.value.structValue;
      expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.assetSig);
      expect(struct.fields['path']?.stringValue, '/path/to/file.txt');
    });

    test('serializes StringAsset', () async {
      final asset = StringAsset('inline content');
      final result = await PropertySerializer.serializeValue(asset);
      expect(result.value.hasStructValue(), isTrue);
      final struct = result.value.structValue;
      expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.assetSig);
      expect(struct.fields['text']?.stringValue, 'inline content');
    });

    test('serializes RemoteAsset', () async {
      final asset = RemoteAsset('https://example.com/file.js');
      final result = await PropertySerializer.serializeValue(asset);
      expect(result.value.hasStructValue(), isTrue);
      final struct = result.value.structValue;
      expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.assetSig);
      expect(struct.fields['uri']?.stringValue, 'https://example.com/file.js');
    });
  });

  group('Archive serialization', () {
    test('serializes FileArchive', () async {
      final archive = FileArchive('/path/to/archive.zip');
      final result = await PropertySerializer.serializeValue(archive);
      expect(result.value.hasStructValue(), isTrue);
      final struct = result.value.structValue;
      expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.archiveSig);
      expect(struct.fields['path']?.stringValue, '/path/to/archive.zip');
    });

    test('serializes RemoteArchive', () async {
      final archive = RemoteArchive('https://example.com/archive.tar.gz');
      final result = await PropertySerializer.serializeValue(archive);
      expect(result.value.hasStructValue(), isTrue);
      final struct = result.value.structValue;
      expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.archiveSig);
      expect(struct.fields['uri']?.stringValue, 'https://example.com/archive.tar.gz');
    });

    test('serializes AssetArchive', () async {
      final archive = AssetArchive({
        'index.js': StringAsset('exports.handler = () => {};'),
        'config.json': FileAsset('./config.json'),
      });
      final result = await PropertySerializer.serializeValue(archive);
      expect(result.value.hasStructValue(), isTrue);
      final struct = result.value.structValue;
      expect(struct.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.archiveSig);

      // Check assets field
      final assetsStruct = struct.fields['assets']?.structValue;
      expect(assetsStruct, isNotNull);

      // Check that index.js is a StringAsset
      final indexJs = assetsStruct!.fields['index.js']?.structValue;
      expect(indexJs?.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.assetSig);
      expect(indexJs?.fields['text']?.stringValue, 'exports.handler = () => {};');

      // Check that config.json is a FileAsset
      final configJson = assetsStruct.fields['config.json']?.structValue;
      expect(configJson?.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.assetSig);
      expect(configJson?.fields['path']?.stringValue, './config.json');
    });

    test('serializes nested AssetArchive', () async {
      final archive = AssetArchive({
        'src/': AssetArchive({
          'main.js': StringAsset('main'),
        }),
        'readme.txt': StringAsset('readme'),
      });
      final result = await PropertySerializer.serializeValue(archive);
      expect(result.value.hasStructValue(), isTrue);

      final struct = result.value.structValue;
      final assetsStruct = struct.fields['assets']?.structValue;
      expect(assetsStruct, isNotNull);

      // Check nested archive
      final srcArchive = assetsStruct!.fields['src/']?.structValue;
      expect(srcArchive?.fields[PropertySignatures.sigKey]?.stringValue,
          PropertySignatures.archiveSig);
    });
  });

  group('Asset/Archive roundtrip', () {
    test('FileAsset roundtrips', () async {
      final original = FileAsset('/path/to/file.txt');
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, isA<FileAsset>());
      expect(deserialized, equals(original));
    });

    test('StringAsset roundtrips', () async {
      final original = StringAsset('hello world');
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, isA<StringAsset>());
      expect(deserialized, equals(original));
    });

    test('RemoteAsset roundtrips', () async {
      final original = RemoteAsset('https://example.com/file');
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, isA<RemoteAsset>());
      expect(deserialized, equals(original));
    });

    test('FileArchive roundtrips', () async {
      final original = FileArchive('/path/to/archive.zip');
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, isA<FileArchive>());
      expect(deserialized, equals(original));
    });

    test('RemoteArchive roundtrips', () async {
      final original = RemoteArchive('https://example.com/archive.tar.gz');
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, isA<RemoteArchive>());
      expect(deserialized, equals(original));
    });

    test('AssetArchive roundtrips', () async {
      final original = AssetArchive({
        'index.js': StringAsset('code'),
        'config.json': FileAsset('./config.json'),
      });
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, isA<AssetArchive>());
      final archive = deserialized as AssetArchive;
      expect(archive.assets.length, 2);
      expect(archive.assets['index.js'], isA<StringAsset>());
      expect(archive.assets['config.json'], isA<FileAsset>());
    });
  });

  group('Roundtrip serialization', () {
    test('primitives roundtrip correctly', () async {
      final values = [null, true, false, 42, 3.14, 'hello'];
      for (final original in values) {
        final serialized = await PropertySerializer.serializeValue(original);
        final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
        expect(deserialized, original);
      }
    });

    test('list roundtrips correctly', () async {
      final original = [1, 'two', true, null];
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, original);
    });

    test('map roundtrips correctly', () async {
      final original = {'name': 'test', 'count': 42, 'enabled': true};
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, original);
    });

    test('nested structure roundtrips correctly', () async {
      final original = {
        'config': {
          'items': [1, 2, 3],
          'settings': {'enabled': true},
        },
      };
      final serialized = await PropertySerializer.serializeValue(original);
      final deserialized = PropertyDeserializer.deserializeValue(serialized.value);
      expect(deserialized, original);
    });
  });

  group('PropertySignatures', () {
    test('signature values are correct', () {
      expect(PropertySignatures.sigKey, '4dabf18193072939515e22adb298388d');
      expect(PropertySignatures.secretSig, '1b47061264138c4ac30d75fd1eb44270');
      expect(PropertySignatures.resourceSig, '5cf8f73096256a8f31e491e813e4eb8e');
      expect(PropertySignatures.outputSig, 'dd056dca1064fe68746f1486de04adb9');
    });
  });

  group('Special value types', () {
    test('SecretValue hides value in toString', () {
      final secret = SecretValue('sensitive-data');
      expect(secret.toString(), '[secret]');
      expect(secret.value, 'sensitive-data');
    });

    test('UnknownValue toString', () {
      final unknown = UnknownValue();
      expect(unknown.toString(), '[unknown]');
    });

    test('ResourceReference toString', () {
      final ref = ResourceReference(
        urn: 'urn:pulumi:stack::project::type::name',
        id: 'id-123',
      );
      expect(ref.toString(), contains('urn:pulumi:stack::project::type::name'));
      expect(ref.toString(), contains('id-123'));
    });

    test('FileAsset toString', () {
      final asset = FileAsset('/path/to/file.txt');
      expect(asset.toString(), 'FileAsset(/path/to/file.txt)');
    });

    test('StringAsset toString', () {
      final asset = StringAsset('hello world');
      expect(asset.toString(), 'StringAsset(11 chars)');
    });

    test('RemoteAsset toString', () {
      final asset = RemoteAsset('https://example.com/file');
      expect(asset.toString(), 'RemoteAsset(https://example.com/file)');
    });

    test('FileArchive toString', () {
      final archive = FileArchive('/path/to/archive.zip');
      expect(archive.toString(), 'FileArchive(/path/to/archive.zip)');
    });

    test('RemoteArchive toString', () {
      final archive = RemoteArchive('https://example.com/archive.tar.gz');
      expect(archive.toString(), 'RemoteArchive(https://example.com/archive.tar.gz)');
    });

    test('AssetArchive toString', () {
      final archive = AssetArchive({
        'index.js': StringAsset('code'),
        'config.json': FileAsset('./config.json'),
      });
      expect(archive.toString(), 'AssetArchive(2 entries)');
    });

    test('FileAsset equality', () {
      final a = FileAsset('/path/to/file');
      final b = FileAsset('/path/to/file');
      final c = FileAsset('/other/path');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('StringAsset equality', () {
      final a = StringAsset('hello');
      final b = StringAsset('hello');
      final c = StringAsset('world');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('RemoteAsset equality', () {
      final a = RemoteAsset('https://example.com');
      final b = RemoteAsset('https://example.com');
      final c = RemoteAsset('https://other.com');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('FileArchive equality', () {
      final a = FileArchive('/path/to/archive');
      final b = FileArchive('/path/to/archive');
      final c = FileArchive('/other/path');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('RemoteArchive equality', () {
      final a = RemoteArchive('https://example.com/archive.zip');
      final b = RemoteArchive('https://example.com/archive.zip');
      final c = RemoteArchive('https://other.com/archive.zip');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('AssetArchive equality', () {
      final a = AssetArchive({'file': StringAsset('content')});
      final b = AssetArchive({'file': StringAsset('content')});
      final c = AssetArchive({'file': StringAsset('other')});
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('Edge cases', () {
    test('serializes unsupported type by converting to string', () async {
      // Custom class that is not a primitive, list, map, Input, or Output
      final result = await PropertySerializer.serializeValue(DateTime(2024, 1, 1));
      expect(result.value.hasStringValue(), isTrue);
      expect(result.value.stringValue, contains('2024'));
    });

    test('deserializes Value_Kind.notSet as null', () {
      final value = Value(); // Default value has notSet kind
      expect(PropertyDeserializer.deserializeValue(value), isNull);
    });
  });
}
