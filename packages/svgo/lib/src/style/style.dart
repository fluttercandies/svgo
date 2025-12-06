/// CSS style parsing, computation, and manipulation utilities.
///
/// Handles CSS stylesheet parsing, declaration parsing, style computation
/// with specificity rules, and inheritance.
library;

import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css_visitor;

import '../collections/collections.dart';
import '../css_select/css_select.dart' show matchesCssSelector;
import '../types.dart';
import '../xast/xast.dart';

export '../types.dart'
    show
        Specificity,
        StylesheetDeclaration,
        StylesheetRule,
        ComputedStyle,
        StaticStyle,
        DynamicStyle;

// Token kind constants for CSS combinators and operators
abstract class _TokenKind {
  static const int COMBINATOR_DESCENDANT = 514;
  static const int COMBINATOR_PLUS = 515;
  static const int COMBINATOR_GREATER = 516;
  static const int COMBINATOR_TILDE = 517;
  static const int NO_MATCH = 0;
  static const int EQUALS = 61;
  static const int INCLUDES = 126;
  static const int DASH_MATCH = 124;
  static const int PREFIX_MATCH = 94;
  static const int SUFFIX_MATCH = 36;
  static const int SUBSTRING_MATCH = 42;
}

/// A stylesheet containing parsed rules and parent mappings.
class Stylesheet {
  /// The parsed CSS rules sorted by specificity.
  final List<StylesheetRule> rules;

  /// Parent node mappings for style inheritance.
  final Map<XastElement, XastParent> parents;

  const Stylesheet({
    required this.rules,
    required this.parents,
  });
}

/// Computes styles for an element.
typedef ComputedStyles = Map<String, ComputedStyle>;

/// Compares two CSS specificity values.
///
/// Returns:
/// - negative if [a] < [b]
/// - zero if [a] == [b]
/// - positive if [a] > [b]
int compareSpecificity(Specificity a, Specificity b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] < b[i]) return -1;
    if (a[i] > b[i]) return 1;
  }
  return 0;
}

/// Parses CSS style declarations from an inline style string.
///
/// Example:
/// ```dart
/// final declarations = parseStyleDeclarations('fill: red; stroke: blue');
/// // Returns:
/// // [
/// //   StylesheetDeclaration(name: 'fill', value: 'red', important: false),
/// //   StylesheetDeclaration(name: 'stroke', value: 'blue', important: false),
/// // ]
/// ```
List<StylesheetDeclaration> parseStyleDeclarations(String css) {
  final declarations = <StylesheetDeclaration>[];

  if (css.isEmpty) return declarations;

  try {
    // Parse as declaration list
    final stylesheet = css_parser.parse('dummy { $css }');
    final visitor = _DeclarationVisitor();
    stylesheet.visit(visitor);
    declarations.addAll(visitor.declarations);
  } catch (_) {
    // Fallback: simple parsing
    _parseDeclarationsSimple(css, declarations);
  }

  return declarations;
}

/// Simple fallback parser for CSS declarations.
void _parseDeclarationsSimple(String css, List<StylesheetDeclaration> result) {
  final parts = css.split(';');
  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;

    final colonIndex = trimmed.indexOf(':');
    if (colonIndex == -1) continue;

    var name = trimmed.substring(0, colonIndex).trim();
    var value = trimmed.substring(colonIndex + 1).trim();
    var important = false;

    if (value.toLowerCase().endsWith('!important')) {
      important = true;
      value = value.substring(0, value.length - 10).trim();
    }

    if (name.isNotEmpty && value.isNotEmpty) {
      result.add(StylesheetDeclaration(
        name: name,
        value: value,
        important: important,
      ));
    }
  }
}

/// CSS declaration visitor.
class _DeclarationVisitor extends css_visitor.Visitor {
  final declarations = <StylesheetDeclaration>[];

  @override
  void visitDeclaration(css_visitor.Declaration node) {
    final name = node.property;

    // Use span.text to get the original declaration text, preserving values
    final spanText = node.span.text;
    final colonIndex = spanText.indexOf(':');
    if (colonIndex == -1) return;

    var value = spanText.substring(colonIndex + 1).trim();
    final important = node.important;

    // Remove !important suffix if present (we track it separately)
    if (important) {
      value = value.replaceFirst(
          RegExp(r'\s*!important\s*$', caseSensitive: false), '');
    }

    if (value.isNotEmpty) {
      declarations.add(StylesheetDeclaration(
        name: name,
        value: value,
        important: important,
      ));
    }
  }
}

/// Simple expression printer.
class _ExpressionPrinter extends css_visitor.Visitor {
  final StringBuffer buffer;

  _ExpressionPrinter(this.buffer);

