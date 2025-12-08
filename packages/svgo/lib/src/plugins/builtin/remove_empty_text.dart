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

/// Parameters for the removeEmptyText plugin.
class RemoveEmptyTextParams extends PluginParams {
  /// Remove empty `<text>` elements. Default: true
  final bool text;

  /// Remove empty `<tspan>` elements. Default: true
  final bool tspan;

  /// Remove `<tref>` with empty xlink:href. Default: true
  final bool tref;

  const RemoveEmptyTextParams({
    this.text = true,
    this.tspan = true,
    this.tref = true,
  });
}

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
const removeEmptyText = Plugin<RemoveEmptyTextParams>(
  name: 'removeEmptyText',
  description: 'removes empty <text> elements',
  defaultParams: RemoveEmptyTextParams(),
  fn: _removeEmptyTextFn,
);

Visitor? _removeEmptyTextFn(
    XastRoot ast, RemoveEmptyTextParams params, SvgoInfo info) {
  final removeText = params.text;
  final removeTspan = params.tspan;
  final removeTref = params.tref;

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
