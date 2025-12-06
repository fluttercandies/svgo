/// Sort attributes plugin.
///
/// Sorts element attributes for better compression.
///
/// @author Nikolay Frantsev (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Default attribute order for sorting.
const _defaultOrder = [
  'id',
  'width',
  'height',
  'x',
  'x1',
  'x2',
  'y',
  'y1',
  'y2',
  'cx',
  'cy',
  'r',
  'fill',
  'stroke',
  'marker',
  'd',
  'points',
];

/// Sorts element attributes for better compression.
///
/// Attributes are sorted in the following order:
/// 1. xmlns (if xmlnsOrder is 'front')
/// 2. xmlns:* attributes
/// 3. Other namespaced attributes
/// 4. Attributes in the order list
/// 5. Other attributes alphabetically
///
/// Example input:
/// ```xml
/// <svg d="..." fill="red" xmlns="..." id="icon">
/// ```
///
/// Example output:
/// ```xml
/// <svg xmlns="..." id="icon" fill="red" d="...">
/// ```
///
/// Parameters:
/// - `order`: Custom attribute order. Default: id, width, height, x, y, etc.
/// - `xmlnsOrder`: 'front' (default) puts xmlns first, 'alphabetical' sorts normally
const sortAttrs = Plugin(
  name: 'sortAttrs',
  description: 'Sort element attributes for better compression',
  params: {
    'order': _defaultOrder,
    'xmlnsOrder': 'front',
  },
  fn: _sortAttrsFn,
);

Visitor? _sortAttrsFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  final order = (params['order'] as List?)?.cast<String>() ?? _defaultOrder;
  final xmlnsOrder = params['xmlnsOrder']?.toString() ?? 'front';

  int getNsPriority(String name) {
    if (xmlnsOrder == 'front') {
      if (name == 'xmlns') return 3;
      if (name.startsWith('xmlns:')) return 2;
    }
    if (name.contains(':')) return 1;
    return 0;
  }

  int compareAttrs(MapEntry<String, String> a, MapEntry<String, String> b) {
    final aName = a.key;
    final bName = b.key;

    // Sort namespaces
    final aPriority = getNsPriority(aName);
    final bPriority = getNsPriority(bName);
    final priorityNs = bPriority - aPriority;
    if (priorityNs != 0) return priorityNs;

    // Extract the first part from attributes
    final aPart = aName.split('-').first;
    final bPart = bName.split('-').first;

    if (aPart != bPart) {
      final aInOrder = order.contains(aPart);
      final bInOrder = order.contains(bPart);

      // Sort by position in order param
      if (aInOrder && bInOrder) {
        return order.indexOf(aPart) - order.indexOf(bPart);
      }

      // Put attributes from order param before others
      if (aInOrder != bInOrder) {
        return aInOrder ? -1 : 1;
      }
    }

    // Sort alphabetically
    return aName.compareTo(bName);
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        final attrs = node.attributes.entries.toList();
        attrs.sort(compareAttrs);

        node.attributes.clear();
        for (final entry in attrs) {
          node.attributes[entry.key] = entry.value;
        }
        return null;
      },
    ),
  );
}
