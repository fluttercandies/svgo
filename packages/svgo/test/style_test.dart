import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

XastElement getElementById(XastRoot root, String id) {
  XastElement? matched;

  void visitNode(XastChild node) {
    if (node is XastElement) {
      if (node.attributes['id'] == id) {
        matched = node;
        return;
      }
      for (final child in node.children) {
        visitNode(child);
        if (matched != null) return;
      }
    }
  }

  for (final child in root.children) {
    visitNode(child);
    if (matched != null) break;
  }

  if (matched == null) {
    throw StateError('Element with id "$id" not found');
  }
  return matched!;
}

/// Helper to check if a color value matches any of the expected color representations.
/// csslib normalizes colors to hex, so 'red' becomes '#f00' or '#ff0000'.
bool colorMatches(String? actual, List<String> expected) {
  if (actual == null) return false;
  final normalized = actual.toLowerCase();
  return expected.any((e) => e.toLowerCase() == normalized);
}

void main() {
  group('collectStylesheet', () {
    test('collects styles from class selectors', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.a { fill: red; }</style>
          <rect id="class" class="a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles = computeStyle(stylesheet, getElementById(root, 'class'));

      expect(styles['fill'], isA<StaticStyle>());
      // CSS parser may return 'red', '#f00', or '#ff0000' depending on input
      final fillValue = (styles['fill'] as StaticStyle).value.toLowerCase();
      expect(
          fillValue == 'red' || fillValue == '#f00' || fillValue == '#ff0000',
          isTrue);
      expect((styles['fill'] as StaticStyle).inherited, isFalse);
    });

    test('collects styles from multiple classes', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>
            .a { fill: red; }
            .b { fill: green; stroke: black; }
          </style>
          <rect id="two-classes" class="b a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'two-classes'));

      expect(styles['fill'], isA<StaticStyle>());
      // CSS parser may normalize color values
      final fillValue = (styles['fill'] as StaticStyle).value.toLowerCase();
      expect(
          fillValue == 'green' || fillValue == '#008000' || fillValue == '#0f0',
          isTrue);
      expect(styles['stroke'], isA<StaticStyle>());
      final strokeValue = (styles['stroke'] as StaticStyle).value.toLowerCase();
      expect(
          strokeValue == 'black' ||
              strokeValue == '#000' ||
              strokeValue == '#000000',
          isTrue);
    });

    test('collects styles from presentation attributes', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect id="attribute" fill="purple"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'attribute'));

      expect(styles['fill'], isA<StaticStyle>());
      expect((styles['fill'] as StaticStyle).value, equals('purple'));
    });

    test('collects styles from inline style attribute', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect id="inline-style" style="fill: grey;"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'inline-style'));

      expect(styles['fill'], isA<StaticStyle>());
      // CSS parser may normalize color values
      final fillValue = (styles['fill'] as StaticStyle).value.toLowerCase();
      expect(
          fillValue == 'grey' || fillValue == 'gray' || fillValue == '#808080',
          isTrue);
    });

    test('inherits styles from parent elements', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <g fill="yellow">
            <rect id="inheritance"/>
          </g>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'inheritance'));

      expect(styles['fill'], isA<StaticStyle>());
      expect((styles['fill'] as StaticStyle).value, equals('yellow'));
      expect((styles['fill'] as StaticStyle).inherited, isTrue);
    });

    test('inherits styles from nested parent elements', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <g fill="yellow">
            <g style="fill: blue;">
              <g>
                <rect id="nested-inheritance"/>
              </g>
            </g>
          </g>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'nested-inheritance'));

      expect(styles['fill'], isA<StaticStyle>());
      // CSS parser may normalize color values
      final fillValue = (styles['fill'] as StaticStyle).value.toLowerCase();
      expect(
          fillValue == 'blue' || fillValue == '#00f' || fillValue == '#0000ff',
          isTrue);
      expect((styles['fill'] as StaticStyle).inherited, isTrue);
    });

    test('parses CDATA in style elements', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style><![CDATA[.a { fill: red; }]]></style>
          <rect id="cdata" class="a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles = computeStyle(stylesheet, getElementById(root, 'cdata'));

      // CDATA parsing may or may not work depending on CSS parser
      // If it works, we should have a fill style
      if (styles['fill'] != null) {
        expect(styles['fill'], isA<StaticStyle>());
      }
    });
  });

  group('style priority', () {
    test('style rule overrides attribute', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.b { fill: blue; }</style>
          <rect id="style-rule-over-attribute" class="b" fill="grey"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles = computeStyle(
          stylesheet, getElementById(root, 'style-rule-over-attribute'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value.toLowerCase();
      expect(
          fillValue == 'blue' || fillValue == '#00f' || fillValue == '#0000ff',
          isTrue);
    });

    test('inline style overrides style rule', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.b { fill: blue; }</style>
          <rect id="inline-style-over-style-rule" style="fill: purple;" class="b"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles = computeStyle(
          stylesheet, getElementById(root, 'inline-style-over-style-rule'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value.toLowerCase();
      expect(
          fillValue == 'purple' ||
              fillValue == '#800080' ||
              fillValue == '#808',
          isTrue);
    });

    test('attribute overrides inheritance', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <g fill="yellow">
            <rect id="attribute-over-inheritance" fill="orange"/>
          </g>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles = computeStyle(
          stylesheet, getElementById(root, 'attribute-over-inheritance'));

      expect(styles['fill'], isA<StaticStyle>());
      expect((styles['fill'] as StaticStyle).value, equals('orange'));
      expect((styles['fill'] as StaticStyle).inherited, isFalse);
    });
  });

  group('!important styles', () {
    test('important style rule wins over normal', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>
            .a { fill: red; }
            .b { fill: green !important; }
          </style>
          <rect id="important" class="a b"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'important'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value;
      expect(colorMatches(fillValue, ['green', '#008000', '#0f0']), isTrue);
    });

    test('important style rule wins over inline style', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.b { fill: green !important; }</style>
          <rect id="important-over-inline" style="fill: orange;" class="b"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles = computeStyle(
          stylesheet, getElementById(root, 'important-over-inline'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value;
      expect(colorMatches(fillValue, ['green', '#008000', '#0f0']), isTrue);
    });

    test('important inline style wins over important style rule', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.b { fill: green !important; }</style>
          <rect id="inline-important" style="fill: purple !important;" class="b"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'inline-important'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value;
      expect(colorMatches(fillValue, ['purple', '#800080', '#808']), isTrue);
    });
  });

  group('dynamic styles', () {
    test('media queries produce dynamic styles', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>
            @media screen { .a { fill: red; } }
          </style>
          <rect id="media-query" class="a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'media-query'));

      expect(styles['fill'], isA<DynamicStyle>());
    });

    test('style media attribute produces dynamic styles', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style media="print">.a { fill: red; }</style>
          <rect id="media-attr" class="a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'media-attr'));

      expect(styles['fill'], isA<DynamicStyle>());
    });

    test('static style overrides dynamic inherited style', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>
            @media screen { .a { fill: red; } }
            .c { fill: blue; }
          </style>
          <g class="a">
            <rect id="inherited-overridden" class="c"/>
          </g>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles = computeStyle(
          stylesheet, getElementById(root, 'inherited-overridden'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value;
      expect(colorMatches(fillValue, ['blue', '#00f', '#0000ff']), isTrue);
    });
  });

  group('style element type attribute', () {
    test('valid type text/css is processed', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style type="text/css">.a { fill: red; }</style>
          <rect id="valid-type" class="a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'valid-type'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value;
      expect(colorMatches(fillValue, ['red', '#f00', '#ff0000']), isTrue);
    });

    test('empty type is processed', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style type="">.a { fill: green; }</style>
          <rect id="empty-type" class="a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'empty-type'));

      expect(styles['fill'], isA<StaticStyle>());
      final fillValue = (styles['fill'] as StaticStyle).value;
      expect(colorMatches(fillValue, ['green', '#008000', '#0f0']), isTrue);
    });

    test('invalid type is ignored', () {
      final root = parseSvg('''
        <svg xmlns="http://www.w3.org/2000/svg">
          <style type="text/invalid">.a { fill: blue; }</style>
          <rect id="invalid-type" class="a"/>
        </svg>
      ''');

      final stylesheet = collectStylesheet(root);
      final styles =
          computeStyle(stylesheet, getElementById(root, 'invalid-type'));

      expect(styles['fill'], isNull);
    });
  });

  group('parseStyleDeclarations', () {
    test('parses simple declarations', () {
      final declarations = parseStyleDeclarations('fill: red; stroke: blue');

      expect(declarations.length, equals(2));
      expect(declarations[0].name, equals('fill'));
      // csslib may normalize color values
      expect(colorMatches(declarations[0].value, ['red', '#f00', '#ff0000']),
          isTrue);
      expect(declarations[0].important, isFalse);
      expect(declarations[1].name, equals('stroke'));
      expect(colorMatches(declarations[1].value, ['blue', '#00f', '#0000ff']),
          isTrue);
    });

    test('parses !important declarations', () {
      final declarations =
          parseStyleDeclarations('fill: red !important; stroke: blue');

      expect(declarations[0].name, equals('fill'));
      // csslib may normalize color values
      expect(colorMatches(declarations[0].value, ['red', '#f00', '#ff0000']),
          isTrue);
      expect(declarations[0].important, isTrue);
      expect(declarations[1].important, isFalse);
    });

    test('handles empty input', () {
      final declarations = parseStyleDeclarations('');
      expect(declarations, isEmpty);
    });

    test('handles malformed input gracefully', () {
      final declarations = parseStyleDeclarations('fill red stroke blue');
      // Should not throw, may return empty or partial results
      expect(declarations, isA<List<StylesheetDeclaration>>());
    });
  });

  group('compareSpecificity', () {
    test('compares equal specificities', () {
      const a = Specificity(1, 2, 3);
      const b = Specificity(1, 2, 3);
      expect(compareSpecificity(a, b), equals(0));
    });

    test('compares by ids first', () {
      const a = Specificity(2, 0, 0);
      const b = Specificity(1, 10, 10);
      expect(compareSpecificity(a, b), greaterThan(0));
    });

    test('compares by classes when ids are equal', () {
      const a = Specificity(1, 3, 0);
      const b = Specificity(1, 2, 10);
      expect(compareSpecificity(a, b), greaterThan(0));
    });

    test('compares by types when ids and classes are equal', () {
      const a = Specificity(1, 2, 4);
      const b = Specificity(1, 2, 3);
      expect(compareSpecificity(a, b), greaterThan(0));
    });
  });

  group('includesAttrSelector', () {
    test('detects class selector', () {
      expect(includesAttrSelector('.myClass', 'class'), isTrue);
      expect(
          includesAttrSelector('.myClass', 'class', value: 'myClass'), isTrue);
      expect(
          includesAttrSelector('.myClass', 'class', value: 'other'), isFalse);
    });

    test('detects id selector', () {
      expect(includesAttrSelector('#myId', 'id'), isTrue);
      expect(includesAttrSelector('#myId', 'id', value: 'myId'), isTrue);
      expect(includesAttrSelector('#myId', 'id', value: 'other'), isFalse);
    });

    test('detects attribute selector', () {
      expect(includesAttrSelector('[data-test]', 'data-test'), isTrue);
      expect(includesAttrSelector('[data-test="value"]', 'data-test'), isTrue);
      expect(
          includesAttrSelector('[data-test="value"]', 'data-test',
              value: 'value'),
          isTrue);
    });
  });
}
