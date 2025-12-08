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

/// Base class for all plugin parameters.
///
/// Each plugin that requires configuration should define a params class
/// extending this base class. Plugins without parameters can use [EmptyParams].
abstract class PluginParams {
  const PluginParams();
}

/// Empty parameters for plugins that don't need configuration.
class EmptyParams extends PluginParams {
  const EmptyParams();
}

/// Plugin function signature with generic params type.
///
/// Returns a visitor for traversing the XAST, or null if no traversal needed.
typedef PluginFn<P extends PluginParams> = Visitor? Function(
  XastRoot ast,
  P params,
  SvgoInfo info,
);

/// A built-in SVGO plugin with type-safe parameters.
class Plugin<P extends PluginParams> {
  /// The unique name of this plugin.
  final String name;

  /// Human-readable description of what this plugin does.
  final String? description;

  /// Default parameters for this plugin.
  final P defaultParams;

  /// The plugin function that performs the optimization.
  final PluginFn<P> fn;

  const Plugin({
    required this.name,
    this.description,
    required this.defaultParams,
    required this.fn,
  });

  /// Creates a copy of this plugin with new parameters.
  Plugin<P> withParams(P params) {
    return Plugin<P>(
      name: name,
      description: description,
      defaultParams: params,
      fn: fn,
    );
  }

  /// Invokes this plugin on the given AST.
  ///
  /// This method preserves type safety when plugin is stored in a List<Plugin>.
  Visitor? invoke(XastRoot ast, PluginParams params, SvgoInfo info) {
    // Cast is safe because we control the params type via defaultParams
    return fn(ast, params as P, info);
  }
}

/// A plugin preset containing multiple plugins.
class PluginPreset extends Plugin<PresetParams> {
  /// The plugins included in this preset.
  final List<Plugin> plugins;

  const PluginPreset({
    required super.name,
    super.description,
    required super.defaultParams,
    required this.plugins,
    required super.fn,
  });

  /// Whether this is a preset (always true).
  bool get isPreset => true;
}

/// Parameters for plugin presets.
class PresetParams extends PluginParams {
  /// Global float precision override.
  final int? floatPrecision;

  /// Per-plugin parameter overrides.
  /// Key is plugin name, value is either `false` to disable or plugin params.
  final Map<String, Object?>? overrides;

  const PresetParams({
    this.floatPrecision,
    this.overrides,
  });

  PresetParams copyWith({
    int? floatPrecision,
    Map<String, Object?>? overrides,
  }) {
    return PresetParams(
      floatPrecision: floatPrecision ?? this.floatPrecision,
      overrides: overrides ?? this.overrides,
    );
  }
}

/// Invokes a list of plugins on the AST.
///
/// [ast] The XAST root node to process.
/// [info] Information about the SVG.
/// [plugins] List of plugins to invoke.
/// [globalOverrides] Global parameters like floatPrecision.
void invokePlugins(
  XastRoot ast,
  SvgoInfo info,
  List<Plugin> plugins, [
  Map<String, Object?>? pluginOverrides,
  Map<String, dynamic>? globalOverrides,
]) {
  for (final plugin in plugins) {
    final override = pluginOverrides?[plugin.name];

    // Skip disabled plugins
    if (override == false) continue;

    // Get the params to use
    final params = _resolveParams(plugin, override, globalOverrides);

    // Call the plugin function using invoke() for type safety
    final visitor = plugin.invoke(ast, params, info);
    if (visitor != null) {
      visit(ast, visitor);
    }
  }
}

/// Resolves the actual params to use for a plugin invocation.
PluginParams _resolveParams(
  Plugin plugin,
  Object? override,
  Map<String, dynamic>? globalOverrides,
) {
  var params = plugin.defaultParams;

  // If override is a PluginParams of correct type, use it
  if (override != null && override is PluginParams) {
    params = override;
  }

  // Apply global overrides for common params (like floatPrecision)
  // This is handled at a higher level for type safety
  return params;
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
    defaultParams: const PresetParams(),
    fn: (ast, params, info) {
      final floatPrecision = params.floatPrecision;
      final overrides = params.overrides;

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
              '  presetDefault,\n'
              '  $pluginName,\n'
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
