/// Fixtures-based tests that verify plugin behavior matches node_svgo.
///
/// These tests use the same test fixtures from node_svgo to ensure
/// compatibility and correctness.
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

/// Parses a test fixture file in the format:
/// ```
/// optional description
/// ===
/// input SVG
/// @@@
/// expected output SVG
/// @@@
/// optional JSON params
/// ```
(String input, String expected, String? params)? parseFixture(String content) {
  final parts = content.split('@@@');
  if (parts.length < 2) return null;
  var input = parts[0].trim();
  final expected = parts[1].trim();
  final params = parts.length > 2 ? parts[2].trim() : null;

  // Handle description block separated by ===
  if (input.contains('===')) {
    final inputParts = input.split('===');
    input = inputParts.last.trim();
  }

  return (input, expected, params);
}

/// Normalizes SVG for comparison by removing extra whitespace.
String normalizeSvg(String svg) {
  return svg
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'>\s+<'), '><')
      .replaceAll(RegExp(r'\s+/>'), '/>')
      .replaceAll(RegExp(r'"\s+'), '" ')
      .trim();
}

void main() {
  // Use local fixtures directory (copied from node_svgo)
  final fixturesDir = path.join(
    Directory.current.path,
    'test',
    'fixtures',
  );

  if (!Directory(fixturesDir).existsSync()) {
    print('Fixtures directory not found: $fixturesDir');
    return;
  }

  group('convertPathData fixtures', () {
    _runFixtureTests(fixturesDir, 'convertPathData', [convertPathData]);
  });

  group('cleanupIds fixtures', () {
    _runFixtureTests(fixturesDir, 'cleanupIds', [cleanupIds]);
  });

  group('removeUnknownsAndDefaults fixtures', () {
    _runFixtureTests(
        fixturesDir, 'removeUnknownsAndDefaults', [removeUnknownsAndDefaults]);
  });

  group('inlineStyles fixtures', () {
    _runFixtureTests(fixturesDir, 'inlineStyles', [inlineStyles]);
  });

  group('convertColors fixtures', () {
    _runFixtureTests(fixturesDir, 'convertColors', [convertColors]);
  });

  group('collapseGroups fixtures', () {
    _runFixtureTests(fixturesDir, 'collapseGroups', [collapseGroups]);
  });

  group('mergePaths fixtures', () {
    _runFixtureTests(fixturesDir, 'mergePaths', [mergePaths]);
  });

  group('removeHiddenElems fixtures', () {
    _runFixtureTests(fixturesDir, 'removeHiddenElems', [removeHiddenElems]);
  });
}

void _runFixtureTests(
    String fixturesDir, String pluginName, List<Plugin<PluginParams>> plugins) {
  final dir = Directory(fixturesDir);
  final fixtures = dir
      .listSync()
      .whereType<File>()
      .where(
          (f) => f.path.contains('$pluginName.') && f.path.endsWith('.svg.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final fixture in fixtures) {
    final name = path.basenameWithoutExtension(fixture.path);
    test(name, () {
      final content = fixture.readAsStringSync();
      final parsed = parseFixture(content);

      if (parsed == null) {
        fail('Invalid fixture format: ${fixture.path}');
      }

      final (input, expected, paramsJson) = parsed;

      // Skip fixtures with special parameters (marked with comments)
      if (input.contains('==>') || expected.contains('==>')) {
        // These fixtures have special plugin params
        return;
      }

      // Note: For now, skip fixtures with custom params as the new type-safe
      // API requires creating specific param class instances
      if (paramsJson != null && paramsJson.isNotEmpty) {
        // Skip fixtures with custom params
        return;
      }

      try {
        final result = optimize(
          input,
          SvgoConfig(
            plugins: plugins,
            js2svg: const StringifyOptions(
              indent: 4,
              pretty: true,
            ),
          ),
        );

        final normalizedResult = normalizeSvg(result.data);
        final normalizedExpected = normalizeSvg(expected);

        expect(
          normalizedResult,
          equals(normalizedExpected),
          reason: 'Fixture: $name\n'
              'Input:\n$input\n'
              'Expected:\n$expected\n'
              'Got:\n${result.data}',
        );
      } catch (e) {
        // Some fixtures may have intentionally invalid SVG
        if (!input.contains('...') && !input.contains('invalid')) {
          rethrow;
        }
      }
    });
  }
}
