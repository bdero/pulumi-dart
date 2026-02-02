import 'dart:async';

import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import '../input.dart';
import '../output.dart';

/// Special property signatures used by Pulumi's serialization protocol.
///
/// These signatures mark special value types in the protobuf Struct format:
/// - Secrets are wrapped with a signature to indicate they should be encrypted
/// - Unknown values use a signature to indicate preview-time unknowns
/// - Resource references encode dependencies between resources
class PropertySignatures {
  PropertySignatures._();

  /// Signature key for special Pulumi values.
  static const String sigKey = '4dabf18193072939515e22adb298388d';

  /// Signature value for secret values.
  static const String secretSig = '1b47061264138c4ac30d75fd1eb44270';

  /// Signature value for resource references.
  static const String resourceSig = '5cf8f73096256a8f31e491e813e4eb8e';

  /// Signature value for output references (unknown values).
  static const String outputSig = 'dd056dca1064fe68746f1486de04adb9';

  /// Signature value for archived assets.
  static const String archiveSig = '2f76c2ad3d8460a59238bd21c4f0c099';

  /// Signature value for file assets.
  static const String assetSig = 'c44067f5952c0a294b673a41bacd8c17';
}

/// Result of serializing a value, including metadata.
class SerializedValue {
  /// The serialized protobuf Value.
  final Value value;

  /// URNs of resources this value depends on.
  final Set<String> dependencies;

  /// Whether this value contains secrets.
  final bool containsSecrets;

  /// Whether this value is fully known (not a preview placeholder).
  final bool isKnown;

  SerializedValue({
    required this.value,
    this.dependencies = const {},
    this.containsSecrets = false,
    this.isKnown = true,
  });
}

/// Serializes Dart values to protobuf Struct/Value format for Pulumi.
///
/// This class handles the conversion of Dart types to the protobuf format
/// used by the Pulumi engine. It supports:
/// - Primitive types: null, bool, int, double, String
/// - Collections: List, Map
/// - Pulumi types: Input, Output
/// - Special handling for secrets and dependencies
///
/// ## Example
///
/// ```dart
/// final inputs = {
///   'name': Input.value('my-bucket'),
///   'tags': Input.value({'env': 'prod'}),
/// };
///
/// final serialized = await PropertySerializer.serialize(inputs);
/// // serialized.value is a protobuf Struct
/// // serialized.dependencies contains any resource URNs
/// ```
class PropertySerializer {
  PropertySerializer._();

  /// Serializes a map of Input values to a protobuf Struct.
  ///
  /// This is the primary method for serializing resource inputs before
  /// sending them to the Pulumi engine.
  static Future<SerializedValue> serialize(
    Map<String, Input<Object?>?> inputs,
  ) async {
    final struct = Struct();
    final allDependencies = <String>{};
    var containsSecrets = false;
    var isKnown = true;

    for (final entry in inputs.entries) {
      final input = entry.value;
      if (input == null) continue;

      final result = await serializeInput(input);
      if (!result.isKnown) {
        isKnown = false;
        // For unknown values, we still add them to the struct but mark the whole thing as unknown
      }
      struct.fields[entry.key] = result.value;
      allDependencies.addAll(result.dependencies);
      if (result.containsSecrets) containsSecrets = true;
    }

    return SerializedValue(
      value: Value()..structValue = struct,
      dependencies: allDependencies,
      containsSecrets: containsSecrets,
      isKnown: isKnown,
    );
  }

  /// Serializes a map of Output values to a protobuf Struct.
  ///
  /// Used primarily for component resource outputs.
  static Future<SerializedValue> serializeOutputMap(
    Map<String, Output<Object?>> outputs,
  ) async {
    final struct = Struct();
    final allDependencies = <String>{};
    var containsSecrets = false;
    var isKnown = true;

    for (final entry in outputs.entries) {
      final result = await serializeOutput(entry.value);
      if (!result.isKnown) {
        isKnown = false;
      }
      struct.fields[entry.key] = result.value;
      allDependencies.addAll(result.dependencies);
      if (result.containsSecrets) containsSecrets = true;
    }

    return SerializedValue(
      value: Value()..structValue = struct,
      dependencies: allDependencies,
      containsSecrets: containsSecrets,
      isKnown: isKnown,
    );
  }

  /// Serializes an Input value.
  static Future<SerializedValue> serializeInput(Input<Object?> input) async {
    return switch (input) {
      InputValue(:final value) => await serializeValue(value),
      InputOutput(:final output) => await serializeOutput(output),
      InputFuture(:final future) => await serializeValue(await future),
    };
  }

