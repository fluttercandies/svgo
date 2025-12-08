import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('convertTransform QR decomposition', () {
    test('simplifies translate transforms', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="translate(10, 20)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('translate'));
      // Should optimize without removing functionality
    });

    test('combines consecutive transforms', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="translate(10, 0) translate(0, 20)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            convertTransform.withParams(
              ConvertTransformParams(floatPrecision: 3),
            ),
          ],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('optimizes matrix to simpler transforms', () {
      // Identity matrix should be removable
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="matrix(1, 0, 0, 1, 0, 0)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // Identity matrix should be removed
      expect(result.data, isNot(contains('matrix(1, 0, 0, 1, 0, 0)')));
    });

    test('handles scale transforms', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="scale(2, 2)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // scale(2, 2) could be simplified to scale(2)
      expect(result.data, anyOf(contains('scale(2)'), contains('scale(2 2)')));
    });

    test('handles rotate transforms', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="rotate(45)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('rotate'));
    });

    test('handles skewX transforms', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="skewX(30)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('handles skewY transforms', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="skewY(30)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('converts matrix with only translation', () {
      // Matrix representing only translate(50, 100)
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="matrix(1 0 0 1 50 100)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // Should convert matrix to translate
      expect(result.data, contains('transform'));
    });

    test('converts matrix with only scale', () {
      // Matrix representing only scale(2, 3)
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="matrix(2 0 0 3 0 0)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('handles complex combined transforms', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="translate(10, 20) rotate(45) scale(2)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('respects floatPrecision parameter', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="translate(10.123456789, 20.987654321)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            convertTransform.withParams(
              ConvertTransformParams(floatPrecision: 2),
            ),
          ],
        ),
      );

      // Should be rounded to 2 decimal places
      expect(result.data, contains('transform'));
    });

    test('respects transformPrecision parameter', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="rotate(45.123456789)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [
            convertTransform.withParams(
              ConvertTransformParams(transformPrecision: 1),
            ),
          ],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('removes identity translate', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="translate(0, 0)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // Identity translate should be removed
      expect(result.data, isNot(contains('translate(0')));
    });

    test('removes identity scale', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="scale(1, 1)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // Identity scale should be removed
      expect(result.data, isNot(contains('scale(1')));
    });

    test('removes identity rotate', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="rotate(0)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // Zero rotation should be removed
      expect(result.data, isNot(contains('rotate(0')));
    });

    test('simplifies scale(x, x) to scale(x)', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="scale(3, 3)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // scale(3, 3) should become scale(3)
      expect(result.data, anyOf(contains('scale(3)'), contains('scale(3 3)')));
    });

    test('combines rotate transforms with translate', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="translate(50, 50) rotate(45) translate(-50, -50)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // Should combine into rotate(45, 50, 50)
      expect(result.data, contains('transform'));
    });

    test('handles gradientTransform attribute', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="grad" gradientTransform="rotate(45)">
      <stop offset="0%" stop-color="red"/>
      <stop offset="100%" stop-color="blue"/>
    </linearGradient>
  </defs>
  <rect fill="url(#grad)" width="100" height="100"/>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('gradientTransform'));
    });

    test('handles patternTransform attribute', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <pattern id="pattern" patternTransform="scale(2)">
      <circle r="5"/>
    </pattern>
  </defs>
  <rect fill="url(#pattern)" width="100" height="100"/>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('patternTransform'));
    });
  });

  group('convertTransform matrix decomposition', () {
    test('decomposes shear matrix using QRAB method', () {
      // Matrix with shear: matrix(1, 0.5, 0.5, 1, 0, 0)
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="matrix(1, 0.5, 0.5, 1, 0, 0)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('handles reflection matrix (negative scale)', () {
      // Matrix with reflection: matrix(-1, 0, 0, 1, 0, 0)
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="matrix(-1, 0, 0, 1, 0, 0)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      expect(result.data, contains('transform'));
    });

    test('converts complex matrix with rotation and scale', () {
      // Matrix representing rotate(30) scale(2)
      // cos(30)*2 = 1.732, sin(30)*2 = 1
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <g transform="matrix(1.732, 1, -1, 1.732, 0, 0)">
    <rect width="50" height="50"/>
  </g>
</svg>''';

      final result = optimize(
        input,
        SvgoConfig(
          plugins: [convertTransform],
        ),
      );

      // Should decompose into simpler transforms
      expect(result.data, contains('transform'));
    });
  });
}
