/// Adds attributes to an outer <svg> element.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Parameters for the addAttributesToSVGElement plugin.
class AddAttributesToSVGElementParams extends PluginParams {
  /// Attributes to add to the SVG element.
  final List<Object> attributes;

  const AddAttributesToSVGElementParams({
    this.attributes = const [],
  });
}

const addAttributesToSVGElement = Plugin<AddAttributesToSVGElementParams>(
  name: 'addAttributesToSVGElement',
  description: 'adds attributes to an outer <svg> element',
  defaultParams: AddAttributesToSVGElementParams(),
  fn: _addAttributesToSVGElementFn,
);

Visitor? _addAttributesToSVGElementFn(
  XastRoot ast,
  AddAttributesToSVGElementParams params,
  SvgoInfo info,
) {
  final attributes = params.attributes;

  if (attributes.isEmpty) {
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
