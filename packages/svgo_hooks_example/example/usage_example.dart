import 'dart:io';
import '../lib/svgo_hooks_example.dart';

void main() async {
  print('=== SVG Hooks Example Usage ===\n');

  // List all available SVG files
  print('1. Available SVG files:');
  final svgs = await SvgOptimizer.listAvailableSvgs();
  for (final svg in svgs) {
    print('  - $svg');
  }
  print('');

  // Demonstrate getting optimized SVG
  if (svgs.isNotEmpty) {
    print('2. Getting optimized SVG:');
    for (final svg in svgs) {
      try {
        print('\nProcessing file: $svg');

        // Run optimization first
        print('Running SVG optimization...');
        final result = await Process.run('dart', [
          'run',
          '--hooks',
        ], workingDirectory: Directory.current.path);

        if (result.exitCode == 0) {
          print('✓ Optimization completed');
          print(result.stdout);
        } else {
          print('✗ Optimization failed: ${result.stderr}');
          continue;
        }

        // Get optimized content
        final optimizedSvg = await SvgOptimizer.getOptimizedSvg(svg);
        print('Optimized SVG content:');
        print(optimizedSvg);
        print('${'=' * 50}');
      } catch (e) {
        print('Error: $e');
      }
    }
  } else {
    print(
      'No SVG files found, please ensure there are .svg files in assets/ directory',
    );
  }

  print('\n3. Usage in real applications:');
  print('''
In your Flutter application, you can use optimized SVGs like this:

import 'package:svgo_hooks_example/svgo_hooks_example.dart';

class MySvgWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: SvgOptimizer.getOptimizedSvg('icons/app_icon.svg'),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SvgPicture.string(snapshot.data!);
        }
        return CircularProgressIndicator();
      },
    );
  }
}
  ''');

  print('\n4. How hooks work:');
  print('''
When running the following commands, hooks/build.dart will automatically execute:
- dart run
- dart build  
- dart test

Optimization process:
1. Scan all .svg files in assets/ directory
2. Optimize using SVGO (remove comments, compress, clean up, etc.)
3. Save optimized files to output directory
4. Automatically bundle into application

This way, your application gets smaller, more efficient SVG files!
  ''');
}
