/// Remove comments plugin.
///
/// Removes XML comment nodes from the SVG document.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes comments.
///
/// Example input:
/// ```xml
/// <!-- Generator: Adobe Illustrator 15.0.0 -->
/// <svg>...</svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>...</svg>
/// ```
///
/// Parameters:
/// - `preservePatterns`: List of regex patterns. Comments matching any pattern
///   are preserved. Default: `[r'^!']` (preserves copyright/license comments).
///   Set to `null` or empty list to remove all comments.
const removeComments = Plugin(
  name: 'removeComments',
  description: 'removes comments',
  params: {
    'preservePatterns': [r'^!'],
  },
  fn: _removeCommentsFn,
);

Visitor? _removeCommentsFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  final preservePatterns = params['preservePatterns'];

  List<RegExp>? patterns;
  if (preservePatterns != null && preservePatterns is List) {
    patterns = preservePatterns.map((p) {
      if (p is RegExp) return p;
      return RegExp(p.toString());
    }).toList();
  }

  return Visitor(
    comment: VisitorNode(
      enter: (node, parentNode) {
        if (patterns != null && patterns.isNotEmpty) {
          final matches =
              patterns.any((pattern) => pattern.hasMatch(node.value));
          if (matches) return null;
        }
        detachNodeFromParent(node, parentNode);
        return null;
      },
    ),
  );
}
