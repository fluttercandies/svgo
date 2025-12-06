/// Remove editors namespace data plugin.
///
/// Removes editor-specific namespaces, elements, and attributes from SVG.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../collections/collections.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes editor-specific namespaces, elements, and attributes.
///
/// Removes data added by SVG editors like Adobe Illustrator, Inkscape, etc.
///
/// Example input:
/// ```xml
/// <svg xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd">
///   <sodipodi:namedview/>
///   <path sodipodi:nodetypes="cccc"/>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>
///   <path/>
/// </svg>
/// ```
///
/// Parameters:
/// - `additionalNamespaces`: Additional namespace URIs to remove.
const removeEditorsNSData = Plugin(
  name: 'removeEditorsNSData',
  description: 'removes editors namespaces, elements and attributes',
  params: {
    'additionalNamespaces': <String>[],
  },
  fn: _removeEditorsNSDataFn,
);

Visitor? _removeEditorsNSDataFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  var namespaces = Set<String>.from(editorNamespaces);

  final additionalNamespaces = params['additionalNamespaces'];
  if (additionalNamespaces is List) {
    for (final ns in additionalNamespaces) {
      namespaces.add(ns.toString());
    }
  }

  final prefixes = <String>[];

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Collect namespace prefixes from svg element
        if (node.name == 'svg') {
          final attrsToRemove = <String>[];
          for (final entry in node.attributes.entries) {
            if (entry.key.startsWith('xmlns:') &&
                namespaces.contains(entry.value)) {
              prefixes.add(entry.key.substring('xmlns:'.length));
              attrsToRemove.add(entry.key);
            }
          }
          for (final name in attrsToRemove) {
            node.attributes.remove(name);
          }
        }

        // Remove editor attributes, e.g. <* sodipodi:*="">
        final attrsToRemove = <String>[];
        for (final name in node.attributes.keys) {
          if (name.contains(':')) {
            final prefix = name.split(':').first;
            if (prefixes.contains(prefix)) {
              attrsToRemove.add(name);
            }
          }
        }
        for (final name in attrsToRemove) {
          node.attributes.remove(name);
        }

        // Remove editor elements, e.g. <sodipodi:*>
        if (node.name.contains(':')) {
          final prefix = node.name.split(':').first;
          if (prefixes.contains(prefix)) {
            detachNodeFromParent(node, parentNode);
          }
        }
        return null;
      },
    ),
  );
}
