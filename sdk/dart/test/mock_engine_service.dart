import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as empty;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:pulumi/src/proto/pulumi/engine.pb.dart';
import 'package:pulumi/src/proto/pulumi/engine.pbgrpc.dart';

/// A mock Engine service for testing.
class MockEngineService extends EngineServiceBase {
  final List<LogRequest> logRequests = [];
  final List<GetRootResourceRequest> getRootResourceRequests = [];
  final List<SetRootResourceRequest> setRootResourceRequests = [];
  final List<StartDebuggingRequest> startDebuggingRequests = [];
  final List<RequirePulumiVersionRequest> requireVersionRequests = [];

  // Configurable responses
  String rootResourceUrn = '';
  bool throwOnRequireVersion = false;
  String requireVersionError = 'Version not compatible';

  @override
  Future<empty.Empty> log(ServiceCall call, LogRequest request) async {
    logRequests.add(request);
    return empty.Empty();
  }

  @override
  Future<GetRootResourceResponse> getRootResource(
    ServiceCall call,
    GetRootResourceRequest request,
  ) async {
    getRootResourceRequests.add(request);
    return GetRootResourceResponse(urn: rootResourceUrn);
  }

  @override
  Future<SetRootResourceResponse> setRootResource(
    ServiceCall call,
    SetRootResourceRequest request,
  ) async {
    setRootResourceRequests.add(request);
    rootResourceUrn = request.urn;
    return SetRootResourceResponse();
  }

  @override
  Future<empty.Empty> startDebugging(
    ServiceCall call,
    StartDebuggingRequest request,
  ) async {
    startDebuggingRequests.add(request);
    return empty.Empty();
  }

  @override
  Future<RequirePulumiVersionResponse> requirePulumiVersion(
    ServiceCall call,
    RequirePulumiVersionRequest request,
  ) async {
    requireVersionRequests.add(request);
    if (throwOnRequireVersion) {
      throw GrpcError.failedPrecondition(requireVersionError);
    }
    return RequirePulumiVersionResponse();
  }
}

/// Starts a mock Engine server and returns the service and port.
Future<(MockEngineService, int, Server)> startMockEngineServer() async {
  final mockService = MockEngineService();
  final server = Server.create(services: [mockService]);
  await server.serve(address: 'localhost', port: 0);
  return (mockService, server.port!, server);
}
