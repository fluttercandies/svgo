<p align="center">
  <img src="svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<p align="center">
  <h1>SVGO Dart</h1>
</p>

<p align="center">
  A powerful SVG optimization tool for Dart and Flutter.
</p>

<p align="center">
  <a href="https://pub.dev/packages/svgo"><img src="https://img.shields.io/pub/v/svgo.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo-dart/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo-dart" alt="license"></a>
</p>

A comprehensive SVG optimization library for the Dart/Flutter ecosystem, providing powerful tools to reduce file sizes while preserving visual quality. Inspired by proven optimization techniques used in popular SVG tools.

## Packages

| Package | Description | pub.dev |
|---------|-------------|---------|
| [svgo](packages/svgo) | Core SVGO library | [![pub package](https://img.shields.io/pub/v/svgo.svg)](https://pub.dev/packages/svgo) |
| [svgo_cli](packages/svgo_cli) | Command-line interface | [![pub package](https://img.shields.io/pub/v/svgo_cli.svg)](https://pub.dev/packages/svgo_cli) |
| [svgo_hooks_example](packages/svgo_hooks_example) | Build hooks example | [![pub package](https://img.shields.io/pub/v/svgo_hooks_example.svg)](https://pub.dev/packages/svgo_hooks_example) |

## Features

- ✅ Parse SVG files into an Abstract Syntax Tree (XAST)
- ✅ Apply various optimization plugins
- ✅ Serialize optimized AST back to SVG string
- ✅ Fully configurable with plugin system
- ✅ Multipass optimization support
- ✅ 54 builtin optimization plugins (full parity with Node.js SVGO)
- ✅ CSS style parsing and computation
- ✅ Path data manipulation utilities
- ✅ Command-line interface

## Quick Start

### As a Library

Add `svgo` to your `pubspec.yaml`:

```yaml
dependencies:
  svgo: ^1.0.0
```

Then use it in your Dart code:

```dart
import 'package:svgo/svgo.dart';

void main() {
  final input = '''
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      <!-- A red rectangle -->
      <rect x="0" y="0" width="100" height="100" fill="red"/>
    </svg>
  ''';

  final result = optimize(input);
  print(result.data);
  // Output: <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="100" height="100" fill="red"/></svg>
}
```

### As a CLI Tool

Install globally:

```bash
dart pub global activate svgo_cli
```

Then use it:

```bash
# Optimize a single file (overwrites input)
svgo input.svg

# Optimize to output directory
svgo -o dist input.svg

# Optimize all SVGs in a directory
svgo "src/**/*.svg"

# Multipass optimization with custom precision
svgo -m -p 2 icon.svg
```

## Configuration

### Using Presets

```dart
final result = optimize(input, SvgoConfig(
  plugins: ['preset-default'],
));
```

### Custom Plugin Configuration

```dart
final result = optimize(input, SvgoConfig(
  plugins: [
    'removeComments',
    'removeMetadata',
    {
      'name': 'cleanupNumericValues',
      'params': {'floatPrecision': 2},
    },
  ],
));
```

### Multipass Optimization

```dart
final result = optimize(input, SvgoConfig(
  multipass: true,
));
```

## Available Plugins

### Cleanup Plugins
- `cleanupAttrs` - Cleanup attributes from newlines, trailing spaces
- `cleanupNumericValues` - Round numeric values, remove default units

### Removal Plugins
- `removeComments` - Remove comments
- `removeDesc` - Remove `<desc>` elements
- `removeDoctype` - Remove DOCTYPE declaration
- `removeEditorsNSData` - Remove editor-specific namespaces
- `removeEmptyAttrs` - Remove empty attributes
- `removeEmptyContainers` - Remove empty container elements
- `removeEmptyText` - Remove empty text elements
- `removeMetadata` - Remove `<metadata>` elements
- `removeTitle` - Remove `<title>` elements
- `removeUnusedNS` - Remove unused namespace declarations
- `removeUselessDefs` - Remove elements in `<defs>` without id
- `removeXMLProcInst` - Remove XML processing instructions

### Conversion Plugins
- `convertColors` - Convert color values to shorter formats
- `convertEllipseToCircle` - Convert ellipses to circles when rx=ry
- `convertShapeToPath` - Convert shapes to path elements

### Structure Plugins
- `collapseGroups` - Collapse useless groups
- `moveElemsAttrsToGroup` - Move common attributes to parent group
- `moveGroupAttrsToElems` - Move group transforms to children
- `sortAttrs` - Sort element attributes
- `sortDefsChildren` - Sort `<defs>` children for better compression

### Style Plugins
- `mergeStyles` - Merge multiple style elements

## Build Hooks

> **Version note**: Support for build hooks was introduced in Dart 3.10.

The `svgo_hooks_example` package demonstrates how to use Dart Hooks to automatically optimize SVG files during build time. See the [svgo_hooks_example](packages/svgo_hooks_example) package for a complete implementation.

## Development

This project uses [Melos](https://melos.invertase.dev/) for monorepo management.

```bash
# Install melos
dart pub global activate melos

# Bootstrap (install dependencies for all packages)
melos bootstrap

# Run analysis
melos analyze

# Run tests
melos test

# Format code
melos format
```

## License

MIT License - Copyright (c) 2025 iota9star

See [LICENSE](LICENSE) for details.

## Acknowledgments

Thanks to [SVGO](https://github.com/svg/svgo) for inspiration and reference.

---

---

## 中文文档

完整的中文文档请查看 [README.zh.md](README.zh.md)。
