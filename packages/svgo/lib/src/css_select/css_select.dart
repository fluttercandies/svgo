/// CSS Selector matching utilities.
///
/// Provides CSS selector matching functionality similar to css-select.
/// Supports tag names, IDs, classes, attribute selectors, and combinators.
library;

import '../xast/xast.dart';

/// Checks if an element matches a CSS selector.
///
/// Supports:
/// - Tag names: `rect`, `circle`, `*`
/// - ID selectors: `#myId`
/// - Class selectors: `.myClass`
/// - Attribute selectors: `[attr]`, `[attr=value]`, `[attr~=value]`, etc.
/// - Descendant combinator: `div p`
/// - Child combinator: `div > p`
/// - Adjacent sibling: `div + p`
/// - General sibling: `div ~ p`
/// - Compound selectors: `div.class#id`
/// - Selector lists: `div, span`
///
/// [element] The element to test.
/// [selector] The CSS selector string.
/// [parents] Optional map of element to parent relationships.
/// [siblings] Optional function to get siblings of an element.
bool matchesCssSelector(
  XastElement element,
  String selector, {
  Map<XastElement, XastParent>? parents,
  List<XastChild> Function(XastElement)? siblings,
}) {
  selector = selector.trim();
  if (selector.isEmpty) return false;

  // Handle selector list (comma-separated)
  if (selector.contains(',')) {
    return selector.split(',').any(
          (s) => matchesCssSelector(
            element,
            s.trim(),
            parents: parents,
            siblings: siblings,
          ),
        );
  }

  // Use simple matching (more reliable for our use case)
  return _matchesSelectorSimple(element, selector, parents, siblings);
}

/// Gets the parent element.
XastElement? _getParentElement(
  XastElement element,
  Map<XastElement, XastParent>? parents,
) {
  if (parents == null) return null;
  final parent = parents[element];
  if (parent is XastElement) return parent;
  return null;
}

/// Gets the previous sibling element.
XastElement? _getPreviousSibling(
  XastElement element,
  Map<XastElement, XastParent>? parents,
  List<XastChild> Function(XastElement)? siblings,
) {
  if (parents == null) return null;

  final parent = parents[element];
  if (parent == null) return null;

  List<XastChild> siblingList;
  if (siblings != null && parent is XastElement) {
    siblingList = siblings(parent);
  } else {
    siblingList = parent.children;
  }

  final index = siblingList.indexOf(element);
  if (index <= 0) return null;

  // Find the previous element sibling
  for (var i = index - 1; i >= 0; i--) {
    final sibling = siblingList[i];
    if (sibling is XastElement) return sibling;
  }
  return null;
}

/// Simple selector matching fallback.
bool _matchesSelectorSimple(
  XastElement element,
  String selector,
  Map<XastElement, XastParent>? parents,
  List<XastChild> Function(XastElement)? siblings,
) {
  selector = selector.trim();

  // Check if selector has combinators (but not inside attribute selectors)
  if (_hasCombinator(selector)) {
    return _matchesComplexSelectorSimple(element, selector, parents, siblings);
  }

  // Handle :not() pseudo-class
  final notMatch = RegExp(r':not\(([^)]+)\)').firstMatch(selector);
  if (notMatch != null) {
    final notSelector = notMatch.group(1)!;
    // Element must NOT match the inner selector
    if (_matchesCompoundSelectorSimple(element, notSelector)) {
      return false;
    }
    // Remove the :not() part and continue matching
    selector = selector.replaceFirst(notMatch.group(0)!, '');
  }

  // Skip other pseudo selectors
  if (selector.contains(':')) {
    // Remove pseudo parts for matching
    final colonIndex = selector.indexOf(':');
    selector = selector.substring(0, colonIndex);
    if (selector.isEmpty && notMatch != null) {
      return true; // Only :not() was present
    }
    if (selector.isEmpty) return false;
  }

  return _matchesCompoundSelectorSimple(element, selector);
}

/// Checks if selector has combinators (space, >, +, ~) outside of attribute selectors.
bool _hasCombinator(String selector) {
  var inBracket = false;
  var inQuote = false;
  var quoteChar = '';

  for (var i = 0; i < selector.length; i++) {
    final char = selector[i];

    if (!inBracket && !inQuote) {
      if (char == '[') {
        inBracket = true;
        continue;
      }
      // Check for combinators
      if (char == ' ' || char == '>') {
        // Check it's not just whitespace before/after brackets
        if (char == ' ') {
          // Find the next non-space character
          var j = i + 1;
          while (j < selector.length && selector[j] == ' ') {
            j++;
          }
          if (j < selector.length &&
              selector[j] != '[' &&
              selector[j] != '.' &&
              selector[j] != '#' &&
              selector[j] != ':') {
            return true;
          }
        } else {
          return true;
        }
      }
      if (char == '+' || char == '~') {
        return true;
      }
    } else if (inBracket) {
      if (!inQuote && (char == '"' || char == "'")) {
        inQuote = true;
        quoteChar = char;
      } else if (inQuote && char == quoteChar) {
        inQuote = false;
      } else if (!inQuote && char == ']') {
        inBracket = false;
      }
    }
  }
  return false;
}

