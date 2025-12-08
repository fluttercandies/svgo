/// Configuration file loading and parsing for SVGO CLI.
///
/// Supports loading configuration from:
/// - svgo.yaml or svgo.yml (priority)
/// - pubspec.yaml (under `svgo:` key)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:svgo/svgo.dart';
import 'package:yaml/yaml.dart';

/// Represents SVGO configuration loaded from a file.
class SvgoFileConfig {
  /// Path to the configuration file that was loaded.
  final String? configPath;

  /// Enable multipass optimization.
  final bool multipass;

  /// Global float precision override.
  final int? floatPrecision;

  /// Output as data URI type.
  final DataUriType? datauri;

  /// List of plugin configurations.
  final List<PluginConfig> plugins;

  /// Stringification options.
  final StringifyOptions? js2svg;

  const SvgoFileConfig({
    this.configPath,
    this.multipass = false,
    this.floatPrecision,
    this.datauri,
    this.plugins = const [],
    this.js2svg,
  });

  /// Creates a default configuration.
  factory SvgoFileConfig.defaults() => const SvgoFileConfig();

  /// Converts this file config to an SvgoConfig.
  SvgoConfig toSvgoConfig() {
    // Build plugin list
    final resolvedPlugins = _resolvePlugins(plugins);

    return SvgoConfig(
      multipass: multipass,
      floatPrecision: floatPrecision,
      datauri: datauri,
      plugins: resolvedPlugins.isNotEmpty ? resolvedPlugins : null,
      js2svg: js2svg,
    );
  }

  /// Resolves plugin configurations to actual Plugin instances.
  List<Plugin> _resolvePlugins(List<PluginConfig> configs) {
    if (configs.isEmpty) return [];

    final result = <Plugin>[];
    for (final config in configs) {
      final plugin = _resolvePlugin(config);
      if (plugin != null) {
        result.add(plugin);
      }
    }
    return result;
  }

  /// Resolves a single plugin configuration to a Plugin instance.
  Plugin? _resolvePlugin(PluginConfig config) {
    // Handle disabled plugin
    if (!config.enabled) return null;

    // Find the builtin plugin by name
    final builtin = _findBuiltinPlugin(config.name);
    if (builtin == null) {
      stderr.writeln('Warning: Unknown plugin "${config.name}"');
      return null;
    }

    // If it's a preset, handle overrides
    if (builtin is PluginPreset) {
      return _resolvePreset(builtin, config.params);
    }

    // Apply custom params if provided
    if (config.params != null && config.params!.isNotEmpty) {
      final params = _createParams(builtin, config.params!);
      if (params != null) {
        return _createPluginWithParams(builtin, params);
      }
    }

    return builtin;
  }

  /// Resolves a preset plugin with overrides.
  Plugin _resolvePreset(PluginPreset preset, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return preset;

    final overrides = <String, Object?>{};
    int? floatPrecision;

    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'floatPrecision') {
        floatPrecision = value as int?;
        continue;
      }

      if (key == 'overrides' && value is Map) {
        // Handle overrides map
        for (final override in value.entries) {
          final pluginName = override.key.toString();
          final pluginConfig = override.value;

          if (pluginConfig == false) {
            overrides[pluginName] = false;
          } else if (pluginConfig is Map) {
            final builtinPlugin = _findBuiltinPlugin(pluginName);
            if (builtinPlugin != null) {
              final pluginParams = _createParams(
                builtinPlugin,
                Map<String, dynamic>.from(pluginConfig),
              );
              if (pluginParams != null) {
                overrides[pluginName] = pluginParams;
              }
            }
          }
        }
      }
    }

    return preset.withParams(PresetParams(
      floatPrecision: floatPrecision,
      overrides: overrides.isNotEmpty ? overrides : null,
    ));
  }

  /// Finds a builtin plugin by name.
  static Plugin? _findBuiltinPlugin(String name) {
    // Map of all builtin plugins
    return _builtinPluginMap[name];
  }

  /// Creates plugin parameters from a map.
  static PluginParams? _createParams(
    Plugin plugin,
    Map<String, dynamic> params,
  ) {
    return _pluginParamFactories[plugin.name]?.call(params);
  }

  /// Creates a plugin with custom parameters.
  static Plugin? _createPluginWithParams(Plugin plugin, PluginParams params) {
    // Use dynamic invocation since we need to preserve type safety
    try {
      return (plugin as dynamic).withParams(params);
    } catch (e) {
      stderr.writeln('Warning: Failed to apply params to "${plugin.name}": $e');
      return plugin;
    }
  }
}

