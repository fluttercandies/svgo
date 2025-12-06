/// Removes specified attributes.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeAttrs = Plugin(
  name: 'removeAttrs',
  description: 'removes specified attributes',
  params: {
    'elemSeparator': ':',
    'preserveCurrentColor': false,
  },
  fn: _removeAttrsFn,
);

Visitor? _removeAttrsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final attrsParam = params['attrs'];
  if (attrsParam == null) {
    return null;
  }

  final elemSeparator = (params['elemSeparator'] as String?) ?? ':';
  final preserveCurrentColor = params['preserveCurrentColor'] == true;

  final attrs =
      attrsParam is List ? attrsParam.cast<String>() : [attrsParam as String];

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        for (var pattern in attrs) {
          // If no element separators, assume it's attribute name
          if (!pattern.contains(elemSeparator)) {
            pattern = ['.*', pattern, '.*'].join(elemSeparator);
          } else if (pattern.split(elemSeparator).length < 3) {
            pattern = [pattern, '.*'].join(elemSeparator);
          }

          final list = pattern.split(elemSeparator).map((value) {
            if (value == '*') {
              value = '.*';
            }
            return RegExp('^$value\$', caseSensitive: false);
          }).toList();

          if (list[0].hasMatch(node.name)) {
            final attrsToRemove = <String>[];
            for (final entry in node.attributes.entries) {
              final name = entry.key;
              final value = entry.value;

              final isCurrentColor = value.toLowerCase() == 'currentcolor';
              final isFillCurrentColor =
                  preserveCurrentColor && name == 'fill' && isCurrentColor;
              final isStrokeCurrentColor =
                  preserveCurrentColor && name == 'stroke' && isCurrentColor;

              if (!isFillCurrentColor &&
                  !isStrokeCurrentColor &&
                  list[1].hasMatch(name) &&
                  list[2].hasMatch(value)) {
                attrsToRemove.add(name);
              }
            }
            for (final attr in attrsToRemove) {
              node.attributes.remove(attr);
            }
          }
        }
        return null;
      },
    ),
  );
}
