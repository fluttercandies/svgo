/// Inline styles plugin.
///
/// Merges styles from style elements into inline styles.
library;

import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css_visitor;

import '../../collections/collections.dart';
import '../../css_select/css_select.dart';
import '../../style/style.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../../xast/xast_utils.dart';
import '../plugin.dart';

/// Merges styles from style elements into inline styles.
///
/// This plugin inlines CSS rules from <style> elements into the
/// corresponding elements' style attributes.
///
/// **Example:**
/// ```xml
/// <!-- Before -->
/// <svg>
///   <style>.red { fill: red }</style>
///   <rect class="red"/>
/// </svg>
///
/// <!-- After -->
/// <svg>
///   <rect style="fill:red"/>
/// </svg>
/// ```
///
/// Parameters:
/// - `onlyMatchedOnce`: Only inline selectors that match exactly once (default: true)
/// - `removeMatchedSelectors`: Remove matched selectors from style element (default: true)
/// - `useMqs`: Media queries to process (default: ['', 'screen'])
/// - `usePseudos`: Pseudo-classes to process (default: [''])
const inlineStyles = Plugin(
  name: 'inlineStyles',
  description: 'inline styles (additional options)',
  params: {
    'onlyMatchedOnce': true,
    'removeMatchedSelectors': true,
    'useMqs': <String>['', 'screen'],
    'usePseudos': <String>[''],
  },
  fn: _inlineStylesFn,
);

/// Pseudo-classes that can be evaluated during optimization.
/// These are functional and tree-structural pseudo-classes that
/// can be evaluated statically.
final _preservedPseudos = {
  ...PseudoClasses.functional,
  ...PseudoClasses.treeStructural,
};

/// Parsed CSS rule with selector and declarations.
class _CssRule {
  final String selectorText;
  final String originalSelectorText; // Selector text with pseudo-classes
  final Specificity specificity;
  final List<_CssDeclaration> declarations;
  final bool hasPseudo;
  final int sourceIndex; // Track source order
  List<XastElement>? matchedElements;

  _CssRule({
    required this.selectorText,
    required this.originalSelectorText,
    required this.specificity,
    required this.declarations,
    required this.sourceIndex,
    this.hasPseudo = false,
  });
}

/// CSS declaration with property, value, and importance.
class _CssDeclaration {
  final String property;
  final String value;
  final bool important;

  _CssDeclaration({
    required this.property,
    required this.value,
    this.important = false,
  });
}

/// Style element with its parent and parsed CSS AST.
class _StyleElement {
  final XastElement node;
  final XastParent parent;
  final css_visitor.StyleSheet cssAst;
  final String originalCss;

  _StyleElement({
    required this.node,
    required this.parent,
    required this.cssAst,
    required this.originalCss,
  });
}