/// Configuration for a single plugin.
class PluginConfig {
  /// The name of the plugin.
  final String name;

  /// Whether the plugin is enabled.
  final bool enabled;

  /// Plugin-specific parameters.
  final Map<String, dynamic>? params;

  const PluginConfig({
    required this.name,
    this.enabled = true,
    this.params,
  });

  @override
  String toString() =>
      'PluginConfig($name, enabled: $enabled, params: $params)';
}

/// Loads SVGO configuration from the current directory or parent directories.
///
/// Configuration is loaded in the following priority:
/// 1. svgo.yaml or svgo.yml in [directory] or parent directories
/// 2. pubspec.yaml with `svgo:` key in [directory] or parent directories
///
/// Returns null if no configuration file is found.
Future<SvgoFileConfig?> loadConfig([String? directory]) async {
  final searchDir = directory ?? Directory.current.path;
  return _searchConfig(searchDir);
}

/// Loads SVGO configuration from a specific file.
///
/// Throws [FileSystemException] if the file doesn't exist.
/// Throws [FormatException] if the file is invalid.
Future<SvgoFileConfig> loadConfigFromFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw FileSystemException('Configuration file not found', filePath);
  }

  final content = await file.readAsString();
  final yaml = loadYaml(content);

  if (yaml == null) {
    return SvgoFileConfig(configPath: filePath);
  }

  // Check if this is a pubspec.yaml
  final fileName = p.basename(filePath);
  if (fileName == 'pubspec.yaml' || fileName == 'pubspec.yml') {
    if (yaml is! Map || !yaml.containsKey('svgo')) {
      throw FormatException('No "svgo" key found in pubspec.yaml');
    }
    return _parseConfig(yaml['svgo'], filePath);
  }

  return _parseConfig(yaml, filePath);
}

/// Searches for a configuration file in the directory and parent directories.
Future<SvgoFileConfig?> _searchConfig(String directory) async {
  var currentDir = p.normalize(p.absolute(directory));
  final root = p.rootPrefix(currentDir);

  while (currentDir.length >= root.length) {
    // Check for svgo.yaml/svgo.yml first (priority)
    for (final name in ['svgo.yaml', 'svgo.yml']) {
      final configPath = p.join(currentDir, name);
      final file = File(configPath);
      if (await file.exists()) {
        try {
          return await loadConfigFromFile(configPath);
        } catch (e) {
          stderr.writeln('Warning: Failed to load $configPath: $e');
        }
      }
    }

    // Then check pubspec.yaml
    final pubspecPath = p.join(currentDir, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);
    if (await pubspecFile.exists()) {
      try {
        final content = await pubspecFile.readAsString();
        final yaml = loadYaml(content);
        if (yaml is Map && yaml.containsKey('svgo')) {
          return _parseConfig(yaml['svgo'], pubspecPath);
        }
      } catch (e) {
        // Ignore invalid pubspec, continue searching
      }
    }

    // Move to parent directory
    final parentDir = p.dirname(currentDir);
    if (parentDir == currentDir) break;
    currentDir = parentDir;
  }

  return null;
}

