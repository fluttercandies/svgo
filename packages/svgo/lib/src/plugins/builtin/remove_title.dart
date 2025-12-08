/// Remove title plugin.
///
/// Removes `<title>` elements from SVG documents.
///
/// @author Igor Kalashnikov (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes `<title>` elements.
///
/// @see https://developer.mozilla.org/en-US/docs/Web/SVG/Element/title
///
/// Example input:
/// ```xml
/// <svg>
///   <title>My Image</title>
///   <rect/>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>
///   <rect/>
/// </svg>
/// ```
const removeTitle = Plugin<EmptyParams>(
  name: 'removeTitle',
  description: 'removes <title>',
  defaultParams: EmptyParams(),
  fn: _removeTitleFn,
);

Visitor? _removeTitleFn(XastRoot ast, EmptyParams params, SvgoInfo info) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'title') {
          detachNodeFromParent(node, parentNode);
        }
        return null;
      },
    ),
  );
}
