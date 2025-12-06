/// SVG path data stringification.
///
/// Converts path data items back to an SVG path string with configurable
/// precision and formatting options.
library;

import '../types.dart';

/// Options for path data stringification.
class PathStringifyOptions {
  /// Number of decimal places for coordinate values.
  ///
  /// Default is 3.
  final int floatPrecision;

  /// Omit space after command letter.
  ///
  /// Default is true.
  final bool removeLeadingSpace;

  /// Remove leading zero from floating-point numbers.
  ///
  /// For example, `0.5` becomes `.5`, `-0.5` becomes `-.5`.
  /// Default is true.
  final bool leadingZero;

  /// Use short arc commands format when possible.
  ///
  /// When true, arc flags can be written without separator: `a20 60 45 0130 20`.
  /// When false (default), arc flags have spaces: `a20 60 45 0 1 30 20`.
  /// Default is false (compatible with more environments).
  final bool useShortArcFlags;

  /// Allow negative numbers to be written without space.
  ///
  /// For example, `10 -5` can be written as `10-5`.
  /// Also allows decimals without space after previous decimal: `.5.5`.
  /// Default is true.
  final bool negativeExtraSpace;

  const PathStringifyOptions({
    this.floatPrecision = 3,
    this.removeLeadingSpace = true,
    this.leadingZero = true,
    this.useShortArcFlags = false,
    this.negativeExtraSpace = true,
  });

  /// Default stringify options.
  static const PathStringifyOptions defaults = PathStringifyOptions();
}

/// Rounds a number to the specified precision and converts to string.
/// Always removes trailing zeros from decimal numbers.
/// Uses scientific notation for very small numbers (like JavaScript does).
String _roundNumber(double value, int precision) {
  final factor = _pow10(precision);
  final rounded = (value * factor).round() / factor;

  if (rounded == rounded.truncate()) {
    return rounded.truncate().toString();
  }

  // Use toString() first to get scientific notation for very small numbers
  // JavaScript does this automatically: (0.0000001).toString() => "1e-7"
  final strValue = rounded.toString();

  // If it's already in scientific notation, keep it
  if (strValue.contains('e')) {
    return strValue;
  }

  // Otherwise use toStringAsFixed for normal numbers
  var result = rounded.toStringAsFixed(precision);

  // Remove trailing zeros
  while (result.endsWith('0')) {
    result = result.substring(0, result.length - 1);
  }
  if (result.endsWith('.')) {
    result = result.substring(0, result.length - 1);
  }

  return result;
}

/// Removes leading zero from floating-point numbers.
/// 0.5 → .5
/// -0.5 → -.5
String _removeLeadingZero(String value) {
  if (value.length > 1 && value[0] == '0' && value[1] == '.') {
    return value.substring(1);
  }
  if (value.length > 2 &&
      value[0] == '-' &&
      value[1] == '0' &&
      value[2] == '.') {
    return '-${value.substring(2)}';
  }
  return value;
}

/// Returns 10^n for small positive integers efficiently.
double _pow10(int n) {
  switch (n) {
    case 0:
      return 1;
    case 1:
      return 10;
    case 2:
      return 100;
    case 3:
      return 1000;
    case 4:
      return 10000;
    case 5:
      return 100000;
    case 6:
      return 1000000;
    default:
      var result = 1.0;
      for (var i = 0; i < n; i++) {
        result *= 10;
      }
      return result;
  }
}

/// Checks if a space is needed between two consecutive numbers.
/// This implements the negativeExtraSpace optimization.
bool _needsDelimiter(
  String prevStr,
  String currStr,
  double currValue,
  double prevValue,
  bool negativeExtraSpace,
) {
  if (prevStr.isEmpty) return false;

  // No extra space in front of negative number
  if (negativeExtraSpace && currValue < 0) {
    return false;
  }

  // No extra space in front of a floating number if previous is also floating
  if (negativeExtraSpace &&
      currStr.isNotEmpty &&
      currStr[0] == '.' &&
      prevValue != prevValue.truncateToDouble()) {
    return false;
  }

  return true;
}

/// Converts a row of numbers to an optimized string view.
/// This matches node_svgo's cleanupOutData function.
String _cleanupOutData(
  List<double> data,
  PathStringifyOptions options, [
  PathDataCommand? command,
]) {
  final buffer = StringBuffer();
  double prev = 0;

  for (var i = 0; i < data.length; i++) {
    final item = data[i];
    var delimiter = ' ';

    // no extra space in front of first number
    if (i == 0) {
      delimiter = '';
    }

    // no extra space after arc command flags (large-arc and sweep flags)
    if (options.useShortArcFlags &&
        (command == PathDataCommand.A || command == PathDataCommand.a)) {
      final pos = i % 7;
      if (pos == 4 || pos == 5) {
        delimiter = '';
      }
    }

    // Round the value first
    var itemStr = _roundNumber(item, options.floatPrecision);

    // remove floating-point numbers leading zeros
    if (options.leadingZero) {
      itemStr = _removeLeadingZero(itemStr);
    }

    // no extra space in front of negative number or
    // in front of a floating number if a previous number is floating too
    if (options.negativeExtraSpace &&
        delimiter.isNotEmpty &&
        (item < 0 ||
            (itemStr.isNotEmpty &&
                itemStr[0] == '.' &&
                prev != prev.truncateToDouble()))) {
      delimiter = '';
    }

    prev = item;
    buffer.write(delimiter);
    buffer.write(itemStr);
  }

  return buffer.toString();
}

