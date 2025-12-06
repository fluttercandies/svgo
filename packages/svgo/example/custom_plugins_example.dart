/// Example: Custom plugins configuration
///
/// This example shows how to configure plugins.
library;

import 'package:svgo/svgo.dart';

void main() {
  final input = '''
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
  <!-- This is a comment -->
  <rect x="0" y="0" width="100" height="100" fill="#ff0000" stroke="none"/>
  <ellipse cx="50" cy="50" rx="25" ry="25" fill="blue"/>
</svg>
  ''';

  print('=== Using Default Preset ===');
  final defaultResult = optimize(
      input,
      SvgoConfig(
        plugins: ['preset-default'],
      ));
  print(defaultResult.data);

  print('\n=== Custom Plugin Selection ===');
  // Only use specific plugins
  final customResult = optimize(
      input,
      SvgoConfig(
        plugins: [
          'removeComments',
          'convertColors',
          'convertEllipseToCircle',
        ],
      ));
  print(customResult.data);

  print('\n=== Plugin with Parameters ===');
  // Configure plugin parameters
  final paramResult = optimize(
      input,
      SvgoConfig(
        plugins: [
          {
            'name': 'cleanupNumericValues',
            'params': {
              'floatPrecision': 1,
            },
          },
          'removeComments',
          'convertColors',
        ],
      ));
  print(paramResult.data);
}
