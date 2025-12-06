/// Remove desc plugin.
///
/// Removes `<desc>` elements from SVG documents.
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes `<desc>` elements.
///
/// By default, only removes empty descriptions or those with standard editor
/// content. Enable `removeAny` to remove all descriptions.
const removeDesc = Plugin(
  name: 'removeDesc',
  description: 'removes <desc>',
  params: {'removeAny': false},
  fn: _removeDescFn,
);

Visitor? _removeDescFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  final removeAny = params['removeAny'] == true;
  final standardDescs = RegExp(r'^(Created with|Created using)');

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'desc') {
          if (removeAny || node.children.isEmpty) {
            detachNodeFromParent(node, parentNode);
            return null;
          }
          final first = node.children.first;
          if (first is XastText && standardDescs.hasMatch(first.value)) {
            detachNodeFromParent(node, parentNode);
          }
        }
        return null;
      },
    ),
  );
}
