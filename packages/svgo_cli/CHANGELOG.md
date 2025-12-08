# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- Configuration file support (svgo.config.yaml)
- Plugin selection via command-line
- Stdin/stdout support
- Watch mode for development
- Parallel processing for large batches
