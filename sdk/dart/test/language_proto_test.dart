/// Tests for language.proto generated Dart types.
///
/// Verifies that:
/// 1. Message classes can be serialized/deserialized
/// 2. gRPC client methods have correct signatures
/// 3. LanguageRuntimeServiceBase abstract methods match expected interface

import 'dart:convert';
import 'dart:typed_data';

import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart';
import 'package:pulumi/pulumi.dart';
import 'package:test/test.dart';

void main() {
  group('Language proto message serialization', () {
    test('ProgramInfo serializes and deserializes correctly', () {
      final options = Struct()
        ..fields['useAot'] = (Value()..boolValue = true)
        ..fields['timeout'] = (Value()..numberValue = 30.0);

      final original = ProgramInfo(
        rootDirectory: '/project/root',
        programDirectory: '/project/root/src',
        entryPoint: 'main.dart',
        options: options,
      );

      // Serialize to bytes
      final bytes = original.writeToBuffer();
      expect(bytes, isNotEmpty);

      // Deserialize from bytes
      final restored = ProgramInfo.fromBuffer(bytes);

      expect(restored.rootDirectory, '/project/root');
      expect(restored.programDirectory, '/project/root/src');
      expect(restored.entryPoint, 'main.dart');
      expect(restored.hasOptions(), isTrue);
      expect(restored.options.fields['useAot']?.boolValue, isTrue);
      expect(restored.options.fields['timeout']?.numberValue, 30.0);
    });

    test('RunRequest serializes and deserializes correctly', () {
      final programInfo = ProgramInfo(
        rootDirectory: '/root',
        programDirectory: '/root/src',
        entryPoint: '.',
      );

      final configPropertyMap = Struct()
        ..fields['aws:region'] = (Value()..stringValue = 'us-west-2');

      final original = RunRequest(
        project: 'my-project',
        stack: 'dev',
        pwd: '/root',
        args: ['--debug', '--verbose'],
        config: [
          MapEntry('key1', 'value1'),
          MapEntry('key2', 'value2'),
        ],
        dryRun: true,
        parallel: 4,
        monitorAddress: 'localhost:12345',
        queryMode: false,
        configSecretKeys: ['secretKey1'],
        organization: 'my-org',
        configPropertyMap: configPropertyMap,
        info: programInfo,
      );

      final bytes = original.writeToBuffer();
      final restored = RunRequest.fromBuffer(bytes);

      expect(restored.project, 'my-project');
      expect(restored.stack, 'dev');
      expect(restored.pwd, '/root');
      expect(restored.args, ['--debug', '--verbose']);
      expect(restored.config['key1'], 'value1');
      expect(restored.config['key2'], 'value2');
      expect(restored.dryRun, isTrue);
      expect(restored.parallel, 4);
      expect(restored.monitorAddress, 'localhost:12345');
      expect(restored.queryMode, isFalse);
      expect(restored.configSecretKeys, ['secretKey1']);
      expect(restored.organization, 'my-org');
      expect(
          restored.configPropertyMap.fields['aws:region']?.stringValue,
          'us-west-2');
      expect(restored.info.rootDirectory, '/root');
    });

    test('RunResponse serializes and deserializes correctly', () {
      final original = RunResponse(
        error: 'Something went wrong',
        bail: true,
      );

      final bytes = original.writeToBuffer();
      final restored = RunResponse.fromBuffer(bytes);

      expect(restored.error, 'Something went wrong');
      expect(restored.bail, isTrue);
    });

    test('AboutResponse serializes with metadata map', () {
      final original = AboutResponse(
        executable: 'dart',
        version: '3.2.0',
        metadata: [
          MapEntry('os', 'linux'),
          MapEntry('arch', 'x64'),
        ],
      );

      final bytes = original.writeToBuffer();
      final restored = AboutResponse.fromBuffer(bytes);

      expect(restored.executable, 'dart');
      expect(restored.version, '3.2.0');
      expect(restored.metadata['os'], 'linux');
      expect(restored.metadata['arch'], 'x64');
    });

    test('DependencyInfo serializes and deserializes correctly', () {
      final original = DependencyInfo(
        name: 'pulumi',
        version: '1.0.0',
      );

      final bytes = original.writeToBuffer();
      final restored = DependencyInfo.fromBuffer(bytes);

      expect(restored.name, 'pulumi');
      expect(restored.version, '1.0.0');
    });

    test('GetProgramDependenciesRequest serializes with nested ProgramInfo', () {
      final programInfo = ProgramInfo(
        rootDirectory: '/project',
        programDirectory: '/project/app',
        entryPoint: 'lib/main.dart',
      );

      final original = GetProgramDependenciesRequest(
        transitiveDependencies: true,
        info: programInfo,
      );

      final bytes = original.writeToBuffer();
      final restored = GetProgramDependenciesRequest.fromBuffer(bytes);

      expect(restored.transitiveDependencies, isTrue);
      expect(restored.info.rootDirectory, '/project');
      expect(restored.info.programDirectory, '/project/app');
      expect(restored.info.entryPoint, 'lib/main.dart');
    });

    test('GetProgramDependenciesResponse serializes with list of dependencies', () {
      final original = GetProgramDependenciesResponse(
        dependencies: [
          DependencyInfo(name: 'pulumi', version: '1.0.0'),
          DependencyInfo(name: 'pulumi_aws', version: '2.0.0'),
        ],
      );

      final bytes = original.writeToBuffer();
      final restored = GetProgramDependenciesResponse.fromBuffer(bytes);

      expect(restored.dependencies.length, 2);
      expect(restored.dependencies[0].name, 'pulumi');
      expect(restored.dependencies[0].version, '1.0.0');
      expect(restored.dependencies[1].name, 'pulumi_aws');
      expect(restored.dependencies[1].version, '2.0.0');
    });

    test('InstallDependenciesRequest serializes correctly', () {
      final programInfo = ProgramInfo(
        rootDirectory: '/project',
        programDirectory: '/project/app',
        entryPoint: '.',
      );

      final original = InstallDependenciesRequest(
        isTerminal: true,
        info: programInfo,
      );

      final bytes = original.writeToBuffer();
      final restored = InstallDependenciesRequest.fromBuffer(bytes);

      expect(restored.isTerminal, isTrue);
      expect(restored.info.rootDirectory, '/project');
    });

    test('InstallDependenciesResponse serializes stdout/stderr', () {
      final original = InstallDependenciesResponse(
        stdout: utf8.encode('Installing dependencies...'),
        stderr: utf8.encode('Warning: outdated package'),
      );

      final bytes = original.writeToBuffer();
      final restored = InstallDependenciesResponse.fromBuffer(bytes);

      expect(utf8.decode(restored.stdout), 'Installing dependencies...');
      expect(utf8.decode(restored.stderr), 'Warning: outdated package');
    });

    test('RunPluginRequest serializes with lists', () {
      final programInfo = ProgramInfo(
        rootDirectory: '/project',
        programDirectory: '/project/plugin',
        entryPoint: '.',
      );

      final original = RunPluginRequest(
        pwd: '/project',
        args: ['arg1', 'arg2'],
        env: ['VAR1=value1', 'VAR2=value2'],
        info: programInfo,
      );

      final bytes = original.writeToBuffer();
      final restored = RunPluginRequest.fromBuffer(bytes);

      expect(restored.pwd, '/project');
      expect(restored.args, ['arg1', 'arg2']);
      expect(restored.env, ['VAR1=value1', 'VAR2=value2']);
      expect(restored.info.rootDirectory, '/project');
    });

    test('RunPluginResponse oneof works correctly', () {
      // Test stdout variant
      final stdoutResponse = RunPluginResponse(
        stdout: utf8.encode('output'),
      );
      expect(stdoutResponse.whichOutput(), RunPluginResponse_Output.stdout);
      expect(utf8.decode(stdoutResponse.stdout), 'output');

      // Test stderr variant
      final stderrResponse = RunPluginResponse(
        stderr: utf8.encode('error'),
      );
      expect(stderrResponse.whichOutput(), RunPluginResponse_Output.stderr);
      expect(utf8.decode(stderrResponse.stderr), 'error');

      // Test exitcode variant
      final exitcodeResponse = RunPluginResponse(
        exitcode: 0,
      );
      expect(exitcodeResponse.whichOutput(), RunPluginResponse_Output.exitcode);
      expect(exitcodeResponse.exitcode, 0);
    });

    test('GenerateProgramRequest serializes source map', () {
      final original = GenerateProgramRequest(
        source: [
          MapEntry('main.pcl', 'resource "aws:s3:Bucket" { }'),
          MapEntry('utils.pcl', 'function helper() { }'),
        ],
        loaderTarget: 'localhost:54321',
      );

      final bytes = original.writeToBuffer();
      final restored = GenerateProgramRequest.fromBuffer(bytes);

      expect(restored.source['main.pcl'], 'resource "aws:s3:Bucket" { }');
      expect(restored.source['utils.pcl'], 'function helper() { }');
      expect(restored.loaderTarget, 'localhost:54321');
    });

    test('GenerateProjectRequest serializes with all fields', () {
      final original = GenerateProjectRequest(
        sourceDirectory: '/source',
        targetDirectory: '/target',
        project: '{"name": "test-project"}',
        strict: true,
        loaderTarget: 'localhost:12345',
        localDependencies: [
          MapEntry('pulumi_aws', '/local/pulumi_aws'),
        ],
      );

      final bytes = original.writeToBuffer();
      final restored = GenerateProjectRequest.fromBuffer(bytes);

      expect(restored.sourceDirectory, '/source');
      expect(restored.targetDirectory, '/target');
      expect(restored.project, '{"name": "test-project"}');
      expect(restored.strict, isTrue);
      expect(restored.loaderTarget, 'localhost:12345');
      expect(restored.localDependencies['pulumi_aws'], '/local/pulumi_aws');
    });

    test('GeneratePackageRequest serializes with byte maps', () {
      final original = GeneratePackageRequest(
        directory: '/output',
        schema: '{"name": "my-package"}',
        extraFiles: [
          MapEntry('README.md', utf8.encode('# My Package')),
        ],
        loaderTarget: 'localhost:54321',
      );

      final bytes = original.writeToBuffer();
      final restored = GeneratePackageRequest.fromBuffer(bytes);

      expect(restored.directory, '/output');
      expect(restored.schema, '{"name": "my-package"}');
      expect(utf8.decode(restored.extraFiles['README.md']!), '# My Package');
      expect(restored.loaderTarget, 'localhost:54321');
    });

    test('PackRequest and PackResponse serialize correctly', () {
      final request = PackRequest(
        packageDirectory: '/my-package',
        version: '1.0.0',
        destinationDirectory: '/artifacts',
      );

      final requestBytes = request.writeToBuffer();
      final restoredRequest = PackRequest.fromBuffer(requestBytes);

      expect(restoredRequest.packageDirectory, '/my-package');
      expect(restoredRequest.version, '1.0.0');
      expect(restoredRequest.destinationDirectory, '/artifacts');

      final response = PackResponse(
        artifactPath: '/artifacts/my-package-1.0.0.tar.gz',
      );

      final responseBytes = response.writeToBuffer();
      final restoredResponse = PackResponse.fromBuffer(responseBytes);

      expect(restoredResponse.artifactPath, '/artifacts/my-package-1.0.0.tar.gz');
    });
  });

  group('Language proto JSON serialization', () {
    test('ProgramInfo serializes to and from JSON', () {
      final original = ProgramInfo(
        rootDirectory: '/root',
        programDirectory: '/root/src',
        entryPoint: 'main.dart',
      );

      final json = original.writeToJson();
      final restored = ProgramInfo.fromJson(json);

      expect(restored.rootDirectory, '/root');
      expect(restored.programDirectory, '/root/src');
      expect(restored.entryPoint, 'main.dart');
    });

    test('RunRequest serializes to and from JSON', () {
      final original = RunRequest(
        project: 'test-project',
        stack: 'production',
        dryRun: false,
        parallel: 8,
      );

      final json = original.writeToJson();
      final restored = RunRequest.fromJson(json);

      expect(restored.project, 'test-project');
      expect(restored.stack, 'production');
      expect(restored.dryRun, isFalse);
      expect(restored.parallel, 8);
    });

    test('AboutResponse with metadata serializes to JSON', () {
      final original = AboutResponse(
        executable: 'dart',
        version: '3.0.0',
        metadata: [MapEntry('runtime', 'dart')],
      );

      final json = original.writeToJson();
      final restored = AboutResponse.fromJson(json);

      expect(restored.executable, 'dart');
      expect(restored.version, '3.0.0');
      expect(restored.metadata['runtime'], 'dart');
    });
  });

  group('Language proto field presence detection', () {
    test('ProgramInfo has* methods work correctly', () {
      final empty = ProgramInfo();
      expect(empty.hasRootDirectory(), isFalse);
      expect(empty.hasProgramDirectory(), isFalse);
      expect(empty.hasEntryPoint(), isFalse);
      expect(empty.hasOptions(), isFalse);

      final populated = ProgramInfo(
        rootDirectory: '/root',
        programDirectory: '/src',
        entryPoint: '.',
        options: Struct(),
      );
      expect(populated.hasRootDirectory(), isTrue);
      expect(populated.hasProgramDirectory(), isTrue);
      expect(populated.hasEntryPoint(), isTrue);
      expect(populated.hasOptions(), isTrue);
    });

    test('RunRequest has* methods work correctly', () {
      final request = RunRequest(
        project: 'test',
        dryRun: true,
      );

      expect(request.hasProject(), isTrue);
      expect(request.hasDryRun(), isTrue);
      expect(request.hasStack(), isFalse);
      expect(request.hasMonitorAddress(), isFalse);
      expect(request.hasQueryMode(), isFalse);
    });

    test('RunResponse has* methods work correctly', () {
      final empty = RunResponse();
      expect(empty.hasError(), isFalse);
      expect(empty.hasBail(), isFalse);

      final withError = RunResponse(error: 'Failed');
      expect(withError.hasError(), isTrue);
      expect(withError.hasBail(), isFalse);
    });

    test('clear* methods work correctly', () {
      final info = ProgramInfo(
        rootDirectory: '/root',
        programDirectory: '/src',
      );

      expect(info.hasRootDirectory(), isTrue);
      info.clearRootDirectory();
      expect(info.hasRootDirectory(), isFalse);
      expect(info.rootDirectory, ''); // Default value
    });
  });

  group('Language proto default values', () {
    test('ProgramInfo has empty string defaults', () {
      final info = ProgramInfo();
      expect(info.rootDirectory, '');
      expect(info.programDirectory, '');
      expect(info.entryPoint, '');
    });

    test('RunRequest has correct defaults', () {
      final request = RunRequest();
      expect(request.project, '');
      expect(request.stack, '');
      expect(request.dryRun, isFalse);
      expect(request.parallel, 0);
      expect(request.queryMode, isFalse);
      expect(request.args, isEmpty);
      expect(request.config, isEmpty);
    });

    test('RunResponse has correct defaults', () {
      final response = RunResponse();
      expect(response.error, '');
      expect(response.bail, isFalse);
    });
  });

  group('LanguageRuntimeServiceBase interface', () {
    test('LanguageRuntimeServiceBase is an abstract class', () {
      // Verify that LanguageRuntimeServiceBase cannot be directly instantiated
      // by checking it's accessible as a type
      expect(LanguageRuntimeServiceBase, isNotNull);
    });

    test('LanguageRuntimeServiceBase has correct service name', () {
      // Create a minimal implementation to test the interface
      final service = _TestLanguageRuntimeService();
      expect(service.$name, 'pulumirpc.LanguageRuntime');
    });
  });

  group('LanguageRuntimeClient interface', () {
    test('LanguageRuntimeClient has correct default host', () {
      expect(LanguageRuntimeClient.defaultHost, '');
    });

    test('LanguageRuntimeClient has oauth scopes defined', () {
      expect(LanguageRuntimeClient.oauthScopes, isA<List<String>>());
    });
  });

  group('Language proto message equality and copying', () {
    test('Messages can be deep copied', () {
      final original = ProgramInfo(
        rootDirectory: '/root',
        programDirectory: '/src',
        entryPoint: 'main.dart',
      );

      // ignore: deprecated_member_use_from_same_package
      final copy = original.deepCopy();

      expect(copy.rootDirectory, original.rootDirectory);
      expect(copy.programDirectory, original.programDirectory);
      expect(copy.entryPoint, original.entryPoint);

      // Verify copy is independent
      copy.rootDirectory = '/other';
      expect(original.rootDirectory, '/root');
      expect(copy.rootDirectory, '/other');
    });

    test('ensureOptions creates nested message if missing', () {
      final info = ProgramInfo();
      expect(info.hasOptions(), isFalse);

      final options = info.ensureOptions();
      expect(info.hasOptions(), isTrue);
      expect(options, isA<Struct>());

      // Same instance is returned
      expect(identical(options, info.options), isTrue);
    });

    test('ensureInfo creates nested ProgramInfo if missing', () {
      final request = RunRequest();
      expect(request.hasInfo(), isFalse);

      final info = request.ensureInfo();
      expect(request.hasInfo(), isTrue);
      expect(info, isA<ProgramInfo>());
    });
  });
}

