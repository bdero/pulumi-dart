import 'package:test/test.dart';

import 'package:pulumi/src/runtime/runtime.dart';
import 'package:pulumi/src/runtime/monitor.dart';

import 'mock_monitor_service.dart';

void main() {
  group('Runtime', () {
    tearDown(() {
      // Reset runtime after each test
      Runtime.reset();
    });

    test('isInitialized returns false before initialization', () {
      expect(Runtime.isInitialized, isFalse);
    });

    test('instance throws before initialization', () {
      expect(() => Runtime.instance, throwsA(isA<StateError>()));
    });

    test('initialize creates runtime instance', () async {
      final (_, port) = await startMockServer();

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      expect(Runtime.isInitialized, isTrue);
      expect(Runtime.instance.project, equals('test-project'));
      expect(Runtime.instance.stack, equals('test-stack'));
      expect(Runtime.instance.isDryRun, isFalse);
      expect(Runtime.instance.organization, isNull);

      await Runtime.instance.monitor.terminate();
    });

    test('initialize with all options', () async {
      final (_, port) = await startMockServer();

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'my-project',
        stack: 'production',
        isDryRun: true,
        organization: 'my-org',
      );

      expect(Runtime.instance.project, equals('my-project'));
      expect(Runtime.instance.stack, equals('production'));
      expect(Runtime.instance.isDryRun, isTrue);
      expect(Runtime.instance.organization, equals('my-org'));

      await Runtime.instance.monitor.terminate();
    });

    test('initialize throws if already initialized', () async {
      final (_, port) = await startMockServer();

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      expect(
        () => Runtime.initialize(
          monitorAddress: 'localhost:$port',
          project: 'test-project',
          stack: 'test-stack',
        ),
        throwsA(isA<StateError>()),
      );

      await Runtime.instance.monitor.terminate();
    });

    test('initializeWithMonitor uses provided monitor', () async {
      final (_, port) = await startMockServer();
      final monitor = ResourceMonitor.connect('localhost:$port');

      Runtime.initializeWithMonitor(
        monitor: monitor,
        project: 'custom-project',
        stack: 'custom-stack',
      );

      expect(Runtime.instance.monitor, same(monitor));
      expect(Runtime.instance.project, equals('custom-project'));

      await monitor.terminate();
    });

    test('reset clears the instance', () async {
      final (_, port) = await startMockServer();

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'test-project',
        stack: 'test-stack',
      );

      expect(Runtime.isInitialized, isTrue);
      await Runtime.instance.monitor.terminate();

      Runtime.reset();

      expect(Runtime.isInitialized, isFalse);
    });

    test('can reinitialize after reset', () async {
      final (_, port) = await startMockServer();

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'first-project',
        stack: 'first-stack',
      );

      await Runtime.instance.monitor.terminate();
      Runtime.reset();

      await Runtime.initialize(
        monitorAddress: 'localhost:$port',
        project: 'second-project',
        stack: 'second-stack',
      );

      expect(Runtime.instance.project, equals('second-project'));
      expect(Runtime.instance.stack, equals('second-stack'));

      await Runtime.instance.monitor.terminate();
    });
  });
}