  /// Serializes an Output value.
  static Future<SerializedValue> serializeOutput(Output<Object?> output) async {
    final data = await output.dataFuture;

    if (!data.isKnown) {
      // For unknown values, we use the output signature
      final unknownStruct = Struct()
        ..fields[PropertySignatures.sigKey] =
            (Value()..stringValue = PropertySignatures.outputSig);

      return SerializedValue(
        value: Value()..structValue = unknownStruct,
        dependencies: data.dependencies,
        containsSecrets: data.isSecret,
        isKnown: false,
      );
    }

    final result = await serializeValue(data.value);

    // Merge dependencies
    final allDeps = {...data.dependencies, ...result.dependencies};
    final isSecret = data.isSecret || result.containsSecrets;

    if (isSecret) {
      // Wrap in secret signature
      final secretStruct = Struct()
        ..fields[PropertySignatures.sigKey] =
            (Value()..stringValue = PropertySignatures.secretSig)
        ..fields['value'] = result.value;

      return SerializedValue(
        value: Value()..structValue = secretStruct,
        dependencies: allDeps,
        containsSecrets: true,
        isKnown: true,
      );
    }

    return SerializedValue(
      value: result.value,
      dependencies: allDeps,
      containsSecrets: false,
      isKnown: true,
    );
  }

  /// Serializes any Dart value to a protobuf Value.
  static Future<SerializedValue> serializeValue(Object? value) async {
    if (value == null) {
      return SerializedValue(value: Value()..nullValue = NullValue.NULL_VALUE);
    }

    if (value is bool) {
      return SerializedValue(value: Value()..boolValue = value);
    }

    if (value is int) {
      return SerializedValue(value: Value()..numberValue = value.toDouble());
    }

    if (value is double) {
      return SerializedValue(value: Value()..numberValue = value);
    }

    if (value is String) {
      return SerializedValue(value: Value()..stringValue = value);
    }

    if (value is Output) {
      return await serializeOutput(value);
    }

    if (value is Input) {
      return await serializeInput(value);
    }

    if (value is List) {
      return await _serializeList(value);
    }

    if (value is Map) {
      return await _serializeMap(value);
    }

    if (value is Asset) {
      return _serializeAsset(value);
    }

    if (value is Archive) {
      return await _serializeArchive(value);
    }

    // For unsupported types, try to convert to string
    return SerializedValue(value: Value()..stringValue = value.toString());
  }

  static Future<SerializedValue> _serializeList(List<dynamic> list) async {
    final listValue = ListValue();
    final allDependencies = <String>{};
    var containsSecrets = false;
    var isKnown = true;

    for (final item in list) {
      final result = await serializeValue(item);
      listValue.values.add(result.value);
      allDependencies.addAll(result.dependencies);
      if (result.containsSecrets) containsSecrets = true;
      if (!result.isKnown) isKnown = false;
    }

    return SerializedValue(
      value: Value()..listValue = listValue,
      dependencies: allDependencies,
      containsSecrets: containsSecrets,
      isKnown: isKnown,
    );
  }

  static Future<SerializedValue> _serializeMap(Map<dynamic, dynamic> map) async {
    final struct = Struct();
    final allDependencies = <String>{};
    var containsSecrets = false;
    var isKnown = true;

    for (final entry in map.entries) {
      final key = entry.key.toString();
      final result = await serializeValue(entry.value);
      struct.fields[key] = result.value;
      allDependencies.addAll(result.dependencies);
      if (result.containsSecrets) containsSecrets = true;
      if (!result.isKnown) isKnown = false;
    }

    return SerializedValue(
      value: Value()..structValue = struct,
      dependencies: allDependencies,
      containsSecrets: containsSecrets,
      isKnown: isKnown,
    );
  }

  /// Serializes an Asset to its protobuf representation.
  static SerializedValue _serializeAsset(Asset asset) {
    final struct = Struct()
      ..fields[PropertySignatures.sigKey] =
          (Value()..stringValue = PropertySignatures.assetSig);

    switch (asset) {
      case FileAsset(:final path):
        struct.fields['path'] = Value()..stringValue = path;
      case StringAsset(:final text):
        struct.fields['text'] = Value()..stringValue = text;
      case RemoteAsset(:final uri):
        struct.fields['uri'] = Value()..stringValue = uri;
    }

    return SerializedValue(value: Value()..structValue = struct);
  }

