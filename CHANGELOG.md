# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-06

### Added

- Initial release of SVGO Dart - a complete port of [SVGO](https://github.com/svg/svgo) to Dart
- **svgo** package: Core library for SVG optimization
  - Complete SVG parser with XAST (Abstract Syntax Tree) generation
  - Visitor pattern for AST traversal and manipulation
  - 54 builtin optimization plugins (full parity with Node.js SVGO)
  - CSS style parsing and computation using csslib
  - CSS selector matching for style computation
  - Path data parsing and stringification
  - Multipass optimization support
  - Data URI encoding support (base64, URL-encoded, unencoded)
- **svgo_cli** package: Command-line interface
  - Single file and batch processing support
  - Glob pattern support for file matching
  - Output directory option
  - Multipass optimization mode
  - Configurable float precision
  - Quiet mode for scripting

### Plugin Categories

- **Cleanup Plugins** - Clean up attributes, values, and deprecated features
- **Remove Plugins** - Remove unnecessary elements, attributes, and content
- **Convert Plugins** - Convert elements and attributes to more efficient formats
- **Merge & Move Plugins** - Optimize structure by merging and moving elements
- **Sort Plugins** - Sort content for better compression
- **Style Plugins** - Process and optimize CSS styles
- **Other Plugins** - Additional optimization utilities

> For detailed plugin documentation, see [packages/svgo/CHANGELOG.md](packages/svgo/CHANGELOG.md)