/// Matches a compound selector (no combinators).
bool _matchesCompoundSelectorSimple(XastElement element, String selector) {
  var remaining = selector.trim();
  if (remaining.isEmpty) return true;

  // Universal selector
  if (remaining == '*') return true;

  // Element name (at the start)
  final nameMatch = RegExp(r'^([a-zA-Z][a-zA-Z0-9-]*)').firstMatch(remaining);
  if (nameMatch != null) {
    if (element.name != nameMatch.group(1)) {
      return false;
    }
    remaining = remaining.substring(nameMatch.end);
  }

  // ID selectors
  final idMatches = RegExp(r'#([a-zA-Z_][a-zA-Z0-9_-]*)').allMatches(remaining);
  for (final match in idMatches) {
    if (element.attributes['id'] != match.group(1)) {
      return false;
    }
  }

  // Class selectors
  final classMatches =
      RegExp(r'\.([a-zA-Z_][a-zA-Z0-9_-]*)').allMatches(remaining);
  for (final match in classMatches) {
    final elementClasses =
        element.attributes['class']?.split(RegExp(r'\s+')) ?? [];
    if (!elementClasses.contains(match.group(1))) {
      return false;
    }
  }

  // Attribute selectors
  final attrPattern = RegExp(
    r'''\[([a-zA-Z_:][a-zA-Z0-9_:-]*)(?:([~|^$*]?=)['"]?([^'"\]]+)['"]?)?\]''',
  );
  for (final match in attrPattern.allMatches(remaining)) {
    final attrName = match.group(1)!;
    final operator = match.group(2);
    final attrValue = match.group(3);

    if (!element.attributes.containsKey(attrName)) {
      return false;
    }

    if (operator != null && attrValue != null) {
      final elemValue = element.attributes[attrName]!;
      switch (operator) {
        case '=':
          if (elemValue != attrValue) return false;
        case '~=':
          if (!elemValue.split(RegExp(r'\s+')).contains(attrValue)) {
            return false;
          }
        case '|=':
          if (elemValue != attrValue && !elemValue.startsWith('$attrValue-')) {
            return false;
          }
        case '^=':
          if (!elemValue.startsWith(attrValue)) return false;
        case r'$=':
          if (!elemValue.endsWith(attrValue)) return false;
        case '*=':
          if (!elemValue.contains(attrValue)) return false;
      }
    }
  }

  return true;
}

/// Matches a complex selector with combinators.
bool _matchesComplexSelectorSimple(
  XastElement element,
  String selector,
  Map<XastElement, XastParent>? parents,
  List<XastChild> Function(XastElement)? siblings,
) {
  // Tokenize by combinators
  final tokens = _tokenizeSelector(selector);
  if (tokens.isEmpty) return false;

  // Start matching from the rightmost token
  var currentElement = element;
  var tokenIndex = tokens.length - 1;

  while (tokenIndex >= 0) {
    final token = tokens[tokenIndex];

    if (!_matchesCompoundSelectorSimple(currentElement, token.selector)) {
      return false;
    }

    tokenIndex--;
    if (tokenIndex < 0) break;

    // Get next element based on combinator
    final combinator = tokens[tokenIndex + 1].combinator;
    final nextElement = _findNextElementSimple(
      currentElement,
      combinator,
      parents,
      siblings,
    );

    if (nextElement == null) return false;
    currentElement = nextElement;
  }

  return true;
}

/// Selector token with combinator.
class _SelectorToken {
  final String selector;
  final String combinator;

  _SelectorToken(this.selector, this.combinator);
}

/// Tokenizes a complex selector.
List<_SelectorToken> _tokenizeSelector(String selector) {
  final tokens = <_SelectorToken>[];
  final combinatorPattern = RegExp(r'\s*([>+~])\s*|\s+');

  var lastEnd = 0;
  var lastCombinator = '';

  for (final match in combinatorPattern.allMatches(selector)) {
    final part = selector.substring(lastEnd, match.start).trim();
    if (part.isNotEmpty) {
      tokens.add(_SelectorToken(part, lastCombinator));
    }

    lastCombinator = match.group(1) ?? ' ';
    lastEnd = match.end;
  }

  // Add the last part
  final lastPart = selector.substring(lastEnd).trim();
  if (lastPart.isNotEmpty) {
    tokens.add(_SelectorToken(lastPart, lastCombinator));
  }

  return tokens;
}

/// Finds next element for simple matching.
XastElement? _findNextElementSimple(
  XastElement element,
  String combinator,
  Map<XastElement, XastParent>? parents,
  List<XastChild> Function(XastElement)? siblings,
) {
  switch (combinator) {
    case ' ':
    case '>':
      return _getParentElement(element, parents);
    case '+':
    case '~':
      return _getPreviousSibling(element, parents, siblings);
    default:
      return _getParentElement(element, parents);
  }
}

/// Query all elements matching a selector.
List<XastElement> querySelectorAll(
  XastParent root,
  String selector, {
  Map<XastElement, XastParent>? parents,
}) {
  final results = <XastElement>[];
  parents ??= _buildParentMap(root);

  void visit(XastParent node) {
    for (final child in node.children) {
      if (child is XastElement) {
        if (matchesCssSelector(child, selector, parents: parents)) {
          results.add(child);
        }
        visit(child);
      }
    }
  }

  visit(root);
  return results;
}

/// Query the first element matching a selector.
XastElement? querySelector(
  XastParent root,
  String selector, {
  Map<XastElement, XastParent>? parents,
}) {
  parents ??= _buildParentMap(root);

  XastElement? find(XastParent node) {
    for (final child in node.children) {
      if (child is XastElement) {
        if (matchesCssSelector(child, selector, parents: parents)) {
          return child;
        }
        final found = find(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  return find(root);
}

/// Builds a parent map for a tree.
Map<XastElement, XastParent> _buildParentMap(XastParent root) {
  final parents = <XastElement, XastParent>{};

  void visit(XastParent node) {
    for (final child in node.children) {
      if (child is XastElement) {
        parents[child] = node;
        visit(child);
      }
    }
  }

  visit(root);
  return parents;
}
