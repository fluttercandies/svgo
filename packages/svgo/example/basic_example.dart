/// Example: Basic SVG optimization
///
/// This example demonstrates basic usage of the SVGO library.
library;

import 'package:svgo/svgo.dart';

void main() {
  // Sample SVG with redundant content
  final input = '''
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

  print('=== Basic Optimization ===');
  print('Input length: ${input.length} bytes');

  // Basic optimization with default settings
  final result = optimize(input);

  print('Output length: ${result.data.length} bytes');
  print('Saved: ${input.length - result.data.length} bytes');
  print('\nOptimized SVG:');
  print(result.data);

  print('\n=== With Multipass ===');

  // Multipass optimization for maximum compression
  final multipassResult = optimize(
      input,
      SvgoConfig(
        multipass: true,
      ));

  print('Output length: ${multipassResult.data.length} bytes');
  print('\nOptimized SVG:');
  print(multipassResult.data);

  print('\n=== With Custom Precision ===');

  // Custom float precision
  final precisionResult = optimize(
      input,
      SvgoConfig(
        floatPrecision: 1,
      ));

  print('Output length: ${precisionResult.data.length} bytes');
  print('\nOptimized SVG:');
  print(precisionResult.data);

  print('\n=== As Data URI ===');

  // Output as data URI
  final dataUriResult = optimize(
      input,
      SvgoConfig(
        datauri: DataUriType.base64,
      ));

  print('Data URI:');
  print(dataUriResult.data);
}
