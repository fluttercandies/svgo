/// Sort defs children plugin.
///
/// Sorts children of `<defs>` to improve compression.
///
/// @author David Leston (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Sorts children of `<defs>` to improve compression.
///
/// Elements are sorted by:
/// 1. Frequency (most common first)
/// 2. Element name length (longer names first)
/// 3. Element name alphabetically
///
/// This grouping helps GZIP/deflate compression by increasing repetition.
///
/// Example input:
/// ```xml
/// <defs>
///   <clipPath id="a"/>
///   <linearGradient id="b"/>
///   <clipPath id="c"/>
/// </defs>
/// ```
///
/// Example output:
/// ```xml
/// <defs>
///   <clipPath id="a"/>
///   <clipPath id="c"/>
///   <linearGradient id="b"/>
/// </defs>
/// ```
const sortDefsChildren = Plugin(
  name: 'sortDefsChildren',
  description: 'Sorts children of <defs> to improve compression',
  fn: _sortDefsChildrenFn,
);

Visitor? _sortDefsChildrenFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'defs') {
          // Count frequencies
          final frequencies = <String, int>{};
          for (final child in node.children) {
            if (child is XastElement) {
              frequencies[child.name] = (frequencies[child.name] ?? 0) + 1;
            }
          }

          // Sort children
          node.children.sort((a, b) {
            if (a is! XastElement || b is! XastElement) {
              return 0;
            }

            final aFrequency = frequencies[a.name] ?? 0;
            final bFrequency = frequencies[b.name] ?? 0;

            // Sort by frequency (descending)
            final frequencyComparison = bFrequency - aFrequency;
            if (frequencyComparison != 0) {
              return frequencyComparison;
            }

            // Sort by name length (descending)
            final lengthComparison = b.name.length - a.name.length;
            if (lengthComparison != 0) {
              return lengthComparison;
            }

            // Sort by name (descending for grouping)
            if (a.name != b.name) {
              return a.name.compareTo(b.name) > 0 ? -1 : 1;
            }

            return 0;
          });
        }
        return null;
      },
    ),
  );
}
