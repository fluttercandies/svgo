/// Remove desc plugin.
///
/// Removes `<desc>` elements from SVG documents.
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Parameters for the removeDesc plugin.
class RemoveDescParams extends PluginParams {
  /// Remove all descriptions, not just empty/standard ones.
  final bool removeAny;

  const RemoveDescParams({
    this.removeAny = false,
  });

  /// Creates params that remove all descriptions.
  const RemoveDescParams.removeAll() : removeAny = true;
}

/// Removes `<desc>` elements.
///
/// By default, only removes empty descriptions or those with standard editor
/// content. Enable `removeAny` to remove all descriptions.
const removeDesc = Plugin<RemoveDescParams>(
  name: 'removeDesc',
  description: 'removes <desc>',
  defaultParams: RemoveDescParams(),
  fn: _removeDescFn,
);

Visitor? _removeDescFn(XastRoot ast, RemoveDescParams params, SvgoInfo info) {
  final removeAny = params.removeAny;
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