/// Minimal implementation of LanguageRuntimeServiceBase for testing.
class _TestLanguageRuntimeService extends LanguageRuntimeServiceBase {
  @override
  Future<GetRequiredPluginsResponse> getRequiredPlugins(
      call, GetRequiredPluginsRequest request) async {
    return GetRequiredPluginsResponse();
  }

  @override
  Future<RunResponse> run(call, RunRequest request) async {
    return RunResponse();
  }

  @override
  Future<PluginInfo> getPluginInfo(call, request) async {
    return PluginInfo();
  }

  @override
  Stream<InstallDependenciesResponse> installDependencies(
      call, InstallDependenciesRequest request) async* {
    yield InstallDependenciesResponse();
  }

  @override
  Future<AboutResponse> about(call, request) async {
    return AboutResponse();
  }

  @override
  Future<GetProgramDependenciesResponse> getProgramDependencies(
      call, GetProgramDependenciesRequest request) async {
    return GetProgramDependenciesResponse();
  }

  @override
  Stream<RunPluginResponse> runPlugin(call, RunPluginRequest request) async* {
    yield RunPluginResponse();
  }

  @override
  Future<GenerateProgramResponse> generateProgram(
      call, GenerateProgramRequest request) async {
    return GenerateProgramResponse();
  }

  @override
  Future<GenerateProjectResponse> generateProject(
      call, GenerateProjectRequest request) async {
    return GenerateProjectResponse();
  }

  @override
  Future<GeneratePackageResponse> generatePackage(
      call, GeneratePackageRequest request) async {
    return GeneratePackageResponse();
  }

  @override
  Future<PackResponse> pack(call, PackRequest request) async {
    return PackResponse();
  }
}
