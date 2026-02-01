// This is a generated file - do not edit.
//
// Generated from pulumi/language.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart' as $3;

import 'codegen/hcl.pb.dart' as $4;
import 'plugin.pb.dart' as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// ProgramInfo are the common set of options that a language runtime needs to execute or query a program. This
/// is filled in by the engine based on where the `Pulumi.yaml` file was, the `runtime.options` property, and
/// the `main` property.
class ProgramInfo extends $pb.GeneratedMessage {
  factory ProgramInfo({
    $core.String? rootDirectory,
    $core.String? programDirectory,
    $core.String? entryPoint,
    $3.Struct? options,
  }) {
    final result = create();
    if (rootDirectory != null) result.rootDirectory = rootDirectory;
    if (programDirectory != null) result.programDirectory = programDirectory;
    if (entryPoint != null) result.entryPoint = entryPoint;
    if (options != null) result.options = options;
    return result;
  }

  ProgramInfo._();

  factory ProgramInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgramInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgramInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'rootDirectory')
    ..aOS(2, _omitFieldNames ? '' : 'programDirectory')
    ..aOS(3, _omitFieldNames ? '' : 'entryPoint')
    ..aOM<$3.Struct>(4, _omitFieldNames ? '' : 'options',
        subBuilder: $3.Struct.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgramInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgramInfo copyWith(void Function(ProgramInfo) updates) =>
      super.copyWith((message) => updates(message as ProgramInfo))
          as ProgramInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProgramInfo create() => ProgramInfo._();
  @$core.override
  ProgramInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgramInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgramInfo>(create);
  static ProgramInfo? _defaultInstance;

  /// the root of the project, where the `Pulumi.yaml` file is located.
  @$pb.TagNumber(1)
  $core.String get rootDirectory => $_getSZ(0);
  @$pb.TagNumber(1)
  set rootDirectory($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRootDirectory() => $_has(0);
  @$pb.TagNumber(1)
  void clearRootDirectory() => $_clearField(1);

  /// the absolute path to the directory of the program to execute. Generally, but not required to be,
  /// underneath the root directory.
  @$pb.TagNumber(2)
  $core.String get programDirectory => $_getSZ(1);
  @$pb.TagNumber(2)
  set programDirectory($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProgramDirectory() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgramDirectory() => $_clearField(2);

  /// the entry point of the program, normally '.' meaning to just use the program directory, but can also be
  /// a filename inside the program directory. How that filename is interpreted, if at all, is language
  /// specific.
  @$pb.TagNumber(3)
  $core.String get entryPoint => $_getSZ(2);
  @$pb.TagNumber(3)
  set entryPoint($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEntryPoint() => $_has(2);
  @$pb.TagNumber(3)
  void clearEntryPoint() => $_clearField(3);

  /// JSON style options from the `Pulumi.yaml` runtime options section.
  @$pb.TagNumber(4)
  $3.Struct get options => $_getN(3);
  @$pb.TagNumber(4)
  set options($3.Struct value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasOptions() => $_has(3);
  @$pb.TagNumber(4)
  void clearOptions() => $_clearField(4);
  @$pb.TagNumber(4)
  $3.Struct ensureOptions() => $_ensure(3);
}

/// AboutResponse returns runtime information about the language.
class AboutResponse extends $pb.GeneratedMessage {
  factory AboutResponse({
    $core.String? executable,
    $core.String? version,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
  }) {
    final result = create();
    if (executable != null) result.executable = executable;
    if (version != null) result.version = version;
    if (metadata != null) result.metadata.addEntries(metadata);
    return result;
  }

  AboutResponse._();

  factory AboutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AboutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AboutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'executable')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'AboutResponse.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('pulumirpc'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AboutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AboutResponse copyWith(void Function(AboutResponse) updates) =>
      super.copyWith((message) => updates(message as AboutResponse))
          as AboutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AboutResponse create() => AboutResponse._();
  @$core.override
  AboutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AboutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AboutResponse>(create);
  static AboutResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get executable => $_getSZ(0);
  @$pb.TagNumber(1)
  set executable($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExecutable() => $_has(0);
  @$pb.TagNumber(1)
  void clearExecutable() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(2);
}

class GetProgramDependenciesRequest extends $pb.GeneratedMessage {
  factory GetProgramDependenciesRequest({
    @$core.Deprecated('This field is deprecated.') $core.String? project,
    @$core.Deprecated('This field is deprecated.') $core.String? pwd,
    @$core.Deprecated('This field is deprecated.') $core.String? program,
    $core.bool? transitiveDependencies,
    ProgramInfo? info,
  }) {
    final result = create();
    if (project != null) result.project = project;
    if (pwd != null) result.pwd = pwd;
    if (program != null) result.program = program;
    if (transitiveDependencies != null)
      result.transitiveDependencies = transitiveDependencies;
    if (info != null) result.info = info;
    return result;
  }

  GetProgramDependenciesRequest._();

  factory GetProgramDependenciesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProgramDependenciesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProgramDependenciesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'project')
    ..aOS(2, _omitFieldNames ? '' : 'pwd')
    ..aOS(3, _omitFieldNames ? '' : 'program')
    ..aOB(4, _omitFieldNames ? '' : 'transitiveDependencies',
        protoName: 'transitiveDependencies')
    ..aOM<ProgramInfo>(5, _omitFieldNames ? '' : 'info',
        subBuilder: ProgramInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgramDependenciesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgramDependenciesRequest copyWith(
          void Function(GetProgramDependenciesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetProgramDependenciesRequest))
          as GetProgramDependenciesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProgramDependenciesRequest create() =>
      GetProgramDependenciesRequest._();
  @$core.override
  GetProgramDependenciesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProgramDependenciesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProgramDependenciesRequest>(create);
  static GetProgramDependenciesRequest? _defaultInstance;

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  $core.String get project => $_getSZ(0);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  set project($core.String value) => $_setString(0, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  $core.bool hasProject() => $_has(0);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  void clearProject() => $_clearField(1);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.String get pwd => $_getSZ(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  set pwd($core.String value) => $_setString(1, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.bool hasPwd() => $_has(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  void clearPwd() => $_clearField(2);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.String get program => $_getSZ(2);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  set program($core.String value) => $_setString(2, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.bool hasProgram() => $_has(2);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  void clearProgram() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get transitiveDependencies => $_getBF(3);
  @$pb.TagNumber(4)
  set transitiveDependencies($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTransitiveDependencies() => $_has(3);
  @$pb.TagNumber(4)
  void clearTransitiveDependencies() => $_clearField(4);

  @$pb.TagNumber(5)
  ProgramInfo get info => $_getN(4);
  @$pb.TagNumber(5)
  set info(ProgramInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasInfo() => $_has(4);
  @$pb.TagNumber(5)
  void clearInfo() => $_clearField(5);
  @$pb.TagNumber(5)
  ProgramInfo ensureInfo() => $_ensure(4);
}

class DependencyInfo extends $pb.GeneratedMessage {
  factory DependencyInfo({
    $core.String? name,
    $core.String? version,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (version != null) result.version = version;
    return result;
  }

  DependencyInfo._();

  factory DependencyInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DependencyInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DependencyInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DependencyInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DependencyInfo copyWith(void Function(DependencyInfo) updates) =>
      super.copyWith((message) => updates(message as DependencyInfo))
          as DependencyInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DependencyInfo create() => DependencyInfo._();
  @$core.override
  DependencyInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DependencyInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DependencyInfo>(create);
  static DependencyInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);
}

class GetProgramDependenciesResponse extends $pb.GeneratedMessage {
  factory GetProgramDependenciesResponse({
    $core.Iterable<DependencyInfo>? dependencies,
  }) {
    final result = create();
    if (dependencies != null) result.dependencies.addAll(dependencies);
    return result;
  }

  GetProgramDependenciesResponse._();

  factory GetProgramDependenciesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProgramDependenciesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProgramDependenciesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..pPM<DependencyInfo>(1, _omitFieldNames ? '' : 'dependencies',
        subBuilder: DependencyInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgramDependenciesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgramDependenciesResponse copyWith(
          void Function(GetProgramDependenciesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetProgramDependenciesResponse))
          as GetProgramDependenciesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProgramDependenciesResponse create() =>
      GetProgramDependenciesResponse._();
  @$core.override
  GetProgramDependenciesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProgramDependenciesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProgramDependenciesResponse>(create);
  static GetProgramDependenciesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DependencyInfo> get dependencies => $_getList(0);
}

class GetRequiredPluginsRequest extends $pb.GeneratedMessage {
  factory GetRequiredPluginsRequest({
    @$core.Deprecated('This field is deprecated.') $core.String? project,
    @$core.Deprecated('This field is deprecated.') $core.String? pwd,
    @$core.Deprecated('This field is deprecated.') $core.String? program,
    ProgramInfo? info,
  }) {
    final result = create();
    if (project != null) result.project = project;
    if (pwd != null) result.pwd = pwd;
    if (program != null) result.program = program;
    if (info != null) result.info = info;
    return result;
  }

  GetRequiredPluginsRequest._();

  factory GetRequiredPluginsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRequiredPluginsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRequiredPluginsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'project')
    ..aOS(2, _omitFieldNames ? '' : 'pwd')
    ..aOS(3, _omitFieldNames ? '' : 'program')
    ..aOM<ProgramInfo>(4, _omitFieldNames ? '' : 'info',
        subBuilder: ProgramInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequiredPluginsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequiredPluginsRequest copyWith(
          void Function(GetRequiredPluginsRequest) updates) =>
      super.copyWith((message) => updates(message as GetRequiredPluginsRequest))
          as GetRequiredPluginsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRequiredPluginsRequest create() => GetRequiredPluginsRequest._();
  @$core.override
  GetRequiredPluginsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRequiredPluginsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRequiredPluginsRequest>(create);
  static GetRequiredPluginsRequest? _defaultInstance;

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  $core.String get project => $_getSZ(0);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  set project($core.String value) => $_setString(0, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  $core.bool hasProject() => $_has(0);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  void clearProject() => $_clearField(1);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.String get pwd => $_getSZ(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  set pwd($core.String value) => $_setString(1, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.bool hasPwd() => $_has(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  void clearPwd() => $_clearField(2);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.String get program => $_getSZ(2);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  set program($core.String value) => $_setString(2, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.bool hasProgram() => $_has(2);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  void clearProgram() => $_clearField(3);

  @$pb.TagNumber(4)
  ProgramInfo get info => $_getN(3);
  @$pb.TagNumber(4)
  set info(ProgramInfo value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasInfo() => $_has(3);
  @$pb.TagNumber(4)
  void clearInfo() => $_clearField(4);
  @$pb.TagNumber(4)
  ProgramInfo ensureInfo() => $_ensure(3);
}

class GetRequiredPluginsResponse extends $pb.GeneratedMessage {
  factory GetRequiredPluginsResponse({
    $core.Iterable<$2.PluginDependency>? plugins,
  }) {
    final result = create();
    if (plugins != null) result.plugins.addAll(plugins);
    return result;
  }

  GetRequiredPluginsResponse._();

  factory GetRequiredPluginsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRequiredPluginsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRequiredPluginsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..pPM<$2.PluginDependency>(1, _omitFieldNames ? '' : 'plugins',
        subBuilder: $2.PluginDependency.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequiredPluginsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequiredPluginsResponse copyWith(
          void Function(GetRequiredPluginsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetRequiredPluginsResponse))
          as GetRequiredPluginsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRequiredPluginsResponse create() => GetRequiredPluginsResponse._();
  @$core.override
  GetRequiredPluginsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRequiredPluginsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRequiredPluginsResponse>(create);
  static GetRequiredPluginsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$2.PluginDependency> get plugins => $_getList(0);
}

/// RunRequest asks the interpreter to execute a program.
class RunRequest extends $pb.GeneratedMessage {
  factory RunRequest({
    $core.String? project,
    $core.String? stack,
    $core.String? pwd,
    @$core.Deprecated('This field is deprecated.') $core.String? program,
    $core.Iterable<$core.String>? args,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? config,
    $core.bool? dryRun,
    $core.int? parallel,
    $core.String? monitorAddress,
    $core.bool? queryMode,
    $core.Iterable<$core.String>? configSecretKeys,
    $core.String? organization,
    $3.Struct? configPropertyMap,
    ProgramInfo? info,
  }) {
    final result = create();
    if (project != null) result.project = project;
    if (stack != null) result.stack = stack;
    if (pwd != null) result.pwd = pwd;
    if (program != null) result.program = program;
    if (args != null) result.args.addAll(args);
    if (config != null) result.config.addEntries(config);
    if (dryRun != null) result.dryRun = dryRun;
    if (parallel != null) result.parallel = parallel;
    if (monitorAddress != null) result.monitorAddress = monitorAddress;
    if (queryMode != null) result.queryMode = queryMode;
    if (configSecretKeys != null)
      result.configSecretKeys.addAll(configSecretKeys);
    if (organization != null) result.organization = organization;
    if (configPropertyMap != null) result.configPropertyMap = configPropertyMap;
    if (info != null) result.info = info;
    return result;
  }

  RunRequest._();

  factory RunRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RunRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'project')
    ..aOS(2, _omitFieldNames ? '' : 'stack')
    ..aOS(3, _omitFieldNames ? '' : 'pwd')
    ..aOS(4, _omitFieldNames ? '' : 'program')
    ..pPS(5, _omitFieldNames ? '' : 'args')
    ..m<$core.String, $core.String>(6, _omitFieldNames ? '' : 'config',
        entryClassName: 'RunRequest.ConfigEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('pulumirpc'))
    ..aOB(7, _omitFieldNames ? '' : 'dryRun', protoName: 'dryRun')
    ..aI(8, _omitFieldNames ? '' : 'parallel')
    ..aOS(9, _omitFieldNames ? '' : 'monitorAddress')
    ..aOB(10, _omitFieldNames ? '' : 'queryMode', protoName: 'queryMode')
    ..pPS(11, _omitFieldNames ? '' : 'configSecretKeys',
        protoName: 'configSecretKeys')
    ..aOS(12, _omitFieldNames ? '' : 'organization')
    ..aOM<$3.Struct>(13, _omitFieldNames ? '' : 'configPropertyMap',
        protoName: 'configPropertyMap', subBuilder: $3.Struct.create)
    ..aOM<ProgramInfo>(14, _omitFieldNames ? '' : 'info',
        subBuilder: ProgramInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunRequest copyWith(void Function(RunRequest) updates) =>
      super.copyWith((message) => updates(message as RunRequest)) as RunRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RunRequest create() => RunRequest._();
  @$core.override
  RunRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RunRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RunRequest>(create);
  static RunRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get project => $_getSZ(0);
  @$pb.TagNumber(1)
  set project($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProject() => $_has(0);
  @$pb.TagNumber(1)
  void clearProject() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get stack => $_getSZ(1);
  @$pb.TagNumber(2)
  set stack($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStack() => $_has(1);
  @$pb.TagNumber(2)
  void clearStack() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get pwd => $_getSZ(2);
  @$pb.TagNumber(3)
  set pwd($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPwd() => $_has(2);
  @$pb.TagNumber(3)
  void clearPwd() => $_clearField(3);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  $core.String get program => $_getSZ(3);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  set program($core.String value) => $_setString(3, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  $core.bool hasProgram() => $_has(3);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  void clearProgram() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get args => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbMap<$core.String, $core.String> get config => $_getMap(5);

  @$pb.TagNumber(7)
  $core.bool get dryRun => $_getBF(6);
  @$pb.TagNumber(7)
  set dryRun($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDryRun() => $_has(6);
  @$pb.TagNumber(7)
  void clearDryRun() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get parallel => $_getIZ(7);
  @$pb.TagNumber(8)
  set parallel($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasParallel() => $_has(7);
  @$pb.TagNumber(8)
  void clearParallel() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get monitorAddress => $_getSZ(8);
  @$pb.TagNumber(9)
  set monitorAddress($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMonitorAddress() => $_has(8);
  @$pb.TagNumber(9)
  void clearMonitorAddress() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get queryMode => $_getBF(9);
  @$pb.TagNumber(10)
  set queryMode($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasQueryMode() => $_has(9);
  @$pb.TagNumber(10)
  void clearQueryMode() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get configSecretKeys => $_getList(10);

  @$pb.TagNumber(12)
  $core.String get organization => $_getSZ(11);
  @$pb.TagNumber(12)
  set organization($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasOrganization() => $_has(11);
  @$pb.TagNumber(12)
  void clearOrganization() => $_clearField(12);

  @$pb.TagNumber(13)
  $3.Struct get configPropertyMap => $_getN(12);
  @$pb.TagNumber(13)
  set configPropertyMap($3.Struct value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasConfigPropertyMap() => $_has(12);
  @$pb.TagNumber(13)
  void clearConfigPropertyMap() => $_clearField(13);
  @$pb.TagNumber(13)
  $3.Struct ensureConfigPropertyMap() => $_ensure(12);

  @$pb.TagNumber(14)
  ProgramInfo get info => $_getN(13);
  @$pb.TagNumber(14)
  set info(ProgramInfo value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasInfo() => $_has(13);
  @$pb.TagNumber(14)
  void clearInfo() => $_clearField(14);
  @$pb.TagNumber(14)
  ProgramInfo ensureInfo() => $_ensure(13);
}

/// RunResponse is the response back from the interpreter/source back to the monitor.
class RunResponse extends $pb.GeneratedMessage {
  factory RunResponse({
    $core.String? error,
    $core.bool? bail,
  }) {
    final result = create();
    if (error != null) result.error = error;
    if (bail != null) result.bail = bail;
    return result;
  }

  RunResponse._();

  factory RunResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RunResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'error')
    ..aOB(2, _omitFieldNames ? '' : 'bail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunResponse copyWith(void Function(RunResponse) updates) =>
      super.copyWith((message) => updates(message as RunResponse))
          as RunResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RunResponse create() => RunResponse._();
  @$core.override
  RunResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RunResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RunResponse>(create);
  static RunResponse? _defaultInstance;

  /// An unhandled error if any occurred.
  @$pb.TagNumber(1)
  $core.String get error => $_getSZ(0);
  @$pb.TagNumber(1)
  set error($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(1)
  void clearError() => $_clearField(1);

  /// An error happened.  And it was reported to the user.  Work should stop immediately
  /// with nothing further to print to the user.  This corresponds to a "result.Bail()"
  /// value in the 'go' layer.
  @$pb.TagNumber(2)
  $core.bool get bail => $_getBF(1);
  @$pb.TagNumber(2)
  set bail($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBail() => $_has(1);
  @$pb.TagNumber(2)
  void clearBail() => $_clearField(2);
}

class InstallDependenciesRequest extends $pb.GeneratedMessage {
  factory InstallDependenciesRequest({
    @$core.Deprecated('This field is deprecated.') $core.String? directory,
    $core.bool? isTerminal,
    ProgramInfo? info,
  }) {
    final result = create();
    if (directory != null) result.directory = directory;
    if (isTerminal != null) result.isTerminal = isTerminal;
    if (info != null) result.info = info;
    return result;
  }

  InstallDependenciesRequest._();

  factory InstallDependenciesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InstallDependenciesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InstallDependenciesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'directory')
    ..aOB(2, _omitFieldNames ? '' : 'isTerminal')
    ..aOM<ProgramInfo>(3, _omitFieldNames ? '' : 'info',
        subBuilder: ProgramInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InstallDependenciesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InstallDependenciesRequest copyWith(
          void Function(InstallDependenciesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as InstallDependenciesRequest))
          as InstallDependenciesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InstallDependenciesRequest create() => InstallDependenciesRequest._();
  @$core.override
  InstallDependenciesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InstallDependenciesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InstallDependenciesRequest>(create);
  static InstallDependenciesRequest? _defaultInstance;

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  $core.String get directory => $_getSZ(0);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  set directory($core.String value) => $_setString(0, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  $core.bool hasDirectory() => $_has(0);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(1)
  void clearDirectory() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isTerminal => $_getBF(1);
  @$pb.TagNumber(2)
  set isTerminal($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsTerminal() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsTerminal() => $_clearField(2);

  @$pb.TagNumber(3)
  ProgramInfo get info => $_getN(2);
  @$pb.TagNumber(3)
  set info(ProgramInfo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearInfo() => $_clearField(3);
  @$pb.TagNumber(3)
  ProgramInfo ensureInfo() => $_ensure(2);
}

class InstallDependenciesResponse extends $pb.GeneratedMessage {
  factory InstallDependenciesResponse({
    $core.List<$core.int>? stdout,
    $core.List<$core.int>? stderr,
  }) {
    final result = create();
    if (stdout != null) result.stdout = stdout;
    if (stderr != null) result.stderr = stderr;
    return result;
  }

  InstallDependenciesResponse._();

  factory InstallDependenciesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InstallDependenciesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InstallDependenciesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'stdout', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'stderr', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InstallDependenciesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InstallDependenciesResponse copyWith(
          void Function(InstallDependenciesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as InstallDependenciesResponse))
          as InstallDependenciesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InstallDependenciesResponse create() =>
      InstallDependenciesResponse._();
  @$core.override
  InstallDependenciesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InstallDependenciesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InstallDependenciesResponse>(create);
  static InstallDependenciesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get stdout => $_getN(0);
  @$pb.TagNumber(1)
  set stdout($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStdout() => $_has(0);
  @$pb.TagNumber(1)
  void clearStdout() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get stderr => $_getN(1);
  @$pb.TagNumber(2)
  set stderr($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStderr() => $_has(1);
  @$pb.TagNumber(2)
  void clearStderr() => $_clearField(2);
}

class RunPluginRequest extends $pb.GeneratedMessage {
  factory RunPluginRequest({
    $core.String? pwd,
    @$core.Deprecated('This field is deprecated.') $core.String? program,
    $core.Iterable<$core.String>? args,
    $core.Iterable<$core.String>? env,
    ProgramInfo? info,
  }) {
    final result = create();
    if (pwd != null) result.pwd = pwd;
    if (program != null) result.program = program;
    if (args != null) result.args.addAll(args);
    if (env != null) result.env.addAll(env);
    if (info != null) result.info = info;
    return result;
  }

  RunPluginRequest._();

  factory RunPluginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RunPluginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunPluginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pwd')
    ..aOS(2, _omitFieldNames ? '' : 'program')
    ..pPS(3, _omitFieldNames ? '' : 'args')
    ..pPS(4, _omitFieldNames ? '' : 'env')
    ..aOM<ProgramInfo>(5, _omitFieldNames ? '' : 'info',
        subBuilder: ProgramInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunPluginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunPluginRequest copyWith(void Function(RunPluginRequest) updates) =>
      super.copyWith((message) => updates(message as RunPluginRequest))
          as RunPluginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RunPluginRequest create() => RunPluginRequest._();
  @$core.override
  RunPluginRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RunPluginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RunPluginRequest>(create);
  static RunPluginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pwd => $_getSZ(0);
  @$pb.TagNumber(1)
  set pwd($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPwd() => $_has(0);
  @$pb.TagNumber(1)
  void clearPwd() => $_clearField(1);

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.String get program => $_getSZ(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  set program($core.String value) => $_setString(1, value);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  $core.bool hasProgram() => $_has(1);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(2)
  void clearProgram() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get args => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get env => $_getList(3);

  @$pb.TagNumber(5)
  ProgramInfo get info => $_getN(4);
  @$pb.TagNumber(5)
  set info(ProgramInfo value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasInfo() => $_has(4);
  @$pb.TagNumber(5)
  void clearInfo() => $_clearField(5);
  @$pb.TagNumber(5)
  ProgramInfo ensureInfo() => $_ensure(4);
}

enum RunPluginResponse_Output { stdout, stderr, exitcode, notSet }

class RunPluginResponse extends $pb.GeneratedMessage {
  factory RunPluginResponse({
    $core.List<$core.int>? stdout,
    $core.List<$core.int>? stderr,
    $core.int? exitcode,
  }) {
    final result = create();
    if (stdout != null) result.stdout = stdout;
    if (stderr != null) result.stderr = stderr;
    if (exitcode != null) result.exitcode = exitcode;
    return result;
  }

  RunPluginResponse._();

  factory RunPluginResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RunPluginResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RunPluginResponse_Output>
      _RunPluginResponse_OutputByTag = {
    1: RunPluginResponse_Output.stdout,
    2: RunPluginResponse_Output.stderr,
    3: RunPluginResponse_Output.exitcode,
    0: RunPluginResponse_Output.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunPluginResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3])
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'stdout', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'stderr', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'exitcode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunPluginResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunPluginResponse copyWith(void Function(RunPluginResponse) updates) =>
      super.copyWith((message) => updates(message as RunPluginResponse))
          as RunPluginResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RunPluginResponse create() => RunPluginResponse._();
  @$core.override
  RunPluginResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RunPluginResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RunPluginResponse>(create);
  static RunPluginResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  RunPluginResponse_Output whichOutput() =>
      _RunPluginResponse_OutputByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearOutput() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.List<$core.int> get stdout => $_getN(0);
  @$pb.TagNumber(1)
  set stdout($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStdout() => $_has(0);
  @$pb.TagNumber(1)
  void clearStdout() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get stderr => $_getN(1);
  @$pb.TagNumber(2)
  set stderr($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStderr() => $_has(1);
  @$pb.TagNumber(2)
  void clearStderr() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get exitcode => $_getIZ(2);
  @$pb.TagNumber(3)
  set exitcode($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExitcode() => $_has(2);
  @$pb.TagNumber(3)
  void clearExitcode() => $_clearField(3);
}

class GenerateProgramRequest extends $pb.GeneratedMessage {
  factory GenerateProgramRequest({
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? source,
    $core.String? loaderTarget,
  }) {
    final result = create();
    if (source != null) result.source.addEntries(source);
    if (loaderTarget != null) result.loaderTarget = loaderTarget;
    return result;
  }

  GenerateProgramRequest._();

  factory GenerateProgramRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateProgramRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateProgramRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'source',
        entryClassName: 'GenerateProgramRequest.SourceEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('pulumirpc'))
    ..aOS(2, _omitFieldNames ? '' : 'loaderTarget')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProgramRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProgramRequest copyWith(
          void Function(GenerateProgramRequest) updates) =>
      super.copyWith((message) => updates(message as GenerateProgramRequest))
          as GenerateProgramRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateProgramRequest create() => GenerateProgramRequest._();
  @$core.override
  GenerateProgramRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateProgramRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateProgramRequest>(create);
  static GenerateProgramRequest? _defaultInstance;

  /// the PCL source of the project.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, $core.String> get source => $_getMap(0);

  /// The target of a codegen.LoaderServer to use for loading schemas.
  @$pb.TagNumber(2)
  $core.String get loaderTarget => $_getSZ(1);
  @$pb.TagNumber(2)
  set loaderTarget($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLoaderTarget() => $_has(1);
  @$pb.TagNumber(2)
  void clearLoaderTarget() => $_clearField(2);
}

class GenerateProgramResponse extends $pb.GeneratedMessage {
  factory GenerateProgramResponse({
    $core.Iterable<$4.Diagnostic>? diagnostics,
    $core.Iterable<$core.MapEntry<$core.String, $core.List<$core.int>>>? source,
  }) {
    final result = create();
    if (diagnostics != null) result.diagnostics.addAll(diagnostics);
    if (source != null) result.source.addEntries(source);
    return result;
  }

  GenerateProgramResponse._();

  factory GenerateProgramResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateProgramResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateProgramResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..pPM<$4.Diagnostic>(1, _omitFieldNames ? '' : 'diagnostics',
        subBuilder: $4.Diagnostic.create)
    ..m<$core.String, $core.List<$core.int>>(2, _omitFieldNames ? '' : 'source',
        entryClassName: 'GenerateProgramResponse.SourceEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OY,
        packageName: const $pb.PackageName('pulumirpc'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProgramResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProgramResponse copyWith(
          void Function(GenerateProgramResponse) updates) =>
      super.copyWith((message) => updates(message as GenerateProgramResponse))
          as GenerateProgramResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateProgramResponse create() => GenerateProgramResponse._();
  @$core.override
  GenerateProgramResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateProgramResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateProgramResponse>(create);
  static GenerateProgramResponse? _defaultInstance;

  /// any diagnostics from code generation.
  @$pb.TagNumber(1)
  $pb.PbList<$4.Diagnostic> get diagnostics => $_getList(0);

  /// the generated program source code.
  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $core.List<$core.int>> get source => $_getMap(1);
}

class GenerateProjectRequest extends $pb.GeneratedMessage {
  factory GenerateProjectRequest({
    $core.String? sourceDirectory,
    $core.String? targetDirectory,
    $core.String? project,
    $core.bool? strict,
    $core.String? loaderTarget,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        localDependencies,
  }) {
    final result = create();
    if (sourceDirectory != null) result.sourceDirectory = sourceDirectory;
    if (targetDirectory != null) result.targetDirectory = targetDirectory;
    if (project != null) result.project = project;
    if (strict != null) result.strict = strict;
    if (loaderTarget != null) result.loaderTarget = loaderTarget;
    if (localDependencies != null)
      result.localDependencies.addEntries(localDependencies);
    return result;
  }

  GenerateProjectRequest._();

  factory GenerateProjectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateProjectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateProjectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sourceDirectory')
    ..aOS(2, _omitFieldNames ? '' : 'targetDirectory')
    ..aOS(3, _omitFieldNames ? '' : 'project')
    ..aOB(4, _omitFieldNames ? '' : 'strict')
    ..aOS(5, _omitFieldNames ? '' : 'loaderTarget')
    ..m<$core.String, $core.String>(
        6, _omitFieldNames ? '' : 'localDependencies',
        entryClassName: 'GenerateProjectRequest.LocalDependenciesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('pulumirpc'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProjectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProjectRequest copyWith(
          void Function(GenerateProjectRequest) updates) =>
      super.copyWith((message) => updates(message as GenerateProjectRequest))
          as GenerateProjectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateProjectRequest create() => GenerateProjectRequest._();
  @$core.override
  GenerateProjectRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateProjectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateProjectRequest>(create);
  static GenerateProjectRequest? _defaultInstance;

  /// the directory to generate the project from.
  @$pb.TagNumber(1)
  $core.String get sourceDirectory => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceDirectory($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceDirectory() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceDirectory() => $_clearField(1);

  /// the directory to generate the project in.
  @$pb.TagNumber(2)
  $core.String get targetDirectory => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetDirectory($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetDirectory() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetDirectory() => $_clearField(2);

  /// the JSON-encoded pulumi project file.
  @$pb.TagNumber(3)
  $core.String get project => $_getSZ(2);
  @$pb.TagNumber(3)
  set project($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProject() => $_has(2);
  @$pb.TagNumber(3)
  void clearProject() => $_clearField(3);

  /// if PCL binding should be strict or not.
  @$pb.TagNumber(4)
  $core.bool get strict => $_getBF(3);
  @$pb.TagNumber(4)
  set strict($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStrict() => $_has(3);
  @$pb.TagNumber(4)
  void clearStrict() => $_clearField(4);

  /// The target of a codegen.LoaderServer to use for loading schemas.
  @$pb.TagNumber(5)
  $core.String get loaderTarget => $_getSZ(4);
  @$pb.TagNumber(5)
  set loaderTarget($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLoaderTarget() => $_has(4);
  @$pb.TagNumber(5)
  void clearLoaderTarget() => $_clearField(5);

  /// local dependencies to use instead of using the package system. This is a map of package name to a local
  /// path of a language specific artifact to use for the SDK for that package.
  @$pb.TagNumber(6)
  $pb.PbMap<$core.String, $core.String> get localDependencies => $_getMap(5);
}

class GenerateProjectResponse extends $pb.GeneratedMessage {
  factory GenerateProjectResponse({
    $core.Iterable<$4.Diagnostic>? diagnostics,
  }) {
    final result = create();
    if (diagnostics != null) result.diagnostics.addAll(diagnostics);
    return result;
  }

  GenerateProjectResponse._();

  factory GenerateProjectResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateProjectResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateProjectResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..pPM<$4.Diagnostic>(1, _omitFieldNames ? '' : 'diagnostics',
        subBuilder: $4.Diagnostic.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProjectResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateProjectResponse copyWith(
          void Function(GenerateProjectResponse) updates) =>
      super.copyWith((message) => updates(message as GenerateProjectResponse))
          as GenerateProjectResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateProjectResponse create() => GenerateProjectResponse._();
  @$core.override
  GenerateProjectResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateProjectResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateProjectResponse>(create);
  static GenerateProjectResponse? _defaultInstance;

  /// any diagnostics from code generation.
  @$pb.TagNumber(1)
  $pb.PbList<$4.Diagnostic> get diagnostics => $_getList(0);
}

class GeneratePackageRequest extends $pb.GeneratedMessage {
  factory GeneratePackageRequest({
    $core.String? directory,
    $core.String? schema,
    $core.Iterable<$core.MapEntry<$core.String, $core.List<$core.int>>>?
        extraFiles,
    $core.String? loaderTarget,
  }) {
    final result = create();
    if (directory != null) result.directory = directory;
    if (schema != null) result.schema = schema;
    if (extraFiles != null) result.extraFiles.addEntries(extraFiles);
    if (loaderTarget != null) result.loaderTarget = loaderTarget;
    return result;
  }

  GeneratePackageRequest._();

  factory GeneratePackageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GeneratePackageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GeneratePackageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'directory')
    ..aOS(2, _omitFieldNames ? '' : 'schema')
    ..m<$core.String, $core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'extraFiles',
        entryClassName: 'GeneratePackageRequest.ExtraFilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OY,
        packageName: const $pb.PackageName('pulumirpc'))
    ..aOS(4, _omitFieldNames ? '' : 'loaderTarget')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePackageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePackageRequest copyWith(
          void Function(GeneratePackageRequest) updates) =>
      super.copyWith((message) => updates(message as GeneratePackageRequest))
          as GeneratePackageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GeneratePackageRequest create() => GeneratePackageRequest._();
  @$core.override
  GeneratePackageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GeneratePackageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GeneratePackageRequest>(create);
  static GeneratePackageRequest? _defaultInstance;

  /// the directory to generate the package in.
  @$pb.TagNumber(1)
  $core.String get directory => $_getSZ(0);
  @$pb.TagNumber(1)
  set directory($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDirectory() => $_has(0);
  @$pb.TagNumber(1)
  void clearDirectory() => $_clearField(1);

  /// the JSON-encoded schema.
  @$pb.TagNumber(2)
  $core.String get schema => $_getSZ(1);
  @$pb.TagNumber(2)
  set schema($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSchema() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchema() => $_clearField(2);

  /// extra files to copy to the package output.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.List<$core.int>> get extraFiles => $_getMap(2);

  /// The target of a codegen.LoaderServer to use for loading schemas.
  @$pb.TagNumber(4)
  $core.String get loaderTarget => $_getSZ(3);
  @$pb.TagNumber(4)
  set loaderTarget($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLoaderTarget() => $_has(3);
  @$pb.TagNumber(4)
  void clearLoaderTarget() => $_clearField(4);
}

class GeneratePackageResponse extends $pb.GeneratedMessage {
  factory GeneratePackageResponse({
    $core.Iterable<$4.Diagnostic>? diagnostics,
  }) {
    final result = create();
    if (diagnostics != null) result.diagnostics.addAll(diagnostics);
    return result;
  }

  GeneratePackageResponse._();

  factory GeneratePackageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GeneratePackageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GeneratePackageResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..pPM<$4.Diagnostic>(1, _omitFieldNames ? '' : 'diagnostics',
        subBuilder: $4.Diagnostic.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePackageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GeneratePackageResponse copyWith(
          void Function(GeneratePackageResponse) updates) =>
      super.copyWith((message) => updates(message as GeneratePackageResponse))
          as GeneratePackageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GeneratePackageResponse create() => GeneratePackageResponse._();
  @$core.override
  GeneratePackageResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GeneratePackageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GeneratePackageResponse>(create);
  static GeneratePackageResponse? _defaultInstance;

  /// any diagnostics from code generation.
  @$pb.TagNumber(1)
  $pb.PbList<$4.Diagnostic> get diagnostics => $_getList(0);
}

class PackRequest extends $pb.GeneratedMessage {
  factory PackRequest({
    $core.String? packageDirectory,
    $core.String? version,
    $core.String? destinationDirectory,
  }) {
    final result = create();
    if (packageDirectory != null) result.packageDirectory = packageDirectory;
    if (version != null) result.version = version;
    if (destinationDirectory != null)
      result.destinationDirectory = destinationDirectory;
    return result;
  }

  PackRequest._();

  factory PackRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PackRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PackRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'packageDirectory')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..aOS(3, _omitFieldNames ? '' : 'destinationDirectory')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackRequest copyWith(void Function(PackRequest) updates) =>
      super.copyWith((message) => updates(message as PackRequest))
          as PackRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PackRequest create() => PackRequest._();
  @$core.override
  PackRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PackRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PackRequest>(create);
  static PackRequest? _defaultInstance;

  /// the directory of a package to pack.
  @$pb.TagNumber(1)
  $core.String get packageDirectory => $_getSZ(0);
  @$pb.TagNumber(1)
  set packageDirectory($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPackageDirectory() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackageDirectory() => $_clearField(1);

  /// the version to tag the artifact with.
  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  /// the directory to write the packed artifact to.
  @$pb.TagNumber(3)
  $core.String get destinationDirectory => $_getSZ(2);
  @$pb.TagNumber(3)
  set destinationDirectory($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDestinationDirectory() => $_has(2);
  @$pb.TagNumber(3)
  void clearDestinationDirectory() => $_clearField(3);
}

class PackResponse extends $pb.GeneratedMessage {
  factory PackResponse({
    $core.String? artifactPath,
  }) {
    final result = create();
    if (artifactPath != null) result.artifactPath = artifactPath;
    return result;
  }

  PackResponse._();

  factory PackResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PackResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PackResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'pulumirpc'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'artifactPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PackResponse copyWith(void Function(PackResponse) updates) =>
      super.copyWith((message) => updates(message as PackResponse))
          as PackResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PackResponse create() => PackResponse._();
  @$core.override
  PackResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PackResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PackResponse>(create);
  static PackResponse? _defaultInstance;

  /// the full path of the packed artifact.
  @$pb.TagNumber(1)
  $core.String get artifactPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set artifactPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasArtifactPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearArtifactPath() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
