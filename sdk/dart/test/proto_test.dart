import 'package:test/test.dart';
import 'package:pulumi/pulumi.dart';
import 'package:pulumi/src/proto/pulumi/alias.pb.dart' as alias_pb;

void main() {
  group('Proto Generated Types', () {
    test('can create RegisterResourceRequest', () {
      final request = RegisterResourceRequest()
        ..type = 'aws:s3/bucket:Bucket'
        ..name = 'my-bucket'
        ..custom = true
        ..protect = false;

      expect(request.type, equals('aws:s3/bucket:Bucket'));
      expect(request.name, equals('my-bucket'));
      expect(request.custom, isTrue);
      expect(request.protect, isFalse);
    });

    test('can create RegisterResourceResponse', () {
      final response = RegisterResourceResponse()
        ..urn = 'urn:pulumi:dev::project::aws:s3/bucket:Bucket::my-bucket'
        ..id = 'bucket-12345';

      expect(response.urn, contains('aws:s3/bucket:Bucket'));
      expect(response.id, equals('bucket-12345'));
    });

    test('can create PluginInfo', () {
      final info = PluginInfo()
        ..version = '0.1.0';

      expect(info.version, equals('0.1.0'));
    });

    test('can create LogRequest', () {
      final logRequest = LogRequest()
        ..severity = LogSeverity.INFO
        ..message = 'Test message'
        ..ephemeral = false;

      expect(logRequest.severity, equals(LogSeverity.INFO));
      expect(logRequest.message, equals('Test message'));
      expect(logRequest.ephemeral, isFalse);
    });

    test('can create InvokeRequest', () {
      final request = InvokeRequest()
        ..tok = 'aws:index/getAvailabilityZones:getAvailabilityZones'
        ..preview = false;

      expect(request.tok, contains('getAvailabilityZones'));
      expect(request.preview, isFalse);
    });

    test('LogSeverity enum values are correct', () {
      expect(LogSeverity.DEBUG.value, equals(0));
      expect(LogSeverity.INFO.value, equals(1));
      expect(LogSeverity.WARNING.value, equals(2));
      expect(LogSeverity.ERROR.value, equals(3));
    });

    test('Alias message can be created', () {
      final alias = alias_pb.Alias()
        ..urn = 'urn:pulumi:dev::project::aws:s3/bucket:Bucket::old-name';

      expect(alias.urn, contains('old-name'));
    });

    test('CallbackInvokeRequest can be created', () {
      final request = CallbackInvokeRequest()
        ..token = 'callback-token-123';

      expect(request.token, equals('callback-token-123'));
    });
  });

  group('gRPC Service Definitions', () {
    test('ResourceMonitorClient type exists', () {
      // This test verifies the gRPC client type was generated correctly
      // We can't actually create a client without a channel, but the type should exist
      expect(ResourceMonitorClient, isNotNull);
    });

    test('EngineClient type exists', () {
      expect(EngineClient, isNotNull);
    });

    test('ResourceProviderClient type exists', () {
      expect(ResourceProviderClient, isNotNull);
    });

    test('CallbacksClient type exists', () {
      expect(CallbacksClient, isNotNull);
    });
  });
}
