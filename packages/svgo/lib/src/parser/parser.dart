/// SVG parser.
///
/// Converts SVG XML strings into an Abstract Syntax Tree (XAST) representation
/// that can be manipulated by plugins.
library;

import 'package:xml/xml.dart';

import '../xast/xast.dart';
import '../collections/collections.dart';
import 'parser_error.dart';

/// Parses an SVG string into an XAST tree.
///
/// The parser handles:
/// - XML processing instructions (<?xml ...?>)
/// - DOCTYPE declarations
/// - Comments
/// - CDATA sections
/// - Elements with attributes
/// - Text nodes
///
/// Example:
/// ```dart
/// final ast = parseSvg('''
///   <?xml version="1.0" encoding="UTF-8"?>
///   <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
///     <rect x="0" y="0" width="100" height="100" fill="red"/>
///   </svg>
/// ''');
/// ```
///
/// Throws [SvgoParserError] if the SVG is malformed.
XastRoot parseSvg(String data, [String? from]) {
  final root = XastRoot();
  final stack = <XastParent>[root];

  XastParent current() => stack.last;

  void pushToContent(XastChild node) {
    current().children.add(node);
  }

  try {
    // Parse the XML document
    final document = XmlDocument.parse(data);

    // Process each node in the document
    _processNode(document, (node) {
      switch (node) {
        case XmlDeclaration():
          final attrs =
              node.attributes.map((a) => '${a.name}="${a.value}"').join(' ');
          pushToContent(XastInstruction(
            name: 'xml',
            value: attrs,
          ));

        case XmlDoctype():
          pushToContent(XastDoctype(
            name: 'svg',
            doctype: node.value ?? '',
          ));

        case XmlComment():
          pushToContent(XastComment(value: node.value.trim()));

        case XmlCDATA():
          pushToContent(XastCdata(value: node.value));

        case XmlText():
          final parent = current();
          String text = node.value;

          if (parent is XastElement) {
            if (textElems.contains(parent.name)) {
              pushToContent(XastText(value: text));
            } else {
              final trimmed = text.trim();
              if (trimmed.isNotEmpty) {
                pushToContent(XastText(value: trimmed));
              }
            }
          }

        case XmlElement():
          final element = XastElement(
            name: node.name.qualified,
            attributes: {
              for (final attr in node.attributes)
                _getAttributeName(attr): attr.value,
            },
          );

          pushToContent(element);
          stack.add(element);

          // Process children
          for (final child in node.children) {
            _processNode(child, (n) {
              switch (n) {
                case XmlComment():
                  element.children.add(XastComment(value: n.value.trim()));

                case XmlCDATA():
                  element.children.add(XastCdata(value: n.value));

                case XmlText():
                  String text = n.value;
                  if (textElems.contains(element.name)) {
                    element.children.add(XastText(value: text));
                  } else {
                    final trimmed = text.trim();
                    if (trimmed.isNotEmpty) {
                      element.children.add(XastText(value: trimmed));
                    }
                  }

                case XmlElement():
                  final childElement = XastElement(
                    name: n.name.qualified,
                    attributes: {
                      for (final attr in n.attributes)
                        _getAttributeName(attr): attr.value,
                    },
                  );
                  element.children.add(childElement);
                  stack.add(childElement);

                  // Recursively process nested children
                  for (final nestedChild in n.children) {
                    _processChildNode(nestedChild, stack);
                  }

                  stack.removeLast();

                default:
                  break;
              }
            });
          }

          stack.removeLast();

        default:
          break;
      }
    });
  } on XmlException catch (e) {
    // Extract line and column from error message if possible
    var line = 1;
    var column = 1;

    // Try to extract position from XmlException
    final message = e.toString();
    final posMatch = RegExp(r'at (\d+):(\d+)').firstMatch(message);
    if (posMatch != null) {
      line = int.tryParse(posMatch.group(1) ?? '1') ?? 1;
      column = int.tryParse(posMatch.group(2) ?? '1') ?? 1;
    }

    throw SvgoParserError(
      e.message,
      line,
      column,
      data,
      from,
    );
  } catch (e) {
    throw SvgoParserError(
      e.toString(),
      1,
      1,
      data,
      from,
    );
  }

  return root;
}

void _processNode(XmlNode node, void Function(XmlNode) handler) {
  if (node is XmlDocument) {
    for (final child in node.children) {
      _processNode(child, handler);
    }
  } else {
    handler(node);
  }
}

void _processChildNode(XmlNode node, List<XastParent> stack) {
  final current = stack.last;

  switch (node) {
    case XmlComment():
      if (current is XastElement) {
        current.children.add(XastComment(value: node.value.trim()));
      }

    case XmlCDATA():
      if (current is XastElement) {
        current.children.add(XastCdata(value: node.value));
      }

    case XmlText():
      if (current is XastElement) {
        String text = node.value;
        if (textElems.contains(current.name)) {
          current.children.add(XastText(value: text));
        } else {
          final trimmed = text.trim();
          if (trimmed.isNotEmpty) {
            current.children.add(XastText(value: trimmed));
          }
        }
      }

    case XmlElement():
      if (current is XastElement) {
        final element = XastElement(
          name: node.name.qualified,
          attributes: {
            for (final attr in node.attributes)
              _getAttributeName(attr): attr.value,
          },
        );
        current.children.add(element);
        stack.add(element);

        for (final child in node.children) {
          _processChildNode(child, stack);
        }

        stack.removeLast();
      }

    default:
      break;
  }
}

String _getAttributeName(XmlAttribute attr) {
  final prefix = attr.name.prefix;
  final local = attr.name.local;
  if (prefix != null && prefix.isNotEmpty) {
    return '$prefix:$local';
  }
  return local;
}

/// Parses an SVG string and returns the document info.
///
/// This is a lower-level function that provides access to parsing events
/// for advanced use cases.
XastRoot parseSvgWithEvents(String data, [String? from]) {
  return parseSvg(data, from);
}