  /// Serializes an Archive to its protobuf representation.
  static Future<SerializedValue> _serializeArchive(Archive archive) async {
    final struct = Struct()
      ..fields[PropertySignatures.sigKey] =
          (Value()..stringValue = PropertySignatures.archiveSig);

    final allDependencies = <String>{};
    var containsSecrets = false;
    var isKnown = true;

    switch (archive) {
      case FileArchive(:final path):
        struct.fields['path'] = Value()..stringValue = path;
      case RemoteArchive(:final uri):
        struct.fields['uri'] = Value()..stringValue = uri;
      case AssetArchive(:final assets):
        final assetsStruct = Struct();
        for (final entry in assets.entries) {
          final result = await serializeValue(entry.value);
          assetsStruct.fields[entry.key] = result.value;
          allDependencies.addAll(result.dependencies);
          if (result.containsSecrets) containsSecrets = true;
          if (!result.isKnown) isKnown = false;
        }
        struct.fields['assets'] = Value()..structValue = assetsStruct;
    }

    return SerializedValue(
      value: Value()..structValue = struct,
      dependencies: allDependencies,
      containsSecrets: containsSecrets,
      isKnown: isKnown,
    );
  }
}

/// Deserializes protobuf Struct/Value format back to Dart values.
///
/// This class handles the conversion of protobuf values from the Pulumi
/// engine back to Dart types. It understands the special property signatures
/// for secrets, resource references, and unknown values.
///
/// ## Example
///
/// ```dart
/// final struct = response.object;
/// final values = PropertyDeserializer.deserializeStruct(struct);
/// // values is a Map<String, dynamic> with Dart types
/// ```
class PropertyDeserializer {
  PropertyDeserializer._();

  /// Deserializes a protobuf Struct to a Dart Map.
  static Map<String, dynamic> deserializeStruct(Struct struct) {
    final result = <String, dynamic>{};
    for (final entry in struct.fields.entries) {
      result[entry.key] = deserializeValue(entry.value);
    }
    return result;
  }

  /// Deserializes a protobuf Value to a Dart value.
  ///
  /// Handles special Pulumi signatures:
  /// - Secret values are unwrapped to their inner value
  /// - Resource references return the resource URN
  /// - Unknown values return null
  static dynamic deserializeValue(Value value) {
    switch (value.whichKind()) {
      case Value_Kind.nullValue:
        return null;

      case Value_Kind.boolValue:
        return value.boolValue;

      case Value_Kind.numberValue:
        final num = value.numberValue;
        // Convert to int if it's a whole number
        if (num == num.toInt()) {
          return num.toInt();
        }
        return num;

      case Value_Kind.stringValue:
        return value.stringValue;

      case Value_Kind.listValue:
        return value.listValue.values.map(deserializeValue).toList();

      case Value_Kind.structValue:
        return _deserializeStructValue(value.structValue);

      case Value_Kind.notSet:
        return null;
    }
  }

  static dynamic _deserializeStructValue(Struct struct) {
    // Check for special Pulumi signatures
    if (struct.fields.containsKey(PropertySignatures.sigKey)) {
      final sig = struct.fields[PropertySignatures.sigKey]?.stringValue;

      if (sig == PropertySignatures.secretSig) {
        // Secret: unwrap the inner value
        final innerValue = struct.fields['value'];
        if (innerValue != null) {
          return SecretValue(deserializeValue(innerValue));
        }
        return null;
      }

      if (sig == PropertySignatures.outputSig) {
        // Unknown output during preview
        return UnknownValue();
      }

      if (sig == PropertySignatures.resourceSig) {
        // Resource reference
        final urn = struct.fields['urn']?.stringValue;
        final id = struct.fields['id']?.stringValue;
        return ResourceReference(urn: urn ?? '', id: id);
      }

      if (sig == PropertySignatures.assetSig) {
        // File/string asset
        if (struct.fields.containsKey('path')) {
          return FileAsset(struct.fields['path']!.stringValue);
        }
        if (struct.fields.containsKey('text')) {
          return StringAsset(struct.fields['text']!.stringValue);
        }
        if (struct.fields.containsKey('uri')) {
          return RemoteAsset(struct.fields['uri']!.stringValue);
        }
        return null;
      }

      if (sig == PropertySignatures.archiveSig) {
        // Archive
        if (struct.fields.containsKey('path')) {
          return FileArchive(struct.fields['path']!.stringValue);
        }
        if (struct.fields.containsKey('uri')) {
          return RemoteArchive(struct.fields['uri']!.stringValue);
        }
        if (struct.fields.containsKey('assets')) {
          final assetsStruct = struct.fields['assets']!.structValue;
          final assets = <String, Object>{};
          for (final entry in assetsStruct.fields.entries) {
            final deserialized = deserializeValue(entry.value);
            if (deserialized is Asset || deserialized is Archive) {
              assets[entry.key] = deserialized;
            }
          }
          return AssetArchive(assets);
        }
        return null;
      }
    }

    // Regular struct - convert to Map
    return deserializeStruct(struct);
  }