  @override
  void visitLiteralTerm(css_visitor.LiteralTerm node) {
    buffer.write(node.text);
    buffer.write(' ');
  }

  @override
  void visitNumberTerm(css_visitor.NumberTerm node) {
    buffer.write(node.text);
    buffer.write(' ');
  }

  @override
  void visitUnitTerm(css_visitor.UnitTerm node) {
    buffer.write(node.text);
    buffer.write(' ');
  }

  @override
  void visitHexColorTerm(css_visitor.HexColorTerm node) {
    buffer.write('#');
    buffer.write(node.text);
    buffer.write(' ');
  }

  @override
  void visitFunctionTerm(css_visitor.FunctionTerm node) {
    buffer.write(node.text);
    buffer.write('(');
    super.visitFunctionTerm(node);
    buffer.write(') ');
  }

  @override
  void visitUriTerm(css_visitor.UriTerm node) {
    buffer.write('url(');
    buffer.write(node.text);
    buffer.write(') ');
  }

  @override
  void visitOperatorComma(css_visitor.OperatorComma node) {
    buffer.write(', ');
  }

  @override
  void visitOperatorSlash(css_visitor.OperatorSlash node) {
    buffer.write('/ ');
  }
}

/// Parses a CSS stylesheet and extracts rules.
///
/// [css] The CSS stylesheet content.
/// [dynamic] Whether the stylesheet is from a dynamic context (media queries).
List<StylesheetRule> parseStylesheet(String css, {bool dynamic = false}) {
  final rules = <StylesheetRule>[];

  if (css.isEmpty) return rules;

  try {
    final stylesheet = css_parser.parse(css);
    final visitor = _StylesheetVisitor(dynamic: dynamic);
    stylesheet.visit(visitor);
    rules.addAll(visitor.rules);
  } catch (_) {
    // Parsing failed, return empty rules
  }

  return rules;
}

/// CSS stylesheet visitor.
class _StylesheetVisitor extends css_visitor.Visitor {
  final bool dynamic;
  final rules = <StylesheetRule>[];

  _StylesheetVisitor({this.dynamic = false});

  @override
  void visitRuleSet(css_visitor.RuleSet node) {
    final declarations = <StylesheetDeclaration>[];

    // Collect declarations
    for (final declaration in node.declarationGroup.declarations) {
      if (declaration is css_visitor.Declaration) {
        final expression = declaration.expression;
        if (expression != null) {
          final value = _expressionToString(expression);
          declarations.add(StylesheetDeclaration(
            name: declaration.property,
            value: value,
            important: declaration.important,
          ));
        }
      }
    }

    // Process selectors
    final selector = node.selectorGroup;
    if (selector != null) {
      for (final sel in selector.selectors) {
        final specificity = _computeSpecificity(sel);
        final hasPseudoClasses = _hasPseudoClasses(sel);

        rules.add(StylesheetRule(
          specificity: specificity,
          dynamic: hasPseudoClasses || dynamic,
          selector: _removePseudoClasses(sel),
          declarations: declarations,
        ));
      }
    }
  }

  @override
  void visitMediaDirective(css_visitor.MediaDirective node) {
    // Media queries are dynamic
    final nestedVisitor = _StylesheetVisitor(dynamic: true);
    for (final rule in node.rules) {
      rule.visit(nestedVisitor);
    }
    rules.addAll(nestedVisitor.rules);
  }

  @override
  void visitKeyFrameDirective(css_visitor.KeyFrameDirective node) {
    // Skip keyframes
  }

  String _expressionToString(css_visitor.Expression expression) {
    final buffer = StringBuffer();
    final printer = _ExpressionPrinter(buffer);
    expression.visit(printer);
    return buffer.toString().trim();
  }

  String _simpleSelectorToString(css_visitor.SimpleSelector selector) {
    if (selector is css_visitor.ElementSelector) {
      return selector.name;
    } else if (selector is css_visitor.ClassSelector) {
      return '.${selector.name}';
    } else if (selector is css_visitor.IdSelector) {
      return '#${selector.name}';
    } else if (selector is css_visitor.AttributeSelector) {
      final op = selector.operatorKind;
      if (op == _TokenKind.NO_MATCH) {
        return '[${selector.name}]';
      }
      final opStr = _attributeOperator(op);
      return '[${selector.name}$opStr"${selector.value}"]';
    } else if (selector is css_visitor.PseudoClassSelector) {
      return ':${selector.name}';
    } else if (selector is css_visitor.PseudoElementSelector) {
      return '::${selector.name}';
    } else if (selector is css_visitor.NamespaceSelector) {
      return '${selector.namespace}|${selector.nameAsSimpleSelector?.name ?? '*'}';
    }
    return '*';
  }

