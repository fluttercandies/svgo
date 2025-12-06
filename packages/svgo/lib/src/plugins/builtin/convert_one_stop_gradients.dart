/// Converts one-stop (single color) gradients to a plain color.
library;

import '../../collections/collections.dart';
import '../../style/style.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const convertOneStopGradients = Plugin(
  name: 'convertOneStopGradients',
  description: 'converts one-stop (single color) gradients to a plain color',
  fn: _convertOneStopGradientsFn,
);

Visitor? _convertOneStopGradientsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final stylesheet = collectStylesheet(ast);
  final effectedDefs = <XastElement>{};
  final allDefs = <XastElement, XastParent>{};
  final gradientsToDetach = <XastElement, XastParent>{};
  var xlinkHrefCount = 0;

  XastElement? findElement(XastNode root, String selector) {
    if (!selector.startsWith('#')) return null;
    final id = selector.substring(1);

    XastElement? result;
    void search(XastNode node) {
      if (result != null) return;
      if (node is XastElement) {
        if (node.attributes['id'] == id) {
          result = node;
          return;
        }
        for (final child in node.children) {
          search(child);
        }
      } else if (node is XastRoot) {
        for (final child in node.children) {
          search(child);
        }
      }
    }

    search(root);
    return result;
  }

  List<XastElement> findElementsWithAttribute(
    XastNode root,
    String attrName,
    String attrValue,
  ) {
    final result = <XastElement>[];

    void search(XastNode node) {
      if (node is XastElement) {
        if (node.attributes[attrName] == attrValue) {
          result.add(node);
        }
        for (final child in node.children) {
          search(child);
        }
      } else if (node is XastRoot) {
        for (final child in node.children) {
          search(child);
        }
      }
    }

    search(root);
    return result;
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.attributes['xlink:href'] != null) {
          xlinkHrefCount++;
        }

        if (node.name == 'defs' && parentNode != null) {
          allDefs[node] = parentNode;
          return null;
        }

        if (node.name != 'linearGradient' && node.name != 'radialGradient') {
          return null;
        }

        final stops = node.children
            .whereType<XastElement>()
            .where((c) => c.name == 'stop')
            .toList();

        final href = node.attributes['xlink:href'] ?? node.attributes['href'];
        XastElement? effectiveNode;
        if (stops.isEmpty && href != null && href.startsWith('#')) {
          effectiveNode = findElement(ast, href);
        } else {
          effectiveNode = node;
        }

        if (effectiveNode == null) {
          if (parentNode != null) {
            gradientsToDetach[node] = parentNode;
          }
          return null;
        }

        final effectiveStops = effectiveNode.children
            .whereType<XastElement>()
            .where((c) => c.name == 'stop')
            .toList();

        if (effectiveStops.length != 1) {
          return null;
        }

        if (parentNode is XastElement && parentNode.name == 'defs') {
          effectedDefs.add(parentNode);
        }

        if (parentNode != null) {
          gradientsToDetach[node] = parentNode;
        }

        String? color;
        final computedStyle = computeStyle(stylesheet, effectiveStops[0]);
        final style = computedStyle['stop-color'];
        if (style != null && style is StaticStyle) {
          color = style.value;
        }

        final id = node.attributes['id'];
        if (id == null) return null;

        final selectorVal = 'url(#$id)';

        for (final attr in colorsProps) {
          final elements = findElementsWithAttribute(ast, attr, selectorVal);
          for (final element in elements) {
            if (color != null) {
              element.attributes[attr] = color;
            } else {
              element.attributes.remove(attr);
            }
          }
        }

        // Handle style attributes
        void searchStyleAttrs(XastNode searchNode) {
          if (searchNode is XastElement) {
            final style = searchNode.attributes['style'];
            if (style != null && style.contains(selectorVal)) {
              searchNode.attributes['style'] = style.replaceAll(
                selectorVal,
                color ?? 'black',
              );
            }
            for (final child in searchNode.children) {
              searchStyleAttrs(child);
            }
          } else if (searchNode is XastRoot) {
            for (final child in searchNode.children) {
              searchStyleAttrs(child);
            }
          }
        }

        searchStyleAttrs(ast);

        return null;
      },
      exit: (node, parentNode) {
        if (node.name == 'svg') {
          for (final entry in gradientsToDetach.entries) {
            if (entry.key.attributes['xlink:href'] != null) {
              xlinkHrefCount--;
            }
            detachNodeFromParent(entry.key, entry.value);
          }

          if (xlinkHrefCount == 0) {
            node.attributes.remove('xmlns:xlink');
          }

          for (final entry in allDefs.entries) {
            if (effectedDefs.contains(entry.key) &&
                entry.key.children.isEmpty) {
              detachNodeFromParent(entry.key, entry.value);
            }
          }
        }
        return;
      },
    ),
  );
}
