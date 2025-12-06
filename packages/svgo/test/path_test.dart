import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('parsePathData', () {
    test('parses moveto commands', () {
      final result = parsePathData('M10 20');

      expect(result.length, equals(1));
      expect(result[0].command, equals(PathDataCommand.M));
      expect(result[0].args, equals([10.0, 20.0]));
    });

    test('parses relative moveto commands', () {
      final result = parsePathData('m10 20');

      expect(result.length, equals(1));
      expect(result[0].command, equals(PathDataCommand.m));
      expect(result[0].args, equals([10.0, 20.0]));
    });

    test('parses lineto commands', () {
      final result = parsePathData('M0 0 L10 20');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.L));
      expect(result[1].args, equals([10.0, 20.0]));
    });

    test('parses horizontal lineto', () {
      final result = parsePathData('M0 0 H10');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.H));
      expect(result[1].args, equals([10.0]));
    });

    test('parses vertical lineto', () {
      final result = parsePathData('M0 0 V20');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.V));
      expect(result[1].args, equals([20.0]));
    });

    test('parses cubic bezier', () {
      final result = parsePathData('M0 0 C10 20 30 40 50 60');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.C));
      expect(result[1].args, equals([10.0, 20.0, 30.0, 40.0, 50.0, 60.0]));
    });

    test('parses smooth cubic bezier', () {
      final result = parsePathData('M0 0 S10 20 30 40');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.S));
      expect(result[1].args, equals([10.0, 20.0, 30.0, 40.0]));
    });

    test('parses quadratic bezier', () {
      final result = parsePathData('M0 0 Q10 20 30 40');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.Q));
      expect(result[1].args, equals([10.0, 20.0, 30.0, 40.0]));
    });

    test('parses smooth quadratic bezier', () {
      final result = parsePathData('M0 0 T10 20');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.T));
      expect(result[1].args, equals([10.0, 20.0]));
    });

    test('parses arc commands', () {
      final result = parsePathData('M0 0 A5 5 0 0 1 10 10');

      expect(result.length, equals(2));
      expect(result[1].command, equals(PathDataCommand.A));
      expect(result[1].args, equals([5.0, 5.0, 0.0, 0.0, 1.0, 10.0, 10.0]));
    });

    test('parses closepath', () {
      final result = parsePathData('M0 0 L10 10 Z');

      expect(result.length, equals(3));
      expect(result[2].command, equals(PathDataCommand.Z));
      expect(result[2].args, isEmpty);
    });

    test('parses lowercase closepath', () {
      final result = parsePathData('M0 0 L10 10 z');

      expect(result.length, equals(3));
      expect(result[2].command, equals(PathDataCommand.z));
    });

    test('parses multiple coordinate pairs', () {
      final result = parsePathData('M0 0 10 20 30 40');

      expect(result.length, equals(3));
      expect(result[0].command, equals(PathDataCommand.M));
      expect(result[1].command, equals(PathDataCommand.L));
      expect(result[2].command, equals(PathDataCommand.L));
    });

    test('handles comma separators', () {
      final result = parsePathData('M0,0 L10,20');

      expect(result.length, equals(2));
      expect(result[0].args, equals([0.0, 0.0]));
      expect(result[1].args, equals([10.0, 20.0]));
    });

    test('handles negative numbers', () {
      final result = parsePathData('M-10 -20 L-30 -40');

      expect(result[0].args, equals([-10.0, -20.0]));
      expect(result[1].args, equals([-30.0, -40.0]));
    });

    test('handles decimal numbers', () {
      final result = parsePathData('M10.5 20.25 L30.125 40.0625');

      expect(result[0].args, equals([10.5, 20.25]));
      expect(result[1].args, equals([30.125, 40.0625]));
    });

    test('handles scientific notation', () {
      final result = parsePathData('M1e2 2e-1');

      expect(result[0].args, equals([100.0, 0.2]));
    });

    test('handles empty input', () {
      final result = parsePathData('');
      expect(result, isEmpty);
    });

    test('handles whitespace only', () {
      final result = parsePathData('   ');
      expect(result, isEmpty);
    });
  });

  group('stringifyPathData', () {
    test('stringifies moveto', () {
      final result = stringifyPathData([
        PathDataItem(PathDataCommand.M, [10, 20]),
      ]);

      expect(result, equals('M10 20'));
    });

    test('stringifies multiple commands', () {
      final result = stringifyPathData([
        PathDataItem(PathDataCommand.M, [0, 0]),
        PathDataItem(PathDataCommand.L, [10, 20]),
        PathDataItem(PathDataCommand.Z, []),
      ]);

      expect(result, contains('M0 0'));
      // The stringifier may use implicit L after M (valid SVG optimization)
      expect(result, anyOf(contains('L10 20'), contains('10 20')));
      // Closepath may be 'z' or 'Z'
      expect(result.toLowerCase(), contains('z'));
    });

    test('respects float precision', () {
      final result = stringifyPathData(
        [
          PathDataItem(PathDataCommand.M, [10.123456, 20.654321]),
        ],
        PathStringifyOptions(floatPrecision: 2),
      );

      expect(result, equals('M10.12 20.65'));
    });

    test('removes trailing zeros', () {
      final result = stringifyPathData([
        PathDataItem(PathDataCommand.M, [10.0, 20.0]),
      ]);

      expect(result, isNot(contains('.0')));
    });

    test('uses closepath character', () {
      final result = stringifyPathData([
        PathDataItem(PathDataCommand.M, [0, 0]),
        PathDataItem(PathDataCommand.Z, []),
      ]);

      // Both 'z' and 'Z' are valid closepath representations
      expect(result.toLowerCase(), contains('z'));
    });
  });

  group('convertRelativeToAbsolute', () {
    test('converts relative moveto to absolute', () {
      final result = convertRelativeToAbsolute([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.m, [5, 5]),
      ]);

      expect(result[1].command, equals(PathDataCommand.M));
      expect(result[1].args, equals([15.0, 15.0]));
    });

    test('converts relative lineto to absolute', () {
      final result = convertRelativeToAbsolute([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.l, [5, 5]),
      ]);

      expect(result[1].command, equals(PathDataCommand.L));
      expect(result[1].args, equals([15.0, 15.0]));
    });

    test('converts relative horizontal lineto', () {
      final result = convertRelativeToAbsolute([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.h, [5]),
      ]);

      expect(result[1].command, equals(PathDataCommand.H));
      expect(result[1].args, equals([15.0]));
    });

    test('converts relative vertical lineto', () {
      final result = convertRelativeToAbsolute([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.v, [5]),
      ]);

      expect(result[1].command, equals(PathDataCommand.V));
      expect(result[1].args, equals([15.0]));
    });

    test('handles closepath and returns to start', () {
      final result = convertRelativeToAbsolute([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.l, [10, 0]),
        PathDataItem(PathDataCommand.z, []),
        PathDataItem(PathDataCommand.l, [5, 5]),
      ]);

      // After closepath, cursor should be back at start
      expect(result[3].command, equals(PathDataCommand.L));
      expect(result[3].args, equals([15.0, 15.0]));
    });
  });

  group('convertAbsoluteToRelative', () {
    test('keeps first moveto absolute', () {
      final result = convertAbsoluteToRelative([
        PathDataItem(PathDataCommand.M, [10, 10]),
      ]);

      expect(result[0].command, equals(PathDataCommand.M));
      expect(result[0].args, equals([10.0, 10.0]));
    });

    test('converts absolute lineto to relative', () {
      final result = convertAbsoluteToRelative([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.L, [20, 30]),
      ]);

      expect(result[1].command, equals(PathDataCommand.l));
      expect(result[1].args, equals([10.0, 20.0]));
    });

    test('converts subsequent moveto to relative', () {
      final result = convertAbsoluteToRelative([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.L, [20, 20]),
        PathDataItem(PathDataCommand.M, [30, 30]),
      ]);

      expect(result[2].command, equals(PathDataCommand.m));
      expect(result[2].args, equals([10.0, 10.0]));
    });
  });

  group('computePathBoundingBox', () {
    test('computes bounding box for simple path', () {
      final bbox = computePathBoundingBox([
        PathDataItem(PathDataCommand.M, [10, 20]),
        PathDataItem(PathDataCommand.L, [100, 80]),
      ]);

      expect(bbox, isNotNull);
      expect(bbox!.minX, equals(10.0));
      expect(bbox.minY, equals(20.0));
      expect(bbox.maxX, equals(100.0));
      expect(bbox.maxY, equals(80.0));
    });

    test('returns null for empty path', () {
      final bbox = computePathBoundingBox([]);
      expect(bbox, isNull);
    });

    test('handles horizontal and vertical lines', () {
      final bbox = computePathBoundingBox([
        PathDataItem(PathDataCommand.M, [10, 10]),
        PathDataItem(PathDataCommand.H, [100]),
        PathDataItem(PathDataCommand.V, [50]),
      ]);

      expect(bbox, isNotNull);
      expect(bbox!.minX, equals(10.0));
      expect(bbox.maxX, equals(100.0));
      expect(bbox.minY, equals(10.0));
      expect(bbox.maxY, equals(50.0));
    });
  });

  group('PathDataCommand', () {
    test('fromChar returns correct command', () {
      expect(PathDataCommand.fromChar('M'), equals(PathDataCommand.M));
      expect(PathDataCommand.fromChar('m'), equals(PathDataCommand.m));
      expect(PathDataCommand.fromChar('L'), equals(PathDataCommand.L));
      expect(PathDataCommand.fromChar('Z'), equals(PathDataCommand.Z));
      expect(PathDataCommand.fromChar('X'), isNull);
    });

    test('argsCount returns correct values', () {
      expect(PathDataCommand.M.argsCount, equals(2));
      expect(PathDataCommand.Z.argsCount, equals(0));
      expect(PathDataCommand.H.argsCount, equals(1));
      expect(PathDataCommand.C.argsCount, equals(6));
      expect(PathDataCommand.A.argsCount, equals(7));
    });

    test('isRelative and isAbsolute work correctly', () {
      expect(PathDataCommand.M.isAbsolute, isTrue);
      expect(PathDataCommand.M.isRelative, isFalse);
      expect(PathDataCommand.m.isRelative, isTrue);
      expect(PathDataCommand.m.isAbsolute, isFalse);
    });

    test('toAbsolute and toRelative work correctly', () {
      expect(PathDataCommand.m.toAbsolute, equals(PathDataCommand.M));
      expect(PathDataCommand.M.toRelative, equals(PathDataCommand.m));
      expect(PathDataCommand.M.toAbsolute, equals(PathDataCommand.M));
    });
  });

  group('PathDataItem', () {
    test('equality works correctly', () {
      final a = PathDataItem(PathDataCommand.M, [10, 20]);
      final b = PathDataItem(PathDataCommand.M, [10, 20]);
      final c = PathDataItem(PathDataCommand.M, [10, 30]);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates a copy', () {
      final original = PathDataItem(PathDataCommand.M, [10, 20]);
      final copy = original.copyWith(args: [30, 40]);

      expect(copy.command, equals(PathDataCommand.M));
      expect(copy.args, equals([30.0, 40.0]));
      expect(original.args, equals([10.0, 20.0]));
    });

    test('toString returns readable representation', () {
      final item = PathDataItem(PathDataCommand.M, [10, 20]);
      expect(item.toString(), equals('M10.0 20.0'));
    });
  });
}
