/// Example: Using SVGO CLI programmatically
///
/// This example demonstrates how to use the SVGO CLI library programmatically
/// in your Dart applications. While the primary usage is via command line,
/// you can also integrate it directly into your code.
///
/// ## Command Line Usage
///
/// After installing globally:
/// ```bash
/// dart pub global activate svgo_cli
/// ```
///
/// You can use the CLI directly:
/// ```bash
/// # Optimize a single file (overwrites input)
/// svgo input.svg
///
/// # Optimize to output directory
/// svgo -o dist input.svg
///
/// # Optimize multiple files
/// svgo icon1.svg icon2.svg icon3.svg
///
/// # Optimize all SVGs in a directory (using glob pattern)
/// svgo "src/**/*.svg"
///
/// # Multipass optimization
/// svgo -m input.svg
///
/// # Custom precision (2 decimal places)
/// svgo -p 2 input.svg
///
/// # Quiet mode (no output messages)
/// svgo -q input.svg
///
/// # Show help
/// svgo --help
///
/// # Show version
/// svgo --version
/// ```
library;

import 'dart:io';

import 'package:svgo_cli/svgo_cli.dart';

void main() async {
  // Create a sample SVG file for demonstration
  final sampleSvg = '''
<?xml version="1.0" encoding="UTF-8"?>
<!-- Generator: Adobe Illustrator 24.0.0 -->
<svg xmlns="http://www.w3.org/2000/svg" 
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="100" height="100" viewBox="0 0 100 100">
  <metadata>Created with Illustrator</metadata>
  <desc>A simple red rectangle</desc>
  <defs></defs>
  <rect x="0" y="0" width="100" height="100" fill="#FF0000"/>
</svg>
''';

  // Write sample SVG to a temporary file
  final tempDir = Directory.systemTemp.createTempSync('svgo_example_');
  final inputFile = File('${tempDir.path}/sample.svg');
  await inputFile.writeAsString(sampleSvg);

  print('Created sample SVG file: ${inputFile.path}');
  print('Original size: ${sampleSvg.length} bytes');
  print('');

  // Run SVGO CLI programmatically
  print('Running SVGO optimization...');
  print('');

  // Example 1: Basic optimization
  final exitCode = await run([inputFile.path]);

  if (exitCode == 0) {
    print('');
    print('Optimization completed successfully!');

    // Read the optimized file
    final optimized = await inputFile.readAsString();
    print('');
    print('Optimized SVG:');
    print(optimized);
  }

  // Cleanup
  tempDir.deleteSync(recursive: true);
}
