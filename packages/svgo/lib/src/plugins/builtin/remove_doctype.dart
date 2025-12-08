/// Remove DOCTYPE declaration plugin.
///
/// Removes the DOCTYPE declaration from SVG documents.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes DOCTYPE declaration.
///
/// "Unfortunately the SVG DTDs are a source of so many issues that the
/// SVG WG has decided not to write one for the upcoming SVG 1.2 standard.
/// In fact SVG WG members are even telling people not to use a DOCTYPE
/// declaration in SVG 1.0 and 1.1 documents"
/// @see https://jwatt.org/svg/authoring/#doctype-declaration
///
/// Example input:
/// ```xml
/// <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
///   "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
/// <svg>...</svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>...</svg>
/// ```
const removeDoctype = Plugin<EmptyParams>(
  name: 'removeDoctype',
  description: 'removes doctype declaration',
  defaultParams: EmptyParams(),
  fn: _removeDoctypeFn,
);

Visitor? _removeDoctypeFn(XastRoot ast, EmptyParams params, SvgoInfo info) {
  return Visitor(
    doctype: VisitorNode(
      enter: (node, parentNode) {
        detachNodeFromParent(node, parentNode);
        return null;
      },
    ),
  );
}