/// Parses SVGO configuration from a YAML map.
SvgoFileConfig _parseConfig(dynamic yaml, String configPath) {
  if (yaml == null) {
    return SvgoFileConfig(configPath: configPath);
  }

  if (yaml is! Map) {
    throw FormatException(
      'Invalid SVGO configuration: expected a map, got ${yaml.runtimeType}',
    );
  }

  // Parse basic options
  final multipass = yaml['multipass'] as bool? ?? false;
  final floatPrecision = yaml['floatPrecision'] as int?;

  // Parse datauri
  DataUriType? datauri;
  final datauriValue = yaml['datauri'];
  if (datauriValue != null) {
    datauri = _parseDataUriType(datauriValue.toString());
  }

  // Parse plugins
  final plugins = _parsePlugins(yaml['plugins']);

  // Parse js2svg / stringify options
  StringifyOptions? js2svg;
  final js2svgValue = yaml['js2svg'];
  if (js2svgValue is Map) {
    js2svg = _parseStringifyOptions(js2svgValue);
  }

  return SvgoFileConfig(
    configPath: configPath,
    multipass: multipass,
    floatPrecision: floatPrecision,
    datauri: datauri,
    plugins: plugins,
    js2svg: js2svg,
  );
}

/// Parses the plugins list from YAML.
List<PluginConfig> _parsePlugins(dynamic value) {
  if (value == null) return [];

  if (value is! List) {
    throw FormatException(
      'Invalid plugins configuration: expected a list, got ${value.runtimeType}',
    );
  }

  final plugins = <PluginConfig>[];
  for (final item in value) {
    final plugin = _parsePluginConfig(item);
    if (plugin != null) {
      plugins.add(plugin);
    }
  }
  return plugins;
}

/// Parses a single plugin configuration.
PluginConfig? _parsePluginConfig(dynamic value) {
  // String: just the plugin name
  if (value is String) {
    return PluginConfig(name: value);
  }

  // Map with single key: plugin name with params or enabled state
  if (value is Map && value.length == 1) {
    final name = value.keys.first.toString();
    final config = value.values.first;

    // `pluginName: false` - disabled plugin
    if (config == false) {
      return PluginConfig(name: name, enabled: false);
    }

    // `pluginName: true` - enabled plugin with defaults
    if (config == true) {
      return PluginConfig(name: name, enabled: true);
    }

    // `pluginName: { params }` - plugin with parameters
    if (config is Map) {
      return PluginConfig(
        name: name,
        enabled: config['enabled'] as bool? ?? true,
        params: Map<String, dynamic>.from(config),
      );
    }

    // Just the name
    return PluginConfig(name: name);
  }

  // Map with 'name' key
  if (value is Map && value.containsKey('name')) {
    final name = value['name'].toString();
    final enabled = value['enabled'] as bool? ?? true;

    // Remove 'name' and 'enabled' from params
    final params = Map<String, dynamic>.from(value)
      ..remove('name')
      ..remove('enabled');

    return PluginConfig(
      name: name,
      enabled: enabled,
      params: params.isNotEmpty ? params : null,
    );
  }

  stderr.writeln('Warning: Invalid plugin configuration: $value');
  return null;
}

/// Parses DataUriType from string.
DataUriType? _parseDataUriType(String value) {
  switch (value.toLowerCase()) {
    case 'base64':
      return DataUriType.base64;
    case 'enc':
      return DataUriType.enc;
    case 'unenc':
      return DataUriType.unenc;
    default:
      stderr.writeln('Warning: Unknown datauri type: $value');
      return null;
  }
}

/// Parses StringifyOptions from YAML map.
StringifyOptions _parseStringifyOptions(Map yaml) {
  EndOfLine eol = EndOfLine.lf;
  final eolValue = yaml['eol'];
  if (eolValue == 'crlf') {
    eol = EndOfLine.crlf;
  }

  return StringifyOptions(
    indent: yaml['indent'] ?? 4,
    useShortTags: yaml['useShortTags'] as bool? ?? true,
    pretty: yaml['pretty'] as bool? ?? false,
    eol: eol,
    finalNewline: yaml['finalNewline'] as bool? ?? false,
  );
}

// ============================================================================
// Builtin plugin mapping
// ============================================================================

