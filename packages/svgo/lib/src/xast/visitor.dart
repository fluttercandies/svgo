/// Visitor pattern implementation for XAST traversal.
///
/// Provides a flexible way to traverse and transform XAST nodes using
/// the visitor pattern with enter/exit callbacks for each node type.
library;

import 'xast.dart';

/// A sentinel value that can be returned from enter callbacks to skip
/// visiting the children of the current node.
const visitSkip = #visitSkip;

/// Callbacks for visiting a specific node type.
///
/// Example:
/// ```dart
/// final callbacks = VisitorNode<XastElement>(
///   enter: (node, parent) {
///     print('Entering element: ${node.name}');
///   },
///   exit: (node, parent) {
///     print('Exiting element: ${node.name}');
///   },
/// );
/// ```
class VisitorNode<T extends XastNode> {
  /// Creates visitor callbacks.
  const VisitorNode({this.enter, this.exit});

  /// Called when entering a node.
  ///
  /// Return [visitSkip] to skip visiting children of this node.
  final Object? Function(T node, XastParent? parentNode)? enter;

  /// Called when exiting a node (after children have been visited).
  final void Function(T node, XastParent? parentNode)? exit;
}

/// Callbacks for visiting the root node.
class VisitorRoot {
  /// Creates visitor callbacks for the root node.
  const VisitorRoot({this.enter, this.exit});

  /// Called when entering the root node.
  final void Function(XastRoot node)? enter;

  /// Called when exiting the root node.
  final void Function(XastRoot node)? exit;
}

/// A visitor definition specifying callbacks for different node types.
///
/// Example:
/// ```dart
/// final visitor = Visitor(
///   element: VisitorNode(
///     enter: (node, parent) {
///       if (node.name == 'rect') {
///         print('Found a rect!');
///       }
///     },
///   ),
///   text: VisitorNode(
///     enter: (node, parent) {
///       print('Text: ${node.value}');
///     },
///   ),
/// );
/// ```
class Visitor {
  /// Creates a visitor with callbacks for each node type.
  const Visitor({
    this.root,
    this.doctype,
    this.instruction,
    this.comment,
    this.cdata,
    this.text,
    this.element,
  });

  /// Callbacks for root nodes.
  final VisitorRoot? root;

  /// Callbacks for DOCTYPE nodes.
  final VisitorNode<XastDoctype>? doctype;

  /// Callbacks for processing instruction nodes.
  final VisitorNode<XastInstruction>? instruction;

  /// Callbacks for comment nodes.
  final VisitorNode<XastComment>? comment;

  /// Callbacks for CDATA nodes.
  final VisitorNode<XastCdata>? cdata;

  /// Callbacks for text nodes.
  final VisitorNode<XastText>? text;

  /// Callbacks for element nodes.
  final VisitorNode<XastElement>? element;
}

/// Visits an XAST tree using the provided visitor.
///
/// The tree is traversed depth-first, calling enter callbacks before
/// visiting children and exit callbacks after.
///
/// Example:
/// ```dart
/// final elementsFound = <String>[];
/// visit(root, Visitor(
///   element: VisitorNode(
///     enter: (node, parent) {
///       elementsFound.add(node.name);
///     },
///   ),
/// ));
/// print('Found elements: $elementsFound');
/// ```
void visit(XastNode node, Visitor visitor, [XastParent? parentNode]) {
  final callbacks = _getCallbacks(node, visitor);

  // Call enter callback
  if (callbacks != null) {
    final result = _callEnter(node, parentNode, callbacks);
    if (result == visitSkip) {
      return;
    }
  }

  // Visit children
  if (node is XastRoot) {
    // Copy children array to not lose cursor when children is spliced
    for (final child in List.of(node.children)) {
      visit(child, visitor, node);
    }
  } else if (node is XastElement && parentNode != null) {
    // Visit element children if still attached to parent
    if (parentNode.children.contains(node)) {
      for (final child in List.of(node.children)) {
        visit(child, visitor, node);
      }
    }
  }

  // Call exit callback
  if (callbacks != null) {
    _callExit(node, parentNode, callbacks);
  }
}

Object? _getCallbacks(XastNode node, Visitor visitor) {
  return switch (node) {
    XastRoot() => visitor.root,
    XastDoctype() => visitor.doctype,
    XastInstruction() => visitor.instruction,
    XastComment() => visitor.comment,
    XastCdata() => visitor.cdata,
    XastText() => visitor.text,
    XastElement() => visitor.element,
  };
}

Object? _callEnter(XastNode node, XastParent? parentNode, Object callbacks) {
  if (callbacks is VisitorRoot && node is XastRoot) {
    callbacks.enter?.call(node);
    return null;
  }

  return switch ((callbacks, node)) {
    (VisitorNode<XastDoctype> v, XastDoctype n) => v.enter?.call(n, parentNode),
    (VisitorNode<XastInstruction> v, XastInstruction n) =>
      v.enter?.call(n, parentNode),
    (VisitorNode<XastComment> v, XastComment n) => v.enter?.call(n, parentNode),
    (VisitorNode<XastCdata> v, XastCdata n) => v.enter?.call(n, parentNode),
    (VisitorNode<XastText> v, XastText n) => v.enter?.call(n, parentNode),
    (VisitorNode<XastElement> v, XastElement n) => v.enter?.call(n, parentNode),
    _ => null,
  };
}

void _callExit(XastNode node, XastParent? parentNode, Object callbacks) {
  if (callbacks is VisitorRoot && node is XastRoot) {
    callbacks.exit?.call(node);
    return;
  }

  switch ((callbacks, node)) {
    case (VisitorNode<XastDoctype> v, XastDoctype n):
      v.exit?.call(n, parentNode);
    case (VisitorNode<XastInstruction> v, XastInstruction n):
      v.exit?.call(n, parentNode);
    case (VisitorNode<XastComment> v, XastComment n):
      v.exit?.call(n, parentNode);
    case (VisitorNode<XastCdata> v, XastCdata n):
      v.exit?.call(n, parentNode);
    case (VisitorNode<XastText> v, XastText n):
      v.exit?.call(n, parentNode);
    case (VisitorNode<XastElement> v, XastElement n):
      v.exit?.call(n, parentNode);
    default:
      break;
  }
}
