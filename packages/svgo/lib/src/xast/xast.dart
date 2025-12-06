/// XML Abstract Syntax Tree (XAST) node definitions.
///
/// This module defines the node types used to represent SVG documents as
/// an abstract syntax tree. The structure follows the XAST specification
/// with SVG-specific extensions.
library;

// =============================================================================
// Base Types
// =============================================================================

/// Base class for all XAST nodes.
sealed class XastNode {
  const XastNode();

  /// Returns the type name of this node.
  String get type;
}

/// Base class for nodes that can contain children.
sealed class XastParent extends XastNode {
  const XastParent();

  /// The child nodes of this parent.
  List<XastChild> get children;
}

/// Base class for nodes that can be children of a parent node.
sealed class XastChild extends XastNode {
  const XastChild();
}

// =============================================================================
// Root Node
// =============================================================================

/// The root node of an SVG document.
///
/// Contains all top-level children including the SVG element,
/// XML processing instructions, DOCTYPE declarations, and comments.
///
/// Example:
/// ```dart
/// final root = XastRoot(children: [
///   XastInstruction(name: 'xml', value: 'version="1.0"'),
///   XastElement(name: 'svg', attributes: {}, children: []),
/// ]);
/// ```
class XastRoot extends XastParent {
  /// Creates a new root node.
  XastRoot({List<XastChild>? children}) : children = children ?? [];

  @override
  String get type => 'root';

  @override
  final List<XastChild> children;

  @override
  String toString() => 'XastRoot(${children.length} children)';
}

// =============================================================================
// Child Nodes
// =============================================================================

/// A DOCTYPE declaration node.
///
/// Example:
/// ```dart
/// final doctype = XastDoctype(
///   name: 'svg',
///   doctype: 'svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "..."',
/// );
/// ```
class XastDoctype extends XastChild {
  /// Creates a new DOCTYPE node.
  const XastDoctype({
    required this.name,
    required this.doctype,
  });

  @override
  String get type => 'doctype';

  /// The document type name (usually 'svg').
  final String name;

  /// The full DOCTYPE declaration content.
  final String doctype;

  @override
  String toString() => 'XastDoctype($name)';
}

/// An XML processing instruction node.
///
/// Example:
/// ```dart
/// final instruction = XastInstruction(
///   name: 'xml',
///   value: 'version="1.0" encoding="UTF-8"',
/// );
/// ```
class XastInstruction extends XastChild {
  /// Creates a new processing instruction node.
  XastInstruction({
    required this.name,
    required this.value,
  });

  @override
  String get type => 'instruction';

  /// The instruction target name.
  final String name;

  /// The instruction value.
  String value;

  @override
  String toString() => 'XastInstruction($name)';
}

/// A comment node.
///
/// Example:
/// ```dart
/// final comment = XastComment(value: 'This is a comment');
/// ```
class XastComment extends XastChild {
  /// Creates a new comment node.
  const XastComment({required this.value});

  @override
  String get type => 'comment';

  /// The comment content (without <!-- and -->).
  final String value;

  @override
  String toString() => 'XastComment(${value.length} chars)';
}

/// A CDATA section node.
///
/// Example:
/// ```dart
/// final cdata = XastCdata(value: 'Some <raw> content');
/// ```
class XastCdata extends XastChild {
  /// Creates a new CDATA node.
  XastCdata({required this.value});

  @override
  String get type => 'cdata';

  /// The CDATA content.
  String value;

  @override
  String toString() => 'XastCdata(${value.length} chars)';
}

/// A text node.
///
/// Example:
/// ```dart
/// final text = XastText(value: 'Hello World');
/// ```
class XastText extends XastChild {
  /// Creates a new text node.
  XastText({required this.value});

  @override
  String get type => 'text';

  /// The text content.
  String value;

  @override
  String toString() => 'XastText(${value.length} chars)';
}

/// An element node.
///
/// The main building block of SVG documents, representing XML elements
/// with attributes and children.
///
/// Example:
/// ```dart
/// final element = XastElement(
///   name: 'rect',
///   attributes: {
///     'x': '10',
///     'y': '20',
///     'width': '100',
///     'height': '50',
///     'fill': 'red',
///   },
///   children: [],
/// );
/// ```
class XastElement extends XastChild implements XastParent {
  /// Creates a new element node.
  XastElement({
    required this.name,
    Map<String, String>? attributes,
    List<XastChild>? children,
  })  : attributes = attributes ?? {},
        children = children ?? [];

  @override
  String get type => 'element';
  String name;

  /// The element attributes as a name-value map.
  final Map<String, String> attributes;

  @override
  final List<XastChild> children;

  /// Cached path data for path elements.
  /// This is used to preserve full precision path data between plugins
  /// (e.g., applyTransforms -> convertPathData) without going through
  /// string serialization which would lose precision.
  /// Similar to node_svgo's `pathJS` property.
  List<dynamic>? pathJS;

  /// Returns true if this element has the given attribute.
  bool hasAttribute(String name) => attributes.containsKey(name);

  /// Returns the value of the given attribute, or null if not present.
  String? getAttribute(String name) => attributes[name];

  /// Sets an attribute value.
  void setAttribute(String name, String value) {
    attributes[name] = value;
  }

  /// Removes an attribute.
  void removeAttribute(String name) {
    attributes.remove(name);
  }

  @override
  String toString() =>
      'XastElement($name, ${attributes.length} attrs, ${children.length} children)';
}

// =============================================================================
// Type Guards
// =============================================================================

/// Extension methods for type checking XAST nodes.
extension XastNodeTypeGuards on XastNode {
  /// Returns true if this is a root node.
  bool get isRoot => this is XastRoot;

  /// Returns true if this is an element node.
  bool get isElement => this is XastElement;

  /// Returns true if this is a text node.
  bool get isText => this is XastText;

  /// Returns true if this is a comment node.
  bool get isComment => this is XastComment;

  /// Returns true if this is a CDATA node.
  bool get isCdata => this is XastCdata;

  /// Returns true if this is a DOCTYPE node.
  bool get isDoctype => this is XastDoctype;

  /// Returns true if this is an instruction node.
  bool get isInstruction => this is XastInstruction;

  /// Returns true if this node can have children.
  bool get isParent => this is XastParent;

  /// Returns true if this is a child node type.
  bool get isChild => this is XastChild;
}