/// Map of all builtin plugin names to their instances.
final _builtinPluginMap = <String, Plugin>{
  // Presets
  'preset-default': presetDefault,

  // Individual plugins
  'addAttributesToSVGElement': addAttributesToSVGElement,
  'addClassesToSVGElement': addClassesToSVGElement,
  'applyTransforms': applyTransforms,
  'cleanupAttrs': cleanupAttrs,
  'cleanupEnableBackground': cleanupEnableBackground,
  'cleanupIds': cleanupIds,
  'cleanupListOfValues': cleanupListOfValues,
  'cleanupNumericValues': cleanupNumericValues,
  'collapseGroups': collapseGroups,
  'convertColors': convertColors,
  'convertEllipseToCircle': convertEllipseToCircle,
  'convertOneStopGradients': convertOneStopGradients,
  'convertPathData': convertPathData,
  'convertShapeToPath': convertShapeToPath,
  'convertStyleToAttrs': convertStyleToAttrs,
  'convertTransform': convertTransform,
  'inlineStyles': inlineStyles,
  'mergePaths': mergePaths,
  'mergeStyles': mergeStyles,
  'minifyStyles': minifyStyles,
  'moveElemsAttrsToGroup': moveElemsAttrsToGroup,
  'moveGroupAttrsToElems': moveGroupAttrsToElems,
  'prefixIds': prefixIds,
  'removeAttrs': removeAttrs,
  'removeAttributesBySelector': removeAttributesBySelector,
  'removeComments': removeComments,
  'removeDeprecatedAttrs': removeDeprecatedAttrs,
  'removeDesc': removeDesc,
  'removeDimensions': removeDimensions,
  'removeDoctype': removeDoctype,
  'removeEditorsNSData': removeEditorsNSData,
  'removeElementsByAttr': removeElementsByAttr,
  'removeEmptyAttrs': removeEmptyAttrs,
  'removeEmptyContainers': removeEmptyContainers,
  'removeEmptyText': removeEmptyText,
  'removeHiddenElems': removeHiddenElems,
  'removeMetadata': removeMetadata,
  'removeNonInheritableGroupAttrs': removeNonInheritableGroupAttrs,
  'removeOffCanvasPaths': removeOffCanvasPaths,
  'removeRasterImages': removeRasterImages,
  'removeScripts': removeScripts,
  'removeStyleElement': removeStyleElement,
  'removeTitle': removeTitle,
  'removeUnknownsAndDefaults': removeUnknownsAndDefaults,
  'removeUnusedNS': removeUnusedNS,
  'removeUselessDefs': removeUselessDefs,
  'removeUselessStrokeAndFill': removeUselessStrokeAndFill,
  'removeViewBox': removeViewBox,
  'removeXlink': removeXlink,
  'removeXMLProcInst': removeXMLProcInst,
  'removeXMLNS': removeXMLNS,
  'reusePaths': reusePaths,
  'sortAttrs': sortAttrs,
  'sortDefsChildren': sortDefsChildren,
};

