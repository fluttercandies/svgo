/// Removes xmlns attribute (for inline SVG).
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeXMLNS = Plugin(
  name: 'removeXMLNS',
  description: 'removes xmlns attribute (for inline svg)',
  fn: _removeXMLNSFn,
);

Visitor? _removeXMLNSFn(
  XastRoot ast,
  PluginParams params,
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
