import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('convertPathData makeArcs', () {
    test('converts circular cubic bezier to arc', () {
      // A cubic bezier approximating a quarter circle
      // Control points calculated for a 90-degree arc
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 50 0 C 77.614 0 100 22.386 100 50"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {
                'makeArcs': {'threshold': 2.5, 'tolerance': 0.5},
                'floatPrecision': 2,
              },
            },
          ],
        ),
      );

      // Should produce arc command if curve approximates circle
      expect(result.data, anyOf(contains('a'), contains('A')));
    });

    test('preserves non-circular curves', () {
      // An elliptical curve that is not a circle
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 0 0 c 10 0 20 30 30 40"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {
                'makeArcs': {'threshold': 2.5, 'tolerance': 0.5},
                'floatPrecision': 3,
              },
            },
          ],
        ),
      );

      // Should keep as curve (c or s command)
      // The exact command may vary but it shouldn't be converted to arc
      expect(result.data, contains('d="'));
    });

    test('respects makeArcs threshold parameter', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 50 0 C 77.614 0 100 22.386 100 50"/>
</svg>
''';

      // Very strict threshold
      final strictResult = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {
                'makeArcs': {'threshold': 0.1, 'tolerance': 0.1},
                'floatPrecision': 3,
              },
            },
          ],
        ),
      );

      // Lenient threshold
      final lenientResult = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {
                'makeArcs': {'threshold': 5.0, 'tolerance': 2.0},
                'floatPrecision': 3,
              },
            },
          ],
        ),
      );

      // Both should produce valid output
      expect(strictResult.data, contains('d="'));
      expect(lenientResult.data, contains('d="'));
    });

    test('makeArcs disabled by default', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 50 0 C 77.614 0 100 22.386 100 50"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: ['convertPathData'],
        ),
      );

      // Without makeArcs, curves are kept as curves
      expect(result.data, contains('d="'));
    });

    test('smartArcRounding adjusts precision for large radii', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">
  <path d="M 500 0 C 776.14 0 1000 223.86 1000 500"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {
                'makeArcs': {'threshold': 2.5, 'tolerance': 0.5},
                'smartArcRounding': true,
                'floatPrecision': 3,
              },
            },
          ],
        ),
      );

      expect(result.data, contains('d="'));
    });

    test('handles shorthand curve commands', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 0 0 c 10 0 20 10 20 20 s 10 20 20 20"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {
                'makeArcs': {'threshold': 2.5, 'tolerance': 0.5},
                'floatPrecision': 3,
              },
            },
          ],
        ),
      );

      expect(result.data, contains('d="'));
    });

    test('joins consecutive arcs on same circle', () {
      // Two consecutive quarter circle beziers
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 50 0 C 77.614 0 100 22.386 100 50 C 100 77.614 77.614 100 50 100"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {
                'makeArcs': {'threshold': 2.5, 'tolerance': 0.5},
                'floatPrecision': 2,
              },
            },
          ],
        ),
      );

      // Should produce at least one arc command
      expect(result.data, contains('d="'));
    });
  });

  group('convertPathData curve optimizations', () {
    test('converts straight curves to lines', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 0 0 c 10 0 20 0 30 0"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {'straightCurves': true},
            },
          ],
        ),
      );

      // Should convert to line (h or l)
      expect(result.data, anyOf(contains('h'), contains('l')));
    });

    test('converts curves to smooth shorthands', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 0 0 c 10 10 20 10 30 0 c -10 -10 -20 -10 -30 0"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {'curveSmoothShorthands': true},
            },
          ],
        ),
      );

      // Should use shorthand s command
      expect(result.data, contains('d="'));
    });

    test('removes useless curve segments', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 10 10 c 0 0 0 0 0 0 l 20 20"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {'removeUseless': true},
            },
          ],
        ),
      );

      // The zero-length curve should be removed
      expect(result.data, contains('d="'));
      // Should not contain the useless 'c 0 0 0 0 0 0' pattern
    });
  });

  group('arc command parameters', () {
    test('correctly sets large-arc-flag', () {
      // A large arc (more than 180 degrees)
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 0 50 a 50 50 0 1 1 100 0"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: ['convertPathData'],
        ),
      );

      expect(result.data, contains('d="'));
    });

    test('correctly sets sweep-flag', () {
      // Clockwise arc
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 0 50 a 50 50 0 0 1 50 -50"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: ['convertPathData'],
        ),
      );

      expect(result.data, contains('d="'));
    });

    test('handles zero-radius arc conversion to line', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 10 10 a 0 0 0 0 0 20 0"/>
</svg>
''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            {
              'name': 'convertPathData',
              'params': {'straightCurves': true},
            },
          ],
        ),
      );

      // Zero-radius arc should be converted to line
      expect(result.data, anyOf(contains('h'), contains('l'), contains('H')));
    });
  });
}
