/// Convert colors plugin.
///
/// Converts colors to shorter formats.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../collections/collections.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

final _regRGB = RegExp(
  r'^rgb\(\s*([-+]?(?:\d*\.\d+|\d+\.?)%?)\s*[,\s]\s*([-+]?(?:\d*\.\d+|\d+\.?)%?)\s*[,\s]\s*([-+]?(?:\d*\.\d+|\d+\.?)%?)\s*\)$',
);
final _regHEX = RegExp(r'^#(([a-fA-F0-9])\2){3}$');
final _regUrlRef = RegExp(r'url\(');

/// Converts [r, g, b] to #rrggbb.
String _convertRgbToHex(List<int> rgb) {
  final hexNumber = ((256 + rgb[0]) << 16) | (rgb[1] << 8) | rgb[2];
  return '#${hexNumber.toRadixString(16).substring(1).toUpperCase()}';
}

/// Converts colors to shorter formats.
///
/// @see https://www.w3.org/TR/SVG11/types.html#DataTypeColor
/// @see https://www.w3.org/TR/SVG11/single-page.html#types-ColorKeywords
///
/// Example conversions:
/// - `fuchsia` → `#ff00ff` (name to hex)
/// - `rgb(255, 0, 255)` → `#ff00ff` (rgb to hex)
/// - `#aabbcc` → `#abc` (short hex)
/// - `#000080` → `navy` (short name)
///
/// Parameters:
/// - `currentColor`: Convert matching colors to currentColor. Default: false
/// - `names2hex`: Convert color names to hex. Default: true
/// - `rgb2hex`: Convert rgb() to hex. Default: true
/// - `convertCase`: Convert hex case: 'lower', 'upper', or false. Default: 'lower'
/// - `shorthex`: Convert long hex to short hex. Default: true
/// - `shortname`: Convert hex to short color name. Default: true
const convertColors = Plugin(
  name: 'convertColors',
  description: 'converts colors: rgb() to #rrggbb and #rrggbb to #rgb',
  params: {
    'currentColor': false,
    'names2hex': true,
    'rgb2hex': true,
    'convertCase': 'lower',
    'shorthex': true,
    'shortname': true,
  },
  fn: _convertColorsFn,
);

Visitor? _convertColorsFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  final currentColor = params['currentColor'];
  final names2hex = params['names2hex'] != false;
  final rgb2hex = params['rgb2hex'] != false;
  final convertCase = params['convertCase'];
  final shorthex = params['shorthex'] != false;
  final shortname = params['shortname'] != false;

  var maskCounter = 0;

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'mask') {
          maskCounter++;
        }

        for (final name in node.attributes.keys.toList()) {
          if (!colorsProps.contains(name)) continue;

          var val = node.attributes[name]!;

          // Convert colors to currentColor
          if (currentColor != null &&
              currentColor != false &&
              maskCounter == 0) {
            bool matched;
            if (currentColor is String) {
              matched = val == currentColor;
            } else if (currentColor is RegExp) {
              matched = currentColor.hasMatch(val);
            } else {
              matched = val != 'none';
            }
            if (matched) {
              val = 'currentColor';
            }
          }

          // Convert color name keyword to long hex
          if (names2hex) {
            final colorName = val.toLowerCase();
            if (colorsNames.containsKey(colorName)) {
              val = colorsNames[colorName]!;
            }
          }

          // Convert rgb() to long hex
          if (rgb2hex) {
            final match = _regRGB.firstMatch(val);
            if (match != null) {
              final numbers = [
                match.group(1)!,
                match.group(2)!,
                match.group(3)!,
              ].map((m) {
                int n;
                if (m.contains('%')) {
                  n = (double.parse(m.replaceAll('%', '')) * 2.55).round();
                } else {
                  n = int.parse(m);
                }
                return n.clamp(0, 255);
              }).toList();
              val = _convertRgbToHex(numbers);
            }
          }

          // Convert case
          if (convertCase != null &&
              convertCase != false &&
              !_regUrlRef.hasMatch(val) &&
              val != 'currentColor') {
            if (convertCase == 'lower') {
              val = val.toLowerCase();
            } else if (convertCase == 'upper') {
              val = val.toUpperCase();
            }
          }

          // Convert long hex to short hex
          if (shorthex) {
            final match = _regHEX.firstMatch(val);
            if (match != null) {
              val = '#${val[1]}${val[3]}${val[5]}';
            }
          }

          // Convert hex to short name
          if (shortname) {
            final colorName = val.toLowerCase();
            if (colorsShortNames.containsKey(colorName)) {
              val = colorsShortNames[colorName]!;
            }
          }

          node.attributes[name] = val;
        }
        return null;
      },
      exit: (node, parentNode) {
        if (node.name == 'mask') {
          maskCounter--;
        }
        return;
      },
    ),
  );
}