/// Factory functions for creating plugin parameters from maps.
final _pluginParamFactories =
    <String, PluginParams Function(Map<String, dynamic>)>{
  'cleanupIds': (params) => CleanupIdsParams(
        remove: params['remove'] as bool? ?? true,
        minify: params['minify'] as bool? ?? true,
        preserve: _parseStringList(params['preserve']),
        preservePrefixes: _parseStringList(params['preservePrefixes']),
        force: params['force'] as bool? ?? false,
      ),
  'cleanupNumericValues': (params) => CleanupNumericValuesParams(
        floatPrecision: params['floatPrecision'] as int? ?? 3,
        leadingZero: params['leadingZero'] as bool? ?? true,
        defaultPx: params['defaultPx'] as bool? ?? true,
        convertToPx: params['convertToPx'] as bool? ?? true,
      ),
  'cleanupListOfValues': (params) => CleanupListOfValuesParams(
        floatPrecision: params['floatPrecision'] as int? ?? 3,
        leadingZero: params['leadingZero'] as bool? ?? true,
        defaultPx: params['defaultPx'] as bool? ?? true,
      ),
  'convertColors': (params) => _createConvertColorsParams(params),
  'convertPathData': (params) => _createConvertPathDataParams(params),
  'convertTransform': (params) => ConvertTransformParams(
        floatPrecision: params['floatPrecision'] as int? ?? 3,
        transformPrecision: params['transformPrecision'] as int? ?? 5,
        matrixToTransform: params['matrixToTransform'] as bool? ?? true,
        shortTranslate: params['shortTranslate'] as bool? ?? true,
        shortScale: params['shortScale'] as bool? ?? true,
        shortRotate: params['shortRotate'] as bool? ?? true,
        removeUseless: params['removeUseless'] as bool? ?? true,
        collapseIntoOne: params['collapseIntoOne'] as bool? ?? true,
        leadingZero: params['leadingZero'] as bool? ?? true,
        negativeExtraSpace: params['negativeExtraSpace'] as bool? ?? false,
      ),
  'inlineStyles': (params) => InlineStylesParams(
        onlyMatchedOnce: params['onlyMatchedOnce'] as bool? ?? true,
        removeMatchedSelectors:
            params['removeMatchedSelectors'] as bool? ?? true,
        useMqs: _parseStringList(params['useMqs']),
        usePseudos: _parseStringList(params['usePseudos']),
      ),
  'mergePaths': (params) => MergePathsParams(
        force: params['force'] as bool? ?? false,
        floatPrecision: params['floatPrecision'] as int? ?? 3,
        noSpaceAfterFlags: params['noSpaceAfterFlags'] as bool? ?? false,
      ),
  'minifyStyles': (params) => MinifyStylesParams(
        restructure: params['restructure'] as bool? ?? true,
        removeComments: params['removeComments'] as bool? ?? true,
        usage: _parseMinifyStylesUsage(params['usage']),
      ),
  'prefixIds': (params) => PrefixIdsParams(
        delim: params['delim'] as String? ?? '__',
        prefix: params['prefix'] as String?,
        prefixIds: params['prefixIds'] as bool? ?? true,
        prefixClassNames: params['prefixClassNames'] as bool? ?? true,
      ),
  'removeAttrs': (params) => RemoveAttrsParams(
        elemSeparator: params['elemSeparator'] as String? ?? ':',
        preserveCurrentColor: params['preserveCurrentColor'] as bool? ?? false,
        attrs: _parseStringList(params['attrs']),
      ),
  'removeAttributesBySelector': (params) {
    final selectors = params['selectors'];
    if (selectors is! List) {
      return const RemoveAttributesBySelectorParams(selectors: []);
    }
    final selectorList = <SelectorAttributesPair>[];
    for (final item in selectors) {
      if (item is Map) {
        selectorList.add(SelectorAttributesPair(
          selector: item['selector'] as String? ?? '',
          attributes: _parseStringList(item['attributes']),
        ));
      }
    }
    return RemoveAttributesBySelectorParams(selectors: selectorList);
  },
  'removeDesc': (params) => RemoveDescParams(
        removeAny: params['removeAny'] as bool? ?? true,
      ),
  'removeElementsByAttr': (params) => RemoveElementsByAttrParams(
        id: _parseStringList(params['id']),
        className: _parseStringList(params['class'] ?? params['className']),
      ),
  'removeHiddenElems': (params) => RemoveHiddenElemsParams(
        isHidden: params['isHidden'] as bool? ?? true,
        displayNone: params['displayNone'] as bool? ?? true,
        opacity0: params['opacity0'] as bool? ?? true,
        circleR0: params['circleR0'] as bool? ?? true,
        ellipseRX0: params['ellipseRX0'] as bool? ?? true,
        ellipseRY0: params['ellipseRY0'] as bool? ?? true,
        rectWidth0: params['rectWidth0'] as bool? ?? true,
        rectHeight0: params['rectHeight0'] as bool? ?? true,
        patternWidth0: params['patternWidth0'] as bool? ?? true,
        patternHeight0: params['patternHeight0'] as bool? ?? true,
        imageWidth0: params['imageWidth0'] as bool? ?? true,
        imageHeight0: params['imageHeight0'] as bool? ?? true,
        pathEmptyD: params['pathEmptyD'] as bool? ?? true,
        polylineEmptyPoints: params['polylineEmptyPoints'] as bool? ?? true,
        polygonEmptyPoints: params['polygonEmptyPoints'] as bool? ?? true,
      ),
  'removeUnknownsAndDefaults': (params) => RemoveUnknownsAndDefaultsParams(
        unknownContent: params['unknownContent'] as bool? ?? true,
        unknownAttrs: params['unknownAttrs'] as bool? ?? true,
        defaultAttrs: params['defaultAttrs'] as bool? ?? true,
        defaultMarkupDeclarations:
            params['defaultMarkupDeclarations'] as bool? ?? true,
        uselessOverrides: params['uselessOverrides'] as bool? ?? true,
        keepDataAttrs: params['keepDataAttrs'] as bool? ?? true,
        keepAriaAttrs: params['keepAriaAttrs'] as bool? ?? true,
        keepRoleAttr: params['keepRoleAttr'] as bool? ?? false,
      ),
  'removeUselessStrokeAndFill': (params) => RemoveUselessStrokeAndFillParams(
        stroke: params['stroke'] as bool? ?? true,
        fill: params['fill'] as bool? ?? true,
        removeNone: params['removeNone'] as bool? ?? false,
      ),
  'sortAttrs': (params) => SortAttrsParams(
        order: _parseStringList(params['order']),
        xmlnsOrder: _parseXmlnsOrder(params['xmlnsOrder']),
      ),
  'addAttributesToSVGElement': (params) => AddAttributesToSVGElementParams(
        attributes: _parseAttributeList(params['attributes']),
      ),
  'addClassesToSVGElement': (params) => AddClassesToSVGElementParams(
        classNames: _parseStringList(params['classNames']),
      ),
  'convertShapeToPath': (params) => ConvertShapeToPathParams(
        convertArcs: params['convertArcs'] as bool? ?? false,
        floatPrecision: params['floatPrecision'] as int? ?? 3,
      ),
  'removeComments': (params) => RemoveCommentsParams(
        preservePatterns: _parseRegExpList(params['preservePatterns']),
      ),
  'removeEditorsNSData': (params) => RemoveEditorsNSDataParams(
        additionalNamespaces: _parseStringList(params['additionalNamespaces']),
      ),
  'removeEmptyText': (params) => RemoveEmptyTextParams(
        text: params['text'] as bool? ?? true,
        tspan: params['tspan'] as bool? ?? true,
        tref: params['tref'] as bool? ?? true,
      ),
  'removeXlink': (params) => RemoveXlinkParams(
        includeLegacy: params['includeLegacy'] as bool? ?? false,
      ),
  'cleanupAttrs': (params) => CleanupAttrsParams(
        newlines: params['newlines'] as bool? ?? true,
        trim: params['trim'] as bool? ?? true,
        spaces: params['spaces'] as bool? ?? true,
      ),
  'removeDeprecatedAttrs': (params) => RemoveDeprecatedAttrsParams(
        removeUnsafe: params['removeUnsafe'] as bool? ?? false,
      ),
};

