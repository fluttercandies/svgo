import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('cleanupIds defs-only check', () {
    test('skips SVG with only defs content', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <symbol id="icon">
              <circle cx="50" cy="50" r="40"/>
            </symbol>
          </defs>
        </svg>
        ''',
        SvgoConfig(
          plugins: [cleanupIds],
        ),
      );
      // IDs should be preserved in defs-only SVGs
      expect(result.data.contains('id="icon"'), isTrue);
    });

    test('minifies IDs in SVG with renderable content', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="longGradientId">
              <stop offset="0" stop-color="red"/>
            </linearGradient>
          </defs>
          <rect fill="url(#longGradientId)" width="100" height="100"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [cleanupIds],
        ),
      );
      // ID should be minified
      expect(result.data.contains('longGradientId'), isFalse);
    });

    test('preserves IDs in defs-only SVGs with symbols', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <symbol id="symbol-one">
              <rect width="10" height="10"/>
            </symbol>
            <symbol id="symbol-two">
              <circle r="5"/>
            </symbol>
          </defs>
        </svg>
        ''',
        SvgoConfig(
          plugins: [cleanupIds],
        ),
      );
      expect(result.data.contains('symbol-one'), isTrue);
      expect(result.data.contains('symbol-two'), isTrue);
    });

    test('processes SVG with style element and renderable content', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.cls { fill: red; }</style>
          <defs>
            <linearGradient id="myGrad">
              <stop offset="0" stop-color="red"/>
            </linearGradient>
          </defs>
          <rect class="cls" fill="url(#myGrad)" width="100" height="100"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [cleanupIds],
        ),
      );
      // Style elements with content cause deoptimization
      expect(result.data.contains('<rect'), isTrue);
    });

    test('removes unused IDs', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect id="unusedId" width="100" height="100"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [cleanupIds],
        ),
      );
      expect(result.data.contains('unusedId'), isFalse);
    });

    test('preserves IDs matching preserve patterns', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect id="icon-box" width="100" height="100"/>
          <rect fill="url(#someRef)" width="50" height="50"/>
        </svg>
        ''',
        SvgoConfig(
          plugins: [
            cleanupIds.withParams(
              CleanupIdsParams(preservePrefixes: ['icon-']),
            ),
          ],
        ),
      );
      expect(result.data.contains('icon-box'), isTrue);
    });

    test('handles SVG with metadata and defs only', () {
      final result = optimize(
        '''
        <svg xmlns="http://www.w3.org/2000/svg">
          <title>Icon Library</title>
          <desc>Collection of icons</desc>
          <defs>
            <symbol id="home-icon">
              <path d="M10 20 L50 20"/>
            </symbol>
          </defs>
        </svg>
        ''',
        SvgoConfig(
          plugins: [cleanupIds],
        ),
      );
      // Should preserve ID since it's a defs-only library
      expect(result.data.contains('home-icon'), isTrue);
    });
  });
}