Visitor? _inlineStylesFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final onlyMatchedOnce = params['onlyMatchedOnce'] as bool? ?? true;
  final removeMatchedSelectors =
      params['removeMatchedSelectors'] as bool? ?? true;
  final useMqs = (params['useMqs'] as List?)?.cast<String>() ?? ['', 'screen'];
  final usePseudos =
      (params['usePseudos'] as List?)?.cast<String>() ?? <String>[''];

  final styleElements = <_StyleElement>[];
  final allRules = <_CssRule>[];

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Skip foreignObject
        if (node.name == 'foreignObject') {
          return visitSkip;
        }

        // Collect style elements
        if (node.name == 'style' && node.children.isNotEmpty) {
          final type = node.attributes['type'];
          if (type != null && type != '' && type != 'text/css') {
            return null;
          }

          final cssText = node.children
              .where((child) => child is XastText || child is XastCdata)
              .map((child) {
            if (child is XastText) return child.value;
            if (child is XastCdata) return child.value;
            return '';
          }).join('');

          try {
            final cssAst = css_parser.parse(cssText);

            if (parentNode != null) {
              styleElements.add(_StyleElement(
                node: node,
                parent: parentNode,
                cssAst: cssAst,
                originalCss: cssText,
              ));
            }

            // Extract rules from CSS AST
            _extractRules(cssAst, allRules, useMqs, usePseudos);

            // Also extract rules from text as a fallback for CSS that csslib
            // doesn't parse correctly
            _extractRulesFromText(cssText, allRules, useMqs, usePseudos);
          } catch (_) {
            // Failed to parse CSS AST, but we can still try text extraction
            if (parentNode != null) {
              // Create a minimal AST for the style element
              final emptyAst = css_visitor.StyleSheet([], null);
              styleElements.add(_StyleElement(
                node: node,
                parent: parentNode,
                cssAst: emptyAst,
                originalCss: cssText,
              ));
              _extractRulesFromText(cssText, allRules, useMqs, usePseudos);
            }
          }
        }

        return null;
      },
    ),
    root: VisitorRoot(
      exit: (node) {
        if (styleElements.isEmpty) {
          return;
        }

        // Sort rules by specificity (highest first),
        // same specificity: later source order first (like CSS cascade)
        final sortedRules = allRules.toList()
          ..sort((a, b) {
            final specCompare =
                -compareSpecificity(a.specificity, b.specificity);
            if (specCompare != 0) return specCompare;
            // Same specificity: later source order comes first
            return b.sourceIndex.compareTo(a.sourceIndex);
          });

        // Match and apply rules using querySelectorAll
        for (final rule in sortedRules) {
          // Use querySelectorAll for full CSS selector support
          List<XastElement> matchedElements;
          try {
            matchedElements = querySelectorAll(ast, rule.selectorText);
          } catch (_) {
            // If selector matching fails, skip this rule
            continue;
          }

          if (matchedElements.isEmpty) {
            continue;
          }

          // Skip if matched more than once and onlyMatchedOnce is true
          if (onlyMatchedOnce && matchedElements.length > 1) {
            continue;
          }

          // Apply styles
          for (final element in matchedElements) {
            _applyStylesToElement(element, rule, sortedRules);
          }

          rule.matchedElements = matchedElements;
        }

        // Clean up if needed
        if (!removeMatchedSelectors) {
          return;
        }

        // Clean up matched class + ID attribute values
        for (final rule in sortedRules) {
          final matched = rule.matchedElements;
          if (matched == null) continue;

          if (onlyMatchedOnce && matched.length > 1) {
            continue;
          }

          for (final element in matched) {
            _cleanupMatchedAttributes(element, rule, sortedRules);
          }
        }

        // Rebuild or remove style elements
        for (final style in styleElements) {
          final newCss = _rebuildCss(
            style.cssAst,
            sortedRules,
            style.originalCss,
          );

          if (newCss.trim().isEmpty) {
            detachNodeFromParent(style.node, style.parent);
          } else {
            final firstChild = style.node.children.first;
            if (firstChild is XastText) {
              firstChild.value = newCss;
            } else if (firstChild is XastCdata) {
              firstChild.value = newCss;
            }
          }
        }

        return;
      },
    ),
  );
}

/// Extracts CSS rules from the stylesheet AST.
void _extractRules(
  css_visitor.StyleSheet cssAst,
  List<_CssRule> rules,
  List<String> useMqs,
  List<String> usePseudos,
) {
  // Convert useMqs to lowercase for case-insensitive comparison
  final useMqsLower = useMqs.map((s) => s.toLowerCase()).toList();

  for (final topLevel in cssAst.topLevels) {
    if (topLevel is css_visitor.RuleSet) {
      _extractRulesFromRuleSet(topLevel, rules, '', useMqs, usePseudos);
    } else if (topLevel is css_visitor.MediaDirective) {
      // Build media query string using CssPrinter for complete output
      final printer = css_visitor.CssPrinter();
      printer.emitMediaQueries(topLevel.mediaQueries);
      final mediaQuery = printer.toString().trim();

      final fullMediaQuery = mediaQuery.isEmpty ? '' : 'media $mediaQuery';

      // Case-insensitive comparison
      final mediaQueryLower = mediaQuery.toLowerCase();
      final fullMediaQueryLower = fullMediaQuery.toLowerCase();

      if (useMqsLower.contains(mediaQueryLower) ||
          useMqsLower.contains(fullMediaQueryLower)) {
        for (final rule in topLevel.rules) {
          if (rule is css_visitor.RuleSet) {
            _extractRulesFromRuleSet(
                rule, rules, mediaQuery, useMqs, usePseudos);
          }
        }
      }
    }
  }
}

