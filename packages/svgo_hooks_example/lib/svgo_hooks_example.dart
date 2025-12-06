library svgo_hooks_example;

import 'dart:io';

/// SVG optimizer example library
///
/// This library demonstrates how to use Dart Hooks to automatically optimize
/// SVG assets during build time. Optimized SVG files are automatically
/// bundled into the application.
class SvgOptimizer {
  /// Get optimized SVG content
  ///
  /// Note: In real applications, these files are automatically optimized
  /// and bundled through hooks. This is just a demonstration API.
  static Future<String> getOptimizedSvg(String assetName) async {
    // In real applications, this would read optimized SVGs from bundled resources
    // This is just example implementation
    final file = File('optimized_assets/$assetName');
    if (await file.exists()) {
      return await file.readAsString();
    }

    // If optimized file doesn't exist, return original file
    final originalFile = File('assets/$assetName');
    if (await originalFile.exists()) {
      return await originalFile.readAsString();
    }

    throw Exception('SVG file not found: $assetName');
  }

  /// List all available SVG files
  static Future<List<String>> listAvailableSvgs() async {
    final assetsDir = Directory('assets');
    if (!await assetsDir.exists()) {
      return [];
    }

    return assetsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.svg'))
        .map((file) => file.path.split('/').last)
        .toList();
  }
}
