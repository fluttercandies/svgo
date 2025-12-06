/// Remove empty text plugin.
///
/// Removes empty text elements from SVG documents.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes empty `<text>`, `<tspan>`, and `<tref>` elements.
///
/// @see https://www.w3.org/TR/SVG11/text.html
///
/// Example input:
/// ```xml
/// <svg>
///   <text/>
///   <tspan/>
///   <tref xlink:href=""/>
///   <text>Hello</text>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>
///   <text>Hello</text>
/// </svg>
/// ```
///
/// Parameters:
/// - `text`: Remove empty `<text>` elements. Default: true
/// - `tspan`: Remove empty `<tspan>` elements. Default: true
/// - `tref`: Remove `<tref>` with empty xlink:href. Default: true
const removeEmptyText = Plugin(
  name: 'removeEmptyText',
  description: 'removes empty <text> elements',
  params: {
    'text': true,
    'tspan': true,
    'tref': true,
  },
  fn: _removeEmptyTextFn,
);

Visitor? _removeEmptyTextFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  final removeText = params['text'] != false;
  final removeTspan = params['tspan'] != false;
  final removeTref = params['tref'] != false;

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Remove empty text element
        if (removeText && node.name == 'text' && node.children.isEmpty) {
          detachNodeFromParent(node, parentNode);
          return;
        }

        // Remove empty tspan element
        if (removeTspan && node.name == 'tspan' && node.children.isEmpty) {
          detachNodeFromParent(node, parentNode);
          return;
        }

        // Remove tref with empty xlink:href attribute
        if (removeTref &&
            node.name == 'tref' &&
            !node.attributes.containsKey('xlink:href')) {
          detachNodeFromParent(node, parentNode);
        }
        return null;
      },
    ),
  );
}
