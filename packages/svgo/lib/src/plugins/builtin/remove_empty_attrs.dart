/// Remove empty attributes plugin.
///
/// Removes attributes with empty values from SVG elements.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../collections/collections.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes attributes with empty values.
///
/// Note: Empty conditional processing attributes are preserved as they
/// prevent elements from rendering.
///
/// Example input:
/// ```xml
/// <svg>
///   <rect fill="" stroke="black"/>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>
///   <rect stroke="black"/>
/// </svg>
/// ```
const removeEmptyAttrs = Plugin(
  name: 'removeEmptyAttrs',
  description: 'removes empty attributes',
  fn: _removeEmptyAttrsFn,
);

Visitor? _removeEmptyAttrsFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        final attrsToRemove = <String>[];

        for (final entry in node.attributes.entries) {
          if (entry.value.isEmpty &&
              !AttrsGroups.conditionalProcessing.contains(entry.key)) {
            attrsToRemove.add(entry.key);
          }
        }

        for (final name in attrsToRemove) {
          node.attributes.remove(name);
        }
        return null;
      },
    ),
  );
}
