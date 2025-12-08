/// Reuse paths plugin.
///
/// Finds duplicate paths and converts them to use elements.
library;

import '../../style/style.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Finds `<path>` elements with the same d, fill, and stroke, and converts
/// them to `<use>` elements referencing a single `<path>` def.
///
/// This plugin identifies duplicate paths and creates a shared definition
/// in `<defs>`, replacing duplicates with `<use>` references to reduce
/// SVG file size.
///
/// **Example:**
/// ```xml
/// <!-- Before -->
/// <svg>
///   <path d="M0 0L10 10" fill="red"/>
///   <path d="M0 0L10 10" fill="red"/>
/// </svg>
///
/// <!-- After -->
/// <svg xmlns:xlink="http://www.w3.org/1999/xlink">
///   <defs>
///     <path id="reuse-0" d="M0 0L10 10" fill="red"/>
///   </defs>
///   <use xlink:href="#reuse-0"/>
///   <use xlink:href="#reuse-0"/>
/// </svg>
/// ```
const reusePaths = Plugin<EmptyParams>(
  name: 'reusePaths',
  description:
      'Finds <path> elements with the same d, fill, and stroke, and converts them to <use> elements',
  defaultParams: EmptyParams(),
  fn: _reusePathsFn,
);

Visitor? _reusePathsFn(XastRoot ast, EmptyParams params, SvgoInfo info) {
  final stylesheet = collectStylesheet(ast);

  // Map of path signature to list of path elements
  final paths = <String, List<XastElement>>{};

  // Reference to the first defs element
  XastElement? svgDefs;
  XastElement? svgElement;

  // Set of hrefs that reference the id of another node
  final hrefs = <String>{};

  // First pass: collect paths and hrefs
  visit(ast, Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Collect paths
        if (node.name == 'path' && node.attributes['d'] != null) {
          final d = node.attributes['d']!;
          final fill = node.attributes['fill'] ?? '';
          final stroke = node.attributes['stroke'] ?? '';
          final key = '$d;s:$stroke;f:$fill';

          paths.putIfAbsent(key, () => []).add(node);
        }

        // Find SVG element
        if (node.name == 'svg' && parentNode is XastRoot) {
          svgElement = node;
        }

        // Find existing defs element
        if (svgDefs == null &&
            node.name == 'defs' &&
            parentNode is XastElement &&
            parentNode.name == 'svg') {
          svgDefs = node;
        }

        // Collect hrefs
        if (node.name == 'use') {
          for (final name in ['href', 'xlink:href']) {
            final href = node.attributes[name];
            if (href != null && href.startsWith('#') && href.length > 1) {
              hrefs.add(href.substring(1));
            }
          }
        }

        return null;
      },
    ),
  ));

  if (svgElement == null) {
    return null;
  }

  // Create defs if needed
  var defsTag = svgDefs;
  defsTag ??= XastElement(
    name: 'defs',
    attributes: {},
    children: [],
  );

  var index = 0;
  for (final list in paths.values) {
    if (list.length > 1) {
      // Create reusable path
      final reusablePath = XastElement(
        name: 'path',
        attributes: {},
        children: [],
      );

      // Copy fill, stroke, and d from the first path
      for (final attr in ['fill', 'stroke', 'd']) {
        if (list[0].attributes.containsKey(attr)) {
          reusablePath.attributes[attr] = list[0].attributes[attr]!;
        }
      }

      // Determine the ID
      final originalId = list[0].attributes['id'];
      if (originalId == null ||
          hrefs.contains(originalId) ||
          stylesheet.rules.any((rule) => rule.selector == '#$originalId')) {
        reusablePath.attributes['id'] = 'reuse-$index';
        index++;
      } else {
        reusablePath.attributes['id'] = originalId;
        list[0].attributes.remove('id');
      }

      defsTag.children.add(reusablePath);

      // Convert paths to <use>
      for (final pathNode in list) {
        pathNode.attributes.remove('d');
        pathNode.attributes.remove('stroke');
        pathNode.attributes.remove('fill');

        // Convert path to use
        pathNode.name = 'use';
        pathNode.attributes['xlink:href'] = '#${reusablePath.attributes['id']}';
      }
    }
  }

  // Add defs if it has children
  if (defsTag.children.isNotEmpty) {
    if (!svgElement!.attributes.containsKey('xmlns:xlink')) {
      svgElement!.attributes['xmlns:xlink'] = 'http://www.w3.org/1999/xlink';
    }

    if (svgDefs == null) {
      svgElement!.children.insert(0, defsTag);
    }
  }

  return null;
}
