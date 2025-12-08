/// Convert ellipse to circle plugin.
///
/// Converts non-eccentric `<ellipse>` elements to `<circle>` elements.
library;

import '../../xast/visitor.dart';
import '../../xast/xast.dart';
import '../plugin.dart';

/// Converts non-eccentric `<ellipse>` elements to `<circle>` elements.
const convertEllipseToCircle = Plugin<EmptyParams>(
  name: 'convertEllipseToCircle',
  description: 'converts non-eccentric <ellipse>s to <circle>s',
  defaultParams: EmptyParams(),
  fn: _convertEllipseToCircleFn,
);

Visitor? _convertEllipseToCircleFn(
  XastRoot ast,
  EmptyParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'ellipse') {
          final rx = node.attributes['rx'] ?? '0';
          final ry = node.attributes['ry'] ?? '0';
          if (rx == ry || rx == 'auto' || ry == 'auto') {
            node.attributes.remove('rx');
            node.attributes.remove('ry');
            node.attributes['r'] = rx == 'auto' ? ry : rx;
            // Change element name (now mutable)
            node.name = 'circle';
          }
        }
        return null;
      },
    ),
  );
}
