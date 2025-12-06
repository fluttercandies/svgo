/// Command-line interface implementation for SVGO.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:svgo/svgo.dart';

/// Version of the CLI tool.
const String version = '1.0.0';

/// Runs the CLI with the given arguments.
///
/// Returns the exit code (0 for success, non-zero for errors).
Future<int> run(List<String> arguments) async {
  final parser = _buildArgParser();

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln();
    _printUsage(parser);
    return 1;
  }

  // Handle help flag
  if (results['help'] as bool) {
    _printUsage(parser);
    return 0;
  }

  // Handle version flag
  if (results['version'] as bool) {
    print('svgo version $version');
    return 0;
  }

  // Get input files/patterns
  final rest = results.rest;
  if (rest.isEmpty) {
    stderr.writeln('Error: No input files specified.');
    stderr.writeln();
    _printUsage(parser);
    return 1;
  }

  // Parse options
  final outputDir = results['output'] as String?;
  final quiet = results['quiet'] as bool;
  final floatPrecision = int.tryParse(results['precision'] as String);
  final multipass = results['multipass'] as bool;

  // Collect input files
  final inputFiles = <File>[];
  for (final pattern in rest) {
    final file = File(pattern);
    if (file.existsSync()) {
      inputFiles.add(file);
    } else {
      // Treat as glob pattern
      final glob = Glob(pattern);
      await for (final entity in glob.list()) {
        if (entity.path.endsWith('.svg')) {
          inputFiles.add(File(entity.path));
        }
      }
    }
  }

  if (inputFiles.isEmpty) {
    stderr.writeln('Error: No SVG files found matching the input patterns.');
    return 1;
  }

  // Create SVGO config
  final config = SvgoConfig(
    multipass: multipass,
    floatPrecision: floatPrecision,
  );

  // Process files
  var processedCount = 0;
  var totalSaved = 0;

  for (final file in inputFiles) {
    try {
      final input = await file.readAsString();
      final inputSize = input.length;

      final result = optimize(input, config);
      final outputSize = result.data.length;
      final saved = inputSize - outputSize;
      totalSaved += saved;

      // Determine output path
      String outputPath;
      if (outputDir != null) {
        final baseName = p.basename(file.path);
        outputPath = p.join(outputDir, baseName);
      } else {
        outputPath = file.path;
      }

      // Write output
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(result.data);

      processedCount++;

      if (!quiet) {
        final savedPercent =
            inputSize > 0 ? (saved / inputSize * 100).toStringAsFixed(1) : '0';
        print(
          '${file.path} → $outputPath '
          '($inputSize → $outputSize bytes, $savedPercent% saved)',
        );
      }
    } catch (e) {
      stderr.writeln('Error processing ${file.path}: $e');
    }
  }

  if (!quiet) {
    print('');
    print('Processed $processedCount file(s), saved $totalSaved bytes total.');
  }

  return 0;
}

/// Builds the argument parser for the CLI.
ArgParser _buildArgParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message.',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Show version information.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Output directory. If not specified, files are overwritten.',
      valueHelp: 'DIR',
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      negatable: false,
      help: 'Suppress output messages.',
    )
    ..addFlag(
      'recursive',
      abbr: 'r',
      negatable: false,
      help: 'Process directories recursively.',
    )
    ..addOption(
      'precision',
      abbr: 'p',
      defaultsTo: '3',
      help: 'Number of decimal places for floating point numbers.',
      valueHelp: 'NUM',
    )
    ..addFlag(
      'multipass',
      abbr: 'm',
      negatable: false,
      help: 'Run optimizations multiple times until no more changes.',
    );
}

/// Prints usage information.
void _printUsage(ArgParser parser) {
  print('SVGO - SVG Optimizer');
  print('');
  print('Usage: svgo [options] <file(s)>');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  svgo input.svg                  Optimize a single file');
  print('  svgo -o dist *.svg              Optimize all SVGs to dist/');
  print('  svgo -m -p 2 icon.svg           Multipass with 2 decimal precision');
  print('  svgo "src/**/*.svg"             Optimize all SVGs recursively');
}
