import '../../collections/collections.dart';
import '../../xast/visitor.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../plugin.dart';

/// Plugin that removes elements in `<defs>` without id.
///
/// Elements in `<defs>` that don't have an id attribute cannot be referenced,
/// so they are useless and can be removed. This also applies to non-rendering
/// elements (like `<linearGradient>`, `<pattern>`, etc.) without ids.
///
/// Example:
/// ```dart
/// final plugin = removeUselessDefs();
/// // Before: <defs><rect width="10" height="10"/></defs>
/// // After: (defs element removed entirely)
/// ```
///
/// References:
/// - SVG Defs: https://developer.mozilla.org/en-US/docs/Web/SVG/Element/defs
const removeUselessDefs = Plugin(
  name: 'removeUselessDefs',
  description: 'removes elements in <defs> without id',
  fn: _removeUselessDefsFn,
);

Visitor? _removeUselessDefsFn(
    XastRoot root, PluginParams params, SvgoInfo info) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Process defs elements or non-rendering elements without id
        if (node.name == 'defs' ||
            (ElemsGroups.nonRendering.contains(node.name) &&
                !node.attributes.containsKey('id'))) {
          // Collect useful nodes (those with id or style elements)
          final usefulNodes = <XastChild>[];
          _collectUsefulNodes(node, usefulNodes);

          if (usefulNodes.isEmpty) {
            // Remove the entire element if no useful nodes
            detachNodeFromParent(node, parentNode);
          } else {
            // Replace children with only useful nodes
            node.children
              ..clear()
              ..addAll(usefulNodes);
          }
        }
        return null;
      },
    ),
  );
}

/// Recursively collects useful nodes (elements with id or style elements).
///
/// A node is considered useful if:
/// - It has an `id` attribute (can be referenced)
/// - It is a `<style>` element (contains CSS rules)
void _collectUsefulNodes(XastElement node, List<XastChild> usefulNodes) {
  for (final child in node.children) {
    if (child is XastElement) {
      if (child.attributes.containsKey('id') || child.name == 'style') {
        // This node is useful, add it to the list
        usefulNodes.add(child);
      } else {
        // Recurse into child to find useful nodes inside
        _collectUsefulNodes(child, usefulNodes);
      }
    }
  }
}
