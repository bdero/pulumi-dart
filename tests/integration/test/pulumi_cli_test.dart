/// End-to-end tests using the real Pulumi CLI and pulumi-random provider.
///
/// These tests verify the full Pulumi workflow by running actual `pulumi preview`
/// and `pulumi up` commands with the Dart language host and pulumi-random provider.
///
/// Prerequisites:
/// - Pulumi CLI installed and in PATH
/// - Language host built: `cd cmd/pulumi-language-dart && go build -o pulumi-language-dart .`
///
/// Run these tests with:
///   cd tests/integration && dart test test/pulumi_cli_test.dart
///
/// Environment variables:
///   PULUMI_DART_E2E=true - Enable these tests (skipped by default)
///   PULUMI_LANGUAGE_HOST - Path to the language host binary (optional, auto-detected)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Runs a Pulumi CLI command in the given directory.
Future<ProcessResult> runPulumiCommand(
  List<String> args, {
  required String workingDir,
  Map<String, String>? extraEnv,
  bool printOutput = true,
}) async {
  // Set PULUMI_HOME to isolate state for this test
  final pulumiHome = '${Directory(workingDir).absolute.path}/.pulumi-home';
  final env = <String, String>{
    // Use isolated Pulumi home directory for credentials
    'PULUMI_HOME': pulumiHome,
    // Disable update checking
    'PULUMI_SKIP_UPDATE_CHECK': 'true',
    // Use empty passphrase for local backend secrets
    'PULUMI_CONFIG_PASSPHRASE': '',
    // Preserve PATH
    'PATH': Platform.environment['PATH'] ?? '',
    ...?extraEnv,
  };

  final result = await Process.run(
    'pulumi',
    args,
    workingDirectory: workingDir,
    environment: env,
    includeParentEnvironment: true,
  );

  if (printOutput && (result.stdout as String).isNotEmpty) {
    print('stdout:\n${result.stdout}');
  }
  if (printOutput && (result.stderr as String).isNotEmpty) {
    print('stderr:\n${result.stderr}');
  }

  return result;
}

/// Sets up the language plugin for testing.
///
/// This copies the built language host to the Pulumi plugin directory under
/// the test's PULUMI_HOME to make it discoverable by Pulumi.
Future<String?> setupLanguagePlugin(String testDir) async {
  // Try to find the built language host
  final repoRoot = Directory.current.parent.parent.path;
  final hostPath = Platform.isWindows
      ? '$repoRoot/cmd/pulumi-language-dart/pulumi-language-dart.exe'
      : '$repoRoot/cmd/pulumi-language-dart/pulumi-language-dart';

  if (!File(hostPath).existsSync()) {
    return null;
  }

  // Create the plugin directory in the PULUMI_HOME directory
  // Pulumi looks for language plugins as: pulumi-language-<name>[.exe]
  final pulumiHome = '$testDir/.pulumi-home';
  final pluginDir = Directory('$pulumiHome/plugins/language-dart-v0.1.0');
  if (!pluginDir.existsSync()) {
    await pluginDir.create(recursive: true);
  }

  // Copy the plugin binary
  final destPath = Platform.isWindows
      ? '${pluginDir.path}/pulumi-language-dart.exe'
      : '${pluginDir.path}/pulumi-language-dart';

  await File(hostPath).copy(destPath);

  // Make executable on Unix
  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', destPath]);
  }

  return pluginDir.path;
}

