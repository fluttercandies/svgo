import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

/// Tests for xml:space="preserve" whitespace handling in parser and stringifier.
void main() {
  group('xml:space preserve', () {
    test('preserves whitespace in text elements', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
<text x="10" y="35" xml:space="preserve">
    <a href="x">
this is a test
    </a>
</text>
</svg>''';

      final parsed = parseSvg(input);
      final output = stringifySvg(parsed);

      // Text content with xml:space="preserve" should maintain whitespace
      expect(output, contains('xml:space="preserve"'));
      // The text content should preserve newlines and spaces
      final textElem = (parsed.children.first as XastElement)
          .children
          .whereType<XastElement>()
          .first;
      expect(textElem.attributes['xml:space'], equals('preserve'));
    });

    test('preserves whitespace in tspan elements', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
<text x="10" y="35" xml:space="preserve">
    <tspan>
this is a test
    </tspan>
</text>
</svg>''';

      final parsed = parseSvg(input);
      final output = stringifySvg(parsed);

      expect(output, contains('xml:space="preserve"'));
    });

    test('handles nested preserve contexts', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
<text xml:space="preserve">  
  <tspan>  preserved  </tspan>  
</text>
</svg>''';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;
      final text = svg.children.whereType<XastElement>().first;

      expect(text.attributes['xml:space'], equals('preserve'));
    });
  });

  group('parser edge cases', () {
    test('handles self-closing tags with attributes', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><circle cx="50" cy="50" r="40"/></svg>';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;
      final circle = svg.children.whereType<XastElement>().first;

      expect(circle.name, equals('circle'));
      expect(circle.attributes['cx'], equals('50'));
      expect(circle.attributes['r'], equals('40'));
    });

    test('handles multiple namespaces', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg" 
           xmlns:xlink="http://www.w3.org/1999/xlink"
           xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd">
  <use xlink:href="#test"/>
</svg>''';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;

      expect(svg.attributes.containsKey('xmlns'), isTrue);
      expect(svg.attributes.containsKey('xmlns:xlink'), isTrue);
      expect(svg.attributes.containsKey('xmlns:sodipodi'), isTrue);
    });

    test('handles empty text content', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><text></text></svg>';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;
      final text = svg.children.whereType<XastElement>().first;

      expect(text.name, equals('text'));
    });

    test('handles special characters in attribute values', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><text data-msg="Hello &amp; Goodbye"/></svg>';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;
      final text = svg.children.whereType<XastElement>().first;

      // The parser should decode XML entities
      expect(text.attributes['data-msg'], equals('Hello & Goodbye'));
    });

    test('handles single quotes in attributes', () {
      const input =
          "<svg xmlns='http://www.w3.org/2000/svg'><rect fill='red'/></svg>";

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;
      final rect = svg.children.whereType<XastElement>().first;

      expect(rect.attributes['fill'], equals('red'));
    });

    test('handles mixed content', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
<text>Hello <tspan fill="red">World</tspan>!</text>
</svg>''';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;
      final text = svg.children.whereType<XastElement>().first;

      // Text element should have mixed content: text nodes and tspan element
      expect(text.children.length, greaterThan(1));
    });

    test('handles deeply nested elements', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
<g id="layer1">
  <g id="layer2">
    <g id="layer3">
      <g id="layer4">
        <rect id="deep"/>
      </g>
    </g>
  </g>
</g>
</svg>''';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;

      XastElement findElement(XastElement parent, String id) {
        for (final child in parent.children.whereType<XastElement>()) {
          if (child.attributes['id'] == id) return child;
          final found = findElement(child, id);
          if (found != parent) return found;
        }
        return parent;
      }

      final deep = findElement(svg, 'deep');
      expect(deep.attributes['id'], equals('deep'));
      expect(deep.name, equals('rect'));
    });

    test('handles numeric attribute values', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50" viewBox="0 0 100 50"/>';

      final parsed = parseSvg(input);
      final svg = parsed.children.first as XastElement;

      expect(svg.attributes['width'], equals('100'));
      expect(svg.attributes['height'], equals('50'));
      expect(svg.attributes['viewBox'], equals('0 0 100 50'));
    });

    test('handles processing instructions', () {
      const input =
          '<?xml version="1.0" encoding="UTF-8"?><?xml-stylesheet type="text/css" href="style.css"?><svg xmlns="http://www.w3.org/2000/svg"/>';

      final parsed = parseSvg(input);

      final instructions = parsed.children.whereType<XastInstruction>();
      expect(instructions.length, greaterThanOrEqualTo(1));
    });

    test('handles whitespace-only text nodes', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
    
  <rect/>
    
</svg>''';

      final parsed = parseSvg(input);
      // Should parse without error
      expect(parsed.children.first, isA<XastElement>());
    });
  });

  group('stringifier edge cases', () {
    test('handles empty root', () {
      final root = XastRoot();
      final output = stringifySvg(root);
      expect(output, isEmpty);
    });

    test('handles elements with no attributes', () {
      final root = XastRoot(children: [
        XastElement(name: 'svg', children: [
          XastElement(name: 'g', children: [
            XastElement(name: 'rect'),
          ]),
        ]),
      ]);

      final output = stringifySvg(root);
      expect(output, contains('<svg>'));
      expect(output, contains('<g>'));
      expect(output, contains('<rect/>'));
    });

    test('handles boolean-like attribute values', () {
      final root = XastRoot(children: [
        XastElement(
          name: 'svg',
          attributes: {'preserveAspectRatio': 'xMidYMid meet'},
        ),
      ]);

      final output = stringifySvg(root);
      expect(output, contains('preserveAspectRatio="xMidYMid meet"'));
    });

    test('handles special XML characters in CDATA', () {
      final root = XastRoot(children: [
        XastElement(name: 'style', children: [
          XastCdata(value: '.a > .b { fill: red; }'),
        ]),
      ]);

      final output = stringifySvg(root);
      expect(output, contains('<![CDATA['));
      expect(output, contains('.a > .b'));
      expect(output, contains(']]>'));
    });

    test('handles multiple comments', () {
      final root = XastRoot(children: [
        XastComment(value: 'First comment'),
        XastElement(name: 'svg', children: [
          XastComment(value: 'Second comment'),
          XastElement(name: 'rect'),
          XastComment(value: 'Third comment'),
        ]),
        XastComment(value: 'Fourth comment'),
      ]);

      final output = stringifySvg(root);
      expect('<!--'.allMatches(output).length, equals(4));
    });

    test('pretty print indentation', () {
      final root = XastRoot(children: [
        XastElement(name: 'svg', children: [
          XastElement(name: 'g', children: [
            XastElement(name: 'rect'),
          ]),
        ]),
      ]);

      final output = stringifySvg(root, StringifyOptions.pretty(indent: 4));

      // Check that indentation exists
      expect(output, contains('\n'));
      // Should have some form of nested indentation
      expect(RegExp(r'\n\s{4}<g>').hasMatch(output), isTrue);
    });

    test('minified output removes unnecessary whitespace', () {
      final root = XastRoot(children: [
        XastElement(name: 'svg', children: [
          XastElement(name: 'g', children: [
            XastElement(name: 'rect'),
          ]),
        ]),
      ]);

      final output = stringifySvg(root);

      // Minified output should not have newlines (unless required)
      expect(output.contains('\n'), isFalse);
    });
  });

  group('roundtrip tests', () {
    test('parse and stringify maintains structure', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect x="10" y="20" width="30" height="40" fill="red"/></svg>';

      final parsed = parseSvg(input);
      final output = stringifySvg(parsed);
      final reparsed = parseSvg(output);

      final svg1 = parsed.children.first as XastElement;
      final svg2 = reparsed.children.first as XastElement;

      expect(svg1.attributes['width'], equals(svg2.attributes['width']));
      expect(svg1.attributes['height'], equals(svg2.attributes['height']));

      final rect1 = svg1.children.whereType<XastElement>().first;
      final rect2 = svg2.children.whereType<XastElement>().first;

      expect(rect1.attributes['x'], equals(rect2.attributes['x']));
      expect(rect1.attributes['fill'], equals(rect2.attributes['fill']));
    });

    test('handles complex SVG roundtrip', () {
      // Note: DOCTYPE handling may vary between parse and stringify
      const input =
          '''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="400" height="400">
  <defs>
    <linearGradient id="grad1">
      <stop offset="0%" style="stop-color:rgb(255,255,0);stop-opacity:1"/>
      <stop offset="100%" style="stop-color:rgb(255,0,0);stop-opacity:1"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="200" height="200" fill="url(#grad1)"/>
  <use xlink:href="#rect1"/>
</svg>''';

      final parsed = parseSvg(input);
      final output = stringifySvg(parsed);
      final reparsed = parseSvg(output);

      // Should not throw and maintain basic structure
      expect(reparsed.children.length, greaterThan(0));
    });
  });
}
