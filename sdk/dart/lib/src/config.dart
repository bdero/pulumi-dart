import 'dart:convert';
import 'dart:io' show Platform;

import 'output.dart';
import 'runtime/runtime.dart';

/// Provides access to stack configuration values.
///
/// Configuration values are set using `pulumi config set` and stored in
/// `Pulumi.<stack>.yaml`. They can be accessed in your program using the
/// Config class.
///
/// ## Example
///
/// ```dart
/// import 'package:pulumi/pulumi.dart';
///
/// Future<void> main() async {
///   await Pulumi.run((ctx) async {
///     final config = Config();
///
///     // Get optional config value
///     final region = config.get('region') ?? 'us-east-1';
///
///     // Require a config value (throws if missing)
///     final apiKey = config.require('apiKey');
///
///     // Get typed values
///     final port = config.getInt('port') ?? 8080;
///     final enabled = config.getBool('featureEnabled') ?? false;
///   });
/// }
/// ```
///
/// ## Namespaces
///
/// By default, the Config class uses the current project name as a namespace.
/// You can specify a different namespace when creating a Config instance:
///
/// ```dart
/// // Use project namespace (default)
/// final config = Config();
///
/// // Use custom namespace for a specific provider
/// final awsConfig = Config('aws');
/// final region = awsConfig.get('region');  // Reads aws:region
/// ```
class Config {
  /// The namespace for configuration keys.
  final String _name;

  /// Cached configuration values from environment.
  static Map<String, String>? _cachedConfig;

  /// Cached set of secret configuration keys from environment.
  static Set<String>? _cachedSecretKeys;

  /// Creates a Config instance with the given namespace.
  ///
  /// If [name] is not provided, uses the current project name from Runtime
  /// or defaults to 'pulumi' if Runtime is not initialized.
  Config([String? name]) : _name = name ?? _getProjectName();

  /// Gets the project name from Runtime or returns a default.
  static String _getProjectName() {
    if (Runtime.isInitialized) {
      return Runtime.instance.project;
    }
    // Fall back to environment variable or default
    return Platform.environment['PULUMI_PROJECT'] ?? 'pulumi';
  }

  /// Lazily loads and caches configuration from environment variables.
  static Map<String, String> _loadConfig() {
    if (_cachedConfig != null) return _cachedConfig!;

    _cachedConfig = {};
    const prefix = 'PULUMI_CONFIG_';

    for (final entry in Platform.environment.entries) {
      if (entry.key.startsWith(prefix)) {
        // Convert PULUMI_CONFIG_NAMESPACE_KEY back to namespace:key
        final envKey = entry.key.substring(prefix.length);
        final configKey = envKey.toLowerCase().replaceAll('_', ':');
        _cachedConfig![configKey] = entry.value;
      }
    }

    return _cachedConfig!;
  }

  /// Lazily loads and caches secret keys from PULUMI_CONFIG_SECRET_KEYS.
  static Set<String> _loadSecretKeys() {
    if (_cachedSecretKeys != null) return _cachedSecretKeys!;

    _cachedSecretKeys = {};
    final secretKeysJson = Platform.environment['PULUMI_CONFIG_SECRET_KEYS'];
    if (secretKeysJson != null && secretKeysJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(secretKeysJson);
        if (decoded is List) {
          for (final key in decoded) {
            if (key is String) {
              _cachedSecretKeys!.add(key);
            }
          }
        }
      } catch (_) {
        // Ignore JSON parsing errors - treat as no secret keys
      }
    }