/// Extracts rules from a single RuleSet.
void _extractRulesFromRuleSet(
  css_visitor.RuleSet ruleSet,
  List<_CssRule> rules,
  String mediaQuery,
  List<String> useMqs,
  List<String> usePseudos,
) {
  final selectorGroup = ruleSet.selectorGroup;
  if (selectorGroup == null) return;

  // Extract declarations
  final declarations = <_CssDeclaration>[];
  for (final decl in ruleSet.declarationGroup.declarations) {
    if (decl is css_visitor.Declaration) {
      // Use span.text to get the original declaration text, preserving values
      final spanText = decl.span.text;
      // Extract value from "property: value" format
      final colonIndex = spanText.indexOf(':');
      if (colonIndex == -1) continue;

      var value = spanText.substring(colonIndex + 1).trim();
      // Remove !important suffix if present (we track it separately)
      if (decl.important) {
        value = value.replaceFirst(
            RegExp(r'\s*!important\s*$', caseSensitive: false), '');
      }

      if (value.isNotEmpty) {
        declarations.add(_CssDeclaration(
          property: decl.property,
          value: value,
          important: decl.important,
        ));
      }
    }
  }

  // Process each selector (even if declarations is empty, for cleanup)
  for (final selector in selectorGroup.selectors) {
    // Check for pseudo-classes/elements
    var hasPseudo = false;
    final pseudoNames = <String>[];

    for (final seq in selector.simpleSelectorSequences) {
      final simple = seq.simpleSelector;
      if (simple is css_visitor.PseudoClassSelector) {
        if (!_preservedPseudos.contains(simple.name)) {
          hasPseudo = true;
          pseudoNames.add(':${simple.name}');
        }
      } else if (simple is css_visitor.PseudoElementSelector) {
        if (!_preservedPseudos.contains(simple.name)) {
          hasPseudo = true;
          pseudoNames.add('::${simple.name}');
        }
      }
    }

    final pseudoSelector = pseudoNames.join('');
    if (hasPseudo && !usePseudos.contains(pseudoSelector)) {
      continue;
    }

    // Build selector text (without pseudo selectors if removing them)
    final selectorText = _selectorToString(selector, removePseudo: hasPseudo);
    final originalSelectorText =
        _selectorToString(selector, removePseudo: false);
    final specificity = _computeSpecificity(selector);

    rules.add(_CssRule(
      selectorText: selectorText,
      originalSelectorText: originalSelectorText,
      specificity: specificity,
      declarations: declarations,
      sourceIndex: rules.length, // Track source order
      hasPseudo: hasPseudo,
    ));
  }
}

/// Extracts CSS rules from raw text using regex.
/// This is a fallback for when csslib cannot parse certain CSS features.
void _extractRulesFromText(
  String css,
  List<_CssRule> rules,
  List<String> useMqs,
  List<String> usePseudos,
) {
  // Get existing selector texts to avoid duplicates
  final existingSelectors = rules.map((r) => r.selectorText).toSet();

  // Remove comments first
  var cleanCss = css.replaceAll(RegExp(r'/\*[^*]*\*+([^/*][^*]*\*+)*/'), '');

  // Remove @rules with blocks (like @document, @keyframes, etc.) to avoid
  // extracting rules from within them
  // First, handle simple @rules without blocks
  cleanCss = cleanCss.replaceAll(
    RegExp(r"@(charset|import|namespace)\s+[^;]+;", caseSensitive: false),
    '',
  );

  // Now remove @rules with blocks by finding matching braces
  cleanCss = _removeAtRulesWithBlocks(cleanCss);

  // Match simple rules: selector { declarations }
  // This regex handles basic rules but skips @rules and nested blocks
  final rulePattern = RegExp(
    r'([^{}]+)\s*\{([^{}]*)\}',
    multiLine: true,
  );

  for (final match in rulePattern.allMatches(cleanCss)) {
    final fullSelectorText = match.group(1)!.trim();
    final declarationsText = match.group(2)!.trim();

    // Skip empty declarations
    if (declarationsText.isEmpty) continue;

    // Skip if selector looks like an @rule or has special characters
    if (fullSelectorText.startsWith('@') ||
        fullSelectorText.startsWith('%') ||
        fullSelectorText.contains('%')) {
      continue;
    }

    // Parse declarations
    final declarations = <_CssDeclaration>[];
    final declParts = declarationsText.split(';');
    for (final part in declParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;

      final property = trimmed.substring(0, colonIndex).trim();
      var value = trimmed.substring(colonIndex + 1).trim();
      var important = false;

      if (value.toLowerCase().endsWith('!important')) {
        important = true;
        value = value.substring(0, value.length - 10).trim();
      }

      if (property.isNotEmpty && value.isNotEmpty) {
        declarations.add(_CssDeclaration(
          property: property,
          value: value,
          important: important,
        ));
      }
    }

    if (declarations.isEmpty) continue;

    // Split selector list into individual selectors
    final selectors = fullSelectorText.split(',').map((s) => s.trim()).toList();

    for (final selectorText in selectors) {
      // Skip empty selectors
      if (selectorText.isEmpty) continue;

      // Check if selector has pseudo-class/element (e.g., :hover, ::before)
      final hasPseudo = selectorText.contains(':');

      // For pseudo selectors, we need to extract the pseudo part and check usePseudos
      if (hasPseudo) {
        // Extract pseudo class/element
        final pseudoMatch = RegExp(r'(:[a-zA-Z-]+)').firstMatch(selectorText);
        if (pseudoMatch != null) {
          final pseudoSelector = pseudoMatch.group(1)!;
          // Skip this rule if pseudo is not in usePseudos
          if (!usePseudos.contains(pseudoSelector)) {
            continue;
          }
        } else {
          // Has colon but not a pseudo pattern, skip
          continue;
        }
      }

      // Remove pseudo part from selector for matching
      final selectorWithoutPseudo = hasPseudo
          ? selectorText.replaceAll(RegExp(r':+[a-zA-Z-]+'), '')
          : selectorText;

      // Skip if this selector was already extracted by AST parser
      if (existingSelectors.contains(selectorWithoutPseudo)) continue;

      // Compute specificity based on selector (without pseudo for matching)
      final specificity = _computeSpecificityFromText(selectorWithoutPseudo);

      rules.add(_CssRule(
        selectorText: selectorWithoutPseudo,
        originalSelectorText: selectorText,
        specificity: specificity,
        declarations: declarations,
        sourceIndex: rules.length,
        hasPseudo: hasPseudo,
      ));
    }
  }
}

