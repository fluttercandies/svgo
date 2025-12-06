/// Remove elements by attribute plugin.
///
/// Removes arbitrary elements by ID or className.
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes arbitrary elements by ID or className.
///
/// This plugin allows you to remove specific elements from the SVG
/// by matching their `id` or `class` attributes.
///
/// **Example - by ID:**
/// ```yaml
/// # Remove element with ID 'elementID'
/// removeElementsByAttr:
///   id: 'elementID'
///
/// # Remove multiple elements by ID
/// removeElementsByAttr:
///   id:
///     - 'elementID'
///     - 'anotherID'
/// ```
///
/// **Example - by class:**
/// ```yaml
/// # Remove all elements with class 'elementClass'
/// removeElementsByAttr:
///   class: 'elementClass'
///
/// # Remove elements with multiple classes
/// removeElementsByAttr:
///   class:
///     - 'elementClass'
///     - 'anotherClass'
/// ```
///
/// Parameters:
/// - `id`: Single ID string or list of IDs to remove.
/// - `class`: Single class string or list of classes to remove.
const removeElementsByAttr = Plugin(
  name: 'removeElementsByAttr',
  description: 'removes arbitrary elements by ID or className',
  fn: _removeElementsByAttrFn,
);

Visitor? _removeElementsByAttrFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  // Parse id parameter
  final idParam = params['id'];
  final ids = <String>[];
  if (idParam is String) {
    ids.add(idParam);
  } else if (idParam is List) {
    ids.addAll(idParam.cast<String>());
  }

  // Parse class parameter
  final classParam = params['class'];
  final classes = <String>[];
  if (classParam is String) {
    classes.add(classParam);
  } else if (classParam is List) {
    classes.addAll(classParam.cast<String>());
  }

  if (ids.isEmpty && classes.isEmpty) {
    return null;
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Remove element if its `id` matches configured `id` params
        if (ids.isNotEmpty && node.attributes.containsKey('id')) {
          if (ids.contains(node.attributes['id'])) {
            detachNodeFromParent(node, parentNode);
            return null;
          }
        }

        // Remove element if its `class` contains any of the configured `class` params
        final nodeClass = node.attributes['class'];
        if (classes.isNotEmpty && nodeClass != null) {
          final classList = nodeClass.split(' ');
          for (final item in classes) {
            if (classList.contains(item)) {
              detachNodeFromParent(node, parentNode);
              return null;
            }
          }
        }

        return null;
      },
    ),
  );
}
