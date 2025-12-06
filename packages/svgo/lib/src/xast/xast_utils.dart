/// XAST utility functions.
///
/// Provides utility functions for working with XAST nodes, including
/// CSS selector querying, node manipulation, and tree traversal helpers.
library;

import 'xast.dart';

/// Detaches a child node from its parent.
///
/// This removes the node from the parent's children list without destroying it,
/// allowing it to be reattached elsewhere if needed.
///
/// If [parentNode] is null, this function does nothing.
void detachNodeFromParent(XastChild node, XastParent? parentNode) {
  if (parentNode == null) return;
  parentNode.children.removeWhere((child) => identical(child, node));
}

/// Replaces a child node with another node.
///
/// Example:
/// ```dart
/// replaceNode(oldNode, newNode, parent);
/// ```
void replaceNode(XastChild oldNode, XastChild newNode, XastParent parentNode) {
  final index = parentNode.children.indexOf(oldNode);
  if (index != -1) {
    parentNode.children[index] = newNode;
  }
}

/// Inserts a node before another node in the parent's children list.
///
/// Example:
/// ```dart
/// insertBefore(newNode, referenceNode, parent);
/// ```
void insertBefore(
  XastChild newNode,
  XastChild referenceNode,
  XastParent parentNode,
) {
  final index = parentNode.children.indexOf(referenceNode);
  if (index != -1) {
    parentNode.children.insert(index, newNode);
  }
}

/// Inserts a node after another node in the parent's children list.
///
/// Example:
/// ```dart
/// insertAfter(newNode, referenceNode, parent);
/// ```
void insertAfter(
  XastChild newNode,
  XastChild referenceNode,
  XastParent parentNode,
) {
  final index = parentNode.children.indexOf(referenceNode);
  if (index != -1) {
    parentNode.children.insert(index + 1, newNode);
  }
}

/// Returns all element children of a parent node.
///
/// Example:
/// ```dart
/// final elements = getElementChildren(parent);
/// ```
List<XastElement> getElementChildren(XastParent parent) {
  return parent.children.whereType<XastElement>().toList();
}

/// Returns all text content within an element (including nested elements).
///
/// Example:
/// ```dart
/// final text = getTextContent(element);
/// ```
String getTextContent(XastParent parent) {
  final buffer = StringBuffer();
  _collectTextContent(parent, buffer);
  return buffer.toString();
}

void _collectTextContent(XastParent parent, StringBuffer buffer) {
  for (final child in parent.children) {
    if (child is XastText) {
      buffer.write(child.value);
    } else if (child is XastCdata) {
      buffer.write(child.value);
    } else if (child is XastElement) {
      _collectTextContent(child, buffer);
    }
  }
}

/// Finds the first element matching the given name.
///
/// If [recursive] is true, searches all descendants.
/// Otherwise, only searches direct children.
///
/// Example:
/// ```dart
/// final rect = findElement(parent, 'rect');
/// ```
XastElement? findElement(
  XastParent parent,
  String name, {
  bool recursive = true,
}) {
  for (final child in parent.children) {
    if (child is XastElement) {
      if (child.name == name) {
        return child;
      }
      if (recursive) {
        final found = findElement(child, name, recursive: true);
        if (found != null) {
          return found;
        }
      }
    }
  }
  return null;
}

/// Finds all elements matching the given name.
///
/// Example:
/// ```dart
/// final rects = findElements(parent, 'rect');
/// ```
List<XastElement> findElements(
  XastParent parent,
  String name, {
  bool recursive = true,
}) {
  final results = <XastElement>[];
  _findElements(parent, name, recursive, results);
  return results;
}

void _findElements(
  XastParent parent,
  String name,
  bool recursive,
  List<XastElement> results,
) {
  for (final child in parent.children) {
    if (child is XastElement) {
      if (child.name == name) {
        results.add(child);
      }
      if (recursive) {
        _findElements(child, name, recursive, results);
      }
    }
  }
}

/// Returns the root element of an XAST tree.
///
/// For SVG documents, this is typically the `<svg>` element.
///
/// Example:
/// ```dart
/// final svg = getRootElement(root);
/// ```
XastElement? getRootElement(XastRoot root) {
  for (final child in root.children) {
    if (child is XastElement) {
      return child;
    }
  }
  return null;
}

/// Clones an XAST node (deep copy).
///
/// Example:
/// ```dart
/// final clone = cloneNode(element);
/// ```
XastNode cloneNode(XastNode node) {
  return switch (node) {
    XastRoot() => XastRoot(
        children: node.children.map((c) => cloneNode(c) as XastChild).toList(),
      ),
    XastDoctype() => XastDoctype(name: node.name, doctype: node.doctype),
    XastInstruction() => XastInstruction(name: node.name, value: node.value),
    XastComment() => XastComment(value: node.value),
    XastCdata() => XastCdata(value: node.value),
    XastText() => XastText(value: node.value),
    XastElement() => XastElement(
        name: node.name,
        attributes: Map.of(node.attributes),
        children: node.children.map((c) => cloneNode(c) as XastChild).toList(),
      ),
  };
}

/// Checks if an element matches a simple selector.
///
/// Supports:
/// - Tag name: `rect`, `circle`
/// - ID: `#myId`
/// - Class: `.myClass`
///
/// Example:
/// ```dart
/// if (matchesSelector(element, 'rect')) { ... }
/// if (matchesSelector(element, '#myId')) { ... }
/// if (matchesSelector(element, '.myClass')) { ... }
/// ```
bool matchesSelector(XastElement element, String selector) {
  selector = selector.trim();

  if (selector.isEmpty) {
    return false;
  }

  // ID selector
  if (selector.startsWith('#')) {
    final id = selector.substring(1);
    return element.attributes['id'] == id;
  }

  // Class selector
  if (selector.startsWith('.')) {
    final className = selector.substring(1);
    final classAttr = element.attributes['class'] ?? '';
    final classes = classAttr.split(RegExp(r'\s+'));
    return classes.contains(className);
  }

  // Tag name selector
  return element.name == selector;
}

/// Returns the depth of a node in the tree (root = 0).
int getNodeDepth(XastNode node, XastRoot root) {
  var depth = 0;
  var found = false;

  void search(XastParent parent, int currentDepth) {
    if (found) return;

    for (final child in parent.children) {
      if (identical(child, node)) {
        depth = currentDepth;
        found = true;
        return;
      }
      if (child is XastElement) {
        search(child, currentDepth + 1);
      }
    }
  }

  if (identical(node, root)) {
    return 0;
  }

  search(root, 1);
  return found ? depth : -1;
}
