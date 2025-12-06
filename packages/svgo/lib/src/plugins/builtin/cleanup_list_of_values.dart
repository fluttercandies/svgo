/// Cleanup list of values plugin.
///
/// Rounds list of values to a fixed precision.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Rounds list of values to the fixed precision.
///
/// This plugin optimizes numeric values in list-type attributes
/// such as `points`, `viewBox`, `enable-background`, etc.
///
/// **Example:**
/// ```xml
/// <!-- Before -->
/// <svg viewBox="0 0 200.28423 200.28423">
/// <polygon points="208.250977 77.1308594 223.069336"/>
///
/// <!-- After -->
/// <svg viewBox="0 0 200.284 200.284">
/// <polygon points="208.251 77.131 223.069"/>
/// ```
///
/// Parameters:
/// - `floatPrecision`: Number of decimal places (default: 3)
/// - `leadingZero`: Remove leading zeros (default: true)
/// - `defaultPx`: Remove default 'px' units (default: true)
/// - `convertToPx`: Convert absolute units to pixels (default: true)
const cleanupListOfValues = Plugin(
  name: 'cleanupListOfValues',
  description: 'rounds list of values to the fixed precision',
  params: {
    'floatPrecision': 3,
    'leadingZero': true,
    'defaultPx': true,
    'convertToPx': true,
  },
  fn: _cleanupListOfValuesFn,
);

final _regNumericValues = RegExp(
    r'^([-+]?\d*\.?\d+([eE][-+]?\d+)?)(px|pt|pc|mm|cm|m|in|ft|em|ex|%)?$');
final _regSeparator = RegExp(r'\s+,?\s*|,\s*');

const _absoluteLengths = <String, double>{
  'cm': 96 / 2.54,
  'mm': 96 / 25.4,
  'in': 96,
  'pt': 4 / 3,
  'pc': 16,
  'px': 1,
};

Visitor? _cleanupListOfValuesFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  final floatPrecision = (params['floatPrecision'] as num?)?.toInt() ?? 3;
  final leadingZero = params['leadingZero'] as bool? ?? true;
  final defaultPx = params['defaultPx'] as bool? ?? true;
  final convertToPx = params['convertToPx'] as bool? ?? true;

  String roundValues(String lists) {
    final roundedList = <String>[];

    for (final elem in lists.split(_regSeparator)) {
      final match = _regNumericValues.firstMatch(elem);
      final matchNew = elem.contains('new');

      if (match != null) {
        var num = double.parse(match.group(1)!);
        num = double.parse(num.toStringAsFixed(floatPrecision));
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
          str = num.toString();
        }

        // Remove default 'px' units
        if (defaultPx && units == 'px') {
          units = '';
        }

        roundedList.add(str + units);
      } else if (matchNew) {
        roundedList.add('new');
      } else if (elem.isNotEmpty) {
        roundedList.add(elem);
      }
    }

    return roundedList.join(' ');
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // List of attributes that contain lists of values
        const listAttributes = [
          'points',
          'enable-background',
          'viewBox',
          'stroke-dasharray',
          'dx',
          'dy',
          'x',
          'y',
        ];

        for (final attr in listAttributes) {
          if (node.attributes.containsKey(attr)) {
            node.attributes[attr] = roundValues(node.attributes[attr]!);
          }
        }
        return null;
      },
    ),
  );
}

/// Removes leading zero from a decimal number.
String _removeLeadingZero(double num) {
  var str = num.toString();

  if (num > 0 && num < 1) {
    str = str.substring(1); // Remove leading 0
  } else if (num > -1 && num < 0) {
    str = '-${str.substring(2)}'; // Remove leading 0 after minus
  }

  // Remove trailing zeros after decimal point
  if (str.contains('.')) {
    str = str.replaceAll(RegExp(r'0+$'), '');
    str = str.replaceAll(RegExp(r'\.$'), '');
  }

  return str;
}
