import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('mergePaths GJK intersection detection', () {
    test('merges non-intersecting paths', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 L10 10"/>
          <path d="M100 100 L110 110"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      // Paths should be merged
      expect(result.data.contains('M100 100'), isTrue);
      expect(result.data.split('<path').length, equals(2)); // Only 1 path
    });

    test('preserves intersecting paths', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 L100 100" fill="red"/>
          <path d="M100 0 L0 100" fill="red"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      // Paths should NOT be merged because they intersect
      expect(result.data.split('<path').length, greaterThanOrEqualTo(2));
    });

    test('merges paths with force option', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 L100 100" fill="red"/>
          <path d="M100 0 L0 100" fill="red"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [
            mergePaths.withParams(MergePathsParams(force: true)),
          ],
        ),
      );
      // Paths should be merged with force=true
      expect(result.data.split('<path').length, equals(2)); // Only 1 path
    });

    test('handles cubic bezier curves', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 C10 20 30 40 50 50"/>
          <path d="M200 200 C210 220 230 240 250 250"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      expect(result.data.split('<path').length, equals(2)); // Merged
    });

    test('handles quadratic bezier curves', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 Q25 50 50 50"/>
          <path d="M200 200 Q225 250 250 250"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      expect(result.data.split('<path').length, equals(2)); // Merged
    });

    test('handles arcs', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M10 10 A5 5 0 0 1 20 20"/>
          <path d="M100 100 A5 5 0 0 1 110 110"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      expect(result.data.split('<path').length, equals(2)); // Merged
    });

    test('does not merge paths with different attributes', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 L10 10" fill="red"/>
          <path d="M100 100 L110 110" fill="blue"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      expect(result.data.split('<path').length, equals(3)); // 2 paths
    });

    test('handles smooth curves (S command)', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 C10 20 20 20 30 10 S50 0 60 10"/>
          <path d="M200 200 C210 220 220 220 230 210 S250 200 260 210"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      expect(result.data.split('<path').length, equals(2)); // Merged
    });

    test('handles smooth quadratic curves (T command)', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 Q25 50 50 50 T100 50"/>
          <path d="M200 200 Q225 250 250 250 T300 250"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      expect(result.data.split('<path').length, equals(2)); // Merged
    });

    test('handles multiple subpaths', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path d="M0 0 L10 10 M20 20 L30 30"/>
          <path d="M100 100 L110 110 M120 120 L130 130"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [mergePaths],
        ),
      );
      expect(result.data.split('<path').length, equals(2)); // Merged
    });
  });
}
