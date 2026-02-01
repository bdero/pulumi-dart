// This is a generated file - do not edit.
//
// Generated from pulumi/language.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'language.pb.dart' as $0;
import 'plugin.pb.dart' as $2;

export 'language.pb.dart';

/// LanguageRuntime is the interface that the planning monitor uses to drive execution of an interpreter responsible
/// for confguring and creating resource objects.
@$pb.GrpcServiceName('pulumirpc.LanguageRuntime')
class LanguageRuntimeClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  LanguageRuntimeClient(super.channel, {super.options, super.interceptors});

  /// GetRequiredPlugins computes the complete set of anticipated plugins required by a program.
  $grpc.ResponseFuture<$0.GetRequiredPluginsResponse> getRequiredPlugins(
    $0.GetRequiredPluginsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getRequiredPlugins, request, options: options);
  }

  /// Run executes a program and returns its result.
  $grpc.ResponseFuture<$0.RunResponse> run(
    $0.RunRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$run, request, options: options);
  }

  /// GetPluginInfo returns generic information about this plugin, like its version.
  $grpc.ResponseFuture<$2.PluginInfo> getPluginInfo(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPluginInfo, request, options: options);
  }

  /// InstallDependencies will install dependencies for the project, e.g. by running `npm install` for nodejs projects.
  $grpc.ResponseStream<$0.InstallDependenciesResponse> installDependencies(
    $0.InstallDependenciesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$installDependencies, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// About returns information about the runtime for this language.
  $grpc.ResponseFuture<$0.AboutResponse> about(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$about, request, options: options);
  }

  /// GetProgramDependencies returns the set of dependencies required by the program.
  $grpc.ResponseFuture<$0.GetProgramDependenciesResponse>
      getProgramDependencies(
    $0.GetProgramDependenciesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getProgramDependencies, request,
        options: options);
  }

  /// RunPlugin executes a plugin program and returns its result asynchronously.
  $grpc.ResponseStream<$0.RunPluginResponse> runPlugin(
    $0.RunPluginRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$runPlugin, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// GenerateProgram generates a given PCL program into a program for this language.
  $grpc.ResponseFuture<$0.GenerateProgramResponse> generateProgram(
    $0.GenerateProgramRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generateProgram, request, options: options);
  }

  /// GenerateProject generates a given PCL program into a project for this language.
  $grpc.ResponseFuture<$0.GenerateProjectResponse> generateProject(
    $0.GenerateProjectRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generateProject, request, options: options);
  }

  /// GeneratePackage generates a given pulumi package into a package for this language.
  $grpc.ResponseFuture<$0.GeneratePackageResponse> generatePackage(
    $0.GeneratePackageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$generatePackage, request, options: options);
  }

  /// Pack packs a package into a language specific artifact.
  $grpc.ResponseFuture<$0.PackResponse> pack(
    $0.PackRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pack, request, options: options);
  }

  // method descriptors

  static final _$getRequiredPlugins = $grpc.ClientMethod<
          $0.GetRequiredPluginsRequest, $0.GetRequiredPluginsResponse>(
      '/pulumirpc.LanguageRuntime/GetRequiredPlugins',
      ($0.GetRequiredPluginsRequest value) => value.writeToBuffer(),
      $0.GetRequiredPluginsResponse.fromBuffer);
  static final _$run = $grpc.ClientMethod<$0.RunRequest, $0.RunResponse>(
      '/pulumirpc.LanguageRuntime/Run',
      ($0.RunRequest value) => value.writeToBuffer(),
      $0.RunResponse.fromBuffer);
  static final _$getPluginInfo = $grpc.ClientMethod<$1.Empty, $2.PluginInfo>(
      '/pulumirpc.LanguageRuntime/GetPluginInfo',
      ($1.Empty value) => value.writeToBuffer(),
      $2.PluginInfo.fromBuffer);
  static final _$installDependencies = $grpc.ClientMethod<
          $0.InstallDependenciesRequest, $0.InstallDependenciesResponse>(
      '/pulumirpc.LanguageRuntime/InstallDependencies',
      ($0.InstallDependenciesRequest value) => value.writeToBuffer(),
      $0.InstallDependenciesResponse.fromBuffer);
  static final _$about = $grpc.ClientMethod<$1.Empty, $0.AboutResponse>(
      '/pulumirpc.LanguageRuntime/About',
      ($1.Empty value) => value.writeToBuffer(),
      $0.AboutResponse.fromBuffer);
  static final _$getProgramDependencies = $grpc.ClientMethod<
          $0.GetProgramDependenciesRequest, $0.GetProgramDependenciesResponse>(
      '/pulumirpc.LanguageRuntime/GetProgramDependencies',
      ($0.GetProgramDependenciesRequest value) => value.writeToBuffer(),
      $0.GetProgramDependenciesResponse.fromBuffer);
  static final _$runPlugin =
      $grpc.ClientMethod<$0.RunPluginRequest, $0.RunPluginResponse>(
          '/pulumirpc.LanguageRuntime/RunPlugin',
          ($0.RunPluginRequest value) => value.writeToBuffer(),
          $0.RunPluginResponse.fromBuffer);
  static final _$generateProgram =
      $grpc.ClientMethod<$0.GenerateProgramRequest, $0.GenerateProgramResponse>(
          '/pulumirpc.LanguageRuntime/GenerateProgram',
          ($0.GenerateProgramRequest value) => value.writeToBuffer(),
          $0.GenerateProgramResponse.fromBuffer);
  static final _$generateProject =
      $grpc.ClientMethod<$0.GenerateProjectRequest, $0.GenerateProjectResponse>(
          '/pulumirpc.LanguageRuntime/GenerateProject',
          ($0.GenerateProjectRequest value) => value.writeToBuffer(),
          $0.GenerateProjectResponse.fromBuffer);
  static final _$generatePackage =
      $grpc.ClientMethod<$0.GeneratePackageRequest, $0.GeneratePackageResponse>(
          '/pulumirpc.LanguageRuntime/GeneratePackage',
          ($0.GeneratePackageRequest value) => value.writeToBuffer(),
          $0.GeneratePackageResponse.fromBuffer);
  static final _$pack = $grpc.ClientMethod<$0.PackRequest, $0.PackResponse>(
      '/pulumirpc.LanguageRuntime/Pack',
      ($0.PackRequest value) => value.writeToBuffer(),
      $0.PackResponse.fromBuffer);
}