/// Parses a list of strings from various input formats.
List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is String) return [value];
  if (value is List) return value.map((e) => e.toString()).toList();
  return [];
}

/// Parses a list of RegExp patterns.
List<RegExp> _parseRegExpList(dynamic value) {
  final strings = _parseStringList(value);
  return strings.map((s) => RegExp(s)).toList();
}

/// Parses attributes list for addAttributesToSVGElement.
/// Supports both string attributes and map attributes.
List<Object> _parseAttributeList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    final result = <Object>[];
    for (final item in value) {
      if (item is String) {
        result.add(item);
      } else if (item is Map) {
        result.add(Map<String, String?>.from(
          item.map((k, v) => MapEntry(k.toString(), v?.toString())),
        ));
      }
    }
    return result;
  }
  if (value is Map) {
    return [
      Map<String, String?>.from(
        value.map((k, v) => MapEntry(k.toString(), v?.toString())),
      ),
    ];
  }
  return [];
}

/// Parses XmlnsOrder enum from string.
XmlnsOrder _parseXmlnsOrder(dynamic value) {
  if (value == null) return XmlnsOrder.front;
  final str = value.toString().toLowerCase();
  if (str == 'alphabetical') return XmlnsOrder.alphabetical;
  return XmlnsOrder.front;
}

