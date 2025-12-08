/// Move elements attributes to group plugin.
///
/// Moves common attributes of group children to the group.
library;

import '../../collections/collections.dart';
import '../../xast/visitor.dart';
import '../../xast/xast.dart';
import '../plugin.dart';

/// Plugin that moves common attributes of group children to the group.
///
/// This plugin extracts common inheritable attributes from all children
/// of a group element and moves them to the parent group, reducing
/// redundancy and file size.
///
/// Example:
/// ```dart
/// // Before:
/// // <g attr1="val1">
/// //   <g attr2="val2">text</g>
/// //   <circle attr2="val2" attr3="val3"/>
/// // </g>
///
/// // After:
/// // <g attr1="val1" attr2="val2">
/// //   <g>text</g>
/// //   <circle attr3="val3"/>
/// // </g>
/// ```
///
/// References:
/// - SVG Inheritable Properties: https://www.w3.org/TR/SVG11/propidx.html
const moveElemsAttrsToGroup = Plugin<EmptyParams>(
  name: 'moveElemsAttrsToGroup',
  description: 'Move common attributes of group children to the group',
  defaultParams: EmptyParams(),
  fn: _moveElemsAttrsToGroupFn,
);

Visitor? _moveElemsAttrsToGroupFn(
    XastRoot root, EmptyParams params, SvgoInfo info) {
  // Find if any style element is present
  var deoptimizedWithStyles = false;

  // First pass: check for style elements
  void checkForStyles(XastNode node) {
    if (node is XastElement) {
      if (node.name == 'style') {
        deoptimizedWithStyles = true;
        return;
      }
      for (final child in node.children) {
        if (deoptimizedWithStyles) return;
        checkForStyles(child);
      }
    }
  }

  for (final child in root.children) {
    if (deoptimizedWithStyles) break;
    checkForStyles(child);
  }

  return Visitor(
    element: VisitorNode(
      exit: (node, parentNode) {
        // Process only groups with more than 1 child
        if (node.name != 'g' || node.children.length <= 1) {
          return;
        }

        // Deoptimize the plugin when style elements are present
        // Selectors may rely on id, classes or tag names
        if (deoptimizedWithStyles) {
          return;
        }

        // Find common attributes in group children
        final commonAttributes = <String, String>{};
        var initial = true;
        var everyChildIsPath = true;

        for (final child in node.children) {
          if (child is XastElement) {
            if (!pathElems.contains(child.name)) {
              everyChildIsPath = false;
            }

            if (initial) {
              initial = false;
              // Collect all inheritable attributes from first child element
              for (final entry in child.attributes.entries) {
                // Consider only inheritable attributes
                if (inheritableAttrs.contains(entry.key)) {
                  commonAttributes[entry.key] = entry.value;
                }
              }
            } else {
              // Exclude uncommon attributes from initial list
              final toRemove = <String>[];
              for (final entry in commonAttributes.entries) {
                if (child.attributes[entry.key] != entry.value) {
                  toRemove.add(entry.key);
                }
              }
              for (final key in toRemove) {
                commonAttributes.remove(key);
              }
            }
          }
        }

        // Preserve transform on children when group has filter, clip-path, or mask
        if (node.attributes['filter'] != null ||
            node.attributes['clip-path'] != null ||
            node.attributes['mask'] != null) {
          commonAttributes.remove('transform');
        }

        // Preserve transform when all children are paths
        // so the transform could be applied to path data by other plugins
        if (everyChildIsPath) {
          commonAttributes.remove('transform');
        }

        // Add common children attributes to group
        for (final entry in commonAttributes.entries) {
          if (entry.key == 'transform') {
            if (node.attributes['transform'] != null) {
              node.attributes['transform'] =
                  '${node.attributes['transform']} ${entry.value}';
            } else {
              node.attributes['transform'] = entry.value;
            }
          } else {
            node.attributes[entry.key] = entry.value;
          }
        }

        // Delete common attributes from children
        for (final child in node.children) {
          if (child is XastElement) {
            for (final name in commonAttributes.keys) {
              child.attributes.remove(name);
            }
          }
        }

        return;
      },
    ),
  );
}