/// Creates a minimal Pulumi Dart project for testing.
Future<void> createTestProject({
  required String projectDir,
  required String projectName,
  bool useRandomProvider = true,
}) async {
  // Create project directory
  final dir = Directory(projectDir);
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }

  // Create Pulumi.yaml
  final pulumiYaml = '''
name: $projectName
description: End-to-end test project
runtime: dart
''';
  await File('$projectDir/Pulumi.yaml').writeAsString(pulumiYaml);

  // Create pubspec.yaml
  final sdkPath = Directory.current.parent.parent.path.replaceAll('\\', '/') + '/sdk/dart';
  final pubspecYaml = '''
name: $projectName
description: End-to-end test project
version: 0.1.0
publish_to: none

environment:
  sdk: '>=3.8.0 <4.0.0'

dependencies:
  pulumi:
    path: $sdkPath
''';
  await File('$projectDir/pubspec.yaml').writeAsString(pubspecYaml);

  // Create bin directory
  await Directory('$projectDir/bin').create(recursive: true);

  // Create main.dart with a simple program using random provider
  final mainDart = '''
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:pulumi/pulumi.dart';

/// A custom resource representing a random string from the pulumi-random provider.
class RandomString extends CustomResource {
  late final Output<String> result;
  late final Output<int> length;

  final int _length;

  RandomString(
    String name, {
    required int length,
    bool special = true,
    bool upper = true,
    bool lower = true,
    bool numeric = true,
    CustomResourceOptions? options,
  })  : _length = length,
        super('random:index/randomString:RandomString', name, options) {
    _inputs = {
      'length': Input.value(length),
      'special': Input.value(special),
      'upper': Input.value(upper),
      'lower': Input.value(lower),
      'numeric': Input.value(numeric),
    };
  }

  Map<String, Input<Object?>?> _inputs = {};

  @override
  Map<String, Input<Object?>?> get inputs => _inputs;

  @override
  void processOutputs(Struct properties) {
    super.processOutputs(properties);
    result = Output.of(properties.fields['result']?.stringValue ?? '');
    length = Output.of(properties.fields['length']?.numberValue.toInt() ?? _length);
  }
}

Future<void> main() async {
  await Pulumi.run((ctx) async {
    // Create a random string resource
    final randomStr = RandomString(
      'e2e-test-string',
      length: 16,
      special: false,
      upper: true,
      lower: true,
      numeric: true,
    );

    // Wait for registration
    await randomStr.registered;

    // Export outputs
    ctx.export('randomStringResult', randomStr.result);
    ctx.export('randomStringId', randomStr.id);
    ctx.export('randomStringUrn', randomStr.urn);
  });
}
''';
  // Use the package name as the file name (Dart convention for default entry point)
  await File('$projectDir/bin/$projectName.dart').writeAsString(mainDart);

  // Run dart pub get
  final pubGetResult = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: projectDir,
  );
  if (pubGetResult.exitCode != 0) {
    throw Exception('dart pub get failed: ${pubGetResult.stderr}');
  }
}