/// Stringifies path data items into an SVG path data string.
///
/// Example:
/// ```dart
/// final pathData = [
///   PathDataItem(PathDataCommand.M, [10, 20]),
///   PathDataItem(PathDataCommand.L, [30, 40]),
///   PathDataItem(PathDataCommand.Z, []),
/// ];
/// final pathString = stringifyPathData(pathData);
/// // Returns: 'M10 20L30 40Z'
/// ```
///
/// [pathData] The list of path data items to stringify.
/// [options] Options for controlling the output format.
String stringifyPathData(
  List<PathDataItem> pathData, [
  PathStringifyOptions options = PathStringifyOptions.defaults,
]) {
  if (pathData.isEmpty) return '';

  if (pathData.length == 1) {
    final item = pathData[0];
    var strData = '';
    if (item.args.isNotEmpty) {
      strData = _cleanupOutData(item.args, options, item.command);
    }
    return item.command.value + strData;
  }

  final buffer = StringBuffer();

  // Create a copy of the first item to potentially modify its command
  var firstCommand = pathData[0].command;
  final firstArgs = pathData[0].args;

  // Match leading moveto with following lineto:
  // If M is followed by l, change M to m
  // If m is followed by L, change m to M
  if (pathData.length > 1) {
    final secondCommand = pathData[1].command;
    if (firstCommand == PathDataCommand.M &&
        secondCommand == PathDataCommand.l) {
      firstCommand = PathDataCommand.m;
    } else if (firstCommand == PathDataCommand.m &&
        secondCommand == PathDataCommand.L) {
      firstCommand = PathDataCommand.M;
    }
  }

  // Write first command
  buffer.write(firstCommand.value);
  if (firstArgs.isNotEmpty) {
    buffer.write(_cleanupOutData(firstArgs, options, firstCommand));
  }

  PathDataCommand prevCommand = firstCommand;

  // Process remaining items
  for (var i = 1; i < pathData.length; i++) {
    final item = pathData[i];
    final command = item.command;
    final args = item.args;

    // Check if we can omit the command letter (implicit line-to after move-to)
    final canOmitCommand = _canOmitCommand(prevCommand, command, args.length);

    if (!canOmitCommand) {
      buffer.write(command.value);
    }

    if (args.isNotEmpty) {
      final strData = _cleanupOutData(args, options, command);
      if (canOmitCommand && strData.isNotEmpty) {
        // Need to check if we need delimiter after previous args
        final prevArgs = i > 0 ? pathData[i - 1].args : <double>[];
        if (prevArgs.isNotEmpty) {
          final prevValue = prevArgs.last;
          final prevStr = options.leadingZero
              ? _removeLeadingZero(
                  _roundNumber(prevValue, options.floatPrecision))
              : _roundNumber(prevValue, options.floatPrecision);
          final currValue = args[0];
          final currStr = options.leadingZero
              ? _removeLeadingZero(
                  _roundNumber(currValue, options.floatPrecision))
              : _roundNumber(currValue, options.floatPrecision);

          if (_needsDelimiter(prevStr, currStr, currValue, prevValue,
              options.negativeExtraSpace)) {
            buffer.write(' ');
          }
        }
        // Skip the leading space in strData since we handled delimiter
        buffer.write(strData);
      } else {
        buffer.write(strData);
      }
    }

    prevCommand = command;
  }

  return buffer.toString();
}

/// Checks if a command letter can be omitted (implicit line-to after move-to).
bool _canOmitCommand(
  PathDataCommand? prevCommand,
  PathDataCommand currentCommand,
  int argsCount,
) {
  if (prevCommand == null) return false;

  // Implicit L after M
  if (prevCommand == PathDataCommand.M && currentCommand == PathDataCommand.L) {
    return true;
  }
  // Implicit l after m
  if (prevCommand == PathDataCommand.m && currentCommand == PathDataCommand.l) {
    return true;
  }
  // Repeated command
  if (prevCommand == currentCommand && argsCount > 0) {
    return true;
  }
  return false;
}

/// Stringifies a single path data item.
///
/// This is useful for debugging or when you need to convert individual
/// commands.
String stringifyPathDataItem(
  PathDataItem item, [
  PathStringifyOptions options = PathStringifyOptions.defaults,
]) {
  return stringifyPathData([item], options);
}
