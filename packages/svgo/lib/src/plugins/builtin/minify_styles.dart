/// Minify styles plugin.
///
/// Minifies styles in style elements and style attributes using csslib.
library;

import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css_visitor;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../../xast/xast_utils.dart';
import '../plugin.dart';

/// Minifies styles in style elements and style attributes.
///
/// This plugin minifies CSS content in <style> elements and style
/// attributes by removing unnecessary whitespace and optimizing values.
///
/// **Example:**
/// ```xml
/// <!-- Before -->
/// <svg>
///   <style>
///     .foo {
///       fill: #ff0000;
///       stroke: #00ff00;
///     }
///   </style>
///   <rect style="fill: red;   stroke: blue;"/>
/// </svg>
///
/// <!-- After -->
/// <svg>
///   <style>.foo{fill:red;stroke:#0f0}</style>
///   <rect style="fill:red;stroke:blue"/>
/// </svg>
/// ```
///
/// Parameters:
/// - `restructure`: Enable structure optimizations (default: true)
/// - `removeComments`: Remove CSS comments (default: true)
/// - `usage`: Usage data for dead code elimination (default: true)
///   - Can be boolean or object with tags, ids, classes fields
///   - force: Force usage data even if scripts detected (default: false)
const minifyStyles = Plugin(
  name: 'minifyStyles',
  description: 'minifies styles and removes unused styles',
  params: {
    'restructure': true,
    'removeComments': true,
    'usage': true,
  },
  fn: _minifyStylesFn,
);

Visitor? _minifyStylesFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final removeComments = params['removeComments'] as bool? ?? true;
  final usage = params['usage'];

  // Parse usage options
  var enableTagsUsage = true;
  var enableIdsUsage = true;
  var enableClassesUsage = true;
  var forceUsageDeoptimized = false;

  if (usage is bool) {
    enableTagsUsage = usage;
    enableIdsUsage = usage;
    enableClassesUsage = usage;
  } else if (usage is Map) {
    enableTagsUsage = usage['tags'] as bool? ?? true;
    enableIdsUsage = usage['ids'] as bool? ?? true;
    enableClassesUsage = usage['classes'] as bool? ?? true;
    forceUsageDeoptimized = usage['force'] as bool? ?? false;
  }

  // Collect style elements and elements with style attributes
  final styleElements = <(XastElement, XastParent)>[];
  final elementsWithStyle = <XastElement>[];

  // Usage tracking
  final tagsUsage = <String>{};
  final idsUsage = <String>{};
  final classesUsage = <String>{};
  var deoptimized = false;

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Detect scripts that could dynamically modify styles
        if (_hasScripts(node)) {
          deoptimized = true;
        }

        // Collect usage data
        tagsUsage.add(node.name);
        final id = node.attributes['id'];
        if (id != null) {
          idsUsage.add(id);
        }
        final classAttr = node.attributes['class'];
        if (classAttr != null) {
          for (final className in classAttr.split(RegExp(r'\s+'))) {
            if (className.isNotEmpty) {
              classesUsage.add(className);
            }
          }
        }

        // Collect style elements and elements with style attributes
        if (node.name == 'style' && node.children.isNotEmpty) {
          if (parentNode != null) {
            styleElements.add((node, parentNode));
          }
        } else if (node.attributes.containsKey('style')) {
          elementsWithStyle.add(node);
        }
        return null;
      },
    ),
    root: VisitorRoot(
      exit: (node) {
        // Build usage data for optimization
        final usageData = <String, Set<String>>{};
        if (!deoptimized || forceUsageDeoptimized) {
          if (enableTagsUsage) usageData['tags'] = tagsUsage;
          if (enableIdsUsage) usageData['ids'] = idsUsage;
          if (enableClassesUsage) usageData['classes'] = classesUsage;
        }

        // Minify style elements
        for (final (styleNode, styleParent) in styleElements) {
          if (styleNode.children.isEmpty) continue;

          final firstChild = styleNode.children.first;
          String cssText;
          if (firstChild is XastText) {
            cssText = firstChild.value;
          } else if (firstChild is XastCdata) {
            cssText = firstChild.value;
          } else {
            continue;
          }

          final minified = _minifyCssWithCsslib(
            cssText,
            removeComments: removeComments,
            usageData: usageData,
          );

          if (minified.isEmpty) {
            detachNodeFromParent(styleNode, styleParent);
            continue;
          }

          // Preserve CDATA if necessary (contains < or >)
          if (cssText.contains('<') || cssText.contains('>')) {
            if (firstChild is XastCdata) {
              firstChild.value = minified;
            } else {
              styleNode.children[0] = XastCdata(value: minified);
            }
          } else {
            if (firstChild is XastText) {
              firstChild.value = minified;
            } else {
              styleNode.children[0] = XastText(value: minified);
            }
          }
        }

        // Minify style attributes
        for (final element in elementsWithStyle) {
          final style = element.attributes['style'];
          if (style != null && style.isNotEmpty) {
            element.attributes['style'] = _minifyStyleDeclarations(style);
          }
        }

        return;
      },
    ),
  );
}

