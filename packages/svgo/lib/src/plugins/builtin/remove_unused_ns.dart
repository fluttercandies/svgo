/// Remove unused namespaces plugin.
///
/// Removes unused namespace declarations from the svg element.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes unused namespace declarations from the svg element.
///
/// Detects namespace declarations (xmlns:*) that are not used in any
/// element names or attributes and removes them.
///
/// Example input:
/// ```xml
/// <svg xmlns:xlink="http://www.w3.org/1999/xlink"
///      xmlns:foo="http://example.com/foo">
///   <image xlink:href="image.png"/>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg xmlns:xlink="http://www.w3.org/1999/xlink">
///   <image xlink:href="image.png"/>
/// </svg>
/// ```
const removeUnusedNS = Plugin<EmptyParams>(
  name: 'removeUnusedNS',
  description: 'removes unused namespaces declaration',
  defaultParams: EmptyParams(),
  fn: _removeUnusedNSFn,
);

Visitor? _removeUnusedNSFn(XastRoot ast, EmptyParams params, SvgoInfo info) {
  final unusedNamespaces = <String>{};

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Collect all namespaces from svg element
        if (node.name == 'svg' && parentNode is XastRoot) {
          for (final name in node.attributes.keys) {
            if (name.startsWith('xmlns:')) {
              final local = name.substring('xmlns:'.length);
              unusedNamespaces.add(local);
            }
          }
        }

        if (unusedNamespaces.isNotEmpty) {
          // Preserve namespace used in nested element names
          if (node.name.contains(':')) {
            final ns = node.name.split(':').first;
            unusedNamespaces.remove(ns);
          }

          // Preserve namespace used in nested element attributes
          for (final name in node.attributes.keys) {
            if (name.contains(':')) {
              final ns = name.split(':').first;
              unusedNamespaces.remove(ns);
            }
          }
        }
        return null;
      },
      exit: (node, parentNode) {
        // Remove unused namespace attributes from svg element
        if (node.name == 'svg' && parentNode is XastRoot) {
          for (final name in unusedNamespaces) {
            node.attributes.remove('xmlns:$name');
          }
        }
        return;
      },
    ),
  );
}
