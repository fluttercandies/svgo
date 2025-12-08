/// Removes xmlns attribute (for inline SVG).
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeXMLNS = Plugin<EmptyParams>(
  name: 'removeXMLNS',
  description: 'removes xmlns attribute (for inline svg)',
  defaultParams: EmptyParams(),
  fn: _removeXMLNSFn,
);

Visitor? _removeXMLNSFn(
  XastRoot ast,
  EmptyParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'svg') {
          node.attributes.remove('xmlns');
        }
        return null;
      },
    ),
  );
}