/// Removes @rules with blocks from CSS text.
String _removeAtRulesWithBlocks(String css) {
  final result = StringBuffer();
  var i = 0;

  while (i < css.length) {
    // Check for @rule
    if (css[i] == '@') {
      // Find the type of @rule
      final ruleStart = i;
      i++;

      // Read the @rule name
      while (i < css.length && (css[i].contains(RegExp(r'[a-zA-Z-]')))) {
        i++;
      }

      final ruleName = css.substring(ruleStart + 1, i).toLowerCase();

      // Skip whitespace
      while (i < css.length && css[i].contains(RegExp(r'\s'))) {
        i++;
      }

      // Check if this @rule has a block
      if (_atRulesWithBlocks.contains(ruleName)) {
        // Find the opening brace and skip the entire block
        var braceCount = 0;
        var foundBrace = false;

        while (i < css.length) {
          if (css[i] == '{') {
            braceCount++;
            foundBrace = true;
          } else if (css[i] == '}') {
            braceCount--;
            if (foundBrace && braceCount == 0) {
              i++;
              break;
            }
          }
          i++;
        }
        // Don't add this @rule to result
        continue;
      }
      // For other @rules, include them
      result.write(css.substring(ruleStart, i));
    } else {
      result.write(css[i]);
      i++;
    }
  }

  return result.toString();
}

/// Set of @rules that have blocks which should be skipped
const _atRulesWithBlocks = {
  'font-face',
  'keyframes',
  'viewport',
  'page',
  'supports',
  'document',
  'media',
  'counter-style',
  'font-feature-values',
  'layer',
  'scope',
  'container',
  'starting-style',
};

/// Computes specificity from a selector text string.
Specificity _computeSpecificityFromText(String selector) {
  var ids = 0;
  var classes = 0;
  var types = 0;

  // Count IDs
  ids = RegExp(r'#[a-zA-Z_-][a-zA-Z0-9_-]*').allMatches(selector).length;

  // Count classes and attribute selectors
  classes = RegExp(r'\.[a-zA-Z_-][a-zA-Z0-9_-]*').allMatches(selector).length;
  classes += RegExp(r'\[[^\]]+\]').allMatches(selector).length;

  // Count type selectors (element names)
  // This is approximate - we look for word characters at the start or after combinators
  final typePattern =
      RegExp(r'(?:^|[\s>+~])([a-zA-Z][a-zA-Z0-9-]*)(?=[.#\[\s>+~]|$)');
  for (final match in typePattern.allMatches(selector)) {
    final name = match.group(1);
    if (name != null && name != '*') {
      types++;
    }
  }

  return Specificity(ids, classes, types);
}

