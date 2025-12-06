import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('optimize', () {
    test('removes comments by default', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <!-- comment -->
  <rect/>
</svg>''';

      final result = optimize(input);
      expect(result.data, isNot(contains('<!--')));
      expect(result.data, isNot(contains('-->')));
    });

    test('removes XML declaration by default', () {
      const input = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>''';

      final result = optimize(input);
      expect(result.data, isNot(contains('<?xml')));
    });

    test('removes DOCTYPE by default', () {
      const input =
          '''<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>''';

      final result = optimize(input);
      expect(result.data, isNot(contains('<!DOCTYPE')));
    });

    test('removes metadata by default', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <metadata>Some metadata</metadata>
  <rect/>
</svg>''';

      final result = optimize(input);
      expect(result.data, isNot(contains('<metadata>')));
    });

    test('converts colors to shorter format', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect fill="#ff0000"/></svg>';

      final result = optimize(input);
      expect(result.data, contains('red'));
      expect(result.data, isNot(contains('#ff0000')));
    });

    test('converts ellipse to circle when rx equals ry', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><ellipse cx="50" cy="50" rx="25" ry="25"/></svg>';

      final result = optimize(input);
      expect(result.data, contains('<circle'));
      expect(result.data, isNot(contains('<ellipse')));
    });

    test('removes empty containers', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <g></g>
  <rect/>
</svg>''';

      final result = optimize(input);
      expect(result.data, isNot(contains('<g></g>')));
    });

    test('respects multipass option', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <g><g><rect/></g></g>
</svg>''';

      final singlePass = optimize(input);
      final multiPass = optimize(input, SvgoConfig(multipass: true));

      // Multipass should potentially produce smaller output
      expect(multiPass.data.length, lessThanOrEqualTo(singlePass.data.length));
    });

    test('respects floatPrecision option', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect x="10.123456" y="20.654321"/></svg>';

      final result2 = optimize(input, SvgoConfig(floatPrecision: 2));
      final result1 = optimize(input, SvgoConfig(floatPrecision: 1));

      expect(result1.data.length, lessThanOrEqualTo(result2.data.length));
    });

    test('outputs data URI when configured', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final base64Result = optimize(
          input,
          SvgoConfig(
            datauri: DataUriType.base64,
          ));
      expect(base64Result.data, startsWith('data:image/svg+xml;base64,'));

      final encResult = optimize(
          input,
          SvgoConfig(
            datauri: DataUriType.enc,
          ));
      expect(encResult.data, startsWith('data:image/svg+xml,'));
    });
  });

  group('parseSvg', () {
    test('parses valid SVG', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final ast = parseSvg(input);
      expect(ast, isA<XastRoot>());
      expect(ast.children, isNotEmpty);
    });

    test('parses nested elements', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <g id="group1">
    <rect id="rect1"/>
    <circle id="circle1"/>
  </g>
</svg>''';

      final ast = parseSvg(input);
      final svg = ast.children.whereType<XastElement>().first;
      expect(svg.name, equals('svg'));

      final g = svg.children.whereType<XastElement>().first;
      expect(g.name, equals('g'));
      expect(g.attributes['id'], equals('group1'));

      final shapes = g.children.whereType<XastElement>().toList();
      expect(shapes.length, equals(2));
    });
  });

  group('stringifySvg', () {
    test('stringifies AST back to SVG', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final ast = parseSvg(input);
      final output = stringifySvg(ast);

      expect(output, contains('<svg'));
      expect(output, contains('<rect'));
      expect(output, contains('</svg>'));
    });
  });
}
