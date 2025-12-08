/// Remove metadata plugin.
///
/// Removes `<metadata>` elements from SVG documents.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes `<metadata>` elements.
///
/// @see https://www.w3.org/TR/SVG11/metadata.html
///
/// Example input:
/// ```xml
/// <svg>
///   <metadata>
///     <rdf:RDF>...</rdf:RDF>
///   </metadata>
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
const removeMetadata = Plugin<EmptyParams>(
  name: 'removeMetadata',
  description: 'removes <metadata>',
  defaultParams: EmptyParams(),
  fn: _removeMetadataFn,
);

Visitor? _removeMetadataFn(XastRoot ast, EmptyParams params, SvgoInfo info) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'metadata') {
          detachNodeFromParent(node, parentNode);
        }
        return null;
      },
    ),
  );
}
