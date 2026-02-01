import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:test/test.dart';

import 'package:pulumi/src/proto/pulumi/engine.pb.dart';
import 'package:pulumi/src/runtime/engine.dart';

import 'mock_engine_service.dart';

void main() {
  group('Engine', () {
    late MockEngineService mockService;
    late int serverPort;
    late Server server;
    late Engine engine;

    setUp(() async {
      final result = await startMockEngineServer();
      mockService = result.$1;
      serverPort = result.$2;
      server = result.$3;
      engine = Engine.connect('localhost:$serverPort');
    });

    tearDown(() async {
      await engine.terminate();
      await server.shutdown();
    });

    group('connect', () {
      test('connects to address with port', () async {
        // The engine was already connected in setUp
        // Verify it works by calling a method
        await engine.info('test');
        expect(mockService.logRequests, hasLength(1));
      });

      test('parses host and port from address', () async {
        // This is implicitly tested by the successful connection
        await engine.debug('connection test');
        expect(mockService.logRequests, hasLength(1));
      });
    });

    group('fromChannel', () {
      test('creates engine from existing channel', () async {
        final channel = ClientChannel(
          'localhost',
          port: serverPort,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        );

        final engineFromChannel = Engine.fromChannel(channel);
        await engineFromChannel.info('channel test');

        expect(mockService.logRequests, hasLength(1));
        expect(mockService.logRequests.first.message, equals('channel test'));

        await channel.shutdown();
      });
    });

    group('log', () {
      test('logs message with severity', () async {
        await engine.log(LogSeverity.INFO, 'test message');

        expect(mockService.logRequests, hasLength(1));
        final request = mockService.logRequests.first;
        expect(request.severity, equals(LogSeverity.INFO));
        expect(request.message, equals('test message'));
      });

      test('logs with all optional parameters', () async {
        await engine.log(
          LogSeverity.WARNING,
          'detailed message',
          urn: 'urn:pulumi:stack::project::type::name',
          streamId: 42,
          ephemeral: true,
        );

        expect(mockService.logRequests, hasLength(1));
        final request = mockService.logRequests.first;
        expect(request.severity, equals(LogSeverity.WARNING));
        expect(request.message, equals('detailed message'));
        expect(request.urn, equals('urn:pulumi:stack::project::type::name'));
        expect(request.streamId, equals(42));
        expect(request.ephemeral, isTrue);
      });

      test('omits empty urn', () async {
        await engine.log(LogSeverity.INFO, 'test', urn: '');

        final request = mockService.logRequests.first;
        expect(request.hasUrn(), isFalse);
      });

      test('omits zero streamId', () async {
        await engine.log(LogSeverity.INFO, 'test', streamId: 0);

        final request = mockService.logRequests.first;
        expect(request.hasStreamId(), isFalse);
      });
    });

    group('debug', () {
      test('logs with DEBUG severity', () async {
        await engine.debug('debug message');

        expect(mockService.logRequests, hasLength(1));
        final request = mockService.logRequests.first;
        expect(request.severity, equals(LogSeverity.DEBUG));
        expect(request.message, equals('debug message'));
      });

      test('passes optional parameters', () async {
        await engine.debug('debug', urn: 'test-urn', ephemeral: true);

        final request = mockService.logRequests.first;
        expect(request.urn, equals('test-urn'));
        expect(request.ephemeral, isTrue);
      });
    });

    group('info', () {
      test('logs with INFO severity', () async {
        await engine.info('info message');

        expect(mockService.logRequests, hasLength(1));
        final request = mockService.logRequests.first;
        expect(request.severity, equals(LogSeverity.INFO));
        expect(request.message, equals('info message'));
      });
    });

    group('warning', () {
      test('logs with WARNING severity', () async {
        await engine.warning('warning message');

        expect(mockService.logRequests, hasLength(1));
        final request = mockService.logRequests.first;
        expect(request.severity, equals(LogSeverity.WARNING));
        expect(request.message, equals('warning message'));
      });
    });

    group('error', () {
      test('logs with ERROR severity', () async {
        await engine.error('error message');

        expect(mockService.logRequests, hasLength(1));
        final request = mockService.logRequests.first;
        expect(request.severity, equals(LogSeverity.ERROR));
        expect(request.message, equals('error message'));
      });
    });

    group('getRootResource', () {
      test('returns empty string when no root set', () async {
        final urn = await engine.getRootResource();

        expect(urn, isEmpty);
        expect(mockService.getRootResourceRequests, hasLength(1));
      });

      test('returns configured root URN', () async {
        mockService.rootResourceUrn =
            'urn:pulumi:stack::project::pulumi:pulumi:Stack::my-stack';

        final urn = await engine.getRootResource();

        expect(
            urn, equals('urn:pulumi:stack::project::pulumi:pulumi:Stack::my-stack'));
      });
    });

    group('setRootResource', () {
      test('sets the root resource URN', () async {
        const testUrn = 'urn:pulumi:stack::project::pulumi:pulumi:Stack::test';

        await engine.setRootResource(testUrn);

        expect(mockService.setRootResourceRequests, hasLength(1));
        expect(mockService.setRootResourceRequests.first.urn, equals(testUrn));
        expect(mockService.rootResourceUrn, equals(testUrn));
      });

      test('updates can be retrieved', () async {
        const testUrn = 'urn:pulumi:stack::project::pulumi:pulumi:Stack::test';

        await engine.setRootResource(testUrn);
        final retrieved = await engine.getRootResource();

        expect(retrieved, equals(testUrn));
      });
    });

    group('startDebugging', () {
      test('sends debugging request with message', () async {
        await engine.startDebugging(message: 'Connect debugger to port 5005');

        expect(mockService.startDebuggingRequests, hasLength(1));
        final request = mockService.startDebuggingRequests.first;
        expect(request.message, equals('Connect debugger to port 5005'));
      });

      test('sends debugging request with config', () async {
        final config = Struct()
          ..fields['port'] = (Value()..numberValue = 5005)
          ..fields['host'] = (Value()..stringValue = 'localhost');

        await engine.startDebugging(config: config);

        expect(mockService.startDebuggingRequests, hasLength(1));
        final request = mockService.startDebuggingRequests.first;
        expect(request.config.fields['port']?.numberValue, equals(5005));
        expect(request.config.fields['host']?.stringValue, equals('localhost'));
      });

      test('sends debugging request with both config and message', () async {
        final config = Struct()
          ..fields['port'] = (Value()..numberValue = 5005);

        await engine.startDebugging(
          config: config,
          message: 'Debug session started',
        );

        final request = mockService.startDebuggingRequests.first;
        expect(request.config.fields['port']?.numberValue, equals(5005));
        expect(request.message, equals('Debug session started'));
      });

      test('omits empty message', () async {
        await engine.startDebugging(message: '');

        final request = mockService.startDebuggingRequests.first;
        expect(request.hasMessage(), isFalse);
      });
    });

    group('requirePulumiVersion', () {
      test('sends version requirement', () async {
        await engine.requirePulumiVersion('>=3.0.0');

        expect(mockService.requireVersionRequests, hasLength(1));
        expect(
          mockService.requireVersionRequests.first.pulumiVersionRange,
          equals('>=3.0.0'),
        );
      });

      test('supports complex version ranges', () async {
        await engine.requirePulumiVersion('>=3.5.0 !3.7.7');

        expect(
          mockService.requireVersionRequests.first.pulumiVersionRange,
          equals('>=3.5.0 !3.7.7'),
        );
      });

      test('supports OR ranges', () async {
        await engine.requirePulumiVersion('<3.4.0 || >3.8.0');

        expect(
          mockService.requireVersionRequests.first.pulumiVersionRange,
          equals('<3.4.0 || >3.8.0'),
        );
      });

      test('throws on incompatible version', () async {
        mockService.throwOnRequireVersion = true;
        mockService.requireVersionError = 'Version 2.0.0 does not match >=3.0.0';

        expect(
          () => engine.requirePulumiVersion('>=3.0.0'),
          throwsA(isA<GrpcError>()),
        );
      });
    });

    group('shutdown', () {
      test('shuts down the channel', () async {
        // Create a separate engine for shutdown test
        final (_, port, testServer) = await startMockEngineServer();
        final testEngine = Engine.connect('localhost:$port');

        await testEngine.info('before shutdown');
        await testEngine.shutdown();

        // After shutdown, operations should fail
        expect(
          () => testEngine.info('after shutdown'),
          throwsA(anything),
        );

        await testServer.shutdown();
      });
    });

    group('terminate', () {
      test('terminates the channel immediately', () async {
        // Create a separate engine for terminate test
        final (_, port, testServer) = await startMockEngineServer();
        final testEngine = Engine.connect('localhost:$port');

        await testEngine.info('before terminate');
        await testEngine.terminate();

        // After terminate, operations should fail
        expect(
          () => testEngine.info('after terminate'),
          throwsA(anything),
        );

        await testServer.shutdown();
      });
    });
  });
}
