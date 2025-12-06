/// Removes hidden elements with disabled rendering.
library;

import '../../collections/collections.dart';
import '../../path/path.dart';
import '../../style/style.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeHiddenElems = Plugin(
  name: 'removeHiddenElems',
  description: 'removes hidden elements (zero sized, with absent attributes)',
  params: {
    'isHidden': true,
    'displayNone': true,
    'opacity0': true,
    'circleR0': true,
    'ellipseRX0': true,
    'ellipseRY0': true,
    'rectWidth0': true,
    'rectHeight0': true,
    'patternWidth0': true,
    'patternHeight0': true,
    'imageWidth0': true,
    'imageHeight0': true,
    'pathEmptyD': true,
    'polylineEmptyPoints': true,
    'polygonEmptyPoints': true,
  },
  fn: _removeHiddenElemsFn,
);

/// Checks if element or children have scripts.
bool _hasScripts(XastElement node) {
  if (node.name == 'script') return true;
  if (node.attributes.containsKey('onload') ||
      node.attributes.containsKey('onclick') ||
      node.attributes.containsKey('onmouseover') ||
      node.attributes.containsKey('onmouseout') ||
      node.attributes.containsKey('onmousedown') ||
      node.attributes.containsKey('onmouseup') ||
      node.attributes.containsKey('onmousemove')) {
    return true;
  }
  return false;
}

/// Finds all IDs referenced in URL references.
Set<String> _findReferences(String name, String value) {
  final ids = <String>{};

  // Check href attributes
  if (name == 'href' || name == 'xlink:href') {
    if (value.startsWith('#')) {
      ids.add(value.substring(1));
    }
    return ids;
  }

  // Check url() references
  final urlMatches = RegExp(r'url\(#([^)]+)\)').allMatches(value);
  for (final match in urlMatches) {
    final id = match.group(1);
    if (id != null) ids.add(id);
  }

  return ids;
}

/// Queries for elements matching a simple selector within a subtree.
bool _querySelector(XastElement node, String selector) {
  // Parse simple attribute selector [attr=value]
  final attrMatch = RegExp(r'^\[([a-zA-Z_:][a-zA-Z0-9_:-]*)=([^\]]+)\]$')
      .firstMatch(selector);
  if (attrMatch != null) {
    final attrName = attrMatch.group(1)!;
    final attrValue = attrMatch.group(2)!;

    bool matches(XastElement elem) {
      if (elem.attributes[attrName] == attrValue) return true;
      for (final child in elem.children) {
        if (child is XastElement && matches(child)) return true;
      }
      return false;
    }

    return matches(node);
  }

  return false;
}

