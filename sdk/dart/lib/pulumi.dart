/// Pulumi SDK for Infrastructure as Code in Dart.
///
/// This library provides the core types and runtime for writing Pulumi programs
/// in Dart. Use this library to define and manage cloud infrastructure resources.
///
/// ## Example
///
/// ```dart
/// import 'package:pulumi/pulumi.dart';
///
/// Future<void> main() async {
///   await Pulumi.run((ctx) async {
///     // Define your infrastructure here
///   });
/// }
/// ```
library pulumi;

// Core SDK types
export 'src/output.dart';
export 'src/input.dart';
export 'src/options.dart';
export 'src/resource.dart';
export 'src/pulumi.dart';
export 'src/config.dart';
export 'src/invoke.dart';

// Runtime utilities (used by generated provider SDKs)
export 'src/runtime/serialization.dart' show PropertyDeserializer;

// Asset and Archive types
export 'src/runtime/serialization.dart'
    show Asset, FileAsset, StringAsset, RemoteAsset;
export 'src/runtime/serialization.dart'
    show Archive, FileArchive, RemoteArchive, AssetArchive;

// Proto-generated gRPC clients (internal use only)
// Note: alias.pb.dart Alias is hidden to avoid conflict with SDK Alias type
export 'src/proto/pulumi/resource.pb.dart';
export 'src/proto/pulumi/resource.pbgrpc.dart';
export 'src/proto/pulumi/provider.pb.dart';
export 'src/proto/pulumi/provider.pbgrpc.dart';
export 'src/proto/pulumi/engine.pb.dart';
export 'src/proto/pulumi/engine.pbgrpc.dart';
export 'src/proto/pulumi/plugin.pb.dart';
export 'src/proto/pulumi/alias.pb.dart' hide Alias;
export 'src/proto/pulumi/callback.pb.dart';
export 'src/proto/pulumi/callback.pbgrpc.dart';
export 'src/proto/pulumi/source.pb.dart';
