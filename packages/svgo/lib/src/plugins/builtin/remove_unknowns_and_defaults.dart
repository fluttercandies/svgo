/// Removes unknown elements content and attributes, removes attrs with default values.
library;

import '../../collections/collections.dart';
import '../../style/style.dart' hide presentationNonInheritableGroupAttrs;
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Parameters for the removeUnknownsAndDefaults plugin.
class RemoveUnknownsAndDefaultsParams extends PluginParams {
  final bool unknownContent;
  final bool unknownAttrs;
  final bool defaultAttrs;
  final bool defaultMarkupDeclarations;
  final bool uselessOverrides;
  final bool keepDataAttrs;
  final bool keepAriaAttrs;
  final bool keepRoleAttr;

  const RemoveUnknownsAndDefaultsParams({
    this.unknownContent = true,
    this.unknownAttrs = true,
    this.defaultAttrs = true,
    this.defaultMarkupDeclarations = true,
    this.uselessOverrides = true,
    this.keepDataAttrs = true,
    this.keepAriaAttrs = true,
    this.keepRoleAttr = false,
  });
}

const removeUnknownsAndDefaults = Plugin<RemoveUnknownsAndDefaultsParams>(
  name: 'removeUnknownsAndDefaults',
  description:
      'removes unknown elements content and attributes, removes attrs with default values',
  defaultParams: RemoveUnknownsAndDefaultsParams(),
  fn: _removeUnknownsAndDefaultsFn,
);

// Pre-computed maps for efficient lookups
late final Map<String, Set<String>> _allowedChildrenPerElement;
late final Map<String, Set<String>> _allowedAttributesPerElement;
late final Map<String, Map<String, String>> _attributesDefaultsPerElement;
var _mapsInitialized = false;

void _initMaps() {
  if (_mapsInitialized) return;

  _allowedChildrenPerElement = {};
  _allowedAttributesPerElement = {};
  _attributesDefaultsPerElement = {};

  for (final entry in elems.entries) {
    final name = entry.key;
    final config = entry.value;

    // Build allowed children
    final allowedChildren = <String>{};
    if (config.content != null) {
      allowedChildren.addAll(config.content!);
    }
    if (config.contentGroups != null) {
      for (final groupName in config.contentGroups!) {
        final group = elemsGroups[groupName];
        if (group != null) {
          allowedChildren.addAll(group);
        }
      }
    }

    // Build allowed attributes
    final allowedAttributes = <String>{};
    if (config.attrs != null) {
      allowedAttributes.addAll(config.attrs!);
    }

    // Build attribute defaults
    final attributeDefaults = <String, String>{};
    if (config.defaults != null) {
      attributeDefaults.addAll(config.defaults!);
    }

    // Add attributes and defaults from attribute groups
    for (final groupName in config.attrsGroups) {
      final group = attrsGroups[groupName];
      if (group != null) {
        allowedAttributes.addAll(group);
      }
      final groupDefaults = attrsGroupsDefaults[groupName];
      if (groupDefaults != null) {
        for (final defaultEntry in groupDefaults.entries) {
          // Don't override element-specific defaults
          if (!attributeDefaults.containsKey(defaultEntry.key)) {
            attributeDefaults[defaultEntry.key] = defaultEntry.value;
          }
        }
      }
    }

    _allowedChildrenPerElement[name] = allowedChildren;
    _allowedAttributesPerElement[name] = allowedAttributes;
    _attributesDefaultsPerElement[name] = attributeDefaults;
  }

  _mapsInitialized = true;
}

Visitor? _removeUnknownsAndDefaultsFn(
  XastRoot ast,
  RemoveUnknownsAndDefaultsParams params,
  SvgoInfo info,
) {
  // Initialize lookup maps
  _initMaps();

  final unknownContent = params.unknownContent;
  final unknownAttrs = params.unknownAttrs;
  final defaultAttrs = params.defaultAttrs;
  final defaultMarkupDeclarations = params.defaultMarkupDeclarations;
  final uselessOverrides = params.uselessOverrides;
  final keepDataAttrs = params.keepDataAttrs;
  final keepAriaAttrs = params.keepAriaAttrs;
  final keepRoleAttr = params.keepRoleAttr;

  final stylesheet = collectStylesheet(ast);

  return Visitor(
    instruction: VisitorNode(
      enter: (node, parentNode) {
        if (defaultMarkupDeclarations) {
          node.value = node.value
              .replaceAll(RegExp(r'\s*standalone\s*=\s*(["\x27])no\1'), '');
        }
        return null;
      },
    ),
    element: VisitorNode(
      enter: (node, parentNode) {
        // Skip namespaced elements
        if (node.name.contains(':')) {
          return null;
        }
        // Skip visiting foreignObject subtree
        if (node.name == 'foreignObject') {
          return visitSkip;
        }

        // Remove unknown element's content
        if (unknownContent && parentNode is XastElement) {
          final allowedChildren =
              _allowedChildrenPerElement[parentNode.name] ?? {};

          if (allowedChildren.isEmpty) {
            // Remove unknown elements
            if (!_allowedChildrenPerElement.containsKey(node.name)) {
              detachNodeFromParent(node, parentNode);
              return null;
            }
          } else {
            // Remove not allowed children
            if (!allowedChildren.contains(node.name)) {
              detachNodeFromParent(node, parentNode);
              return null;
            }
          }
        }

        final allowedAttributes = _allowedAttributesPerElement[node.name];
        final attributesDefaults = _attributesDefaultsPerElement[node.name];

        Map<String, ComputedStyle>? computedParentStyle;
        if (parentNode is XastElement) {
          computedParentStyle = computeStyle(stylesheet, parentNode);
        }

        // Collect attributes to remove
        final attrsToRemove = <String>[];

        for (final entry in node.attributes.entries) {
          final name = entry.key;
          final value = entry.value;

          if (keepDataAttrs && name.startsWith('data-')) continue;
          if (keepAriaAttrs && name.startsWith('aria-')) continue;
          if (keepRoleAttr && name == 'role') continue;
          // Skip xmlns attribute
          if (name == 'xmlns') continue;
          // Skip namespaced attributes except xml:* and xlink:*
          if (name.contains(':')) {
            final prefix = name.split(':').first;
            if (prefix != 'xml' && prefix != 'xlink') continue;
          }

          // Remove unknown attributes
          if (unknownAttrs &&
              allowedAttributes != null &&
              !allowedAttributes.contains(name)) {
            attrsToRemove.add(name);
            continue;
          }

          // Remove default attrs
          if (defaultAttrs &&
              !node.attributes.containsKey('id') &&
              attributesDefaults != null &&
              attributesDefaults[name] == value) {
            // Keep defaults if parent has own or inherited style
            if (computedParentStyle?[name] == null &&
                !stylesheet.rules
                    .any((r) => includesAttrSelector(r.selector, name))) {
              attrsToRemove.add(name);
              continue;
            }
          }

          // Remove useless overrides
          if (uselessOverrides && !node.attributes.containsKey('id')) {
            final style = computedParentStyle?[name];
            if (!presentationNonInheritableGroupAttrs.contains(name) &&
                style != null &&
                style is StaticStyle &&
                style.value == value) {
              attrsToRemove.add(name);
              continue;
            }
          }
        }

        for (final attr in attrsToRemove) {
          node.attributes.remove(attr);
        }

        return null;
      },
    ),
  );
}