/// Converts a selector to string.
String _selectorToString(css_visitor.Selector selector,
    {bool removePseudo = false}) {
  final buffer = StringBuffer();

  for (var i = 0; i < selector.simpleSelectorSequences.length; i++) {
    final seq = selector.simpleSelectorSequences[i];
    final simple = seq.simpleSelector;

    // Skip pseudo selectors if requested
    if (removePseudo &&
        (simple is css_visitor.PseudoClassSelector ||
            simple is css_visitor.PseudoElementSelector)) {
      continue;
    }

    // Add combinator (compact format without spaces)
    // 513 = COMBINATOR_NONE (no combinator, compound selector)
    if (i > 0 && seq.combinator != 513) {
      switch (seq.combinator) {
        case 514: // COMBINATOR_DESCENDANT
          buffer.write(' ');
          break;
        case 515: // COMBINATOR_PLUS
          buffer.write('+');
          break;
        case 516: // COMBINATOR_GREATER
          buffer.write('>');
          break;
        case 517: // COMBINATOR_TILDE
          buffer.write('~');
          break;
        case 519: // COMBINATOR_DEEP (/deep/)
          buffer.write('/deep/');
          break;
      }
    }

    buffer.write(_simpleSelectorToString(simple));
  }

  return buffer.toString().trim();
}

/// Converts a simple selector to string.
String _simpleSelectorToString(css_visitor.SimpleSelector simple) {
  if (simple is css_visitor.ElementSelector) {
    return simple.name;
  } else if (simple is css_visitor.ClassSelector) {
    return '.${simple.name}';
  } else if (simple is css_visitor.IdSelector) {
    return '#${simple.name}';
  } else if (simple is css_visitor.AttributeSelector) {
    // Check if it's an existence selector (no value)
    if (simple.value == null) {
      return '[${simple.name}]';
    }
    final op = _attributeOperator(simple.operatorKind);
    // Get the value as string - handle both Identifier and String types
    final rawValue = simple.value;
    final String value;
    if (rawValue is css_visitor.Identifier) {
      value = rawValue.name;
    } else if (rawValue is String) {
      value = rawValue;
    } else {
      value = rawValue.toString();
    }
    // Empty strings need quotes, as do strings with special characters
    if (value.isEmpty) {
      return '[${simple.name}$op""]';
    }
    // Don't add quotes if value is a simple identifier (no special chars)
    final needsQuotes = value.contains(' ') ||
        value.contains('"') ||
        value.contains("'") ||
        value.contains('[') ||
        value.contains(']');
    if (needsQuotes) {
      return '[${simple.name}$op"$value"]';
    }
    return '[${simple.name}$op$value]';
  } else if (simple is css_visitor.PseudoClassSelector) {
    return ':${simple.name}';
  } else if (simple is css_visitor.PseudoElementSelector) {
    return '::${simple.name}';
  } else if (simple is css_visitor.NegationSelector) {
    // Handle :not() selector
    final innerSelector = simple.negationArg;
    if (innerSelector != null) {
      final innerStr = _simpleSelectorToString(innerSelector);
      return ':not($innerStr)';
    }
    return ':not(*)';
  }
  return '*';
}

/// Converts attribute operator kind to string.
String _attributeOperator(int kind) {
  switch (kind) {
    case 61: // EQUALS
      return '=';
    case 126: // INCLUDES ~=
      return '~=';
    case 124: // DASH_MATCH |=
      return '|=';
    case 94: // PREFIX_MATCH ^=
      return '^=';
    case 36: // SUFFIX_MATCH $=
      return '\$=';
    case 42: // SUBSTRING_MATCH *=
      return '*=';
    default:
      return '=';
  }
}

/// Computes specificity for a selector.
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
    } else if (simple is css_visitor.ElementSelector) {
      if (simple.name != '*') {
        types++;
      }
    } else if (simple is css_visitor.PseudoElementSelector) {
      types++;
    }
  }

  return Specificity(ids, classes, types);
}

