/// Removes viewBox attribute when possible.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const _viewBoxElems = {'pattern', 'svg', 'symbol'};

const removeViewBox = Plugin(
  name: 'removeViewBox',
  description: 'removes viewBox attribute when possible',
  fn: _removeViewBoxFn,
);

Visitor? _removeViewBoxFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (_viewBoxElems.contains(node.name) &&
            node.attributes['viewBox'] != null &&
            node.attributes['width'] != null &&
            node.attributes['height'] != null) {
          // Skip nested svg elements
          if (node.name == 'svg' && parentNode is! XastRoot) {
            return null;
          }

          final numbers = node.attributes['viewBox']!.split(RegExp(r'[ ,]+'));
          if (numbers.length == 4 &&
              numbers[0] == '0' &&
              numbers[1] == '0' &&
              node.attributes['width']!.replaceAll(RegExp(r'px$'), '') ==
                  numbers[2] &&
              node.attributes['height']!.replaceAll(RegExp(r'px$'), '') ==
                  numbers[3]) {
            node.attributes.remove('viewBox');
          }
        }
        return null;
      },
    ),
  );
}
