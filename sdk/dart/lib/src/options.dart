import 'input.dart';
import 'output.dart';

// Forward declaration - Resource will be imported where needed
// This avoids circular imports since Resource uses options
typedef ResourceRef = Object;

/// Specifies an alias for a resource, enabling renaming or moving resources
/// while preserving their state.
///
/// An alias can be specified either as a full URN string, or as a spec that
/// describes the old identity of the resource.
///
/// ## Example
///
/// ```dart
/// // Using a URN alias
/// final bucket = Bucket('new-name',
///   BucketArgs(),
///   CustomResourceOptions(
///     aliases: [Alias.urn('urn:pulumi:stack::project::aws:s3/bucket:Bucket::old-name')],
///   ),
/// );
///
/// // Using a spec alias (renamed resource)
/// final bucket = Bucket('new-name',
///   BucketArgs(),
///   CustomResourceOptions(
///     aliases: [Alias.name('old-name')],
///   ),
/// );
/// ```
sealed class Alias {
  const Alias();

  /// Creates an alias from a full URN.
  factory Alias.urn(String urn) = AliasUrn;

  /// Creates an alias from a spec that describes the old identity.
  factory Alias.spec({
    String? name,
    String? type,
    String? stack,
    String? project,
    String? parentUrn,
    bool? noParent,
  }) = AliasSpec;

  /// Convenience method to create an alias for a renamed resource.
  factory Alias.name(String name) => AliasSpec(name: name);

  /// Convenience method to create an alias for a resource that changed type.
  factory Alias.type(String type) => AliasSpec(type: type);

  /// Convenience method to create an alias for a resource that moved to a
  /// different parent.
  factory Alias.parent(String parentUrn) => AliasSpec(parentUrn: parentUrn);

  /// Convenience method to create an alias for a resource that was previously
  /// a root resource (no parent).
  factory Alias.noParent() => AliasSpec(noParent: true);
}

/// An alias specified as a full URN.
final class AliasUrn extends Alias {
  /// The full URN of the old resource identity.
  final String urn;

  /// Creates an alias URN.
  const AliasUrn(this.urn);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AliasUrn && runtimeType == other.runtimeType && urn == other.urn;

  @override
  int get hashCode => urn.hashCode;

  @override
  String toString() => 'AliasUrn($urn)';
}

/// An alias specified as a set of properties describing the old identity.
///
/// Any properties not specified will be inherited from the current resource.
final class AliasSpec extends Alias {
  /// The old name of the resource.
  final String? name;

  /// The old type of the resource.
  final String? type;

  /// The old stack the resource was in.
  final String? stack;

  /// The old project the resource was in.
  final String? project;

  /// The old parent URN of the resource.
  final String? parentUrn;

  /// If true, the resource previously had no parent.
  final bool? noParent;

