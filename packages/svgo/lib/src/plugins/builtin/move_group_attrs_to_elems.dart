/// Move group attributes to elements plugin.
///
/// Moves some group attributes to the content elements.
library;

import '../../collections/collections.dart';
import '../../xast/visitor.dart';
import '../../xast/xast.dart';
import '../plugin.dart';

/// Plugin that moves some group attributes to the content elements.
///
/// This plugin moves the `transform` attribute from a group element to its
/// children when safe to do so. This allows the transform to potentially
/// be applied directly to path data by other plugins.
///
/// Example:
/// ```dart
/// // Before:
/// // <g transform="scale(2)">
/// //   <path transform="rotate(45)" d="M0,0 L10,20"/>
/// //   <path transform="translate(10, 20)" d="M0,10 L20,30"/>
/// // </g>
///
/// // After:
/// // <g>
/// //   <path transform="scale(2) rotate(45)" d="M0,0 L10,20"/>
/// //   <path transform="scale(2) translate(10, 20)" d="M0,10 L20,30"/>
/// // </g>
/// ```
///
/// References:
/// - SVG Transform Attribute: https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/transform
const moveGroupAttrsToElems = Plugin<EmptyParams>(
  name: 'moveGroupAttrsToElems',
  description: 'moves some group attributes to the content elements',
  defaultParams: EmptyParams(),
  fn: _moveGroupAttrsToElemsFn,
);

/// Elements that can receive the transform attribute from a group.
const _pathElemsWithGroupsAndText = {
  ...pathElems,
  'g',
  'text',
};

/// Regular expression to detect URL references in attribute values.
final _urlReferenceRegex = RegExp(r'url\(');

Visitor? _moveGroupAttrsToElemsFn(
    XastRoot root, EmptyParams params, SvgoInfo info) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Only process groups with transform and children
        if (node.name != 'g' ||
            node.children.isEmpty ||
            node.attributes['transform'] == null) {
          return null;
        }

        // Don't move transform if group has URL references
        // (e.g., fill="url(#gradient)")
        final hasUrlReference = node.attributes.entries.any((entry) =>
            referencesProps.contains(entry.key) &&
            _urlReferenceRegex.hasMatch(entry.value));

        if (hasUrlReference) {
          return null;
        }

        // Check if all children are compatible elements without ids
        final allChildrenCompatible = node.children.every((child) =>
            child is XastElement &&
            _pathElemsWithGroupsAndText.contains(child.name) &&
            child.attributes['id'] == null);

        if (!allChildrenCompatible) {
          return null;
        }

        // Move transform to children
        final transform = node.attributes['transform']!;
        for (final child in node.children) {
          if (child is XastElement) {
            if (child.attributes['transform'] != null) {
              // Prepend group transform to child transform
              child.attributes['transform'] =
                  '$transform ${child.attributes['transform']}';
            } else {
              child.attributes['transform'] = transform;
            }
          }
        }

        // Remove transform from group
        node.attributes.remove('transform');

        return null;
      },
    ),
  );
}