/// Applies styles from a rule to an element.
void _applyStylesToElement(
  XastElement element,
  _CssRule rule,
  List<_CssRule> allRules,
) {
  // Parse existing inline styles
  final existingStyleValues = <String, (String, bool)>{}; // (value, important)
  final existingStyleOrder = <String>[]; // Track order of existing styles
  final existingStyle = element.attributes['style'];

  if (existingStyle != null && existingStyle.isNotEmpty) {
    final decls = parseStyleDeclarations(existingStyle);
    for (final decl in decls) {
      existingStyleValues[decl.name] = (decl.value, decl.important);
      existingStyleOrder.add(decl.name);
    }
  }

  // Collect new declarations to insert (in order to insert at beginning)
  final newDeclarations =
      <(String, String, bool)>[]; // (property, value, important)

  // Apply new declarations
  for (final decl in rule.declarations) {
    // Remove presentation attribute if it exists and not referenced by attr selector
    if (AttrsGroups.presentation.contains(decl.property)) {
      final hasAttrSelector = allRules.any(
        (r) => includesAttrSelector(r.selectorText, decl.property),
      );
      if (!hasAttrSelector) {
        element.attributes.remove(decl.property);
      }
    }

    final existing = existingStyleValues[decl.property];

    if (existing == null) {
      // No existing style, add to new declarations (will be inserted at beginning)
      existingStyleValues[decl.property] = (decl.value, decl.important);
      newDeclarations.add((decl.property, decl.value, decl.important));
    } else if (!existing.$2 && decl.important) {
      // Existing is not important, new is important - replace
      existingStyleValues[decl.property] = (decl.value, decl.important);
    }
    // Otherwise keep existing (inline has higher priority)
  }

  // Rebuild style attribute with correct order:
  // new declarations first, then existing declarations
  if (existingStyleValues.isEmpty) {
    element.attributes.remove('style');
  } else {
    final parts = <String>[];

    // Add new declarations at the beginning (preserving their relative order)
    for (final (prop, value, important) in newDeclarations) {
      parts.add('$prop:$value${important ? '!important' : ''}');
    }

    // Add existing declarations (preserving their original order)
    for (final prop in existingStyleOrder) {
      final value = existingStyleValues[prop];
      if (value != null) {
        parts.add('$prop:${value.$1}${value.$2 ? '!important' : ''}');
      }
    }

    element.attributes['style'] = parts.join(';');
  }
}

/// Cleans up matched class/ID attributes.
void _cleanupMatchedAttributes(
  XastElement element,
  _CssRule rule,
  List<_CssRule> allRules,
) {
  // Clean up class attributes if selector has classes
  final classMatches = RegExp(r'\.([a-zA-Z_][a-zA-Z0-9_-]*)').allMatches(
    rule.selectorText,
  );

  for (final classMatch in classMatches) {
    final className = classMatch.group(1)!;

    // Check if class is used in other selectors
    final classUsedElsewhere = allRules.any((r) {
      if (r == rule) return false;
      if (r.matchedElements != null) return false; // Already processed
      return includesAttrSelector(r.selectorText, 'class',
          value: className, traversed: true);
    });

    if (!classUsedElsewhere) {
      final classAttr = element.attributes['class'];
      if (classAttr != null) {
        final classes =
            classAttr.split(' ').where((c) => c != className).toList();
        if (classes.isEmpty) {
          element.attributes.remove('class');
        } else {
          element.attributes['class'] = classes.join(' ');
        }
      }
    }
  }

  // Clean up ID attribute if selector has ID
  final idMatch = RegExp(r'#([a-zA-Z_][a-zA-Z0-9_-]*)').firstMatch(
    rule.selectorText,
  );
  if (idMatch != null) {
    final idName = idMatch.group(1)!;
    if (element.attributes['id'] == idName) {
      // Check if ID is used in other selectors
      final idUsedElsewhere = allRules.any((r) {
        if (r == rule) return false;
        if (r.matchedElements != null) return false;
        return includesAttrSelector(r.selectorText, 'id',
            value: idName, traversed: true);
      });

      if (!idUsedElsewhere) {
        element.attributes.remove('id');
      }
    }
  }
}

/// Compacts a CSS value by removing extra spaces before !important
String _compactCssValue(String value) {
  // Remove space before !important
  return value.replaceAll(
      RegExp(r'\s+!important', caseSensitive: false), '!important');
}

