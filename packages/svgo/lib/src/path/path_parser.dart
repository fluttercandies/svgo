/// SVG path data parsing.
///
/// Parses SVG path data strings according to the SVG path data BNF.
///
/// @see https://www.w3.org/TR/SVG11/paths.html#PathDataBNF
library;

import '../types.dart';

/// Expected argument counts per path command.
const _argsCountPerCommand = {
  'M': 2,
  'm': 2,
  'Z': 0,
  'z': 0,
  'L': 2,
  'l': 2,
  'H': 1,
  'h': 1,
  'V': 1,
  'v': 1,
  'C': 6,
  'c': 6,
  'S': 4,
  's': 4,
  'Q': 4,
  'q': 4,
  'T': 2,
  't': 2,
  'A': 7,
  'a': 7,
};

/// State for the number reading state machine.
enum _ReadNumberState {
  none,
  sign,
  whole,
  decimalPoint,
  decimal,
  e,
  exponentSign,
  exponent,
}

bool _isWhiteSpace(String c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

bool _isDigit(String c) {
  final codeUnit = c.codeUnitAt(0);
  return codeUnit >= 48 && codeUnit <= 57; // '0' - '9'
}

bool _isCommand(String c) {
  return _argsCountPerCommand.containsKey(c);
}

/// Reads a number from the string starting at the given cursor position.
///
/// Returns a tuple of (newCursor, number) where number is null if no valid
/// number was found.
(int, double?) _readNumber(String string, int cursor) {
  var i = cursor;
  final buffer = StringBuffer();
  var state = _ReadNumberState.none;

  while (i < string.length) {
    final c = string[i];

    if (c == '+' || c == '-') {
      if (state == _ReadNumberState.none) {
        state = _ReadNumberState.sign;
        buffer.write(c);
        i++;
        continue;
      }
      if (state == _ReadNumberState.e) {
        state = _ReadNumberState.exponentSign;
        buffer.write(c);
        i++;
        continue;
      }
      break;
    }

    if (_isDigit(c)) {
      if (state == _ReadNumberState.none ||
          state == _ReadNumberState.sign ||
          state == _ReadNumberState.whole) {
        state = _ReadNumberState.whole;
        buffer.write(c);
        i++;
        continue;
      }
      if (state == _ReadNumberState.decimalPoint ||
          state == _ReadNumberState.decimal) {
        state = _ReadNumberState.decimal;
        buffer.write(c);
        i++;
        continue;
      }
      if (state == _ReadNumberState.e ||
          state == _ReadNumberState.exponentSign ||
          state == _ReadNumberState.exponent) {
        state = _ReadNumberState.exponent;
        buffer.write(c);
        i++;
        continue;
      }
      break;
    }

    if (c == '.') {
      if (state == _ReadNumberState.none ||
          state == _ReadNumberState.sign ||
          state == _ReadNumberState.whole) {
        state = _ReadNumberState.decimalPoint;
        buffer.write(c);
        i++;
        continue;
      }
      break;
    }

    if (c == 'E' || c == 'e') {
      if (state == _ReadNumberState.whole ||
          state == _ReadNumberState.decimalPoint ||
          state == _ReadNumberState.decimal) {
        state = _ReadNumberState.e;
        buffer.write(c);
        i++;
        continue;
      }
      break;
    }

    break;
  }

  final value = buffer.toString();
  final number = double.tryParse(value);

  if (number == null || number.isNaN) {
    return (cursor, null);
  }

  // Step back to delegate iteration to parent loop
  return (i - 1, number);
}

/// Parses an SVG path data string into a list of path data items.
///
/// Example:
/// ```dart
/// final pathData = parsePathData('M10 20 L30 40 Z');
/// // Returns:
/// // [
/// //   PathDataItem(PathDataCommand.M, [10, 20]),
/// //   PathDataItem(PathDataCommand.L, [30, 40]),
/// //   PathDataItem(PathDataCommand.Z, []),
/// // ]
/// ```
///
/// The parser follows the SVG path data grammar:
/// - Handles all path commands (M, L, H, V, C, S, Q, T, A, Z)
/// - Supports both absolute and relative commands
/// - Handles implicit lineto after moveto
/// - Properly parses arc flags without spaces
List<PathDataItem> parsePathData(String string) {
  final pathData = <PathDataItem>[];
  PathDataCommand? command;
  var args = <double>[];
  var argsCount = 0;
  var canHaveComma = false;
  var hadComma = false;

  for (var i = 0; i < string.length; i++) {
    final c = string[i];

    if (_isWhiteSpace(c)) {
      continue;
    }

    // Allow comma only between arguments
    if (canHaveComma && c == ',') {
      if (hadComma) {
        break;
      }
      hadComma = true;
      continue;
    }

    if (_isCommand(c)) {
      if (hadComma) {
        return pathData;
      }

      if (command == null) {
        // Moveto should be leading command
        if (c != 'M' && c != 'm') {
          return pathData;
        }
      } else if (args.isNotEmpty) {
        // Stop if previous command arguments are not flushed
        return pathData;
      }

      command = PathDataCommand.fromChar(c)!;
      args = [];
      argsCount = command.argsCount;
      canHaveComma = false;

      // Flush command without arguments
      if (argsCount == 0) {
        pathData.add(PathDataItem(command, []));
      }
      continue;
    }

    // Avoid parsing arguments if no command detected
    if (command == null) {
      return pathData;
    }

    // Read next argument
    var newCursor = i;
    double? number;

    if (command == PathDataCommand.A || command == PathDataCommand.a) {
      final position = args.length;

      if (position == 0 || position == 1) {
        // Allow only positive number without sign as first two arguments (rx, ry)
        if (c != '+' && c != '-') {
          (newCursor, number) = _readNumber(string, i);
        }
      } else if (position == 2 || position == 5 || position == 6) {
        (newCursor, number) = _readNumber(string, i);
      } else if (position == 3 || position == 4) {
        // Read flags (large-arc-flag and sweep-flag)
        if (c == '0') {
          number = 0;
        } else if (c == '1') {
          number = 1;
        }
      }
    } else {
      (newCursor, number) = _readNumber(string, i);
    }

    if (number == null) {
      return pathData;
    }

    args.add(number);
    canHaveComma = true;
    hadComma = false;
    i = newCursor;

    // Flush arguments when necessary count is reached
    if (args.length == argsCount) {
      pathData.add(PathDataItem(command, args));

      // Subsequent moveto coordinates are treated as implicit lineto commands
      if (command == PathDataCommand.M) {
        command = PathDataCommand.L;
      } else if (command == PathDataCommand.m) {
        command = PathDataCommand.l;
      }

      args = [];
    }
  }

  return pathData;
}