Visitor? _removeHiddenElemsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final isHidden = params['isHidden'] != false;
  final displayNone = params['displayNone'] != false;
  final opacity0 = params['opacity0'] != false;
  final circleR0 = params['circleR0'] != false;
  final ellipseRX0 = params['ellipseRX0'] != false;
  final ellipseRY0 = params['ellipseRY0'] != false;
  final rectWidth0 = params['rectWidth0'] != false;
  final rectHeight0 = params['rectHeight0'] != false;
  final patternWidth0 = params['patternWidth0'] != false;
  final patternHeight0 = params['patternHeight0'] != false;
  final imageWidth0 = params['imageWidth0'] != false;
  final imageHeight0 = params['imageHeight0'] != false;
  final pathEmptyD = params['pathEmptyD'] != false;
  final polylineEmptyPoints = params['polylineEmptyPoints'] != false;
  final polygonEmptyPoints = params['polygonEmptyPoints'] != false;

  final stylesheet = collectStylesheet(ast);

  /// Non-rendering elements to potentially remove.
  final nonRenderedNodes = <XastElement, XastParent>{};

  /// IDs of removed hidden definitions.
  final removedDefIds = <String>{};

  /// All defs elements for cleanup.
  final allDefs = <XastElement, XastParent>{};

  /// All ID references found.
  final allReferences = <String>{};

  /// References by ID for use element cleanup.
  final referencesById =
      <String, List<({XastElement node, XastParent parent})>>{};

  /// If styles are present, we can't be sure if a definition is unused.
  var deoptimized = false;

  /// Remove element and track removed def IDs.
  void removeElement(XastChild node, XastParent parentNode) {
    if (node is XastElement &&
        node.attributes['id'] != null &&
        parentNode is XastElement &&
        parentNode.name == 'defs') {
      removedDefIds.add(node.attributes['id']!);
    }
    detachNodeFromParent(node, parentNode);
  }

  /// Checks if node or any children have referenced IDs.
  bool canRemoveNonRenderingNode(XastElement node) {
    if (node.attributes['id'] != null &&
        allReferences.contains(node.attributes['id'])) {
      return false;
    }
    for (final child in node.children) {
      if (child is XastElement && !canRemoveNonRenderingNode(child)) {
        return false;
      }
    }
    return true;
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Check for scripts or dynamic styles
        if ((node.name == 'style' && node.children.isNotEmpty) ||
            _hasScripts(node)) {
          deoptimized = true;
          return null;
        }

        // Track defs elements
        if (node.name == 'defs' && parentNode != null) {
          allDefs[node] = parentNode;
        }

        // Track use element references
        if (node.name == 'use' && parentNode != null) {
          for (final entry in node.attributes.entries) {
            final name = entry.key;
            final value = entry.value;
            if (name == 'href' || name.endsWith(':href')) {
              if (value.startsWith('#')) {
                final id = value.substring(1);
                referencesById.putIfAbsent(id, () => []).add((
                  node: node,
                  parent: parentNode,
                ));
              }
            }
          }
        }

        // Handle non-rendering elements
        if (ElemsGroups.nonRendering.contains(node.name) &&
            parentNode != null) {
          nonRenderedNodes[node] = parentNode;
          return visitSkip;
        }

        // Collect ID references
        for (final entry in node.attributes.entries) {
          final ids = _findReferences(entry.key, entry.value);
          allReferences.addAll(ids);
        }

        final computedStyle = computeStyle(stylesheet, node);

        // opacity="0" - path elements with markers are handled separately
        if (opacity0) {
          final opacity = computedStyle['opacity'];
          if (opacity is StaticStyle && opacity.value == '0') {
            if (node.name == 'path' && parentNode != null) {
              nonRenderedNodes[node] = parentNode;
              return visitSkip;
            }
            if (parentNode != null) {
              removeElement(node, parentNode);
              return null;
            }
          }
        }

        // visibility="hidden"
        if (isHidden) {
          final visibility = computedStyle['visibility'];
          if (visibility is StaticStyle &&
              visibility.value == 'hidden' &&
              !_querySelector(node, '[visibility=visible]')) {
            if (parentNode != null) {
              removeElement(node, parentNode);
              return null;
            }
          }
        }

        // display="none"
        if (displayNone) {
          final display = computedStyle['display'];
          if (display is StaticStyle &&
              display.value == 'none' &&
              node.name != 'marker') {
            if (parentNode != null) {
              removeElement(node, parentNode);
              return null;
            }
          }
        }

        // Circle with r="0"
        if (circleR0 &&
            node.name == 'circle' &&
            node.children.isEmpty &&
            node.attributes['r'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Ellipse with rx="0"
        if (ellipseRX0 &&
            node.name == 'ellipse' &&
            node.children.isEmpty &&
            node.attributes['rx'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Ellipse with ry="0"
        if (ellipseRY0 &&
            node.name == 'ellipse' &&
            node.children.isEmpty &&
            node.attributes['ry'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Rect with width="0"
        if (rectWidth0 &&
            node.name == 'rect' &&
            node.children.isEmpty &&
            node.attributes['width'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Rect with height="0"
        if (rectHeight0 &&
            node.name == 'rect' &&
            node.children.isEmpty &&
            node.attributes['height'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Pattern with width="0"
        if (patternWidth0 &&
            node.name == 'pattern' &&
            node.attributes['width'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Pattern with height="0"
        if (patternHeight0 &&
            node.name == 'pattern' &&
            node.attributes['height'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Image with width="0"
        if (imageWidth0 &&
            node.name == 'image' &&
            node.attributes['width'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Image with height="0"
        if (imageHeight0 &&
            node.name == 'image' &&
            node.attributes['height'] == '0' &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Path with empty d
        if (pathEmptyD && node.name == 'path' && parentNode != null) {
          final d = node.attributes['d'];
          if (d == null) {
            removeElement(node, parentNode);
            return null;
          }
          try {
            final pathData = parsePathData(d);
            if (pathData.isEmpty) {
              removeElement(node, parentNode);
              return null;
            }
            // Keep single point paths only if they have markers
            if (pathData.length == 1 &&
                computedStyle['marker-start'] == null &&
                computedStyle['marker-end'] == null) {
              removeElement(node, parentNode);
              return null;
            }
          } catch (_) {
            // Keep paths with invalid d attribute
          }
        }

        // Polyline with empty points
        if (polylineEmptyPoints &&
            node.name == 'polyline' &&
            node.attributes['points'] == null &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        // Polygon with empty points
        if (polygonEmptyPoints &&
            node.name == 'polygon' &&
            node.attributes['points'] == null &&
            parentNode != null) {
          removeElement(node, parentNode);
          return null;
        }

        return null;
      },
    ),
    root: VisitorRoot(
      exit: (root) {
        // Remove use elements referencing removed defs
        for (final id in removedDefIds) {
          final refs = referencesById[id];
          if (refs != null) {
            for (final ref in refs) {
              detachNodeFromParent(ref.node, ref.parent);
            }
          }
        }

        // Remove non-rendering nodes that are not referenced
        if (!deoptimized) {
          for (final entry in nonRenderedNodes.entries) {
            if (canRemoveNonRenderingNode(entry.key)) {
              detachNodeFromParent(entry.key, entry.value);
            }
          }
        }

        // Remove empty defs
        for (final entry in allDefs.entries) {
          if (entry.key.children.isEmpty) {
            detachNodeFromParent(entry.key, entry.value);
          }
        }
      },
    ),
  );
}
