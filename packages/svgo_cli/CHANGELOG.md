# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-12-09

### Added

- Configuration file support with priority loading:
  - Explicit config via `--config <FILE>` flag
  - `svgo.yaml` in current directory
  - `svgo.yml` in current directory
  - `svgo:` key in `pubspec.yaml`
- Full plugin enable/disable support via configuration
- Complete plugin parameter configuration support
- `--no-config` flag to disable automatic config file loading
- `SvgoFileConfig` class for programmatic configuration loading
- `PluginConfig` class for plugin configuration representation
- `loadConfig()` and `loadConfigFromFile()` utility functions
- Comprehensive unit tests for configuration system

### Changed

- CLI now supports all output formatting options (pretty, indent, eol, finalNewline, useShortTags)
- Improved error handling and warning messages for unknown plugins/options

## [1.1.0] - 2025-12-08

### Changed

- Updated to use svgo 1.1.0 with type-safe plugin API
- Internal plugin configuration now uses type-safe API

## [1.0.0] - 2025-12-06

### Added

- Initial release of SVGO CLI
- Command-line interface for SVG optimization
- Single file and batch processing support
- Glob pattern support for file matching
- Output directory option (`-o, --output`)
- Recursive directory processing (`-r, --recursive`)
- Multipass optimization mode (`-m, --multipass`)
- Configurable float precision (`-p, --precision`)
- Quiet mode for scripting (`-q, --quiet`)
- Version and help commands
- Progress and summary output
- Byte savings statistics

### Usage Examples

```bash
# Optimize a single file
svgo input.svg

# Optimize to output directory
svgo -o dist input.svg

# Batch processing with glob
svgo "src/**/*.svg"

# Multipass with custom precision
svgo -m -p 2 input.svg
```

## [Unreleased]

### Planned

- Stdin/stdout support
- Watch mode for development
- Parallel processing for large batches