/// Parses MinifyStylesUsage from YAML value.
MinifyStylesUsage _parseMinifyStylesUsage(dynamic value) {
  if (value == null) return const MinifyStylesUsage();
  if (value is bool) {
    // If value is a boolean, treat as whether usage analysis is enabled
    return value
        ? const MinifyStylesUsage()
        : const MinifyStylesUsage(
            tags: false,
            ids: false,
            classes: false,
          );
  }
  if (value is Map) {
    return MinifyStylesUsage(
      tags: value['tags'] as bool? ?? true,
      ids: value['ids'] as bool? ?? true,
      classes: value['classes'] as bool? ?? true,
      force: value['force'] as bool? ?? false,
    );
  }
  return const MinifyStylesUsage();
}

/// Creates ConvertColorsParams from a map.
ConvertColorsParams _createConvertColorsParams(Map<String, dynamic> params) {
  CurrentColorConfig currentColor = const CurrentColorDisabled();
  final currentColorValue = params['currentColor'];
  if (currentColorValue == true) {
    currentColor = const CurrentColorEnabled();
  } else if (currentColorValue is String) {
    currentColor = CurrentColorExact(currentColorValue);
  } else if (currentColorValue is Map && currentColorValue['regex'] != null) {
    currentColor =
        CurrentColorPattern(RegExp(currentColorValue['regex'].toString()));
  }

  ConvertColorsCase convertCase = ConvertColorsCase.lower;
  final caseValue = params['convertCase'] ?? params['case'];
  if (caseValue == 'upper') {
    convertCase = ConvertColorsCase.upper;
  } else if (caseValue == 'none' || caseValue == false) {
    convertCase = ConvertColorsCase.none;
  }

  return ConvertColorsParams(
    currentColor: currentColor,
    names2hex: params['names2hex'] as bool? ?? true,
    rgb2hex: params['rgb2hex'] as bool? ?? true,
    convertCase: convertCase,
    shorthex: params['shorthex'] as bool? ?? true,
    shortname: params['shortname'] as bool? ?? true,
  );
}

/// Creates ConvertPathDataParams from a map.
ConvertPathDataParams _createConvertPathDataParams(
    Map<String, dynamic> params) {
  MakeArcsConfig? makeArcs;
  final makeArcsValue = params['makeArcs'];
  if (makeArcsValue == true) {
    makeArcs = const MakeArcsConfig();
  } else if (makeArcsValue is Map) {
    makeArcs = MakeArcsConfig(
      threshold: (makeArcsValue['threshold'] as num?)?.toDouble() ?? 2.5,
      tolerance: (makeArcsValue['tolerance'] as num?)?.toDouble() ?? 0.5,
    );
  }

  return ConvertPathDataParams(
    applyTransforms: params['applyTransforms'] as bool? ?? true,
    applyTransformsStroked: params['applyTransformsStroked'] as bool? ?? true,
    makeArcs: makeArcs,
    straightCurves: params['straightCurves'] as bool? ?? true,
    convertToQ: params['convertToQ'] as bool? ?? true,
    lineShorthands: params['lineShorthands'] as bool? ?? true,
    convertToZ: params['convertToZ'] as bool? ?? true,
    curveSmoothShorthands: params['curveSmoothShorthands'] as bool? ?? true,
    floatPrecision: params['floatPrecision'] as int? ?? 3,
    transformPrecision: params['transformPrecision'] as int? ?? 5,
    removeUseless: params['removeUseless'] as bool? ?? true,
    collapseRepeated: params['collapseRepeated'] as bool? ?? true,
    utilizeAbsolute: params['utilizeAbsolute'] as bool? ?? true,
    leadingZero: params['leadingZero'] as bool? ?? true,
    negativeExtraSpace: params['negativeExtraSpace'] as bool? ?? true,
    noSpaceAfterFlags: params['noSpaceAfterFlags'] as bool? ?? false,
    forceAbsolutePath: params['forceAbsolutePath'] as bool? ?? false,
  );
}