/// Checks if an element has scripts.
bool _hasScripts(XastElement element) {
  // Check for script elements
  if (element.name == 'script') return true;

  // Check for event handler attributes
  for (final attr in element.attributes.keys) {
    if (attr.startsWith('on')) return true;
  }

  // Check for href with javascript:
  final href = element.attributes['href'] ?? element.attributes['xlink:href'];
  if (href != null && href.startsWith('javascript:')) return true;

  return false;
}

/// Minifies CSS stylesheet content using csslib.
String _minifyCssWithCsslib(
  String css, {
  required bool removeComments,
  Map<String, Set<String>>? usageData,
}) {
  try {
    // Parse with csslib
    final stylesheet = css_parser.parse(css);

    // Remove unused rules if usage data is available
    if (usageData != null && usageData.isNotEmpty) {
      _removeUnusedRules(stylesheet, usageData);
    }

    // Print back to string (compact mode)
    final printer = css_visitor.CssPrinter();
    printer.visitTree(stylesheet, pretty: false);
    var result = printer.toString();

    // Additional optimizations
    result = _optimizeColors(result);
    result = _optimizeFontFamily(result);

    return result.trim();
  } catch (_) {
    // Fallback to regex-based minification if csslib fails
    return _minifyCss(css, removeComments: removeComments);
  }
}

/// Removes unused rules from stylesheet based on usage data.
void _removeUnusedRules(
  css_visitor.StyleSheet stylesheet,
  Map<String, Set<String>> usageData,
) {
  final tags = usageData['tags'] ?? {};
  final ids = usageData['ids'] ?? {};
  final classes = usageData['classes'] ?? {};

  // Filter out unused rules
  stylesheet.topLevels.removeWhere((topLevel) {
    if (topLevel is css_visitor.RuleSet) {
      final selectorGroup = topLevel.selectorGroup;
      if (selectorGroup == null) return false;

      // Check if all selectors are unused
      for (final selector in selectorGroup.selectors) {
        if (_selectorIsUsed(selector, tags, ids, classes)) {
          return false; // Keep rule, at least one selector is used
        }
      }
      return true; // Remove rule, all selectors are unused
    }
    return false;
  });
}

/// Checks if a selector matches any used element.
bool _selectorIsUsed(
  css_visitor.Selector selector,
  Set<String> tags,
  Set<String> ids,
  Set<String> classes,
) {
  for (final seq in selector.simpleSelectorSequences) {
    final simple = seq.simpleSelector;

    if (simple is css_visitor.ElementSelector) {
      if (simple.name != '*' && !tags.contains(simple.name)) {
        return false;
      }
    } else if (simple is css_visitor.IdSelector) {
      if (!ids.contains(simple.name)) {
        return false;
      }
    } else if (simple is css_visitor.ClassSelector) {
      if (!classes.contains(simple.name)) {
        return false;
      }
    }
  }
  return true;
}