@$pb.GrpcServiceName('pulumirpc.LanguageRuntime')
abstract class LanguageRuntimeServiceBase extends $grpc.Service {
  $core.String get $name => 'pulumirpc.LanguageRuntime';

  LanguageRuntimeServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetRequiredPluginsRequest,
            $0.GetRequiredPluginsResponse>(
        'GetRequiredPlugins',
        getRequiredPlugins_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetRequiredPluginsRequest.fromBuffer(value),
        ($0.GetRequiredPluginsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RunRequest, $0.RunResponse>(
        'Run',
        run_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RunRequest.fromBuffer(value),
        ($0.RunResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $2.PluginInfo>(
        'GetPluginInfo',
        getPluginInfo_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($2.PluginInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.InstallDependenciesRequest,
            $0.InstallDependenciesResponse>(
        'InstallDependencies',
        installDependencies_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.InstallDependenciesRequest.fromBuffer(value),
        ($0.InstallDependenciesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.AboutResponse>(
        'About',
        about_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.AboutResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetProgramDependenciesRequest,
            $0.GetProgramDependenciesResponse>(
        'GetProgramDependencies',
        getProgramDependencies_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetProgramDependenciesRequest.fromBuffer(value),
        ($0.GetProgramDependenciesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RunPluginRequest, $0.RunPluginResponse>(
        'RunPlugin',
        runPlugin_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.RunPluginRequest.fromBuffer(value),
        ($0.RunPluginResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GenerateProgramRequest,
            $0.GenerateProgramResponse>(
        'GenerateProgram',
        generateProgram_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GenerateProgramRequest.fromBuffer(value),
        ($0.GenerateProgramResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GenerateProjectRequest,
            $0.GenerateProjectResponse>(
        'GenerateProject',
        generateProject_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GenerateProjectRequest.fromBuffer(value),
        ($0.GenerateProjectResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GeneratePackageRequest,
            $0.GeneratePackageResponse>(
        'GeneratePackage',
        generatePackage_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GeneratePackageRequest.fromBuffer(value),
        ($0.GeneratePackageResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PackRequest, $0.PackResponse>(
        'Pack',
        pack_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PackRequest.fromBuffer(value),
        ($0.PackResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetRequiredPluginsResponse> getRequiredPlugins_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetRequiredPluginsRequest> $request) async {
    return getRequiredPlugins($call, await $request);
  }

  $async.Future<$0.GetRequiredPluginsResponse> getRequiredPlugins(
      $grpc.ServiceCall call, $0.GetRequiredPluginsRequest request);

  $async.Future<$0.RunResponse> run_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.RunRequest> $request) async {
    return run($call, await $request);
  }

  $async.Future<$0.RunResponse> run(
      $grpc.ServiceCall call, $0.RunRequest request);

  $async.Future<$2.PluginInfo> getPluginInfo_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getPluginInfo($call, await $request);
  }

  $async.Future<$2.PluginInfo> getPluginInfo(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Stream<$0.InstallDependenciesResponse> installDependencies_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.InstallDependenciesRequest> $request) async* {
    yield* installDependencies($call, await $request);
  }

  $async.Stream<$0.InstallDependenciesResponse> installDependencies(
      $grpc.ServiceCall call, $0.InstallDependenciesRequest request);

  $async.Future<$0.AboutResponse> about_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return about($call, await $request);
  }

  $async.Future<$0.AboutResponse> about(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.GetProgramDependenciesResponse> getProgramDependencies_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetProgramDependenciesRequest> $request) async {
    return getProgramDependencies($call, await $request);
  }

  $async.Future<$0.GetProgramDependenciesResponse> getProgramDependencies(
      $grpc.ServiceCall call, $0.GetProgramDependenciesRequest request);

  $async.Stream<$0.RunPluginResponse> runPlugin_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RunPluginRequest> $request) async* {
    yield* runPlugin($call, await $request);
  }

  $async.Stream<$0.RunPluginResponse> runPlugin(
      $grpc.ServiceCall call, $0.RunPluginRequest request);

  $async.Future<$0.GenerateProgramResponse> generateProgram_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GenerateProgramRequest> $request) async {
    return generateProgram($call, await $request);
  }

  $async.Future<$0.GenerateProgramResponse> generateProgram(
      $grpc.ServiceCall call, $0.GenerateProgramRequest request);

  $async.Future<$0.GenerateProjectResponse> generateProject_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GenerateProjectRequest> $request) async {
    return generateProject($call, await $request);
  }

  $async.Future<$0.GenerateProjectResponse> generateProject(
      $grpc.ServiceCall call, $0.GenerateProjectRequest request);

  $async.Future<$0.GeneratePackageResponse> generatePackage_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GeneratePackageRequest> $request) async {
    return generatePackage($call, await $request);
  }

  $async.Future<$0.GeneratePackageResponse> generatePackage(
      $grpc.ServiceCall call, $0.GeneratePackageRequest request);

  $async.Future<$0.PackResponse> pack_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PackRequest> $request) async {
    return pack($call, await $request);
  }

  $async.Future<$0.PackResponse> pack(
      $grpc.ServiceCall call, $0.PackRequest request);
}
