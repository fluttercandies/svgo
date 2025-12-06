/// Removes useless stroke and fill attributes.
library;

import '../../collections/collections.dart';
import '../../style/style.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeUselessStrokeAndFill = Plugin(
  name: 'removeUselessStrokeAndFill',
  description: 'removes useless stroke and fill attributes',
  params: {
    'stroke': true,
    'fill': true,
    'removeNone': false,
  },
  fn: _removeUselessStrokeAndFillFn,
);

Visitor? _removeUselessStrokeAndFillFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final removeStroke = params['stroke'] != false;
  final removeFill = params['fill'] != false;
  final removeNone = params['removeNone'] == true;

  // Check if document has scripts or style elements
  var hasStyleOrScript = false;
  visit(
    ast,
    Visitor(
      element: VisitorNode(
        enter: (node, parentNode) {
          if (node.name == 'style' ||
              node.name == 'script' ||
              node.attributes.containsKey('onload') ||
              node.attributes.containsKey('onclick')) {
            hasStyleOrScript = true;
          }
          return null;
        },
      ),
    ),
  );

  if (hasStyleOrScript) {
    return null;
  }

  final stylesheet = collectStylesheet(ast);

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Skip if has id (could be referenced)
        if (node.attributes.containsKey('id')) {
          return visitSkip;
        }

        // Only process shape elements
        if (!ElemsGroups.shape.contains(node.name)) {
          return null;
        }

        final computedStyle = computeStyle(stylesheet, node);
        final stroke = computedStyle['stroke'];
        final strokeOpacity = computedStyle['stroke-opacity'];
        final strokeWidth = computedStyle['stroke-width'];
        final fill = computedStyle['fill'];
        final fillOpacity = computedStyle['fill-opacity'];

        // Check parent stroke
        XastElement? parentElement;
        if (parentNode is XastElement) {
          parentElement = parentNode;
        }
        final parentComputedStyle = parentElement != null
            ? computeStyle(stylesheet, parentElement)
            : null;
        final parentStroke = parentComputedStyle?['stroke'];

        // Remove stroke* attributes
        if (removeStroke) {
          final isStrokeNone = stroke == null ||
              (stroke is StaticStyle && stroke.value == 'none') ||
              (strokeOpacity is StaticStyle && strokeOpacity.value == '0') ||
              (strokeWidth is StaticStyle && strokeWidth.value == '0');

          if (isStrokeNone) {
            final attrsToRemove = <String>[];
            for (final name in node.attributes.keys) {
              if (name.startsWith('stroke')) {
                attrsToRemove.add(name);
              }
            }
            for (final attr in attrsToRemove) {
              node.attributes.remove(attr);
            }

            // Set explicit none to not inherit from parent
            if (parentStroke is StaticStyle && parentStroke.value != 'none') {
              node.attributes['stroke'] = 'none';
            }
          }
        }

        // Remove fill* attributes
        if (removeFill) {
          final isFillNone = (fill is StaticStyle && fill.value == 'none') ||
              (fillOpacity is StaticStyle && fillOpacity.value == '0');

          if (isFillNone) {
            final attrsToRemove = <String>[];
            for (final name in node.attributes.keys) {
              if (name.startsWith('fill-')) {
                attrsToRemove.add(name);
              }
            }
            for (final attr in attrsToRemove) {
              node.attributes.remove(attr);
            }

            if (fill == null || (fill is StaticStyle && fill.value != 'none')) {
              node.attributes['fill'] = 'none';
            }
          }
        }

        // Remove element if both stroke and fill are none
        if (removeNone) {
          final strokeNone =
              stroke == null || node.attributes['stroke'] == 'none';
          final fillNone = (fill is StaticStyle && fill.value == 'none') ||
              node.attributes['fill'] == 'none';

          if (strokeNone && fillNone) {
            detachNodeFromParent(node, parentNode);
          }
        }

        return null;
      },
    ),
  );
}
