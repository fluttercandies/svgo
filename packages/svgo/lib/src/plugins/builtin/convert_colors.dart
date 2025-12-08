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

/// Configuration for currentColor conversion.
sealed class CurrentColorConfig {
  const CurrentColorConfig();
}

/// Disable currentColor conversion.
class CurrentColorDisabled extends CurrentColorConfig {
  const CurrentColorDisabled();
}

/// Convert all non-none colors to currentColor.
class CurrentColorEnabled extends CurrentColorConfig {
  const CurrentColorEnabled();
}

/// Convert only the exact matching color value to currentColor.
class CurrentColorExact extends CurrentColorConfig {
  final String value;
  const CurrentColorExact(this.value);
}

/// Convert colors matching the pattern to currentColor.
class CurrentColorPattern extends CurrentColorConfig {
  final RegExp pattern;
  const CurrentColorPattern(this.pattern);
}

/// Hex case conversion options.
enum ConvertColorsCase {
  /// Convert to lowercase.
  lower,

  /// Convert to uppercase.
  upper,

  /// Don't convert case.
  none,
}

/// Parameters for the convertColors plugin.
class ConvertColorsParams extends PluginParams {
  /// Convert matching colors to currentColor.
  final CurrentColorConfig currentColor;

  /// Convert color names to hex. Default: true
  final bool names2hex;

  /// Convert rgb() to hex. Default: true
  final bool rgb2hex;

  /// Convert hex case. Default: lower
  final ConvertColorsCase convertCase;

  /// Convert long hex to short hex. Default: true
  final bool shorthex;

  /// Convert hex to short color name. Default: true
  final bool shortname;

  const ConvertColorsParams({
    this.currentColor = const CurrentColorDisabled(),
    this.names2hex = true,
    this.rgb2hex = true,
    this.convertCase = ConvertColorsCase.lower,
    this.shorthex = true,
    this.shortname = true,
  });
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
const convertColors = Plugin<ConvertColorsParams>(
  name: 'convertColors',
  description: 'converts colors: rgb() to #rrggbb and #rrggbb to #rgb',
  defaultParams: ConvertColorsParams(),
  fn: _convertColorsFn,
);

Visitor? _convertColorsFn(
  XastRoot ast,
  ConvertColorsParams params,
  SvgoInfo info,
) {
  final currentColor = params.currentColor;
  final names2hex = params.names2hex;
  final rgb2hex = params.rgb2hex;
  final convertCase = params.convertCase;
  final shorthex = params.shorthex;
  final shortname = params.shortname;

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
          if (currentColor is! CurrentColorDisabled && maskCounter == 0) {
            bool matched;
            switch (currentColor) {
              case CurrentColorDisabled():
                matched = false;
              case CurrentColorEnabled():
                matched = val != 'none';
              case CurrentColorExact(:final value):
                matched = val == value;
              case CurrentColorPattern(:final pattern):
                matched = pattern.hasMatch(val);
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
          if (convertCase != ConvertColorsCase.none &&
              !_regUrlRef.hasMatch(val) &&
              val != 'currentColor') {
            switch (convertCase) {
              case ConvertColorsCase.lower:
                val = val.toLowerCase();
              case ConvertColorsCase.upper:
                val = val.toUpperCase();
              case ConvertColorsCase.none:
                break;
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
