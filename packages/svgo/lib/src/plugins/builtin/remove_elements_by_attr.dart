/// Remove elements by attribute plugin.
///
/// Removes arbitrary elements by ID or className.
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Parameters for the removeElementsByAttr plugin.
class RemoveElementsByAttrParams extends PluginParams {
  /// IDs of elements to remove.
  final List<String> id;

  /// Class names of elements to remove.
  final List<String> className;

  const RemoveElementsByAttrParams({
    this.id = const [],
    this.className = const [],
  });
}

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
const removeElementsByAttr = Plugin<RemoveElementsByAttrParams>(
  name: 'removeElementsByAttr',
  description: 'removes arbitrary elements by ID or className',
  defaultParams: RemoveElementsByAttrParams(),
  fn: _removeElementsByAttrFn,
);

Visitor? _removeElementsByAttrFn(
    XastRoot ast, RemoveElementsByAttrParams params, SvgoInfo info) {
  final ids = params.id;
  final classes = params.className;

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
