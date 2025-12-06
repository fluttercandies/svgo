/// Removes deprecated attributes from SVG elements.
library;

import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css_visitor;

import '../../collections/collections.dart';
import '../../style/style.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeDeprecatedAttrs = Plugin(
  name: 'removeDeprecatedAttrs',
  description: 'removes deprecated attributes',
  params: {
    'removeUnsafe': false,
  },
  fn: _removeDeprecatedAttrsFn,
);

/// Extract attribute names used in CSS selectors.
Set<String> _extractAttributesInStylesheet(Stylesheet stylesheet) {
  final attributesInStylesheet = <String>{};

  for (final rule in stylesheet.rules) {
    try {
      final parsed = css_parser.parse(
        '${rule.selector} {}',
        errors: [],
      );
      if (parsed.topLevels.isNotEmpty) {
        final topLevel = parsed.topLevels.first;
        if (topLevel is css_visitor.RuleSet) {
          final selector = topLevel.selectorGroup;
          if (selector != null) {
            _extractAttributesFromSelector(selector, attributesInStylesheet);
          }
        }
      }
    } catch (_) {
      // Ignore parse errors
    }
  }

  return attributesInStylesheet;
}

/// Extract attribute names from a selector.
void _extractAttributesFromSelector(
  css_visitor.SelectorGroup group,
  Set<String> attributesInStylesheet,
) {
  for (final selector in group.selectors) {
    for (final simple in selector.simpleSelectorSequences) {
      final simpleSelector = simple.simpleSelector;
      if (simpleSelector is css_visitor.AttributeSelector) {
        attributesInStylesheet.add(simpleSelector.name);
      }
    }
  }
}

/// Process attributes based on deprecated definition.
void _processAttributes(
  XastElement node,
  Map<String, Set<String>>? deprecatedAttrs,
  bool removeUnsafe,
  Set<String> attributesInStylesheet,
) {
  if (deprecatedAttrs == null) return;

  final safe = deprecatedAttrs['safe'];
  if (safe != null) {
    for (final name in safe) {
      if (attributesInStylesheet.contains(name)) continue;
      node.attributes.remove(name);
    }
  }

  if (removeUnsafe) {
    final unsafe = deprecatedAttrs['unsafe'];
    if (unsafe != null) {
      for (final name in unsafe) {
        if (attributesInStylesheet.contains(name)) continue;
        node.attributes.remove(name);
      }
    }
  }
}

Visitor? _removeDeprecatedAttrsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final removeUnsafe = params['removeUnsafe'] == true;

  // Collect stylesheet to check for attribute selectors
  final stylesheet = collectStylesheet(ast);
  final attributesInStylesheet = _extractAttributesInStylesheet(stylesheet);

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Get element configuration
        final elemConfig = elems[node.name];
        if (elemConfig == null) {
          return null;
        }

        // Special case: xml:lang is safe to remove when lang exists
        if (elemConfig.attrsGroups.contains('core') &&
            node.attributes.containsKey('xml:lang') &&
            !attributesInStylesheet.contains('xml:lang') &&
            node.attributes.containsKey('lang')) {
          node.attributes.remove('xml:lang');
        }

        // Process deprecated attrs by attribute groups
        for (final attrsGroup in elemConfig.attrsGroups) {
          _processAttributes(
            node,
            attrsGroupsDeprecated[attrsGroup],
            removeUnsafe,
            attributesInStylesheet,
          );
        }

        // Process element-specific deprecated attributes
        _processAttributes(
          node,
          elemConfig.deprecated,
          removeUnsafe,
          attributesInStylesheet,
        );

        return null;
      },
    ),
  );
}
