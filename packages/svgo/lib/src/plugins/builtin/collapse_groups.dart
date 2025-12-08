/// Collapse groups plugin.
///
/// Collapses useless groups by moving attributes and replacing with children.
library;

import '../../collections/collections.dart';
import '../../style/style.dart';
import '../../xast/visitor.dart';
import '../../xast/xast.dart';
import '../plugin.dart';

/// Plugin that collapses useless groups.
///
/// This plugin performs two optimizations:
/// 1. Moves group attributes to a single child element when safe
/// 2. Removes groups without attributes by replacing them with their children
///
/// Example:
/// ```dart
/// // Before:
/// // <g>
/// //   <g attr1="val1">
/// //     <path d="..."/>
/// //   </g>
/// // </g>
///
/// // After:
/// // <path attr1="val1" d="..."/>
/// ```
///
/// References:
/// - SVG Groups: https://developer.mozilla.org/en-US/docs/Web/SVG/Element/g
const collapseGroups = Plugin<EmptyParams>(
  name: 'collapseGroups',
  description: 'collapses useless groups',
  defaultParams: EmptyParams(),
  fn: _collapseGroupsFn,
);

Visitor? _collapseGroupsFn(XastRoot root, EmptyParams params, SvgoInfo info) {
  final stylesheet = collectStylesheet(root);

  return Visitor(
    element: VisitorNode(
      exit: (node, parentNode) {
        // Skip root-level or switch children
        if (parentNode is XastRoot) {
          return;
        }
        final parentElem = parentNode as XastElement;
        if (parentElem.name == 'switch') {
          return;
        }

        // Only process non-empty groups
        if (node.name != 'g' || node.children.isEmpty) {
          return;
        }

        // Move group attributes to the single child element
        if (node.attributes.isNotEmpty && node.children.length == 1) {
          final firstChild = node.children[0];
          if (firstChild is! XastElement) {
            return;
          }

          final nodeHasFilter = node.attributes.containsKey('filter') ||
              _getStyleFilter(stylesheet, node) != null;

          // Conditions for moving attributes to child
          if (firstChild.attributes['id'] == null &&
              !nodeHasFilter &&
              (node.attributes['class'] == null ||
                  firstChild.attributes['class'] == null) &&
              ((!node.attributes.containsKey('clip-path') &&
                      !node.attributes.containsKey('mask')) ||
                  (firstChild.name == 'g' &&
                      node.attributes['transform'] == null &&
                      firstChild.attributes['transform'] == null))) {
            final newChildElemAttrs =
                Map<String, String>.from(firstChild.attributes);

            for (final entry in node.attributes.entries) {
              final name = entry.key;
              final value = entry.value;

              // Avoid copying to not conflict with animated attribute
              if (_hasAnimatedAttr(firstChild, name)) {
                return;
              }

              if (!newChildElemAttrs.containsKey(name)) {
                newChildElemAttrs[name] = value;
              } else if (name == 'transform') {
                // Combine transforms: parent transform first
                newChildElemAttrs[name] = '$value ${newChildElemAttrs[name]}';
              } else if (newChildElemAttrs[name] == 'inherit') {
                newChildElemAttrs[name] = value;
              } else if (!inheritableAttrs.contains(name) &&
                  newChildElemAttrs[name] != value) {
                // Non-inheritable attribute with different value, can't merge
                return;
              }
            }

            node.attributes.clear();
            firstChild.attributes
              ..clear()
              ..addAll(newChildElemAttrs);
          }
        }

        // Collapse groups without attributes
        if (node.attributes.isEmpty) {
          // Animation elements "add" attributes to group
          // Group should be preserved
          for (final child in node.children) {
            if (child is XastElement &&
                ElemsGroups.animation.contains(child.name)) {
              return;
            }
          }

          // Replace current node with all its children
          final index = parentElem.children.indexOf(node);
          if (index != -1) {
            parentElem.children.removeAt(index);
            parentElem.children.insertAll(index, node.children);
          }
        }

        return;
      },
    ),
  );
}

/// Checks if a node or any of its children has an animated attribute.
bool _hasAnimatedAttr(XastNode node, String name) {
  if (node is XastElement) {
    if (ElemsGroups.animation.contains(node.name) &&
        node.attributes['attributeName'] == name) {
      return true;
    }
    for (final child in node.children) {
      if (_hasAnimatedAttr(child, name)) {
        return true;
      }
    }
  }
  return false;
}

/// Gets the filter property from computed style if available.
String? _getStyleFilter(Stylesheet stylesheet, XastElement node) {
  final style = computeStyle(stylesheet, node);
  final filter = style['filter'];
  if (filter is StaticStyle) {
    return filter.value;
  }
  return null;
}