void main() {
  // Skip tests if PULUMI_DART_E2E is not set
  final runE2E = Platform.environment['PULUMI_DART_E2E'] == 'true';

  group('End-to-end Pulumi CLI tests', () {
    late Directory tempDir;
    late String projectDir;

    setUpAll(() async {
      // Verify Pulumi CLI is available
      try {
        final result = await Process.run('pulumi', ['version']);
        if (result.exitCode != 0) {
          fail('Pulumi CLI not available');
        }
        print('Using Pulumi ${(result.stdout as String).trim()}');
      } catch (e) {
        fail('Pulumi CLI not installed: $e');
      }
    });

    setUp(() async {
      // Create a temporary directory for the test project
      tempDir = await Directory.systemTemp.createTemp('pulumi_dart_e2e_');
      projectDir = tempDir.path;
      print('Test project directory: $projectDir');
    });

    tearDown(() async {
      // Clean up: destroy any resources and delete temp directory
      try {
        // Try to destroy the stack if it exists
        await runPulumiCommand(
          ['stack', 'rm', 'e2e-test', '--yes', '--force'],
          workingDir: projectDir,
          printOutput: false,
        );
      } catch (_) {
        // Ignore errors during cleanup
      }

      // Delete temp directory
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Ignore errors during cleanup
      }
    });

    test(
      'pulumi preview works with pulumi-random provider',
      () async {
        // Create the test project
        await createTestProject(
          projectDir: projectDir,
          projectName: 'e2e_test_project',
        );

        // Set up the language plugin
        final pluginPath = await setupLanguagePlugin(projectDir);
        if (pluginPath == null) {
          markTestSkipped(
            'Language host not built. Run: cd cmd/pulumi-language-dart && go build',
          );
          return;
        }
        print('Using language plugin from: $pluginPath');

        // Create the local backend directory
        final backendDir = Directory('$projectDir/.pulumi');
        if (!backendDir.existsSync()) {
          await backendDir.create(recursive: true);
        }

        // Login to local backend using file URL
        // Use forward slashes for the file URL even on Windows
        final backendUrl = 'file://${backendDir.path.replaceAll('\\', '/')}';
        var result = await runPulumiCommand(
          ['login', backendUrl],
          workingDir: projectDir,
        );
        expect(result.exitCode, equals(0),
            reason: 'Failed to login to local backend: ${result.stderr}');

        // Initialize a new stack
        result = await runPulumiCommand(
          ['stack', 'init', 'e2e-test', '--non-interactive'],
          workingDir: projectDir,
        );
        expect(result.exitCode, equals(0),
            reason: 'Failed to init stack: ${result.stderr}');

        // Install the random provider
        result = await runPulumiCommand(
          ['plugin', 'install', 'resource', 'random', 'v4.16.0'],
          workingDir: projectDir,
        );
        // Plugin install may fail if already installed, that's OK
        print('Plugin install exit code: ${result.exitCode}');

        // Run pulumi preview
        result = await runPulumiCommand(
          ['preview', '--non-interactive'],
          workingDir: projectDir,
        );

        // Debug: print exit code
        print('Preview exit code: ${result.exitCode}');

        // Verify the output mentions the resource - this is the key check
        final stdout = result.stdout as String;

        // With graceful shutdown implemented, exit code should now be 0
        expect(result.exitCode, equals(0),
            reason: 'Preview should exit with code 0. stderr: ${result.stderr}');
        expect(stdout, contains('random:index'),
            reason: 'Expected random provider resource in preview output.\nstdout: $stdout\nstderr: ${result.stderr}');
        expect(stdout, contains('e2e-test-string'),
            reason: 'Expected resource name in preview output');
        expect(stdout, contains('2 to create'),
            reason: 'Expected Stack + resource to be created');
      },
      skip: !runE2E
          ? 'Set PULUMI_DART_E2E=true to run end-to-end tests'
          : null,
      timeout: Timeout(Duration(minutes: 5)),
    );

    test(
      'pulumi up creates resources and exports outputs',
      () async {
        // Create the test project
        await createTestProject(
          projectDir: projectDir,
          projectName: 'e2e_test_project',
        );

        // Set up the language plugin
        final pluginPath = await setupLanguagePlugin(projectDir);
        if (pluginPath == null) {
          markTestSkipped(
            'Language host not built. Run: cd cmd/pulumi-language-dart && go build',
          );
          return;
        }

        // Create the local backend directory and login
        final backendDir = Directory('$projectDir/.pulumi');
        if (!backendDir.existsSync()) {
          await backendDir.create(recursive: true);
        }
        final backendUrl = 'file://${backendDir.path.replaceAll('\\', '/')}';
        var result = await runPulumiCommand(
          ['login', backendUrl],
          workingDir: projectDir,
        );
        expect(result.exitCode, equals(0),
            reason: 'Failed to login to local backend: ${result.stderr}');

        // Initialize a new stack
        result = await runPulumiCommand(
          ['stack', 'init', 'e2e-test', '--non-interactive'],
          workingDir: projectDir,
        );
        expect(result.exitCode, equals(0),
            reason: 'Failed to init stack: ${result.stderr}');

        // Install the random provider
        await runPulumiCommand(
          ['plugin', 'install', 'resource', 'random', 'v4.16.0'],
          workingDir: projectDir,
        );

        // Run pulumi up with --skip-preview to reduce execution time
        result = await runPulumiCommand(
          ['up', '--yes', '--skip-preview', '--non-interactive'],
          workingDir: projectDir,
        );

        // Verify the output shows the resource was created
        final stdout = result.stdout as String;

        // With graceful shutdown implemented, exit code should now be 0
        expect(result.exitCode, equals(0),
            reason: 'pulumi up should exit with code 0. stderr: ${result.stderr}');
        expect(stdout, contains('random:index'),
            reason: 'Expected random provider resource in up output.\nstdout: $stdout\nstderr: ${result.stderr}');
        expect(stdout, contains('e2e-test-string'),
            reason: 'Expected resource name in up output');
        expect(stdout, contains('2 created'),
            reason: 'Expected Stack + resource to be created');

        print('Successfully created resource');
      },
      skip: !runE2E
          ? 'Set PULUMI_DART_E2E=true to run end-to-end tests'
          : null,
      timeout: Timeout(Duration(minutes: 5)),
    );

    test(
      'pulumi destroy removes resources',
      () async {
        // Create the test project
        await createTestProject(
          projectDir: projectDir,
          projectName: 'e2e_test_project',
        );

        // Set up the language plugin
        final pluginPath = await setupLanguagePlugin(projectDir);
        if (pluginPath == null) {
          markTestSkipped(
            'Language host not built. Run: cd cmd/pulumi-language-dart && go build',
          );
          return;
        }

        // Create the local backend directory and login
        final backendDir = Directory('$projectDir/.pulumi');
        if (!backendDir.existsSync()) {
          await backendDir.create(recursive: true);
        }
        final backendUrl = 'file://${backendDir.path.replaceAll('\\', '/')}';
        var result = await runPulumiCommand(
          ['login', backendUrl],
          workingDir: projectDir,
        );
        expect(result.exitCode, equals(0),
            reason: 'Failed to login to local backend: ${result.stderr}');

        // Initialize and create resources
        result = await runPulumiCommand(
          ['stack', 'init', 'e2e-test', '--non-interactive'],
          workingDir: projectDir,
        );
        expect(result.exitCode, equals(0),
            reason: 'Failed to init stack: ${result.stderr}');
        await runPulumiCommand(
          ['plugin', 'install', 'resource', 'random', 'v4.16.0'],
          workingDir: projectDir,
        );
        result = await runPulumiCommand(
          ['up', '--yes', '--skip-preview', '--non-interactive'],
          workingDir: projectDir,
        );

        // Verify the Stack + resource was created
        var stdout = result.stdout as String;
        expect(result.exitCode, equals(0),
            reason: 'pulumi up should exit with code 0. stderr: ${result.stderr}');
        expect(stdout, contains('2 created'),
            reason: 'pulumi up failed to create resources: ${result.stderr}');

        // Run pulumi destroy
        result = await runPulumiCommand(
          ['destroy', '--yes', '--skip-preview', '--non-interactive'],
          workingDir: projectDir,
        );

        // Verify the Stack + resource was destroyed
        stdout = result.stdout as String;
        expect(result.exitCode, equals(0),
            reason: 'pulumi destroy should exit with code 0. stderr: ${result.stderr}');
        expect(stdout, contains('2 deleted'),
            reason: 'pulumi destroy failed to delete resources: ${result.stderr}');

        print('Successfully destroyed all resources');
      },
      skip: !runE2E
          ? 'Set PULUMI_DART_E2E=true to run end-to-end tests'
          : null,
      timeout: Timeout(Duration(minutes: 5)),
    );
  });

  group('Language plugin detection tests', () {
    test('built language host exists', () async {
      final repoRoot = Directory.current.parent.parent.path;
      final hostPath = Platform.isWindows
          ? '$repoRoot/cmd/pulumi-language-dart/pulumi-language-dart.exe'
          : '$repoRoot/cmd/pulumi-language-dart/pulumi-language-dart';

      final exists = File(hostPath).existsSync();
      if (!exists) {
        print('Language host not found at: $hostPath');
        print('Build it with: cd cmd/pulumi-language-dart && go build');
      }
      // This is informational, not a failure
      print('Language host exists: $exists');
    });
  });
}
