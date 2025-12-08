/// Removes raster images.
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

final _rasterImagePattern = RegExp(r'(\.|image/)(jpe?g|png|gif)');

const removeRasterImages = Plugin<EmptyParams>(
  name: 'removeRasterImages',
  description: 'removes raster images',
  defaultParams: EmptyParams(),
  fn: _removeRasterImagesFn,
);

Visitor? _removeRasterImagesFn(
  XastRoot ast,
  EmptyParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'image') {
          final href = node.attributes['xlink:href'] ?? node.attributes['href'];
          if (href != null && _rasterImagePattern.hasMatch(href)) {
            detachNodeFromParent(node, parentNode);
          }
        }
        return null;
      },
    ),
  );
}
