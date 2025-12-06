/// Merge styles plugin.
///
/// Merges multiple style elements into one.
///
/// @author strarsis (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../../xast/xast_utils.dart';
import '../plugin.dart';

/// Merges multiple `<style>` elements into one.
///
/// This plugin combines all CSS from multiple style elements into a single
/// style element for better compression and fewer HTTP requests.
///
/// Example input:
/// ```xml
/// <svg>
///   <style>.a { fill: red; }</style>
///   <style>.b { stroke: blue; }</style>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>
///   <style>.a { fill: red; }.b { stroke: blue; }</style>
/// </svg>
/// ```
const mergeStyles = Plugin(
  name: 'mergeStyles',
  description: 'merge multiple style elements into one',
  fn: _mergeStylesFn,
);

Visitor? _mergeStylesFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  XastElement? firstStyleElement;
  var collectedStyles = '';
  var styleContentType = 'text'; // 'text' or 'cdata'

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Skip <foreignObject> content
        if (node.name == 'foreignObject') {
          return visitSkip;
        }

        // Collect style elements
        if (node.name != 'style') {
          return null;
        }

        // Skip <style> with invalid type attribute
        final type = node.attributes['type'];
        if (type != null && type.isNotEmpty && type != 'text/css') {
          return null;
        }

        // Extract style element content
        var css = '';
        for (final child in node.children) {
          if (child is XastText) {
            css += child.value;
          }
          if (child is XastCdata) {
            styleContentType = 'cdata';
            css += child.value;
          }
        }

        // Remove empty style elements
        if (css.trim().isEmpty) {
          if (parentNode != null) {
            detachNodeFromParent(node, parentNode);
          }
          return null;
        }

        // Collect css and wrap with media query if present in attribute
        final media = node.attributes['media'];
        if (media == null) {
          collectedStyles += css;
        } else {
          collectedStyles += '@media $media{$css}';
          node.attributes.remove('media');
        }

        // Combine collected styles in the first style element
        if (firstStyleElement == null) {
          firstStyleElement = node;
        } else {
          if (parentNode != null) {
            detachNodeFromParent(node, parentNode);
          }
          final XastChild child = styleContentType == 'cdata'
              ? XastCdata(value: collectedStyles)
              : XastText(value: collectedStyles);
          firstStyleElement!.children
            ..clear()
            ..add(child);
        }

        return null;
      },
    ),
  );
}
