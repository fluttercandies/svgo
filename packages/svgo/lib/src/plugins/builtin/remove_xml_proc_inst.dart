/// Remove XML processing instruction plugin.
///
/// Removes the XML declaration from SVG documents.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes XML processing instruction.
///
/// Example input:
/// ```xml
/// <?xml version="1.0" encoding="utf-8"?>
/// <svg>...</svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>...</svg>
/// ```
const removeXMLProcInst = Plugin(
  name: 'removeXMLProcInst',
  description: 'removes XML processing instructions',
  fn: _removeXMLProcInstFn,
);

Visitor? _removeXMLProcInstFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  return Visitor(
    instruction: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'xml') {
          detachNodeFromParent(node, parentNode);
        }
        return null;
      },
    ),
  );
}
