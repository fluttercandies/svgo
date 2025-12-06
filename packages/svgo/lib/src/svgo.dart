/// Core SVGO optimization functions and configuration.
library;

import 'dart:convert';

import 'parser/parser.dart';
import 'plugins/plugin.dart';
import 'plugins/preset_default.dart';
import 'stringifier/stringifier.dart';
import 'xast/xast.dart';

/// SVGO library version.
const version = '1.0.0';

/// Data URI encoding types.
enum DataUriType {
  /// Base64 encoding.
  base64,

  /// URL encoding (percent-encoding).
  enc,

  /// Unencoded (for safe SVGs).
  unenc,
}

/// SVGO configuration options.
class SvgoConfig {
  /// The path to the input file (for error messages).
  final String? path;

  /// List of plugins to run.
  ///
  /// Can be plugin names (strings), Plugin instances, or maps with
  /// 'name' and optional 'params'.
  ///
  /// Default: `['preset-default']`
  final List<Object>? plugins;

  /// Enable multipass optimization.
  ///
  /// Runs optimization multiple times until the output stops shrinking.
  /// Default: false
  final bool multipass;

  /// Global float precision override.
  final int? floatPrecision;

  /// Output as data URI.
  final DataUriType? datauri;

  /// Options for SVG stringification.
  final StringifyOptions? js2svg;

  const SvgoConfig({
    this.path,
    this.plugins,
    this.multipass = false,
    this.floatPrecision,
    this.datauri,
    this.js2svg,
  });

  /// Creates a config that uses the default preset.
  factory SvgoConfig.defaults() => const SvgoConfig();

  /// Creates a config with specific plugins.
  factory SvgoConfig.withPlugins(List<Object> plugins) =>
      SvgoConfig(plugins: plugins);

  /// Creates a config with multipass enabled.
  factory SvgoConfig.multipass() => const SvgoConfig(multipass: true);
}

/// Output from SVGO optimization.
class SvgoOutput {
  /// The optimized SVG string.
  final String data;

  /// The parsed AST (if needed for further processing).
  final XastRoot? ast;

  const SvgoOutput({
    required this.data,
    this.ast,
  });
}

/// Resolves a plugin configuration to a Plugin instance.
Plugin? _resolvePluginConfig(Object pluginConfig) {
  if (pluginConfig is String) {
    // Resolve builtin plugin specified as string
    final builtinPlugin =
        builtinPlugins.where((p) => p.name == pluginConfig).firstOrNull;
    if (builtinPlugin == null) {
      throw ArgumentError('Unknown builtin plugin "$pluginConfig" specified.');
    }
    return builtinPlugin;
  }

  if (pluginConfig is Plugin) {
    return pluginConfig;
  }

  if (pluginConfig is Map<String, dynamic>) {
    final name = pluginConfig['name'] as String?;
    if (name == null) {
      throw ArgumentError('Plugin name must be specified');
    }

    // Check for custom fn
    final customFn = pluginConfig['fn'] as PluginFn?;
    if (customFn != null) {
      return Plugin(
        name: name,
        params: pluginConfig['params'] as Map<String, dynamic>?,
        fn: customFn,
      );
    }

    // Resolve builtin plugin implementation
    final builtinPlugin =
        builtinPlugins.where((p) => p.name == name).firstOrNull;
    if (builtinPlugin == null) {
      throw ArgumentError('Unknown builtin plugin "$name" specified.');
    }

    final params = pluginConfig['params'] as Map<String, dynamic>?;
    if (params != null) {
      return Plugin(
        name: name,
        params: {...?builtinPlugin.params, ...params},
        fn: builtinPlugin.fn,
      );
    }

    return builtinPlugin;
  }

  return null;
}

/// Encodes SVG string as a data URI.
String _encodeSvgDataUri(String svg, DataUriType type) {
  switch (type) {
    case DataUriType.base64:
      final encoded = base64.encode(utf8.encode(svg));
      return 'data:image/svg+xml;base64,$encoded';
    case DataUriType.enc:
      final encoded = Uri.encodeComponent(svg);
      return 'data:image/svg+xml,$encoded';
    case DataUriType.unenc:
      return 'data:image/svg+xml,$svg';
  }
}

/// Optimizes an SVG string.
///
/// This is the main entry point for SVGO optimization.
///
/// Example:
/// ```dart
/// final input = '<svg xmlns="http://www.w3.org/2000/svg">...</svg>';
/// final result = optimize(input);
/// print(result.data);
///
/// // With configuration:
/// final result = optimize(input, SvgoConfig(
///   multipass: true,
///   plugins: ['preset-default', 'removeViewBox'],
/// ));
/// ```
///
/// [input] The SVG string to optimize.
/// [config] Optional configuration options.
SvgoOutput optimize(String input, [SvgoConfig? config]) {
  config ??= const SvgoConfig();

  final maxPassCount = config.multipass ? 10 : 1;
  var prevResultSize = double.infinity;
  var output = '';

  var currentInput = input;

  for (var i = 0; i < maxPassCount; i++) {
    final info = SvgoInfo(
      path: config.path,
      multipassCount: i,
    );
    final ast = parseSvg(currentInput, config.path);

    final pluginConfigs = config.plugins ?? ['preset-default'];

    final resolvedPlugins =
        pluginConfigs.map(_resolvePluginConfig).whereType<Plugin>().toList();

    final globalOverrides = <String, dynamic>{};
    if (config.floatPrecision != null) {
      globalOverrides['floatPrecision'] = config.floatPrecision;
    }

    invokePlugins(ast, info, resolvedPlugins, null, globalOverrides);
    output = stringifySvg(ast, config.js2svg);

    if (output.length < prevResultSize) {
      currentInput = output;
      prevResultSize = output.length.toDouble();
    } else {
      break;
    }
  }

  if (config.datauri != null) {
    output = _encodeSvgDataUri(output, config.datauri!);
  }

  return SvgoOutput(data: output);
}

/// Optimizes an SVG and returns the parsed AST along with the output.
SvgoOutput optimizeWithAst(String input, [SvgoConfig? config]) {
  config ??= const SvgoConfig();

  final ast = parseSvg(input, config.path);

  final pluginConfigs = config.plugins ?? ['preset-default'];
  final resolvedPlugins =
      pluginConfigs.map(_resolvePluginConfig).whereType<Plugin>().toList();

  final info = SvgoInfo(path: config.path, multipassCount: 0);

  final globalOverrides = <String, dynamic>{};
  if (config.floatPrecision != null) {
    globalOverrides['floatPrecision'] = config.floatPrecision;
  }

  invokePlugins(ast, info, resolvedPlugins, null, globalOverrides);
  final output = stringifySvg(ast, config.js2svg);

  return SvgoOutput(data: output, ast: ast);
}
