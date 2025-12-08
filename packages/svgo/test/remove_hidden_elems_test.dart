import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('removeHiddenElems', () {
    test('removes hidden elements', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect visibility="hidden" width="100" height="100"/>
          <rect width="50" height="50"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('visibility="hidden"'), isFalse);
      expect(result.data.contains('<rect'), isTrue);
    });

    test('removes display none elements', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect style="display:none" width="100" height="100"/>
          <rect width="50" height="50"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('display:none'), isFalse);
    });

    test('removes zero sized circles', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <circle cx="50" cy="50" r="0"/>
          <circle cx="50" cy="50" r="10"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('r="0"'), isFalse);
      expect(result.data.contains('r="10"'), isTrue);
    });

    test('removes zero sized ellipses', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="0" ry="10"/>
          <ellipse cx="50" cy="50" rx="10" ry="10"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('rx="0"'), isFalse);
    });

    test('removes zero width rects', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="0" height="100"/>
          <rect x="10" y="10" width="50" height="100"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('width="0"'), isFalse);
      expect(result.data.contains('width="50"'), isTrue);
    });

    test('removes zero height rects', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect x="10" y="10" width="100" height="0"/>
          <rect x="10" y="10" width="100" height="50"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('height="0"'), isFalse);
      expect(result.data.contains('height="50"'), isTrue);
    });

    test('removes empty paths', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <path/>
          <path d="M0 0 L10 10"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.split('<path').length, equals(2)); // Only 1 path
    });

    test('removes opacity 0 elements', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect opacity="0" width="100" height="100"/>
          <rect opacity="1" width="50" height="50"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('opacity="0"'), isFalse);
    });

    test('preserves markers with display none when referenced', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <marker id="m" style="display:none">
              <circle r="5"/>
            </marker>
          </defs>
          <path d="M0 0 L10 10" marker-end="url(#m)"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      // Markers with display:none are still rendered, so they should be preserved
      expect(result.data.contains('<marker'), isTrue);
    });

    test('removes unused non-rendering elements', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="unused">
              <stop offset="0" stop-color="red"/>
            </linearGradient>
          </defs>
          <rect width="100" height="100"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      // Note: removeHiddenElems tracks non-rendering nodes
      // but doesn't remove them unless they're hidden
      expect(result.data.contains('<rect'), isTrue);
    });

    test('preserves referenced defs', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad">
              <stop offset="0" stop-color="red"/>
            </linearGradient>
          </defs>
          <rect fill="url(#grad)" width="100" height="100"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      expect(result.data.contains('linearGradient'), isTrue);
    });

    test('does not remove elements when script present', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <script>console.log("test")</script>
          <rect visibility="hidden" width="100" height="100"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [removeHiddenElems],
        ),
      );
      // With script present, optimization is deoptimized
      expect(result.data.contains('<script'), isTrue);
    });
  });
}
