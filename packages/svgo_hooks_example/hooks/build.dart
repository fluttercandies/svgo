import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as path;

// Import svgo from local package
import '../../svgo/lib/svgo.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // Get SVG assets directory
    final assetsDir = Directory('assets');
    if (!await assetsDir.exists()) {
      print('Warning: assets directory not found');
      return;
    }

    // Configure SVGO optimization options
    final svgoConfig = SvgoConfig(
      plugins: [
        'removeComments',
        'removeMetadata',
        'removeEditorsNSData',
        'cleanupAttrs',
        'mergeStyles',
        'inlineStyles',
        'minifyStyles',
        'convertColors',
        'removeEmptyAttrs',
        'removeEmptyContainers',
        'removeHiddenElems',
        'cleanupNumericValues',
        'convertShapeToPath',
        'collapseGroups',
        {
          'name': 'cleanupNumericValues',
          'params': {'floatPrecision': 2},
        },
      ],
      multipass: true,
    );

    // Find all SVG files
    final svgFiles = assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.svg'))
        .toList();

    if (svgFiles.isEmpty) {
      print('No SVG files found in assets directory');
      return;
    }

    print('Found ${svgFiles.length} SVG files to optimize');

    // Optimize each SVG file
    for (final svgFile in svgFiles) {
      try {
        // Read original SVG content
        final originalContent = await svgFile.readAsString();
        print('Processing: ${path.relative(svgFile.path)}');

        // Optimize using SVGO
        final result = optimize(originalContent, svgoConfig);

        // Calculate compression ratio
        final originalSize = originalContent.length;
        final optimizedSize = result.data.length;
        final compressionRatio =
            ((originalSize - optimizedSize) / originalSize * 100);

        print('  Original size: $originalSize bytes');
        print('  Optimized size: $optimizedSize bytes');
        print('  Compression: ${compressionRatio.toStringAsFixed(1)}%');

        // Write optimized content to output directory
        final relativePath = path.relative(svgFile.path, from: 'assets');
        final outputFile = File(
          path.join(input.outputDirectory.path, relativePath),
        );

        // Ensure output directory exists
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsString(result.data);

        print('  ✓ Optimized successfully\n');
      } catch (e) {
        print('  ✗ Failed to optimize ${svgFile.path}: $e\n');
      }
    }

    print('SVG optimization completed!');
  });
}