    return _cachedSecretKeys!;
  }

  /// Returns true if the given fully-qualified key is marked as a secret.
  static bool _isSecretKey(String fullKey) {
    return _loadSecretKeys().contains(fullKey);
  }

  /// Gets the fully qualified key name.
  String _fullKey(String key) => '$_name:$key';

  /// Gets an optional configuration value.
  ///
  /// Returns `null` if the key is not set.
  ///
  /// ```dart
  /// final region = config.get('region') ?? 'us-east-1';
  /// ```
  String? get(String key) {
    final config = _loadConfig();
    return config[_fullKey(key)];
  }

  /// Gets a required configuration value.
  ///
  /// Throws [ConfigMissingError] if the key is not set.
  ///
  /// ```dart
  /// final apiKey = config.require('apiKey');
  /// ```
  String require(String key) {
    final value = get(key);
    if (value == null) {
      throw ConfigMissingError(_fullKey(key));
    }
    return value;
  }

  /// Gets an optional secret configuration value.
  ///
  /// Returns an [Output] marked as secret. Returns an Output containing
  /// `null` if the key is not set.
  ///
  /// ```dart
  /// final passwordOutput = config.getSecret('password');
  /// ```
  Output<String?> getSecret(String key) {
    final value = get(key);
    if (value == null) {
      return Output<String?>.of(null).asSecret();
    }
    return Output<String?>.of(value).asSecret();
  }

  /// Gets a required secret configuration value.
  ///
  /// Returns an [Output] marked as secret. Throws [ConfigMissingError]
  /// if the key is not set.
  ///
  /// ```dart
  /// final apiKeyOutput = config.requireSecret('apiKey');
  /// ```
  Output<String> requireSecret(String key) {
    final value = require(key);
    return Output.of(value).asSecret();
  }

  /// Gets an optional boolean configuration value.
  ///
  /// Returns `null` if the key is not set.
  /// Recognizes 'true', '1', 'yes', 'on' (case-insensitive) as true.
  /// All other values are treated as false.
  ///
  /// ```dart
  /// final enabled = config.getBool('featureEnabled') ?? false;
  /// ```
  bool? getBool(String key) {
    final value = get(key);
    if (value == null) return null;
    return _parseBool(value);
  }

  /// Gets a required boolean configuration value.
  ///
  /// Throws [ConfigMissingError] if the key is not set.
  ///
  /// ```dart
  /// final enabled = config.requireBool('featureEnabled');
  /// ```
  bool requireBool(String key) {
    final value = require(key);
    return _parseBool(value);
  }

  /// Gets an optional secret boolean configuration value.
  Output<bool?> getSecretBool(String key) {
    final value = getBool(key);
    if (value == null) {
      return Output<bool?>.of(null).asSecret();
    }
    return Output<bool?>.of(value).asSecret();
  }

  /// Gets a required secret boolean configuration value.
  Output<bool> requireSecretBool(String key) {
    final value = requireBool(key);
    return Output.of(value).asSecret();
  }

  /// Gets an optional integer configuration value.
  ///
  /// Returns `null` if the key is not set.
  /// Throws [ConfigTypeError] if the value cannot be parsed as an integer.
  ///
  /// ```dart
  /// final port = config.getInt('port') ?? 8080;
  /// ```
  int? getInt(String key) {
    final value = get(key);
    if (value == null) return null;
    return _parseInt(key, value);
  }

  /// Gets a required integer configuration value.
  ///
  /// Throws [ConfigMissingError] if the key is not set.
  /// Throws [ConfigTypeError] if the value cannot be parsed as an integer.
  ///
  /// ```dart
  /// final port = config.requireInt('port');
  /// ```
  int requireInt(String key) {
    final value = require(key);
    return _parseInt(key, value);
  }

  /// Gets an optional secret integer configuration value.
  Output<int?> getSecretInt(String key) {
    final value = getInt(key);
    if (value == null) {
      return Output<int?>.of(null).asSecret();
    }
    return Output<int?>.of(value).asSecret();
  }

  /// Gets a required secret integer configuration value.
  Output<int> requireSecretInt(String key) {
    final value = requireInt(key);
    return Output.of(value).asSecret();
  }

  /// Gets an optional double configuration value.
  ///
  /// Returns `null` if the key is not set.
  /// Throws [ConfigTypeError] if the value cannot be parsed as a double.
  ///
  /// ```dart
  /// final ratio = config.getDouble('ratio') ?? 1.0;
  /// ```
  double? getDouble(String key) {
    final value = get(key);
    if (value == null) return null;
    return _parseDouble(key, value);
  }

  /// Gets a required double configuration value.
  ///
  /// Throws [ConfigMissingError] if the key is not set.
  /// Throws [ConfigTypeError] if the value cannot be parsed as a double.
  ///
  /// ```dart
  /// final ratio = config.requireDouble('ratio');
  /// ```
  double requireDouble(String key) {
    final value = require(key);
    return _parseDouble(key, value);
  }

  /// Gets an optional secret double configuration value.
  Output<double?> getSecretDouble(String key) {
    final value = getDouble(key);
    if (value == null) {
      return Output<double?>.of(null).asSecret();
    }
    return Output<double?>.of(value).asSecret();
  }

  /// Gets a required secret double configuration value.
  Output<double> requireSecretDouble(String key) {
    final value = requireDouble(key);
    return Output.of(value).asSecret();
  }

  /// Gets an optional JSON object configuration value.
  ///
  /// Returns `null` if the key is not set.
  /// Throws [ConfigTypeError] if the value cannot be parsed as JSON.
  ///
  /// ```dart
  /// final settings = config.getObject<Map<String, dynamic>>('settings');
  /// ```
  T? getObject<T>(String key) {
    final value = get(key);
    if (value == null) return null;
    return _parseJson<T>(key, value);
  }

  /// Gets a required JSON object configuration value.
  ///
  /// Throws [ConfigMissingError] if the key is not set.
  /// Throws [ConfigTypeError] if the value cannot be parsed as JSON.
  ///
  /// ```dart
  /// final settings = config.requireObject<Map<String, dynamic>>('settings');
  /// ```
  T requireObject<T>(String key) {
    final value = require(key);
    return _parseJson<T>(key, value);
  }

  /// Gets an optional secret JSON object configuration value.
  Output<T?> getSecretObject<T>(String key) {
    final value = getObject<T>(key);
    if (value == null) {
      return Output<T?>.of(null).asSecret();
    }
    return Output<T?>.of(value).asSecret();
  }

  /// Gets a required secret JSON object configuration value.
  Output<T> requireSecretObject<T>(String key) {
    final value = requireObject<T>(key);
    return Output.of(value).asSecret();
  }

  // Parsing helpers

  bool _parseBool(String value) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on';
  }

  int _parseInt(String key, String value) {
    final result = int.tryParse(value);
    if (result == null) {
      throw ConfigTypeError(_fullKey(key), value, 'int');
    }
    return result;
  }

  double _parseDouble(String key, String value) {
    final result = double.tryParse(value);
    if (result == null) {
      throw ConfigTypeError(_fullKey(key), value, 'double');
    }
    return result;
  }

  T _parseJson<T>(String key, String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! T) {
        throw ConfigTypeError(_fullKey(key), value, T.toString());
      }
      return decoded;
    } on FormatException catch (e) {
      throw ConfigTypeError(_fullKey(key), value, 'JSON', e.message);
    }
  }

  /// Returns true if the given key is marked as a secret in the stack configuration.
  ///
  /// This checks if the key is in the list of secret keys passed by the Pulumi engine.
  /// Secret keys are those set with `pulumi config set --secret`.
  bool isSecret(String key) {
    return _isSecretKey(_fullKey(key));
  }

  /// Clears the cached configuration.
  ///
  /// This is primarily for testing purposes.
  static void clearCache() {
    _cachedConfig = null;
    _cachedSecretKeys = null;
  }
}

/// Error thrown when a required configuration key is missing.
class ConfigMissingError extends Error {
  /// The missing configuration key.
  final String key;

  ConfigMissingError(this.key);

  @override
  String toString() => 'Missing required configuration variable: $key\n'
      'Please set it with: pulumi config set $key <value>';
}

/// Error thrown when a configuration value cannot be parsed as the expected type.
class ConfigTypeError extends Error {
  /// The configuration key.
  final String key;

  /// The actual value.
  final String value;

  /// The expected type.
  final String expectedType;

  /// Optional parse error message.
  final String? parseError;

  ConfigTypeError(this.key, this.value, this.expectedType, [this.parseError]);

  @override
  String toString() {
    var msg =
        'Configuration value for "$key" is not a valid $expectedType: "$value"';
    if (parseError != null) {
      msg += '\nParse error: $parseError';
    }
    return msg;
  }
}
