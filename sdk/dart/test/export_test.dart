/// Tests that all necessary types are properly exported from the main pulumi.dart library.
///
/// Generated provider SDKs import from 'package:pulumi/pulumi.dart' and need access to
/// PropertyDeserializer for deserializing complex nested types from protobuf Structs.

import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:pulumi/pulumi.dart';
import 'package:test/test.dart';

void main() {
  group('Public API exports', () {
    test('PropertyDeserializer is accessible from pulumi.dart', () {
      // This test verifies that PropertyDeserializer is properly exported
      // from the main pulumi.dart library, as required by generated provider SDKs.

      final struct = Struct()
        ..fields['name'] = (Value()..stringValue = 'test')
        ..fields['count'] = (Value()..numberValue = 42.0)
        ..fields['enabled'] = (Value()..boolValue = true);

      final result = PropertyDeserializer.deserializeStruct(struct);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['name'], 'test');
      expect(result['count'], 42);
      expect(result['enabled'], true);
    });

    test('PropertyDeserializer handles nested structs', () {
      // Generated code for complex types like GCP's AccessLevelBasic uses
      // PropertyDeserializer.deserializeStruct() for nested objects.

      final innerStruct = Struct()
        ..fields['value'] = (Value()..stringValue = 'nested');

      final outerStruct = Struct()
        ..fields['nested'] = (Value()..structValue = innerStruct);

      final result = PropertyDeserializer.deserializeStruct(outerStruct);

      expect(result['nested'], isA<Map<String, dynamic>>());
      expect((result['nested'] as Map)['value'], 'nested');
    });

    test('PropertyDeserializer handles lists in structs', () {
      // Provider SDKs need to deserialize lists of complex objects.

      final listValue = ListValue()
        ..values.addAll([
          Value()..stringValue = 'item1',
          Value()..stringValue = 'item2',
        ]);

      final struct = Struct()
        ..fields['items'] = (Value()..listValue = listValue);

      final result = PropertyDeserializer.deserializeStruct(struct);

      expect(result['items'], isA<List>());
      expect(result['items'], ['item1', 'item2']);
    });
  });
}
