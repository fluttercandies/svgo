/// Removes width and height in presence of viewBox.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeDimensions = Plugin<EmptyParams>(
  name: 'removeDimensions',
  description:
      'removes width and height in presence of viewBox (opposite to removeViewBox)',
  defaultParams: EmptyParams(),
  fn: _removeDimensionsFn,
);

Visitor? _removeDimensionsFn(
  XastRoot ast,
  EmptyParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'svg') {
          if (node.attributes['viewBox'] != null) {
            node.attributes.remove('width');
            node.attributes.remove('height');
          } else if (node.attributes['width'] != null &&
              node.attributes['height'] != null) {
            final width = double.tryParse(node.attributes['width']!);
            final height = double.tryParse(node.attributes['height']!);
            if (width != null && height != null) {
              node.attributes['viewBox'] = '0 0 $width $height';
              node.attributes.remove('width');
              node.attributes.remove('height');
            }
          }
        }
        return null;
      },
    ),
  );
}