  /// Converts a Struct to OutputData with proper metadata.
  ///
  /// This is useful for processing resource registration responses
  /// where we need to track secrets and dependencies.
  static OutputData<T> toOutputData<T>(
    Value value, {
    Set<String> dependencies = const {},
  }) {
    final result = _deserializeWithMetadata(value);
    return OutputData.known(
      result.value as T,
      isSecret: result.isSecret,
      dependencies: dependencies,
    );
  }

  static _DeserializedWithMetadata _deserializeWithMetadata(Value value) {
    switch (value.whichKind()) {
      case Value_Kind.structValue:
        final struct = value.structValue;

        // Check for special signatures
        if (struct.fields.containsKey(PropertySignatures.sigKey)) {
          final sig = struct.fields[PropertySignatures.sigKey]?.stringValue;

          if (sig == PropertySignatures.secretSig) {
            final innerValue = struct.fields['value'];
            if (innerValue != null) {
              final inner = _deserializeWithMetadata(innerValue);
              return _DeserializedWithMetadata(inner.value, isSecret: true);
            }
            return _DeserializedWithMetadata(null, isSecret: true);
          }

          if (sig == PropertySignatures.outputSig) {
            return _DeserializedWithMetadata(null, isKnown: false);
          }
        }

        // Regular struct
        final map = <String, dynamic>{};
        var anySecret = false;
        for (final entry in struct.fields.entries) {
          final result = _deserializeWithMetadata(entry.value);
          map[entry.key] = result.value;
          if (result.isSecret) anySecret = true;
        }
        return _DeserializedWithMetadata(map, isSecret: anySecret);

      case Value_Kind.listValue:
        final list = <dynamic>[];
        var anySecret = false;
        for (final item in value.listValue.values) {
          final result = _deserializeWithMetadata(item);
          list.add(result.value);
          if (result.isSecret) anySecret = true;
        }
        return _DeserializedWithMetadata(list, isSecret: anySecret);

      default:
        return _DeserializedWithMetadata(deserializeValue(value));
    }
  }
}

class _DeserializedWithMetadata {
  final dynamic value;
  final bool isSecret;
  final bool isKnown;

  _DeserializedWithMetadata(
    this.value, {
    this.isSecret = false,
    this.isKnown = true,
  });
}

/// Represents a secret value from deserialization.
///
/// This wrapper indicates that the contained value should be treated
/// as sensitive and not logged or displayed.
class SecretValue {
  /// The secret value.
  final dynamic value;

  SecretValue(this.value);

  @override
  String toString() => '[secret]';
}

/// Represents an unknown value during preview.
///
/// During `pulumi preview`, some values may not be known until
/// actual deployment. This class represents such unknown values.
class UnknownValue {
  @override
  String toString() => '[unknown]';
}

/// Represents a resource reference from deserialization.
///
/// Resource references encode dependencies between resources.
class ResourceReference {
  /// The URN of the referenced resource.
  final String urn;

  /// The ID of the referenced resource (may be null during preview).
  final String? id;

  ResourceReference({required this.urn, this.id});

  @override
  String toString() => 'ResourceReference(urn: $urn, id: $id)';
}

/// Base class for Pulumi assets.
///
/// An Asset is a blob of text or data that is managed by Pulumi. Assets can be:
/// - [FileAsset]: Contents read from a file on disk
/// - [StringAsset]: Contents provided as a literal string
/// - [RemoteAsset]: Contents fetched from a remote URI
///
/// Assets are typically used for resources that need file-like content,
/// such as AWS Lambda function code, S3 object contents, or configuration files.
///
/// ## Example
///
/// ```dart
/// // Inline code as a string
/// final code = StringAsset('''
///   exports.handler = async (event) => {
///     return { statusCode: 200, body: "Hello!" };
///   };
/// ''');
///
/// // Code from a file
/// final fileCode = FileAsset('./handler.js');
///
/// // Code from a URL
/// final remoteCode = RemoteAsset('https://example.com/handler.js');
/// ```
sealed class Asset {}

/// An asset whose contents are read from a file on disk.
///
/// The file is read at deployment time, and its contents become the asset data.
/// The path can be absolute or relative to the Pulumi program's working directory.
///
/// ## Example
///
/// ```dart
/// final lambdaCode = FileAsset('./src/handler.js');
/// ```
class FileAsset extends Asset {
  /// Path to the file.
  final String path;