/// Minifies CSS stylesheet content.
String _minifyCss(String css, {required bool removeComments}) {
  var result = css;

  // Remove comments
  if (removeComments) {
    result = result.replaceAll(RegExp(r'/\*[^*]*\*+([^/*][^*]*\*+)*/'), '');
  }

  // Remove newlines and extra spaces
  result = result.replaceAll(RegExp(r'\s+'), ' ');

  // Remove spaces around punctuation
  result = result.replaceAll(RegExp(r'\s*([{};:,>+~])\s*'), r'$1');

  // Remove spaces in selectors
  result = result.replaceAll(RegExp(r'\s*,\s*'), ',');

  // Remove last semicolon in declaration block
  result = result.replaceAll(RegExp(r';(\s*})'), r'$1');

  // Remove leading/trailing spaces from rules
  result = result.replaceAll(RegExp(r'{\s*'), '{');
  result = result.replaceAll(RegExp(r'\s*}'), '}');

  // Optimize colors
  result = _optimizeColors(result);

  // Remove quotes around font-family when not needed
  result = _optimizeFontFamily(result);

  // Trim
  result = result.trim();

  return result;
}

/// Minifies style declarations (for style attribute).
String _minifyStyleDeclarations(String style) {
  var result = style;

  // Remove extra whitespace
  result = result.replaceAll(RegExp(r'\s+'), ' ');

  // Remove spaces around colon and semicolon
  result = result.replaceAll(RegExp(r'\s*:\s*'), ':');
  result = result.replaceAll(RegExp(r'\s*;\s*'), ';');

  // Remove trailing semicolon
  result = result.replaceAll(RegExp(r';$'), '');

  // Optimize colors
  result = _optimizeColors(result);

  // Trim
  result = result.trim();

  return result;
}

/// Optimizes color values in CSS.
String _optimizeColors(String css) {
  var result = css;

  // Convert rgb() to hex
  result = result.replaceAllMapped(
    RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)'),
    (m) {
      final r = int.parse(m.group(1)!);
      final g = int.parse(m.group(2)!);
      final b = int.parse(m.group(3)!);
      return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
    },
  );

  // Convert #rrggbb to #rgb when possible
  result = result.replaceAllMapped(
    RegExp(r'#([0-9a-fA-F])\1([0-9a-fA-F])\2([0-9a-fA-F])\3\b'),
    (m) => '#${m.group(1)}${m.group(2)}${m.group(3)}',
  );

  // Convert color names to shorter hex values
  const colorMap = {
    'white': '#fff',
    'black': '#000',
    'red': '#f00',
    'green': '#0f0',
    'blue': '#00f',
    'yellow': '#ff0',
    'cyan': '#0ff',
    'magenta': '#f0f',
    'fuchsia': '#f0f',
    'aqua': '#0ff',
  };

  for (final entry in colorMap.entries) {
    result = result.replaceAll(
      RegExp('(^|[^a-zA-Z])${entry.key}([^a-zA-Z]|\$)', caseSensitive: false),
      '\$1${entry.value}\$2',
    );
  }

  // Convert longer hex to shorter when color name is shorter
  const hexToName = {
    '#808080': 'gray',
    '#f5f5dc': 'beige',
    '#ff6347': 'tomato',
    '#ffd700': 'gold',
    '#ffa500': 'orange',
    '#da70d6': 'orchid',
    '#800000': 'maroon',
    '#000080': 'navy',
    '#808000': 'olive',
    '#ffc0cb': 'pink',
    '#800080': 'purple',
    '#c0c0c0': 'silver',
    '#008080': 'teal',
    '#ee82ee': 'violet',
    '#f5deb3': 'wheat',
  };

  for (final entry in hexToName.entries) {
    if (entry.key.length > entry.value.length) {
      result = result.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }
  }

  return result;
}

/// Optimizes font-family declarations.
String _optimizeFontFamily(String css) {
  // Remove quotes around single-word font names
  return css.replaceAllMapped(
    RegExp(r'''font-family\s*:\s*["']([a-zA-Z0-9-]+)["']'''),
    (m) => 'font-family:${m.group(1)}',
  );
}
