/// Convert style to attributes plugin.
///
/// Converts inline style declarations to SVG presentation attributes.
library;

import '../../collections/collections.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Converts inline style declarations to attributes.
///
/// This plugin converts CSS properties in the `style` attribute to
/// their equivalent SVG presentation attributes.
///
/// **Example:**
/// ```xml
/// <!-- Before -->
/// <g style="fill:#000; color: #fff;">
///
/// <!-- After -->
/// <g fill="#000" color="#fff">
/// ```
///
/// **Example with unknown properties:**
/// ```xml
/// <!-- Before -->
/// <g style="fill:#000; color: #fff; -webkit-blah: blah">
///
/// <!-- After -->
/// <g fill="#000" color="#fff" style="-webkit-blah: blah">
/// ```
///
/// Parameters:
/// - `keepImportant`: Keep !important declarations in style (default: false)
const convertStyleToAttrs = Plugin(
  name: 'convertStyleToAttrs',
  description: 'converts style to attributes',
  params: {
    'keepImportant': false,
  },
  fn: _convertStyleToAttrsFn,
);

// Pattern for escapes like \" or \2051
final _regDeclarationBlock = RegExp(
  r'\s*([^:;\s]+)\s*:\s*([^;!]+)(!important)?\s*(?:;|$)',
  caseSensitive: false,
);

Visitor? _convertStyleToAttrsFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  final keepImportant = params['keepImportant'] as bool? ?? false;

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        final styleValue = node.attributes['style'];
        if (styleValue == null) {
          return null;
        }

        final styles = <List<String>>[];
        final newAttributes = <String, String>{};

        // Parse declarations
        for (final match in _regDeclarationBlock.allMatches(styleValue)) {
          final prop = match.group(1)?.trim();
          final value = match.group(2)?.trim();
          final important = match.group(3);

          if (prop == null || value == null) continue;

          // Skip if keepImportant is true and the property has !important
          if (keepImportant && important != null && important.isNotEmpty) {
            styles.add([prop, value + important]);
            continue;
          }

          styles.add([prop, value]);
        }

        if (styles.isEmpty) {
          return null;
        }

        final remainingStyles = <List<String>>[];

        for (final style in styles) {
          final prop = style[0].toLowerCase();
          var val = style[1];

          // Remove surrounding quotes if present
          if ((val.startsWith("'") && val.endsWith("'")) ||
              (val.startsWith('"') && val.endsWith('"'))) {
            val = val.substring(1, val.length - 1);
          }

          // Check if it's a presentation attribute
          if (AttrsGroups.presentation.contains(prop)) {
            newAttributes[prop] = val;
          } else {
            remainingStyles.add(style);
          }
        }

        // Apply new attributes
        node.attributes.addAll(newAttributes);

        // Update or remove style attribute
        if (remainingStyles.isNotEmpty) {
          node.attributes['style'] = remainingStyles
              .map((declaration) => '${declaration[0]}:${declaration[1]}')
              .join(';');
        } else {
          node.attributes.remove('style');
        }

        return null;
      },
    ),
  );
}