  /// Creates a file asset from the given path.
  FileAsset(this.path);

  @override
  String toString() => 'FileAsset($path)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FileAsset && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// An asset whose contents are provided as a literal string.
///
/// Use this when you want to define the asset content inline in your code.
///
/// ## Example
///
/// ```dart
/// final config = StringAsset('''
/// server:
///   port: 8080
///   host: localhost
/// ''');
/// ```
class StringAsset extends Asset {
  /// The text content.
  final String text;

  /// Creates a string asset with the given content.
  StringAsset(this.text);

  @override
  String toString() => 'StringAsset(${text.length} chars)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StringAsset && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// An asset whose contents are fetched from a remote URI.
///
/// The URI is fetched at deployment time, and its contents become the asset data.
/// Supports http, https, and other URI schemes supported by the Pulumi engine.
///
/// ## Example
///
/// ```dart
/// final script = RemoteAsset('https://example.com/install.sh');
/// ```
class RemoteAsset extends Asset {
  /// URI of the remote asset.
  final String uri;

  /// Creates a remote asset from the given URI.
  RemoteAsset(this.uri);

  @override
  String toString() => 'RemoteAsset($uri)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RemoteAsset && uri == other.uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Base class for Pulumi archives.
///
/// An Archive is a collection of files that is managed by Pulumi. Archives can be:
/// - [FileArchive]: Contents read from a file or directory on disk
/// - [RemoteArchive]: Contents fetched from a remote URI
/// - [AssetArchive]: Composed from a map of assets and/or nested archives
///
/// Archives are typically used for resources that need collections of files,
/// such as AWS Lambda deployment packages or Azure Functions.
///
/// ## Example
///
/// ```dart
/// // Archive from a directory
/// final code = FileArchive('./dist');
///
/// // Archive from a zip file
/// final zipCode = FileArchive('./function.zip');
///
/// // Archive from a remote URL
/// final remoteCode = RemoteArchive('https://example.com/package.zip');
///
/// // Compose an archive from individual assets
/// final composed = AssetArchive({
///   'index.js': StringAsset('exports.handler = () => {};'),
///   'package.json': FileAsset('./package.json'),
/// });
/// ```
sealed class Archive {}

/// An archive whose contents are read from a file or directory on disk.
///
/// If the path points to a file, it should be a zip, tar, or tar.gz archive.
/// If the path points to a directory, its contents are recursively archived.
///
/// ## Example
///
/// ```dart
/// // Archive from a directory
/// final code = FileArchive('./dist');
///
/// // Archive from a zip file
/// final zipCode = FileArchive('./function.zip');
/// ```
class FileArchive extends Archive {
  /// Path to the archive file or directory.
  final String path;

  /// Creates a file archive from the given path.
  FileArchive(this.path);

  @override
  String toString() => 'FileArchive($path)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FileArchive && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// An archive whose contents are fetched from a remote URI.
///
/// The URI should point to a zip, tar, or tar.gz archive.
///
/// ## Example
///
/// ```dart
/// final code = RemoteArchive('https://example.com/package.zip');
/// ```
class RemoteArchive extends Archive {
  /// URI of the remote archive.
  final String uri;

  /// Creates a remote archive from the given URI.
  RemoteArchive(this.uri);

  @override
  String toString() => 'RemoteArchive($uri)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RemoteArchive && uri == other.uri;

  @override
  int get hashCode => uri.hashCode;
}

/// An archive composed from a map of named assets and/or nested archives.
///
/// This allows you to create archives programmatically from individual assets
/// or other archives. The keys are paths within the archive.
///
/// ## Example
///
/// ```dart
/// final archive = AssetArchive({
///   'index.js': StringAsset('exports.handler = () => {};'),
///   'lib/utils.js': FileAsset('./src/utils.js'),
///   'vendor/': FileArchive('./node_modules'),
/// });
/// ```
class AssetArchive extends Archive {
  /// Map of archive paths to their contents (Asset or Archive).
  final Map<String, Object> assets;

  /// Creates an asset archive from the given map.
  ///
  /// The values must be either [Asset] or [Archive] instances.
  AssetArchive(this.assets);

  @override
  String toString() => 'AssetArchive(${assets.length} entries)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetArchive && _mapsEqual(assets, other.assets);

  @override
  int get hashCode => Object.hashAll(assets.entries);

  static bool _mapsEqual(Map<String, Object> a, Map<String, Object> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
