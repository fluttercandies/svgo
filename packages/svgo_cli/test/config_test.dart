import 'dart:io';

import 'package:svgo/svgo.dart';
import 'package:svgo_cli/svgo_cli.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SvgoFileConfig', () {
    test('defaults() creates empty config', () {
      final config = SvgoFileConfig.defaults();
      expect(config.multipass, isFalse);
      expect(config.floatPrecision, isNull);
      expect(config.datauri, isNull);
      expect(config.plugins, isEmpty);
      expect(config.js2svg, isNull);
    });

    test('toSvgoConfig() converts to SvgoConfig', () {
      final fileConfig = SvgoFileConfig(
        multipass: true,
        floatPrecision: 2,
        datauri: DataUriType.base64,
      );

      final svgoConfig = fileConfig.toSvgoConfig();
      expect(svgoConfig.multipass, isTrue);
      expect(svgoConfig.floatPrecision, equals(2));
      expect(svgoConfig.datauri, equals(DataUriType.base64));
    });
  });

  group('PluginConfig', () {
    test('creates with name only', () {
      final config = PluginConfig(name: 'removeComments');
      expect(config.name, equals('removeComments'));
      expect(config.enabled, isTrue);
      expect(config.params, isNull);
    });

    test('creates disabled plugin', () {
      final config = PluginConfig(name: 'removeComments', enabled: false);
      expect(config.enabled, isFalse);
    });

    test('creates with params', () {
      final config = PluginConfig(
        name: 'cleanupIds',
        params: {'minify': false, 'preserve': ['icon-']},
      );
      expect(config.params, isNotNull);
      expect(config.params!['minify'], isFalse);
    });
  });

  group('loadConfigFromFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('svgo_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('throws on non-existent file', () async {
      expect(
        () => loadConfigFromFile('/non/existent/svgo.yaml'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('loads empty yaml file', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.configPath, equals(configFile.path));
      expect(config.multipass, isFalse);
    });

    test('loads basic options from svgo.yaml', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
multipass: true
floatPrecision: 2
datauri: base64
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.multipass, isTrue);
      expect(config.floatPrecision, equals(2));
      expect(config.datauri, equals(DataUriType.base64));
    });

    test('loads plugins list with strings', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - removeComments
  - removeDoctype
  - cleanupIds
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins.length, equals(3));
      expect(config.plugins[0].name, equals('removeComments'));
      expect(config.plugins[1].name, equals('removeDoctype'));
      expect(config.plugins[2].name, equals('cleanupIds'));
    });

    test('loads plugins with disabled state', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - removeComments: false
  - removeDoctype: true
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins.length, equals(2));
      expect(config.plugins[0].name, equals('removeComments'));
      expect(config.plugins[0].enabled, isFalse);
      expect(config.plugins[1].name, equals('removeDoctype'));
      expect(config.plugins[1].enabled, isTrue);
    });

    test('loads plugins with params', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - cleanupIds:
      minify: false
      preserve:
        - icon-home
        - icon-user
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins.length, equals(1));
      expect(config.plugins[0].name, equals('cleanupIds'));
      expect(config.plugins[0].params, isNotNull);
      expect(config.plugins[0].params!['minify'], isFalse);
      expect(config.plugins[0].params!['preserve'], isA<List>());
    });

    test('loads plugins with name key format', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - name: cleanupNumericValues
    floatPrecision: 2
    leadingZero: false
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins.length, equals(1));
      expect(config.plugins[0].name, equals('cleanupNumericValues'));
      expect(config.plugins[0].params!['floatPrecision'], equals(2));
      expect(config.plugins[0].params!['leadingZero'], isFalse);
    });

    test('loads preset-default with overrides', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - preset-default:
      floatPrecision: 2
      overrides:
        removeComments: false
        cleanupIds:
          minify: false
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins.length, equals(1));
      expect(config.plugins[0].name, equals('preset-default'));
      expect(config.plugins[0].params!['floatPrecision'], equals(2));
      expect(config.plugins[0].params!['overrides'], isA<Map>());
    });

    test('loads from pubspec.yaml with svgo key', () async {
      final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: my_package
version: 1.0.0

svgo:
  multipass: true
  plugins:
    - removeComments
''');

      final config = await loadConfigFromFile(pubspecFile.path);
      expect(config.multipass, isTrue);
      expect(config.plugins.length, equals(1));
    });

    test('throws on pubspec.yaml without svgo key', () async {
      final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: my_package
version: 1.0.0
''');

      expect(
        () => loadConfigFromFile(pubspecFile.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('loads js2svg options', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
js2svg:
  indent: 2
  pretty: true
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.js2svg, isNotNull);
      expect(config.js2svg!.indent, equals(2));
      expect(config.js2svg!.pretty, isTrue);
    });

    test('parses datauri types correctly', () async {
      for (final type in ['base64', 'enc', 'unenc']) {
        final configFile = File(p.join(tempDir.path, 'svgo_$type.yaml'));
        await configFile.writeAsString('datauri: $type');

        final config = await loadConfigFromFile(configFile.path);
        final expected = type == 'base64'
            ? DataUriType.base64
            : type == 'enc'
                ? DataUriType.enc
                : DataUriType.unenc;
        expect(config.datauri, equals(expected));
      }
    });
  });

  group('loadConfig - directory search', () {
    late Directory tempDir;
    late Directory subDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('svgo_search_test_');
      subDir = await Directory(p.join(tempDir.path, 'src')).create();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('finds svgo.yaml in current directory', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('multipass: true');

      final config = await loadConfig(tempDir.path);
      expect(config, isNotNull);
      expect(config!.multipass, isTrue);
      expect(config.configPath, equals(configFile.path));
    });

    test('finds svgo.yml in current directory', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yml'));
      await configFile.writeAsString('floatPrecision: 4');

      final config = await loadConfig(tempDir.path);
      expect(config, isNotNull);
      expect(config!.floatPrecision, equals(4));
    });

    test('prefers svgo.yaml over svgo.yml', () async {
      final yamlFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await yamlFile.writeAsString('floatPrecision: 1');

      final ymlFile = File(p.join(tempDir.path, 'svgo.yml'));
      await ymlFile.writeAsString('floatPrecision: 2');

      final config = await loadConfig(tempDir.path);
      expect(config, isNotNull);
      expect(config!.floatPrecision, equals(1));
    });

    test('prefers svgo.yaml over pubspec.yaml', () async {
      final svgoFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await svgoFile.writeAsString('floatPrecision: 1');

      final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test
svgo:
  floatPrecision: 2
''');

      final config = await loadConfig(tempDir.path);
      expect(config, isNotNull);
      expect(config!.floatPrecision, equals(1));
    });

    test('finds config in parent directory', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('multipass: true');

      final config = await loadConfig(subDir.path);
      expect(config, isNotNull);
      expect(config!.multipass, isTrue);
    });

    test('returns null when no config found', () async {
      final config = await loadConfig(tempDir.path);
      expect(config, isNull);
    });

    test('finds pubspec.yaml with svgo key', () async {
      final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: my_package
svgo:
  multipass: true
''');

      final config = await loadConfig(tempDir.path);
      expect(config, isNotNull);
      expect(config!.multipass, isTrue);
    });

    test('ignores pubspec.yaml without svgo key', () async {
      final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('name: my_package');

      final config = await loadConfig(tempDir.path);
      expect(config, isNull);
    });
  });

  group('Plugin parameter parsing', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('svgo_params_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('parses cleanupNumericValues params', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - cleanupNumericValues:
      floatPrecision: 2
      leadingZero: false
      defaultPx: false
      convertToPx: false
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
      expect(svgoConfig.plugins!.length, equals(1));
    });

    test('parses cleanupIds params with preserve list', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - cleanupIds:
      remove: true
      minify: false
      preserve:
        - icon-home
        - icon-user
      preservePrefixes:
        - data-
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
      expect(svgoConfig.plugins!.length, equals(1));
    });

    test('parses convertColors params with currentColor', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - convertColors:
      currentColor: true
      names2hex: false
      shorthex: false
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
    });

    test('parses convertColors with exact currentColor value', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - convertColors:
      currentColor: "#ff0000"
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins[0].params!['currentColor'], equals('#ff0000'));
    });

    test('parses convertPathData params with makeArcs', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - convertPathData:
      applyTransforms: true
      makeArcs:
        threshold: 3.0
        tolerance: 0.6
      floatPrecision: 2
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
    });

    test('parses inlineStyles params', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - inlineStyles:
      onlyMatchedOnce: false
      useMqs:
        - ""
        - screen
        - print
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
    });

    test('parses removeAttrs params', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - removeAttrs:
      attrs:
        - fill
        - stroke
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
    });

    test('parses prefixIds params', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - prefixIds:
      prefix: myprefix
      delim: _
      prefixIds: true
      prefixClassNames: false
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
    });

    test('parses sortAttrs params', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - sortAttrs:
      order:
        - id
        - class
        - width
        - height
      xmlnsOrder: front
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
    });

    test('parses removeComments with preservePatterns', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - removeComments:
      preservePatterns:
        - "^!"
        - "Copyright"
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      expect(svgoConfig.plugins, isNotNull);
    });
  });

  group('Edge cases and error handling', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('svgo_edge_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('handles invalid yaml gracefully', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('invalid: yaml: content: here');

      expect(
        () => loadConfigFromFile(configFile.path),
        throwsA(anything),
      );
    });

    test('handles non-map plugins entry', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins: "not a list"
''');

      expect(
        () => loadConfigFromFile(configFile.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles unknown plugin name with warning', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - unknownPlugin
  - removeComments
''');

      final config = await loadConfigFromFile(configFile.path);
      final svgoConfig = config.toSvgoConfig();

      // Should have only one plugin (removeComments)
      // unknownPlugin should be skipped with warning
      expect(svgoConfig.plugins, isNotNull);
    });

    test('handles empty plugins list', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins: []
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins, isEmpty);

      final svgoConfig = config.toSvgoConfig();
      expect(svgoConfig.plugins, isNull);
    });

    test('handles null yaml content', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('# Just a comment');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.configPath, isNotNull);
    });

    test('handles deeply nested config structure', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
multipass: true
floatPrecision: 3
plugins:
  - preset-default:
      floatPrecision: 2
      overrides:
        cleanupIds:
          minify: true
          preserve:
            - id1
            - id2
        removeComments: false
        convertPathData:
          makeArcs:
            threshold: 2.5
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.multipass, isTrue);
      expect(config.floatPrecision, equals(3));
      expect(config.plugins.length, equals(1));
    });

    test('handles mixed plugin formats', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - removeComments
  - removeDoctype: true
  - cleanupIds: false
  - cleanupNumericValues:
      floatPrecision: 2
  - name: convertColors
    names2hex: false
''');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.plugins.length, equals(5));
      expect(config.plugins[0].name, equals('removeComments'));
      expect(config.plugins[0].enabled, isTrue);
      expect(config.plugins[1].enabled, isTrue);
      expect(config.plugins[2].enabled, isFalse);
      expect(config.plugins[3].params, isNotNull);
      expect(config.plugins[4].name, equals('convertColors'));
    });

    test('handles unknown datauri type', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('datauri: unknown');

      final config = await loadConfigFromFile(configFile.path);
      expect(config.datauri, isNull);
    });
  });

  group('toSvgoConfig integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('svgo_integration_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('full config converts and optimizes SVG correctly', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
multipass: true
plugins:
  - removeComments
  - removeDoctype
  - cleanupNumericValues:
      floatPrecision: 2
''');

      final fileConfig = await loadConfigFromFile(configFile.path);
      final svgoConfig = fileConfig.toSvgoConfig();

      const inputSvg = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<!-- This is a comment -->
<svg xmlns="http://www.w3.org/2000/svg" width="100.123456" height="50.654321">
  <rect x="0" y="0" width="100" height="50"/>
</svg>
''';

      final result = optimize(inputSvg, svgoConfig);

      // Should not contain comment
      expect(result.data, isNot(contains('This is a comment')));
      // Should not contain DOCTYPE
      expect(result.data, isNot(contains('DOCTYPE')));
      // Numeric values should be rounded
      expect(result.data, isNot(contains('100.123456')));
    });

    test('preset-default with overrides works correctly', () async {
      final configFile = File(p.join(tempDir.path, 'svgo.yaml'));
      await configFile.writeAsString('''
plugins:
  - preset-default:
      overrides:
        removeComments: false
''');

      final fileConfig = await loadConfigFromFile(configFile.path);
      final svgoConfig = fileConfig.toSvgoConfig();

      const inputSvg = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <!-- Keep this comment -->
  <rect x="0" y="0" width="100" height="50"/>
</svg>
''';

      final result = optimize(inputSvg, svgoConfig);

      // Comment should be preserved since removeComments is disabled
      expect(result.data, contains('Keep this comment'));
    });
  });
}
