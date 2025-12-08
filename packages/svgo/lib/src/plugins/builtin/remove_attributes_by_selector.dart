/// Remove attributes by selector plugin.
///
/// Removes attributes of elements that match a CSS selector.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// A selector/attributes pair for the removeAttributesBySelector plugin.
class SelectorAttributesPair {
  final String selector;
  final List<String> attributes;

  const SelectorAttributesPair({
    required this.selector,
    required this.attributes,
  });
}

/// Parameters for the removeAttributesBySelector plugin.
class RemoveAttributesBySelectorParams extends PluginParams {
  /// List of selector/attributes configurations.
  final List<SelectorAttributesPair> selectors;

  const RemoveAttributesBySelectorParams({
    this.selectors = const [],
  });
}

/// Removes attributes of elements that match a CSS selector.
///
/// This plugin allows you to remove specific attributes from elements
/// that match a CSS selector.
///
/// **Example - Remove a single attribute:**
/// ```yaml
/// removeAttributesBySelector:
///   selector: "[fill='#00ff00']"
///   attributes: 'fill'
/// ```
///
/// **Before:**
/// ```xml
/// <rect x="0" y="0" width="100" height="100" fill="#00ff00" stroke="#00ff00"/>
/// ```
///
/// **After:**
/// ```xml
/// <rect x="0" y="0" width="100" height="100" stroke="#00ff00"/>
/// ```
const removeAttributesBySelector = Plugin<RemoveAttributesBySelectorParams>(
  name: 'removeAttributesBySelector',
  description: 'removes attributes of elements that match a css selector',
  defaultParams: RemoveAttributesBySelectorParams(),
  fn: _removeAttributesBySelectorFn,
);

Visitor? _removeAttributesBySelectorFn(
    XastRoot ast, RemoveAttributesBySelectorParams params, SvgoInfo info) {
  final selectors = params.selectors;

  if (selectors.isEmpty) {
    return null;
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        for (final selectorConfig in selectors) {
          final selector = selectorConfig.selector;
          final attributes = selectorConfig.attributes;

          // Simple selector matching
          if (_matchesSelector(node, selector)) {
            for (final attrName in attributes) {
              node.attributes.remove(attrName);
            }
          }
        }
        return null;
      },
    ),
  );
}

/// Simple CSS selector matcher.
/// Supports: element names, #id, .class, [attr], [attr=value], [attr='value']
bool _matchesSelector(XastElement node, String selector) {
  // Handle multiple selectors separated by comma
  if (selector.contains(',')) {
    return selector.split(',').any((s) => _matchesSelector(node, s.trim()));
  }

  // Parse selector parts
  var remaining = selector.trim();

  // Element name
  final nameMatch = RegExp(r'^([a-zA-Z][a-zA-Z0-9-]*)').firstMatch(remaining);
  if (nameMatch != null) {
    if (node.name != nameMatch.group(1)) {
      return false;
    }
    remaining = remaining.substring(nameMatch.end);
  }

  // ID selector #id
  final idMatches = RegExp(r'#([a-zA-Z_][a-zA-Z0-9_-]*)').allMatches(remaining);
  for (final match in idMatches) {
    if (node.attributes['id'] != match.group(1)) {
      return false;
    }
  }

  // Class selector .class
  final classMatches =
      RegExp(r'\.([a-zA-Z_][a-zA-Z0-9_-]*)').allMatches(remaining);
  for (final match in classMatches) {
    final nodeClasses = node.attributes['class']?.split(' ') ?? [];
    if (!nodeClasses.contains(match.group(1))) {
      return false;
    }
  }

  // Attribute selector [attr] or [attr=value] or [attr='value']
  final attrMatches = RegExp(
          r"\[([a-zA-Z_:][a-zA-Z0-9_:-]*)(?:=[\x27\x22]?([^\x27\x22\]]+)[\x27\x22]?)?\]")
      .allMatches(remaining);
  for (final match in attrMatches) {
    final attrName = match.group(1)!;
    final attrValue = match.group(2);

    if (!node.attributes.containsKey(attrName)) {
      return false;
    }

    if (attrValue != null && node.attributes[attrName] != attrValue) {
      return false;
    }
  }

  return true;
}
