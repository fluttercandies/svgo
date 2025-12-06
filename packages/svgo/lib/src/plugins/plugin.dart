/// Plugin system for SVGO.
///
/// Provides the plugin interface and plugin invocation engine.
library;

import '../xast/xast.dart';
import '../xast/visitor.dart';

/// Information about the SVG being processed.
class SvgoInfo {
  /// The absolute path to the input file, if available.
  final String? path;

  /// The current multipass iteration count.
  final int multipassCount;

  const SvgoInfo({
    this.path,
    this.multipassCount = 0,
  });
}

/// Plugin parameter type.
typedef PluginParams = Map<String, dynamic>;

/// Plugin function signature.
///
/// Returns a visitor for traversing the XAST, or null if no traversal needed.
typedef PluginFn = Visitor? Function(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
);

/// A built-in SVGO plugin.
class Plugin {
  /// The unique name of this plugin.
  final String name;

  /// Human-readable description of what this plugin does.
  final String? description;

  /// Default parameters for this plugin.
  final PluginParams? params;

  /// The plugin function that performs the optimization.
  final PluginFn fn;

  const Plugin({
    required this.name,
    this.description,
    this.params,
    required this.fn,
  });

  /// Creates a copy of this plugin with merged parameters.
  Plugin copyWithParams(PluginParams newParams) {
    return Plugin(
      name: name,
      description: description,
      params: {...?params, ...newParams},
      fn: fn,
    );
  }
}

/// A plugin preset containing multiple plugins.
class PluginPreset extends Plugin {
  /// The plugins included in this preset.
  final List<Plugin> plugins;

  const PluginPreset({
    required super.name,
    super.description,
    super.params,
    required this.plugins,
    required super.fn,
  });

  /// Whether this is a preset (always true).
  bool get isPreset => true;
}

/// Plugin configuration for SVGO.
///
/// Can be either:
/// - A string (plugin name)
/// - A Plugin instance
/// - A map with 'name' and optional 'params'
typedef PluginConfig = Object;

/// Resolves a plugin configuration to a Plugin instance.
///
/// [config] can be:
/// - A `String` - the plugin name to look up in [builtinPlugins]
/// - A `Plugin` instance - used directly
/// - A `Map` with 'name' key - plugin name with optional params override
Plugin? resolvePluginConfig(PluginConfig config, List<Plugin> builtinPlugins) {
  if (config is String) {
    return builtinPlugins.firstWhere(
      (p) => p.name == config,
      orElse: () => throw ArgumentError('Unknown plugin: $config'),
    );
  }

  if (config is Plugin) {
    return config;
  }

  if (config is Map<String, dynamic>) {
    final name = config['name'] as String?;
    if (name == null) {
      throw ArgumentError('Plugin config must have a "name" field');
    }

    final plugin = builtinPlugins.firstWhere(
      (p) => p.name == name,
      orElse: () => throw ArgumentError('Unknown plugin: $name'),
    );

    final params = config['params'] as Map<String, dynamic>?;
    if (params != null) {
      // Create a new plugin with merged params
      return Plugin(
        name: plugin.name,
        description: plugin.description,
        params: {...?plugin.params, ...params},
        fn: plugin.fn,
      );
    }

    return plugin;
  }

  throw ArgumentError('Invalid plugin config: $config');
}

/// Invokes a list of plugins on the AST.
///
/// [ast] The XAST root node to process.
/// [info] Information about the SVG.
/// [plugins] List of plugins to invoke.
/// [overrides] Per-plugin parameter overrides. Use `false` to disable.
/// [globalOverrides] Global parameters applied to all plugins.
void invokePlugins(
  XastRoot ast,
  SvgoInfo info,
  List<Plugin> plugins, [
  Map<String, dynamic>? overrides,
  Map<String, dynamic>? globalOverrides,
]) {
  for (final plugin in plugins) {
    final override = overrides?[plugin.name];

    // Skip disabled plugins
    if (override == false) continue;

    // Merge parameters
    final params = <String, dynamic>{
      ...?plugin.params,
      ...?globalOverrides,
      if (override is Map<String, dynamic>) ...override,
    };

    // Call the plugin function
    final visitor = plugin.fn(ast, params, info);
    if (visitor != null) {
      visit(ast, visitor);
    }
  }
}

/// Creates a plugin preset.
///
/// Presets are special plugins that invoke a list of other plugins.
///
/// Example:
/// ```dart
/// final myPreset = createPreset(
///   name: 'preset-custom',
///   plugins: [
///     removeComments,
///     removeDoctype,
///     // ... more plugins
///   ],
/// );
/// ```
PluginPreset createPreset({
  required String name,
  String? description,
  required List<Plugin> plugins,
}) {
  return PluginPreset(
    name: name,
    description: description,
    plugins: plugins,
    fn: (ast, params, info) {
      final floatPrecision = params['floatPrecision'];
      final overrides = params['overrides'] as Map<String, dynamic>?;

      final globalOverrides = <String, dynamic>{};
      if (floatPrecision != null) {
        globalOverrides['floatPrecision'] = floatPrecision;
      }

      // Warn about unknown plugin overrides
      if (overrides != null) {
        final pluginNames = plugins.map((p) => p.name).toSet();
        for (final pluginName in overrides.keys) {
          if (!pluginNames.contains(pluginName)) {
            print(
              'Warning: You are trying to configure $pluginName which is not '
              'part of $name.\n'
              'Try to put it before or after, for example:\n\n'
              'plugins: [\n'
              '  SvgoConfig.preset("$name"),\n'
              '  "$pluginName",\n'
              ']\n',
            );
          }
        }
      }

      invokePlugins(ast, info, plugins, overrides, globalOverrides);
      return null;
    },
  );
}
