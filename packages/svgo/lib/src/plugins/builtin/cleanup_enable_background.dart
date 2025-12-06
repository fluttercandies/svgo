/// Removes or cleans up enable-background attribute.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

final _regEnableBackground = RegExp(
  r'^new\s0\s0\s([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\s([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)$',
);

const cleanupEnableBackground = Plugin(
  name: 'cleanupEnableBackground',
  description: 'remove or cleanup enable-background attribute when possible',
  fn: _cleanupEnableBackgroundFn,
);

Visitor? _cleanupEnableBackgroundFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  // Check if there are any filter elements
  var hasFilter = false;
  visit(
    ast,
    Visitor(
      element: VisitorNode(
        enter: (node, parentNode) {
          if (node.name == 'filter') {
            hasFilter = true;
          }
          return null;
        },
      ),
    ),
  );

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (!hasFilter) {
          // No filters, safe to remove enable-background everywhere
          node.attributes.remove('enable-background');

          // Also remove from style attribute if present
          final style = node.attributes['style'];
          if (style != null && style.contains('enable-background')) {
            final newStyle = style
                .split(';')
                .where((decl) => !decl.trim().startsWith('enable-background'))
                .join(';');
            if (newStyle.isEmpty) {
              node.attributes.remove('style');
            } else {
              node.attributes['style'] = newStyle;
            }
          }
          return null;
        }

        // Has filters, only cleanup when dimensions match
        final hasDimensions = node.attributes.containsKey('width') &&
            node.attributes.containsKey('height');

        if ((node.name == 'svg' ||
                node.name == 'mask' ||
                node.name == 'pattern') &&
            hasDimensions) {
          final attrValue = node.attributes['enable-background'];
          if (attrValue != null) {
            final cleaned = _cleanupValue(
              attrValue,
              node.name,
              node.attributes['width']!,
              node.attributes['height']!,
            );
            if (cleaned == null) {
              node.attributes.remove('enable-background');
            } else {
              node.attributes['enable-background'] = cleaned;
            }
          }
        }

        return null;
      },
    ),
  );
}

String? _cleanupValue(
  String value,
  String nodeName,
  String width,
  String height,
) {
  final match = _regEnableBackground.firstMatch(value);

  if (match != null && width == match.group(1) && height == match.group(2)) {
    return nodeName == 'svg' ? null : 'new';
  }

  return value;
}
