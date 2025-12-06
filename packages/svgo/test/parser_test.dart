import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('parseSvg', () {
    test('parses simple SVG', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final ast = parseSvg(input);

      expect(ast, isA<XastRoot>());
      expect(ast.children, isNotEmpty);
      expect(ast.children.first, isA<XastElement>());

      final svg = ast.children.first as XastElement;
      expect(svg.name, equals('svg'));
    });

    test('parses XML declaration', () {
      const input = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"/>''';

      final ast = parseSvg(input);

      expect(ast.children.first, isA<XastInstruction>());
      final instruction = ast.children.first as XastInstruction;
      expect(instruction.name, equals('xml'));
      expect(instruction.value, contains('version'));
    });

    test('parses DOCTYPE', () {
      const input =
          '''<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg"/>''';

      final ast = parseSvg(input);

      expect(ast.children.first, isA<XastDoctype>());
    });

    test('parses comments', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
  <!-- This is a comment -->
  <rect/>
</svg>''';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;

      expect(svg.children.any((c) => c is XastComment), isTrue);
      final comment = svg.children.whereType<XastComment>().first;
      expect(comment.value, equals('This is a comment'));
    });

    test('parses CDATA', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
  <style><![CDATA[.a { fill: red; }]]></style>
</svg>''';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;
      final style = svg.children.whereType<XastElement>().first;

      expect(style.children.any((c) => c is XastCdata), isTrue);
    });

    test('parses nested elements', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
  <g id="group1">
    <rect id="rect1"/>
    <circle id="circle1"/>
  </g>
</svg>''';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;
      final g = svg.children.whereType<XastElement>().first;

      expect(g.name, equals('g'));
      expect(g.attributes['id'], equals('group1'));

      final shapes = g.children.whereType<XastElement>().toList();
      expect(shapes.length, equals(2));
      expect(shapes[0].name, equals('rect'));
      expect(shapes[1].name, equals('circle'));
    });

    test('parses attributes', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"/>';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;

      expect(svg.attributes['width'], equals('100'));
      expect(svg.attributes['height'], equals('50'));
    });

    test('parses namespaced attributes', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg" 
           xmlns:xlink="http://www.w3.org/1999/xlink">
  <use xlink:href="#id"/>
</svg>''';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;
      final use = svg.children.whereType<XastElement>().first;

      expect(use.attributes['xlink:href'], equals('#id'));
    });

    test('parses text nodes', () {
      const input = '''<svg xmlns="http://www.w3.org/2000/svg">
  <text>Hello World</text>
</svg>''';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;
      final text = svg.children.whereType<XastElement>().first;

      expect(text.children.any((c) => c is XastText), isTrue);
      final textNode = text.children.whereType<XastText>().first;
      expect(textNode.value, contains('Hello World'));
    });

    test('throws on invalid XML', () {
      const input = '<svg><rect></svg>';

      expect(() => parseSvg(input), throwsA(isA<SvgoParserError>()));
    });

    test('handles empty SVG', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"/>';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;

      expect(svg.children, isEmpty);
    });
  });

  group('stringifySvg', () {
    test('stringifies simple AST', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final ast = parseSvg(input);
      final output = stringifySvg(ast);

      expect(output, contains('<svg'));
      expect(output, contains('<rect'));
      expect(output, contains('</svg>'));
    });

    test('preserves attributes', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect x="10" y="20"/></svg>';

      final ast = parseSvg(input);
      final output = stringifySvg(ast);

      expect(output, contains('width="100"'));
      expect(output, contains('height="50"'));
      expect(output, contains('x="10"'));
      expect(output, contains('y="20"'));
    });

    test('uses short tags for empty elements by default', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final ast = parseSvg(input);
      final output = stringifySvg(ast);

      expect(output, contains('<rect/>'));
    });

    test('respects pretty printing option', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><g><rect/></g></svg>';

      final ast = parseSvg(input);
      final output = stringifySvg(ast, StringifyOptions.pretty());

      expect(output, contains('\n'));
    });

    test('encodes XML entities in text', () {
      final root = XastRoot(children: [
        XastElement(
          name: 'text',
          children: [XastText(value: 'a < b & c > d')],
        ),
      ]);

      final output = stringifySvg(root);

      expect(output, contains('&lt;'));
      expect(output, contains('&amp;'));
      expect(output, contains('&gt;'));
    });

    test('encodes XML entities in attributes', () {
      final root = XastRoot(children: [
        XastElement(
          name: 'svg',
          attributes: {'data-value': 'a "quoted" & b'},
        ),
      ]);

      final output = stringifySvg(root);

      expect(output, contains('&quot;'));
      expect(output, contains('&amp;'));
    });

    test('outputs DOCTYPE', () {
      final root = XastRoot(children: [
        XastDoctype(
          name: 'svg',
          doctype:
              'svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"',
        ),
        XastElement(name: 'svg'),
      ]);

      final output = stringifySvg(root);

      expect(output, contains('<!DOCTYPE'));
    });

    test('outputs XML declaration', () {
      final root = XastRoot(children: [
        XastInstruction(
          name: 'xml',
          value: 'version="1.0" encoding="UTF-8"',
        ),
        XastElement(name: 'svg'),
      ]);

      final output = stringifySvg(root);

      expect(output, contains('<?xml'));
    });

    test('outputs comments', () {
      final root = XastRoot(children: [
        XastComment(value: 'This is a comment'),
        XastElement(name: 'svg'),
      ]);

      final output = stringifySvg(root);

      expect(output, contains('<!--This is a comment-->'));
    });

    test('outputs CDATA', () {
      final root = XastRoot(children: [
        XastElement(
          name: 'style',
          children: [XastCdata(value: '.a { fill: red; }')],
        ),
      ]);

      final output = stringifySvg(root);

      expect(output, contains('<![CDATA['));
      expect(output, contains(']]>'));
    });
  });

  group('XastElement', () {
    test('hasAttribute returns correct value', () {
      final element = XastElement(
        name: 'rect',
        attributes: {'fill': 'red'},
      );

      expect(element.hasAttribute('fill'), isTrue);
      expect(element.hasAttribute('stroke'), isFalse);
    });

    test('getAttribute returns correct value', () {
      final element = XastElement(
        name: 'rect',
        attributes: {'fill': 'red'},
      );

      expect(element.getAttribute('fill'), equals('red'));
      expect(element.getAttribute('stroke'), isNull);
    });

    test('setAttribute updates value', () {
      final element = XastElement(
        name: 'rect',
        attributes: {'fill': 'red'},
      );

      element.setAttribute('fill', 'blue');
      element.setAttribute('stroke', 'black');

      expect(element.getAttribute('fill'), equals('blue'));
      expect(element.getAttribute('stroke'), equals('black'));
    });

    test('removeAttribute removes value', () {
      final element = XastElement(
        name: 'rect',
        attributes: {'fill': 'red', 'stroke': 'blue'},
      );

      element.removeAttribute('fill');

      expect(element.hasAttribute('fill'), isFalse);
      expect(element.hasAttribute('stroke'), isTrue);
    });

    test('name is mutable', () {
      final element = XastElement(name: 'ellipse');

      element.name = 'circle';

      expect(element.name, equals('circle'));
    });
  });

  group('XastNode type guards', () {
    test('isElement returns correct value', () {
      final element = XastElement(name: 'rect');
      final text = XastText(value: 'hello');

      expect(element.isElement, isTrue);
      expect(text.isElement, isFalse);
    });

    test('isText returns correct value', () {
      final text = XastText(value: 'hello');
      final element = XastElement(name: 'rect');

      expect(text.isText, isTrue);
      expect(element.isText, isFalse);
    });

    test('isComment returns correct value', () {
      final comment = XastComment(value: 'comment');
      final element = XastElement(name: 'rect');

      expect(comment.isComment, isTrue);
      expect(element.isComment, isFalse);
    });

    test('isParent returns correct value', () {
      final root = XastRoot();
      final element = XastElement(name: 'rect');
      final text = XastText(value: 'hello');

      expect(root.isParent, isTrue);
      expect(element.isParent, isTrue);
      expect(text.isParent, isFalse);
    });
  });
}
