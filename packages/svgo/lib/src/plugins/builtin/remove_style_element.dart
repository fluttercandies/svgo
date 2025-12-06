/// Removes <style> element.
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeStyleElement = Plugin(
  name: 'removeStyleElement',
  description: 'removes <style> element',
  fn: _removeStyleElementFn,
);

Visitor? _removeStyleElementFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'style') {
          detachNodeFromParent(node, parentNode);
        }
        return null;
      },
    ),
  );
}
