/// Removes xlink namespace and replaces attributes with SVG 2 equivalents.
library;

import '../../collections/elems.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const _xlinkNamespace = 'http://www.w3.org/1999/xlink';

/// Elements that use xlink:href, but were deprecated in SVG 2 and therefore
/// don't support the SVG 2 href attribute.
///
/// @see https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/xlink:href
/// @see https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/href
const _legacyElements = {
  'cursor',
  'filter',
  'font-face-uri',
  'glyphRef',
  'tref'
};

/// Map of `xlink:show` values to the SVG 2 `target` attribute values.
///
/// @see https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/xlink:show#usage_notes
const _showToTarget = {'new': '_blank', 'replace': '_self'};

const removeXlink = Plugin(
  name: 'removeXlink',
  description:
      'remove xlink namespace and replaces attributes with the SVG 2 equivalent where applicable',
  params: {
    'includeLegacy': false,
  },
  fn: _removeXlinkFn,
);

Visitor? _removeXlinkFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final includeLegacy = params['includeLegacy'] == true;
  final xlinkPrefixes = <String>[];
  final overriddenPrefixes = <String>[];
  final usedInLegacyElement = <String>[];

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        for (final entry in node.attributes.entries) {
          if (entry.key.startsWith('xmlns:')) {
            final prefix = entry.key.split(':')[1];
            if (entry.value == _xlinkNamespace) {
              xlinkPrefixes.add(prefix);
              continue;
            }
            if (xlinkPrefixes.contains(prefix)) {
              overriddenPrefixes.add(prefix);
            }
          }
        }

        if (overriddenPrefixes.any((p) => xlinkPrefixes.contains(p))) {
          return null;
        }

        // Handle xlink:show -> target
        var showHandled = node.attributes.containsKey('target');
        for (final prefix in xlinkPrefixes.reversed) {
          final showAttr = '$prefix:show';
          if (node.attributes.containsKey(showAttr)) {
            final value = node.attributes[showAttr]!;
            final mapping = _showToTarget[value];

            if (showHandled || mapping == null) {
              node.attributes.remove(showAttr);
              continue;
            }

            // Only set target if it differs from the element's default
            final defaultTarget = elems[node.name]?.defaults?['target'];
            if (mapping != defaultTarget) {
              node.attributes['target'] = mapping;
            }

            node.attributes.remove(showAttr);
            showHandled = true;
          }
        }

        // Handle xlink:title -> <title> element
        for (final prefix in xlinkPrefixes) {
          final titleAttr = '$prefix:title';
          if (node.attributes.containsKey(titleAttr)) {
            final value = node.attributes[titleAttr]!;
            final hasTitle =
                node.children.any((c) => c is XastElement && c.name == 'title');
            if (!hasTitle) {
              final titleElement = XastElement(
                name: 'title',
                attributes: {},
                children: [XastText(value: value)],
              );
              node.children.insert(0, titleElement);
            }
            node.attributes.remove(titleAttr);
          }
        }

        // Handle xlink:href -> href
        for (final prefix in xlinkPrefixes) {
          final hrefAttr = '$prefix:href';
          if (node.attributes.containsKey(hrefAttr)) {
            if (_legacyElements.contains(node.name) && !includeLegacy) {
              usedInLegacyElement.add(prefix);
              return null;
            }
            if (!node.attributes.containsKey('href')) {
              node.attributes['href'] = node.attributes[hrefAttr]!;
            }
            node.attributes.remove(hrefAttr);
          }
        }

        return null;
      },
      exit: (node, parentNode) {
        final attrsToRemove = <String>[];

        for (final entry in node.attributes.entries) {
          final key = entry.key;
          final value = entry.value;

          final parts = key.split(':');
          if (parts.length == 2) {
            final prefix = parts[0];

            if (xlinkPrefixes.contains(prefix) &&
                !overriddenPrefixes.contains(prefix) &&
                !usedInLegacyElement.contains(prefix) &&
                !includeLegacy) {
              attrsToRemove.add(key);
              continue;
            }

            if (key.startsWith('xmlns:')) {
              final attr = parts[1];
              if (!usedInLegacyElement.contains(attr)) {
                if (value == _xlinkNamespace) {
                  xlinkPrefixes.remove(attr);
                  attrsToRemove.add(key);
                  continue;
                }
                if (overriddenPrefixes.contains(attr)) {
                  overriddenPrefixes.remove(attr);
                }
              }
            }
          }
        }

        for (final attr in attrsToRemove) {
          node.attributes.remove(attr);
        }

        return;
      },
    ),
  );
}