/// Minifies CSS text without full parsing.
/// This is used when csslib cannot correctly parse certain CSS features.
String _minifyCssText(String css) {
  // Remove comments
  var result = css.replaceAll(RegExp(r'/\*[^*]*\*+([^/*][^*]*\*+)*/'), '');

  // Remove newlines and collapse multiple spaces
  result = result.replaceAll(RegExp(r'\s+'), ' ');

  // Remove spaces around specific characters (but handle @rules specially)
  result = result.replaceAllMapped(
    RegExp(r'\s*([{};,>+~])\s*'),
    (m) => m.group(1)!,
  );

  // Handle colons - remove spaces around them but be careful with pseudo-selectors
  result = result.replaceAllMapped(
    RegExp(r'(\S)\s*:\s*(\S)'),
    (m) => '${m.group(1)}:${m.group(2)}',
  );

  // Remove spaces around brackets (for most cases)
  result = result.replaceAll(RegExp(r'\[\s*'), '[');
  result = result.replaceAll(RegExp(r'\s*\]'), ']');
  result = result.replaceAll(RegExp(r'\(\s*'), '(');
  result = result.replaceAll(RegExp(r'\s*\)'), ')');

  // Remove space between / and following text (for /deep/ selector)
  result = result.replaceAll(RegExp(r'/\s+'), '/');
  result = result.replaceAll(RegExp(r'\s+/'), '/');

  // Remove trailing semicolons before }
  result = result.replaceAll(RegExp(r';\s*}'), '}');

  // Remove space before !important
  result = result.replaceAll(RegExp(r'\s+!important'), '!important');

  // Restore space after @page before pseudo-selector
  // @page :first should have a space
  result = result.replaceAllMapped(
    RegExp(r'@page:'),
    (m) => '@page :',
  );

  // Restore space after @supports, @media before (
  result = result.replaceAllMapped(
    RegExp(r'@(supports|media)\('),
    (m) => '@${m.group(1)} (',
  );

  // Handle quotes: convert single quotes to double quotes for @charset
  result = result.replaceAllMapped(
    RegExp(r"@charset\s*'([^']*)'"),
    (m) => '@charset "${m.group(1)}"',
  );

  // Remove quotes around simple URL values (without special chars)
  result = result.replaceAllMapped(
    RegExp(r'''url\(['"]?([^'")]+)['"]?\)'''),
    (m) {
      final url = m.group(1)!;
      // Keep quotes if URL contains special characters
      if (url.contains(' ') || url.contains('(') || url.contains(')')) {
        return 'url("$url")';
      }
      return 'url($url)';
    },
  );

  // Restore space after commas inside function calls like rgba()
  // Match rgba(...) and add space after commas
  result = result.replaceAllMapped(
    RegExp(r'(rgba?|hsla?)\(([^)]+)\)'),
    (m) {
      final func = m.group(1)!;
      final args = m.group(2)!;
      // Add space after each comma
      final fixedArgs = args.replaceAll(',', ', ');
      return '$func($fixedArgs)';
    },
  );

  return result.trim();
}