  String _attributeOperator(int kind) {
    switch (kind) {
      case _TokenKind.EQUALS:
        return '=';
      case _TokenKind.INCLUDES:
        return '~=';
      case _TokenKind.DASH_MATCH:
        return '|=';
      case _TokenKind.PREFIX_MATCH:
        return '^=';
      case _TokenKind.SUFFIX_MATCH:
        return '\$=';
      case _TokenKind.SUBSTRING_MATCH:
        return '*=';
      default:
        return '=';
    }
  }

  Specificity _computeSpecificity(css_visitor.Selector selector) {
    var ids = 0;
    var classes = 0;
    var types = 0;

    for (final seq in selector.simpleSelectorSequences) {
      final simple = seq.simpleSelector;
      if (simple is css_visitor.IdSelector) {
        ids++;
      } else if (simple is css_visitor.ClassSelector ||
          simple is css_visitor.AttributeSelector ||
          simple is css_visitor.PseudoClassSelector) {
        classes++;
      } else if (simple is css_visitor.ElementSelector ||
          simple is css_visitor.PseudoElementSelector) {
        if (simple is css_visitor.ElementSelector && simple.name != '*') {
          types++;
        } else if (simple is css_visitor.PseudoElementSelector) {
          types++;
        }
      }
    }

    return Specificity(ids, classes, types);
  }

  bool _hasPseudoClasses(css_visitor.Selector selector) {
    for (final seq in selector.simpleSelectorSequences) {
      if (seq.simpleSelector is css_visitor.PseudoClassSelector) {
        return true;
      }
    }
    return false;
  }

  String _removePseudoClasses(css_visitor.Selector selector) {
    final buffer = StringBuffer();
    for (final seq in selector.simpleSelectorSequences) {
      if (seq.simpleSelector is css_visitor.PseudoClassSelector) {
        continue;
      }
      if (seq.combinator == _TokenKind.COMBINATOR_DESCENDANT) {
        buffer.write(' ');
      } else if (seq.combinator == _TokenKind.COMBINATOR_PLUS) {
        buffer.write(' + ');
      } else if (seq.combinator == _TokenKind.COMBINATOR_GREATER) {
        buffer.write(' > ');
      } else if (seq.combinator == _TokenKind.COMBINATOR_TILDE) {
        buffer.write(' ~ ');
      }
      buffer.write(_simpleSelectorToString(seq.simpleSelector));
    }
    return buffer.toString().trim();
  }
}

/// Collects stylesheet rules from an XAST tree.
///
/// Finds all `<style>` elements and parses their CSS content.
///
/// Example:
/// ```dart
/// final stylesheet = collectStylesheet(root);
/// for (final rule in stylesheet.rules) {
///   print('${rule.selector}: ${rule.declarations}');
/// }
/// ```
Stylesheet collectStylesheet(XastRoot root) {
  final rules = <StylesheetRule>[];
  final parents = <XastElement, XastParent>{};

  void visitNode(XastChild node, XastParent parent) {
    if (node is XastElement) {
      parents[node] = parent;

      if (node.name == 'style') {
        final type = node.attributes['type'];
        if (type == null || type.isEmpty || type == 'text/css') {
          final media = node.attributes['media'];
          final dynamic = media != null && media != 'all';

          for (final child in node.children) {
            if (child is XastText || child is XastCdata) {
              final value =
                  child is XastText ? child.value : (child as XastCdata).value;
              rules.addAll(parseStylesheet(value, dynamic: dynamic));
            }
          }
        }
      }

      for (final child in node.children) {
        visitNode(child, node);
      }
    }
  }

  for (final child in root.children) {
    visitNode(child, root);
  }

  // Sort by specificity
  rules.sort((a, b) => compareSpecificity(a.specificity, b.specificity));

  return Stylesheet(rules: rules, parents: parents);
}

