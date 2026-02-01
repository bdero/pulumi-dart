# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-01

### Added

- Initial release of the Pulumi Dart SDK
- Core SDK types: `Output`, `Input`, `Resource`, `CustomResource`, `ComponentResource`
- Resource registration with the Pulumi engine via gRPC
- Support for resource options: `parent`, `dependsOn`, `protect`, `aliases`, `ignoreChanges`, `replaceOnChanges`, `customTimeouts`, `retainOnDelete`, `deletedWith`, `provider`, `version`, `pluginDownloadUrl`
- Custom resource options: `importId`, `deleteBeforeReplace`
- Configuration management via `Config` class
- Stack exports via `Context.export()`
- Output combinators: `apply`, `all`
- Full protobuf/gRPC integration with the Pulumi engine
- Comprehensive documentation and examples
