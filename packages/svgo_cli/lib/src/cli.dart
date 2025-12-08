/// Command-line interface implementation for SVGO.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:svgo/svgo.dart';

import 'config.dart';

/// Version of the CLI tool.
const String version = '1.2.0';

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

  // Parse CLI options
  final outputDir = results['output'] as String?;
  final quiet = results['quiet'] as bool;
  final cliFloatPrecision = int.tryParse(results['precision'] as String);
  final cliMultipass = results['multipass'] as bool;
  final configPath = results['config'] as String?;
  final noConfig = results['no-config'] as bool;

  // Load configuration
  SvgoFileConfig? fileConfig;
  if (!noConfig) {
    if (configPath != null) {
      // Load from specified config file
      try {
        fileConfig = await loadConfigFromFile(configPath);
        if (!quiet) {
          print('Using config: $configPath');
        }
      } catch (e) {
        stderr.writeln('Error loading config file: $e');
        return 1;
      }
    } else {
      // Search for config file
      fileConfig = await loadConfig();
      if (fileConfig != null && !quiet) {
        print('Using config: ${fileConfig.configPath}');
      }
    }
  }

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

  // Create SVGO config by merging file config with CLI options
  // CLI options take precedence over file config
  final config = _mergeConfig(
    fileConfig: fileConfig,
    cliMultipass: cliMultipass,
    cliFloatPrecision: cliFloatPrecision,
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

/// Merges file configuration with CLI options.
/// CLI options take precedence over file configuration.
SvgoConfig _mergeConfig({
  SvgoFileConfig? fileConfig,
  bool cliMultipass = false,
  int? cliFloatPrecision,
}) {
  if (fileConfig == null) {
    return SvgoConfig(
      multipass: cliMultipass,
      floatPrecision: cliFloatPrecision,
    );
  }

  // Convert file config to SvgoConfig, then override with CLI options
  final baseConfig = fileConfig.toSvgoConfig();

  // CLI multipass overrides file config if explicitly set
  final multipass = cliMultipass || baseConfig.multipass;

  // CLI precision overrides file config if explicitly set
  final floatPrecision = cliFloatPrecision ?? baseConfig.floatPrecision;

  return SvgoConfig(
    multipass: multipass,
    floatPrecision: floatPrecision,
    datauri: baseConfig.datauri,
    plugins: baseConfig.plugins,
    js2svg: baseConfig.js2svg,
  );
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
    )
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to config file (svgo.yaml/svgo.yml or pubspec.yaml).',
      valueHelp: 'FILE',
    )
    ..addFlag(
      'no-config',
      negatable: false,
      help: 'Disable loading config from svgo.yaml or pubspec.yaml.',
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
  print('Configuration:');
  print('  SVGO will automatically search for configuration files in order:');
  print(
      '  1. svgo.yaml or svgo.yml in current directory or parent directories');
  print(
      '  2. pubspec.yaml with "svgo:" key in current directory or parent directories');
  print('');
  print('Examples:');
  print('  svgo input.svg                  Optimize a single file');
  print('  svgo -o dist *.svg              Optimize all SVGs to dist/');
  print('  svgo -m -p 2 icon.svg           Multipass with 2 decimal precision');
  print('  svgo "src/**/*.svg"             Optimize all SVGs recursively');
  print('  svgo -c custom.yaml input.svg   Use custom config file');
  print('  svgo --no-config input.svg      Ignore config files');
}