/// Computes the own style of an element (not including inheritance).
ComputedStyles _computeOwnStyle(
  Stylesheet stylesheet,
  XastElement node,
  Map<XastElement, XastParent>? parents,
) {
  final computedStyle = <String, ComputedStyle>{};
  final importantStyles = <String, bool>{};

  // Collect presentation attributes
  for (final entry in node.attributes.entries) {
    if (AttrsGroups.presentation.contains(entry.key)) {
      computedStyle[entry.key] = StaticStyle(
        inherited: false,
        value: entry.value,
      );
      importantStyles[entry.key] = false;
    }
  }

  // Collect matching rules
  for (final rule in stylesheet.rules) {
    if (matchesCssSelector(node, rule.selector, parents: parents)) {
      for (final decl in rule.declarations) {
        final computed = computedStyle[decl.name];
        if (computed is DynamicStyle) continue;

        if (rule.dynamic) {
          computedStyle[decl.name] = const DynamicStyle(
            inherited: false,
          );
          continue;
        }

        if (computed == null ||
            decl.important ||
            importantStyles[decl.name] == false) {
          computedStyle[decl.name] = StaticStyle(
            inherited: false,
            value: decl.value,
          );
          importantStyles[decl.name] = decl.important;
        }
      }
    }
  }

  // Collect inline styles
  final styleAttr = node.attributes['style'];
  if (styleAttr != null) {
    final styleDeclarations = parseStyleDeclarations(styleAttr);
    for (final decl in styleDeclarations) {
      final computed = computedStyle[decl.name];
      if (computed is DynamicStyle) continue;

      if (computed == null ||
          decl.important ||
          importantStyles[decl.name] == false) {
        computedStyle[decl.name] = StaticStyle(
          inherited: false,
          value: decl.value,
        );
        importantStyles[decl.name] = decl.important;
      }
    }
  }

  return computedStyle;
}

/// Computes the full style of an element including inheritance.
///
/// Example:
/// ```dart
/// final stylesheet = collectStylesheet(root);
/// final element = findElement(root, 'rect')!;
/// final styles = computeStyle(stylesheet, element);
///
/// if (styles['fill'] case StaticStyle(:final value)) {
///   print('fill: $value');
/// }
/// ```
ComputedStyles computeStyle(Stylesheet stylesheet, XastElement node) {
  final parents = stylesheet.parents;
  final computedStyles = _computeOwnStyle(stylesheet, node, parents);

  var parent = parents[node];
  while (parent != null && parent is! XastRoot) {
    if (parent is XastElement) {
      final inheritedStyles = _computeOwnStyle(stylesheet, parent, parents);
      for (final entry in inheritedStyles.entries) {
        if (computedStyles[entry.key] == null &&
            inheritableAttrs.contains(entry.key) &&
            !presentationNonInheritableGroupAttrs.contains(entry.key)) {
          final style = entry.value;
          if (style is StaticStyle) {
            computedStyles[entry.key] = StaticStyle(
              inherited: true,
              value: style.value,
            );
          } else {
            computedStyles[entry.key] = const DynamicStyle(
              inherited: true,
            );
          }
        }
      }
      parent = parents[parent];
    } else {
      break;
    }
  }

  return computedStyles;
}

/// Checks if a selector includes an attribute selector for the given attribute.
///
/// Classes and IDs are treated as attribute selectors, so you can check for
/// `.class` by passing `name: 'class'` or `#id` by passing `name: 'id'`.
///
/// [selector] The CSS selector string.
/// [name] The attribute name to check for.
/// [value] Optional specific value to match.
/// [traversed] If true, only check traversed (non-final) selectors.
bool includesAttrSelector(
  String selector,
  String name, {
  String? value,
  bool traversed = false,
}) {
  // Simple parsing: look for attribute selectors
  final attrPattern =
      RegExp(r'\[([^\]=~|^$*]+)(?:([~|^$*]?=)"?([^"\]]*)"?)?\]');

  // Handle class selector
  if (name == 'class') {
    final classPattern = RegExp(r'\.([a-zA-Z_-][a-zA-Z0-9_-]*)');
    for (final match in classPattern.allMatches(selector)) {
      if (value == null || match.group(1) == value) {
        if (!traversed || _isTraversed(selector, match.start)) {
          return true;
        }
      }
    }
  }

  // Handle id selector
  if (name == 'id') {
    final idPattern = RegExp(r'#([a-zA-Z_-][a-zA-Z0-9_-]*)');
    for (final match in idPattern.allMatches(selector)) {
      if (value == null || match.group(1) == value) {
        if (!traversed || _isTraversed(selector, match.start)) {
          return true;
        }
      }
    }
  }

  // Handle attribute selectors
  for (final match in attrPattern.allMatches(selector)) {
    final attrName = match.group(1);
    final attrValue = match.group(3);

    if (attrName == name) {
      if (value == null || attrValue == value) {
        if (!traversed || _isTraversed(selector, match.start)) {
          return true;
        }
      }
    }
  }

  return false;
}

/// Checks if a position in a selector is followed by a combinator (traversed).
bool _isTraversed(String selector, int position) {
  final rest = selector.substring(position);
  // Look for combinators after this position
  final combinatorPattern = RegExp(r'[\s>+~]');
  return combinatorPattern.hasMatch(rest);
}

/// Presentation attributes that are not inheritable when in a group.
const presentationNonInheritableGroupAttrs = {
  'display',
  'opacity',
  'visibility',
  'transform',
  'transform-origin',
  'clip-path',
  'mask',
  'filter',
};
