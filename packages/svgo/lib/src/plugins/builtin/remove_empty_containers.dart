/// Remove empty containers plugin.
///
/// Removes empty container elements from SVG documents.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../collections/collections.dart';
import '../../style/style.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes empty container elements.
///
/// @see https://www.w3.org/TR/SVG11/intro.html#TermContainerElement
///
/// Example input:
/// ```xml
/// <svg>
///   <defs/>
///   <g><marker><a/></marker></g>
///   <rect/>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>
///   <rect/>
/// </svg>
/// ```
const removeEmptyContainers = Plugin(
  name: 'removeEmptyContainers',
  description: 'removes empty container elements',
  fn: _removeEmptyContainersFn,
);

Visitor? _removeEmptyContainersFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  final stylesheet = collectStylesheet(ast);

  return Visitor(
    element: VisitorNode(
      exit: (node, parentNode) {
        // Don't remove <svg> or non-container elements
        if (node.name == 'svg' ||
            !ElemsGroups.container.contains(node.name) ||
            node.children.isNotEmpty) {
          return;
        }

        // Empty <pattern> may contain reusable configuration
        if (node.name == 'pattern' && node.attributes.isNotEmpty) {
          return;
        }

        // Empty <mask> hides masked element
        if (node.name == 'mask' && node.attributes.containsKey('id')) {
          return;
        }

        // Don't remove from <switch> elements
        if (parentNode is XastElement && parentNode.name == 'switch') {
          return;
        }

        // The <g> may not have content, but the filter may cause a rectangle
        // to be created and filled with pattern
        if (node.name == 'g') {
          if (node.attributes.containsKey('filter')) {
            return;
          }
          final styles = computeStyle(stylesheet, node);
          if (styles.containsKey('filter')) {
            return;
          }
        }

        detachNodeFromParent(node, parentNode);
      },
    ),
  );
}
