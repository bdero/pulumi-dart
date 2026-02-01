import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as empty;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';

import 'package:pulumi/src/proto/pulumi/provider.pb.dart' as provider;
import 'package:pulumi/src/proto/pulumi/resource.pb.dart' as resource;
import 'package:pulumi/src/proto/pulumi/resource.pbgrpc.dart' as resource_grpc;

/// A mock ResourceMonitor service for testing.
class MockResourceMonitorService
    extends resource_grpc.ResourceMonitorServiceBase {
  final List<resource.RegisterResourceRequest> registeredResources = [];
  final List<resource.RegisterResourceOutputsRequest> registeredOutputs = [];
  final List<resource.ReadResourceRequest> readRequests = [];
  final List<resource.ResourceInvokeRequest> invokeRequests = [];
  final List<resource.ResourceCallRequest> callRequests = [];
  final List<resource.SupportsFeatureRequest> featureRequests = [];

  final Map<String, bool> supportedFeatures = {};
  bool signalAndWaitCalled = false;

  // Configurable responses
  String nextUrn = 'urn:pulumi:stack::project::type::name';
  String nextId = 'test-id-123';
  Struct nextProperties = Struct();

  @override
  Future<resource.SupportsFeatureResponse> supportsFeature(
    ServiceCall call,
    resource.SupportsFeatureRequest request,
  ) async {
    featureRequests.add(request);
    return resource.SupportsFeatureResponse()
      ..hasSupport = supportedFeatures[request.id] ?? false;
  }

  @override
  Future<resource.RegisterResourceResponse> registerResource(
    ServiceCall call,
    resource.RegisterResourceRequest request,
  ) async {
    registeredResources.add(request);
    return resource.RegisterResourceResponse()
      ..urn = nextUrn
      ..id = nextId
      ..object = nextProperties;
  }

  @override
  Future<empty.Empty> registerResourceOutputs(
    ServiceCall call,
    resource.RegisterResourceOutputsRequest request,
  ) async {
    registeredOutputs.add(request);
    return empty.Empty();
  }

  @override
  Future<resource.ReadResourceResponse> readResource(
    ServiceCall call,
    resource.ReadResourceRequest request,
  ) async {
    readRequests.add(request);
    return resource.ReadResourceResponse()
      ..urn = nextUrn
      ..properties = nextProperties;
  }

  @override
  Future<provider.InvokeResponse> invoke(
    ServiceCall call,
    resource.ResourceInvokeRequest request,
  ) async {
    invokeRequests.add(request);
    return provider.InvokeResponse()..return_1 = nextProperties;
  }

  @override
  Future<provider.CallResponse> call(
    ServiceCall call,
    resource.ResourceCallRequest request,
  ) async {
    callRequests.add(request);
    return provider.CallResponse()..return_1 = nextProperties;
  }

  @override
  Future<empty.Empty> registerStackTransform(
    ServiceCall call,
    dynamic request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<empty.Empty> registerStackInvokeTransform(
    ServiceCall call,
    dynamic request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<empty.Empty> registerResourceHook(
    ServiceCall call,
    resource.RegisterResourceHookRequest request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<empty.Empty> registerErrorHook(
    ServiceCall call,
    resource.RegisterErrorHookRequest request,
  ) async {
    return empty.Empty();
  }

  @override
  Future<resource.RegisterPackageResponse> registerPackage(
    ServiceCall call,
    resource.RegisterPackageRequest request,
  ) async {
    return resource.RegisterPackageResponse();
  }

  @override
  Future<empty.Empty> signalAndWaitForShutdown(
    ServiceCall call,
    empty.Empty request,
  ) async {
    signalAndWaitCalled = true;
    return empty.Empty();
  }
}

/// Starts a mock ResourceMonitor server and returns the service and port.
Future<(MockResourceMonitorService, int)> startMockServer() async {
  final mockService = MockResourceMonitorService();
  final server = Server.create(services: [mockService]);
  await server.serve(address: 'localhost', port: 0);
  return (mockService, server.port!);
}
