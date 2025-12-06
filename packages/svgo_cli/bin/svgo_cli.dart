#!/usr/bin/env dart

/// SVGO CLI entry point.
///
/// Run with: `dart run svgo_cli:svgo_cli <args>`
/// Or after activation: `svgo <args>`
library;

import 'dart:io';

import 'package:svgo_cli/svgo_cli.dart' as cli;

Future<void> main(List<String> arguments) async {
  final exitCode = await cli.run(arguments);
  exit(exitCode);
}
