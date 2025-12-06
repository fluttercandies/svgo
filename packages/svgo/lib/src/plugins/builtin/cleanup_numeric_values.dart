/// Cleanup numeric values plugin.
///
/// Rounds numeric values and removes default 'px' units.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

final _regNumericValues = RegExp(
    r'^([-+]?\d*\.?\d+([eE][-+]?\d+)?)(px|pt|pc|mm|cm|m|in|ft|em|ex|%)?$');

/// Absolute length conversions relative to px.
const _absoluteLengths = {
  'cm': 96 / 2.54,
  'mm': 96 / 25.4,
  'in': 96.0,
  'pt': 4 / 3,
  'pc': 16.0,
  'px': 1.0,
};

/// Removes leading zero from numbers.
String _removeLeadingZero(double num) {
  var str = num.toString();

  // Remove trailing zeros after decimal point
  if (str.contains('.')) {
    str = str.replaceAll(RegExp(r'0+$'), '');
    if (str.endsWith('.')) {
      str = str.substring(0, str.length - 1);
    }
  }

  // Add leading zero back for very small numbers
  if (num != 0 && num > -1 && num < 1) {
    str = str.replaceFirst('0.', '.');
    str = str.replaceFirst('-0.', '-.');
  }

  return str;
}

/// Rounds numeric values and removes default 'px' units.
///
/// Example input:
/// ```xml
/// <svg width="100.00000px" height="50.12345px">
/// ```
///
/// Example output:
/// ```xml
/// <svg width="100" height="50.123">
/// ```
///
/// Parameters:
/// - `floatPrecision`: Decimal places for rounding. Default: 3
/// - `leadingZero`: Remove leading zeros (0.5 -> .5). Default: true
/// - `defaultPx`: Remove default 'px' units. Default: true
/// - `convertToPx`: Convert other absolute units to px if shorter. Default: true
const cleanupNumericValues = Plugin(
  name: 'cleanupNumericValues',
  description:
      'rounds numeric values to the fixed precision, removes default "px" units',
  params: {
    'floatPrecision': 3,
    'leadingZero': true,
    'defaultPx': true,
    'convertToPx': true,
  },
  fn: _cleanupNumericValuesFn,
);

Visitor? _cleanupNumericValuesFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  final floatPrecision = (params['floatPrecision'] as num?)?.toInt() ?? 3;
  final leadingZero = params['leadingZero'] != false;
  final defaultPx = params['defaultPx'] != false;
  final convertToPx = params['convertToPx'] != false;

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Handle viewBox attribute
        final viewBox = node.attributes['viewBox'];
        if (viewBox != null) {
          final numbers = viewBox.trim().split(RegExp(r'(?:\s,?|,)\s*'));
          node.attributes['viewBox'] = numbers.map((value) {
            final num = double.tryParse(value);
            if (num == null || num.isNaN) return value;
            final rounded = double.parse(num.toStringAsFixed(floatPrecision));
            return rounded == rounded.truncate()
                ? rounded.truncate().toString()
                : rounded.toString();
          }).join(' ');
        }

        // Handle other attributes
        for (final name in node.attributes.keys.toList()) {
          // The 'version' attribute is a text string and cannot be rounded
          if (name == 'version') continue;

          final value = node.attributes[name]!;
          final match = _regNumericValues.firstMatch(value);

          if (match != null) {
            var num = double.parse(
              double.parse(match.group(1)!).toStringAsFixed(floatPrecision),
            );
            var units = match.group(3) ?? '';

            // Convert absolute values to pixels
            if (convertToPx &&
                units.isNotEmpty &&
                _absoluteLengths.containsKey(units)) {
              final pxNum = double.parse(
                (_absoluteLengths[units]! * double.parse(match.group(1)!))
                    .toStringAsFixed(floatPrecision),
              );
              if (pxNum.toString().length < match.group(0)!.length) {
                num = pxNum;
                units = 'px';
              }
            }

            // Remove leading zero
            String str;
            if (leadingZero) {
              str = _removeLeadingZero(num);
            } else {
              str = num == num.truncate()
                  ? num.truncate().toString()
                  : num.toString();
            }

            // Remove default 'px' units
            if (defaultPx && units == 'px') {
              units = '';
            }

            node.attributes[name] = str + units;
          }
        }
        return null;
      },
    ),
  );
}