  /// Creates an alias spec.
  const AliasSpec({
    this.name,
    this.type,
    this.stack,
    this.project,
    this.parentUrn,
    this.noParent,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AliasSpec &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type &&
          stack == other.stack &&
          project == other.project &&
          parentUrn == other.parentUrn &&
          noParent == other.noParent;

  @override
  int get hashCode => Object.hash(name, type, stack, project, parentUrn, noParent);

  @override
  String toString() =>
      'AliasSpec(name: $name, type: $type, stack: $stack, project: $project, '
      'parentUrn: $parentUrn, noParent: $noParent)';
}

/// Custom timeout values for resource operations.
///
/// Timeouts should be specified as duration strings like "30m", "1h", "2h30m".
/// If not specified, provider defaults are used.
///
/// ## Example
///
/// ```dart
/// final bucket = Bucket('large-data-bucket',
///   BucketArgs(),
///   CustomResourceOptions(
///     customTimeouts: CustomTimeouts(
///       create: '30m',
///       delete: '1h',
///     ),
///   ),
/// );
/// ```
class CustomTimeouts {
  /// The timeout for create operations.
  final String? create;

  /// The timeout for update operations.
  final String? update;

  /// The timeout for delete operations.
  final String? delete;

  /// Creates custom timeout values.
  const CustomTimeouts({
    this.create,
    this.update,
    this.delete,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomTimeouts &&
          runtimeType == other.runtimeType &&
          create == other.create &&
          update == other.update &&
          delete == other.delete;

  @override
  int get hashCode => Object.hash(create, update, delete);

  @override
  String toString() =>
      'CustomTimeouts(create: $create, update: $update, delete: $delete)';
}

/// Options for controlling resource behavior.
///
/// These options are shared by all resource types. Specific resource types
/// may have additional options (e.g., [CustomResourceOptions]).
///
/// ## Example
///
/// ```dart
/// final component = MyComponent('my-component',
///   MyComponentArgs(),
///   ResourceOptions(
///     parent: parentResource,
///     protect: true,
///     dependsOn: [database, vpc],
///   ),
/// );
/// ```
class ResourceOptions {
  /// An optional parent resource.
  ///
  /// When set, this resource will be a child of the parent, affecting URN
  /// construction and default provider inheritance.
  final ResourceRef? parent;

  /// When true, the resource will be protected from deletion.
  ///
  /// A protected resource cannot be deleted directly; the protection must be
  /// removed first by setting protect to false and running an update.
  final bool protect;

  /// An optional list of explicit dependencies.
  ///
  /// The resource will not be created until all dependencies have been created.
  /// Use this when there's an implicit dependency that Pulumi cannot detect
  /// automatically (e.g., a resource that depends on another resource's
  /// side effects).
  final List<ResourceRef> dependsOn;

  /// An optional provider to use for this resource.
  ///
  /// If not specified, the default provider for the resource type will be used.
  /// This is specified as a provider reference string.
  final String? provider;

  /// When true, the resource will be retained when the stack is destroyed.
  ///
  /// This is useful for resources that should persist after the infrastructure
  /// is torn down, such as S3 buckets with important data.
  final bool retainOnDelete;

  /// The URN of the resource that this resource should be deleted with.
  ///
  /// If specified, when the referenced resource is deleted, this resource
  /// will also be deleted. This is used to express cascade delete semantics.
  final String? deletedWith;

  /// Aliases for this resource, allowing it to be matched to a previous
  /// resource that had a different URN.
  ///
  /// Use this when renaming resources, changing their type, moving them
  /// to a different parent, or moving them between stacks/projects.
  final List<Alias> aliases;

  /// A list of property names to ignore when detecting changes.
  ///
  /// Use this when a property changes frequently but the changes don't
  /// require a resource update (e.g., timestamps or computed values).
  final List<String> ignoreChanges;

  /// A list of property names that will force a replacement when changed.
  ///
  /// Normally, Pulumi determines which properties require replacement based
  /// on the provider schema. Use this to force replacement on additional
  /// properties.
  final List<String> replaceOnChanges;

  /// Custom timeout values for CRUD operations.
  ///
  /// If not specified, provider defaults are used.
  final CustomTimeouts? customTimeouts;

  /// The version of the provider plugin to use.
  ///
  /// If not specified, the latest version will be used.
  final String? version;

  /// A URL to download the provider plugin from.
  ///
  /// This is useful for using custom or pre-release provider versions.
  final String? pluginDownloadUrl;

  /// Creates resource options.
  const ResourceOptions({
    this.parent,
    this.protect = false,
    this.dependsOn = const [],
    this.provider,
    this.retainOnDelete = false,
    this.deletedWith,
    this.aliases = const [],
    this.ignoreChanges = const [],
    this.replaceOnChanges = const [],
    this.customTimeouts,
    this.version,
    this.pluginDownloadUrl,
  });

  /// Creates a copy of this options with the given fields replaced.
  ResourceOptions copyWith({
    ResourceRef? parent,
    bool? protect,
    List<ResourceRef>? dependsOn,
    String? provider,
    bool? retainOnDelete,
    String? deletedWith,
    List<Alias>? aliases,
    List<String>? ignoreChanges,
    List<String>? replaceOnChanges,
    CustomTimeouts? customTimeouts,
    String? version,
    String? pluginDownloadUrl,
  }) {
    return ResourceOptions(
      parent: parent ?? this.parent,
      protect: protect ?? this.protect,
      dependsOn: dependsOn ?? this.dependsOn,
      provider: provider ?? this.provider,
      retainOnDelete: retainOnDelete ?? this.retainOnDelete,
      deletedWith: deletedWith ?? this.deletedWith,
      aliases: aliases ?? this.aliases,
      ignoreChanges: ignoreChanges ?? this.ignoreChanges,
      replaceOnChanges: replaceOnChanges ?? this.replaceOnChanges,
      customTimeouts: customTimeouts ?? this.customTimeouts,
      version: version ?? this.version,
      pluginDownloadUrl: pluginDownloadUrl ?? this.pluginDownloadUrl,
    );
  }
}

/// Options specific to custom resources (resources managed by providers).
///
/// Extends [ResourceOptions] with options that only apply to custom resources,
/// such as import ID and delete-before-replace behavior.
///
/// ## Example
///
/// ```dart
/// // Import an existing resource
/// final bucket = Bucket('imported-bucket',
///   BucketArgs(),
///   CustomResourceOptions(
///     importId: 'my-existing-bucket-name',
///   ),
/// );
///
/// // Force delete before replace
/// final instance = Instance('my-instance',
///   InstanceArgs(),
///   CustomResourceOptions(
///     deleteBeforeReplace: true,
///   ),
/// );
/// ```
class CustomResourceOptions extends ResourceOptions {
  /// An ID to use to import an existing resource.
  ///
  /// When specified, Pulumi will import the existing resource with the given
  /// ID rather than creating a new one. This is used to bring existing
  /// infrastructure under Pulumi management.
  final String? importId;

  /// When true, the resource will be deleted before being replaced.
  ///
  /// By default, Pulumi creates the replacement resource before deleting the
  /// old one (create-before-delete). Setting this to true reverses that order,
  /// which can be necessary when resource names or identifiers must be unique.
  final bool deleteBeforeReplace;

  /// Additional properties that should be treated as secrets.
  ///
  /// These properties will be encrypted in the state file even if the
  /// provider does not mark them as secrets.
  final List<String> additionalSecretOutputs;

  /// Creates custom resource options.
  const CustomResourceOptions({
    super.parent,
    super.protect,
    super.dependsOn,
    super.provider,
    super.retainOnDelete,
    super.deletedWith,
    super.aliases,
    super.ignoreChanges,
    super.replaceOnChanges,
    super.customTimeouts,
    super.version,
    super.pluginDownloadUrl,
    this.importId,
    this.deleteBeforeReplace = false,
    this.additionalSecretOutputs = const [],
  });

  /// Creates a copy of this options with the given fields replaced.
  @override
  CustomResourceOptions copyWith({
    ResourceRef? parent,
    bool? protect,
    List<ResourceRef>? dependsOn,
    String? provider,
    bool? retainOnDelete,
    String? deletedWith,
    List<Alias>? aliases,
    List<String>? ignoreChanges,
    List<String>? replaceOnChanges,
    CustomTimeouts? customTimeouts,
    String? version,
    String? pluginDownloadUrl,
    String? importId,
    bool? deleteBeforeReplace,
    List<String>? additionalSecretOutputs,
  }) {
    return CustomResourceOptions(
      parent: parent ?? this.parent,
      protect: protect ?? this.protect,
      dependsOn: dependsOn ?? this.dependsOn,
      provider: provider ?? this.provider,
      retainOnDelete: retainOnDelete ?? this.retainOnDelete,
      deletedWith: deletedWith ?? this.deletedWith,
      aliases: aliases ?? this.aliases,
      ignoreChanges: ignoreChanges ?? this.ignoreChanges,
      replaceOnChanges: replaceOnChanges ?? this.replaceOnChanges,
      customTimeouts: customTimeouts ?? this.customTimeouts,
      version: version ?? this.version,
      pluginDownloadUrl: pluginDownloadUrl ?? this.pluginDownloadUrl,
      importId: importId ?? this.importId,
      deleteBeforeReplace: deleteBeforeReplace ?? this.deleteBeforeReplace,
      additionalSecretOutputs:
          additionalSecretOutputs ?? this.additionalSecretOutputs,
    );
  }
}

/// Options specific to component resources.
///
/// Currently this is the same as [ResourceOptions], but is provided for
/// type safety and future extensibility.
typedef ComponentResourceOptions = ResourceOptions;