/// Rebuilds CSS from AST, removing matched selectors/rules.
/// Falls back to text-based minification if AST reconstruction fails.
String _rebuildCss(
  css_visitor.StyleSheet cssAst,
  List<_CssRule> matchedRules,
  String originalCss,
) {
  // Get set of matched selector texts (original, with pseudo-classes)
  final matchedSelectors = <String>{};
  for (final rule in matchedRules) {
    if (rule.matchedElements != null && rule.matchedElements!.isNotEmpty) {
      matchedSelectors.add(rule.originalSelectorText);
    }
  }

  // Try to rebuild using AST first
  final buffer = StringBuffer();
  var astReconstructionValid = true;

  for (final topLevel in cssAst.topLevels) {
    if (topLevel is css_visitor.RuleSet) {
      final selectorGroup = topLevel.selectorGroup;
      if (selectorGroup == null) continue;

      // Separate matched and unmatched selectors
      final unmatchedSelectors = <css_visitor.Selector>[];
      for (final selector in selectorGroup.selectors) {
        final text = _selectorToString(selector);
        if (!matchedSelectors.contains(text)) {
          unmatchedSelectors.add(selector);
        }
      }

      if (unmatchedSelectors.isEmpty) {
        // All selectors matched, skip entire rule
        continue;
      }

      // Build compact CSS for unmatched selectors
      final selectorsText =
          unmatchedSelectors.map((s) => _selectorToString(s)).join(',');

      // Get declarations
      final declList = <String>[];
      for (final decl in topLevel.declarationGroup.declarations) {
        if (decl is css_visitor.Declaration) {
          final spanText = decl.span.text;
          final colonIndex = spanText.indexOf(':');
          if (colonIndex == -1) continue;
          var value = spanText.substring(colonIndex + 1).trim();
          // Remove trailing semicolon if present
          if (value.endsWith(';')) {
            value = value.substring(0, value.length - 1);
          }
          // Compact the value (remove space before !important)
          value = _compactCssValue(value);
          declList.add('${decl.property}:$value');
        }
      }

      // Skip empty rules
      if (declList.isEmpty) {
        // If we have selectors but no declarations, AST is likely corrupted
        if (selectorsText.isNotEmpty) {
          astReconstructionValid = false;
        }
        continue;
      }

      // Build the rule with compact format
      buffer.write('$selectorsText{${declList.join(';')}}');
    } else if (topLevel is css_visitor.MediaDirective) {
      // For @media, check if inner rules were matched
      final innerBuffer = StringBuffer();
      for (final rule in topLevel.rules) {
        if (rule is css_visitor.RuleSet) {
          final selectorGroup = rule.selectorGroup;
          if (selectorGroup == null) continue;

          // Separate matched and unmatched selectors
          final unmatchedSelectors = <css_visitor.Selector>[];
          for (final selector in selectorGroup.selectors) {
            final text = _selectorToString(selector);
            if (!matchedSelectors.contains(text)) {
              unmatchedSelectors.add(selector);
            }
          }

          if (unmatchedSelectors.isEmpty) {
            // All selectors matched, skip entire rule
            continue;
          }

          // Build compact CSS for unmatched selectors
          final selectorsText =
              unmatchedSelectors.map((s) => _selectorToString(s)).join(',');

          // Get declarations
          final declList = <String>[];
          for (final decl in rule.declarationGroup.declarations) {
            if (decl is css_visitor.Declaration) {
              final spanText = decl.span.text;
              final colonIndex = spanText.indexOf(':');
              if (colonIndex == -1) continue;
              var value = spanText.substring(colonIndex + 1).trim();
              // Remove trailing semicolon if present
              if (value.endsWith(';')) {
                value = value.substring(0, value.length - 1);
              }
              // Compact the value (remove space before !important)
              value = _compactCssValue(value);
              declList.add('${decl.property}:$value');
            }
          }

          // Skip empty rules
          if (declList.isEmpty) {
            continue;
          }

          // Build the rule with compact format
          innerBuffer.write('$selectorsText{${declList.join(';')}}');
        } else {
          // Other directives inside @media, just output as-is
          final tempStyleSheet = css_visitor.StyleSheet([rule], null);
          final printer = css_visitor.CssPrinter();
          printer.visitTree(tempStyleSheet, pretty: false);
          innerBuffer.write(printer.toString());
        }
      }

      // Output @media with its (potentially empty) content
      final mqPrinter = css_visitor.CssPrinter();
      mqPrinter.emitMediaQueries(topLevel.mediaQueries);
      // Convert to lowercase to match csso output
      final mediaQuery = mqPrinter.toString().trim().toLowerCase();
      buffer.write('@media $mediaQuery{${innerBuffer.toString()}}');
    } else if (topLevel is css_visitor.VarDefinitionDirective) {
      // VarDefinitionDirective often indicates a parsing failure (e.g., @document)
      // Mark AST as invalid and fall back to text-based minification
      astReconstructionValid = false;
    } else {
      // For @directives (like @charset, @font-face, @keyframes, etc.),
      // use CssPrinter in compact mode by wrapping in a temporary StyleSheet
      final tempStyleSheet = css_visitor.StyleSheet([topLevel], null);
      final printer = css_visitor.CssPrinter();
      printer.visitTree(tempStyleSheet, pretty: false);
      buffer.write(printer.toString());
    }
  }

  final astResult = buffer.toString().trim();

  // If AST reconstruction failed or produced empty/invalid result,
  // fall back to text-based minification with selector removal
  if (!astReconstructionValid || astResult.isEmpty) {
    // Remove matched selectors from original CSS, then minify
    var css = originalCss;
    for (final selector in matchedSelectors) {
      // Remove the matched rule from CSS text
      css = _removeRuleFromCss(css, selector);
    }
    return _minifyCssText(css);
  }

  return astResult;
}

/// Removes a CSS rule by selector from CSS text.
String _removeRuleFromCss(String css, String selector) {
  // Escape special regex characters in selector
  final escapedSelector = RegExp.escape(selector);
  // Match the selector and its block (handling nested braces)
  final pattern = RegExp(
    '$escapedSelector\\s*\\{[^}]*\\}',
    multiLine: true,
  );
  return css.replaceAll(pattern, '');
}
