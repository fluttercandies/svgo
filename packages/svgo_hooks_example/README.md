# SVGO Hooks Example

> **Version note**: Support for build hooks was introduced in Dart 3.10.

This is a demonstration project showing how to use Dart Hooks to automatically optimize SVG assets during build time. The hooks optimize SVG files before they are bundled into your application, ensuring smaller file sizes and better performance.

## Hook Example

```dart
import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:svgo/svgo.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    final assetsDir = Directory('assets');
    if (!await assetsDir.exists()) return;

    final svgoConfig = SvgoConfig(
      plugins: [
        'removeComments',
        'removeMetadata',
        'cleanupAttrs',
        'mergeStyles',
        'convertColors',
      ],
      multipass: true,
    );

    final svgFiles = assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.svg'))
        .toList();

    for (final svgFile in svgFiles) {
      final originalContent = await svgFile.readAsString();
      final result = optimize(originalContent, svgoConfig);
      
      final relativePath = path.relative(svgFile.path, from: 'assets');
      final outputFile = File(path.join(input.outputDirectory.path, relativePath));
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(result.data);
    }
  });
}
```

## Features

- 🚀 **Automatic Optimization**: Automatically optimize all SVG files during build time
- 📦 **Zero Configuration**: Use reasonable default settings, no manual setup required
- 📊 **Compression Statistics**: Display compression ratio and size changes for each file
- 🔧 **Configurable**: Support custom SVGO plugins and parameters
- 🧪 **Complete Testing**: Include comprehensive test suite

## Project Structure

```
svgo_hooks_example/
├── assets/                  # Original SVG files
│   ├── bear.svg
│   ├── bell.svg
│   └── ...
├── hooks/
│   └── build.dart           # Build hook script
├── lib/
│   └── svgo_hooks_example.dart  # Library file
├── example/
│   └── usage_example.dart   # Usage example
├── bin/
│   ├── svgo_hooks_example.dart  # Main entry point
│   └── optimize_svgs.dart      # Direct optimization script
└── pubspec.yaml
```

## Installation and Usage

### 1. Add Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  svgo: ^1.0.0
  hooks: ^1.0.0
  path: ^1.8.0
```

### 2. Create Build Hook

Create hook script in `hooks/build.dart` (see example above).

### 3. Run Hooks

Hooks automatically run when you execute:

```bash
dart run              # Run application
dart build            # Build application  
dart test             # Run tests
```

### 4. Use in Code

```dart
import 'package:svgo_hooks_example/svgo_hooks_example.dart';

// Get optimized SVG
final optimizedSvg = await SvgOptimizer.getOptimizedSvg('icons/app_icon.svg');

// List all available SVG files
final availableSvgs = await SvgOptimizer.listAvailableSvgs();
```

## SVGO Configuration

### Default Plugins

This project uses the following SVGO plugins:

- `removeComments` - Remove comments
- `removeMetadata` - Remove metadata
- `removeEditorsNSData` - Remove editor data
- `cleanupAttrs` - Clean up attributes
- `mergeStyles` - Merge styles
- `inlineStyles` - Inline styles
- `minifyStyles` - Minify styles
- `convertColors` - Convert colors
- `removeEmptyAttrs` - Remove empty attributes
- `removeEmptyContainers` - Remove empty containers
- `removeHiddenElems` - Remove hidden elements
- `cleanupNumericValues` - Clean up numeric values
- `convertShapeToPath` - Convert shapes to paths
- `collapseGroups` - Collapse groups

### Custom Configuration

You can customize optimization by modifying `SvgoConfig` in `hooks/build.dart`:

```dart
final svgoConfig = SvgoConfig(
  plugins: [
    'removeComments',
    {
      'name': 'cleanupNumericValues',
      'params': {'floatPrecision': 2},
    },
    // Add custom plugins...
  ],
  multipass: true,
  floatPrecision: 3,
);
```

## Example Output

When running hooks, you'll see output similar to:

```
Found 23 SVG files to optimize
Processing: bear.svg
  Original size: 2048 bytes
  Optimized size: 1024 bytes
  Compression: 50.0%
  ✓ Optimized successfully

Processing: bell.svg
  Original size: 1536 bytes
  Optimized size: 768 bytes
  Compression: 50.0%
  ✓ Optimized successfully

SVG optimization completed!
```

## How It Works

1. **Hook Trigger**: When running `dart run`, `dart build`, or `dart test`
2. **File Scanning**: Scan all `.svg` files in `assets/` directory
3. **SVG Optimization**: Optimize each file using SVGO
4. **Output Save**: Save optimized files to build output directory
5. **Automatic Bundling**: Dart SDK automatically bundles optimized files into application

## Best Practices

### File Organization

```
assets/
├── icons/           # Icon files
├── illustrations/   # Illustration files
└── ui/             # UI elements
```

### Performance Optimization

- For large projects, consider only optimizing modified files
- Use caching mechanisms to avoid repeated optimization
- Run hooks in CI/CD to ensure consistency

### Version Control

- Commit original SVG files to version control
- Ignore optimized files (generated by hooks)
- Generate optimized versions at build time

## Troubleshooting

### Common Issues

**Q: Hooks not running**
A: Ensure `hooks/` directory is in project root and file is named `build.dart`

**Q: Optimized files corrupted**
A: Check if SVG files are valid, try disabling certain plugins

**Q: Low compression ratio**
A: Some SVGs are already highly optimized, try enabling `multipass: true`

### Debugging Tips

1. Use `print` statements to output debug information
2. Check the value of `input.outputDirectory.path`
3. Verify SVG file paths are correct

## Related Resources

- [Dart Hooks Documentation](https://dart.dev/tools/hooks)
- [SVGO Official Documentation](https://github.com/svg/svgo)
- [SVG Optimization Best Practices](https://web.dev/optimize-svgs/)

## License

This project is licensed under BSD-3-Clause License.