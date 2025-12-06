/// Adds attributes to an outer <svg> element.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const addAttributesToSVGElement = Plugin(
  name: 'addAttributesToSVGElement',
  description: 'adds attributes to an outer <svg> element',
  params: {},
  fn: _addAttributesToSVGElementFn,
);

Visitor? _addAttributesToSVGElementFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final attributes = params['attributes'] as List? ??
      (params['attribute'] != null ? [params['attribute']] : null);

  if (attributes == null || attributes.isEmpty) {
    return null;
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'svg' && parentNode is XastRoot) {
          for (final attribute in attributes) {
            if (attribute is String) {
              if (!node.attributes.containsKey(attribute)) {
                node.attributes[attribute] = '';
              }
            } else if (attribute is Map<String, String?>) {
              for (final entry in attribute.entries) {
                if (!node.attributes.containsKey(entry.key)) {
                  node.attributes[entry.key] = entry.value ?? '';
                }
              }
            }
          }
        }
        return null;
      },
    ),
  );
}
