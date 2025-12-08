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

/// Parameters for the removeComments plugin.
class RemoveCommentsParams extends PluginParams {
  /// List of regex patterns. Comments matching any pattern are preserved.
  /// Default: preserves copyright/license comments starting with '!'.
  /// Set to empty list to remove all comments.
  final List<RegExp> preservePatterns;

  const RemoveCommentsParams({
    this.preservePatterns = const [],
  });

  /// Creates params that preserve copyright/license comments (starting with '!').
  factory RemoveCommentsParams.preserveCopyright() {
    return RemoveCommentsParams(preservePatterns: [RegExp(r'^!')]);
  }

  /// Creates params that remove all comments.
  const RemoveCommentsParams.removeAll() : preservePatterns = const [];
}

/// Default preserve pattern for copyright comments.
final _defaultPreservePattern = RegExp(r'^!');

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
final removeComments = Plugin<RemoveCommentsParams>(
  name: 'removeComments',
  description: 'removes comments',
  defaultParams:
      RemoveCommentsParams(preservePatterns: [_defaultPreservePattern]),
  fn: _removeCommentsFn,
);

Visitor? _removeCommentsFn(
  XastRoot ast,
  RemoveCommentsParams params,
  SvgoInfo info,
) {
  final patterns = params.preservePatterns;

  return Visitor(
    comment: VisitorNode(
      enter: (node, parentNode) {
        if (patterns.isNotEmpty) {
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
