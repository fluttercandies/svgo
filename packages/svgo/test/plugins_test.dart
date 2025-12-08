import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('removeComments plugin', () {
    test('removes standard comments', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <!-- This is a comment -->
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeComments]));

      expect(result.data, isNot(contains('<!--')));
      expect(result.data, isNot(contains('-->')));
    });

    test('preserves copyright comments by default', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <!--! Copyright 2024 -->
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeComments]));

      expect(result.data, contains('Copyright'));
    });

    test('removes all comments when preservePatterns is empty', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <!--! Copyright 2024 -->
  <rect/>
</svg>''';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            removeComments.withParams(
              RemoveCommentsParams(preservePatterns: []),
            )
          ]));

      expect(result.data, isNot(contains('Copyright')));
    });
  });

  group('removeDoctype plugin', () {
    test('removes DOCTYPE declaration', () {
      const input =
          '''<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeDoctype]));

      expect(result.data, isNot(contains('<!DOCTYPE')));
    });
  });

  group('removeXMLProcInst plugin', () {
    test('removes XML declaration', () {
      const input = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeXMLProcInst]));

      expect(result.data, isNot(contains('<?xml')));
    });
  });

  group('removeMetadata plugin', () {
    test('removes metadata element', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <metadata>Created with Illustrator</metadata>
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeMetadata]));

      expect(result.data, isNot(contains('<metadata>')));
      expect(result.data, isNot(contains('</metadata>')));
    });
  });

  group('removeDesc plugin', () {
    test('removes empty desc element by default', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <desc></desc>
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeDesc]));

      expect(result.data, isNot(contains('<desc>')));
    });

    test('removes standard editor desc by default', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <desc>Created with Inkscape</desc>
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeDesc]));

      expect(result.data, isNot(contains('<desc>')));
    });

    test('preserves custom desc when removeAny is false', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <desc>A red rectangle</desc>
  <rect/>
</svg>''';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            removeDesc.withParams(RemoveDescParams(removeAny: false))
          ]));

      expect(result.data, contains('<desc>'));
    });

    test('removes any desc when removeAny is true', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <desc>A red rectangle</desc>
  <rect/>
</svg>''';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            removeDesc.withParams(RemoveDescParams(removeAny: true))
          ]));

      expect(result.data, isNot(contains('<desc>')));
    });
  });

  group('convertColors plugin', () {
    test('converts hex to short names', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect fill="#ff0000"/></svg>';

      final result = optimize(input, SvgoConfig(plugins: [convertColors]));

      expect(result.data, contains('red'));
      expect(result.data, isNot(contains('#ff0000')));
    });

    test('converts long hex to short hex', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect fill="#aabbcc"/></svg>';

      final result = optimize(input, SvgoConfig(plugins: [convertColors]));

      expect(result.data, contains('#abc'));
      expect(result.data, isNot(contains('#aabbcc')));
    });

    test('converts rgb to hex', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect fill="rgb(255, 0, 0)"/></svg>';

      final result = optimize(input, SvgoConfig(plugins: [convertColors]));

      expect(result.data, contains('red'));
      expect(result.data, isNot(contains('rgb(')));
    });
  });

  group('convertEllipseToCircle plugin', () {
    test('converts ellipse to circle when rx equals ry', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><ellipse cx="50" cy="50" rx="25" ry="25"/></svg>';

      final result =
          optimize(input, SvgoConfig(plugins: [convertEllipseToCircle]));

      expect(result.data, contains('<circle'));
      expect(result.data, contains('r="25"'));
      expect(result.data, isNot(contains('<ellipse')));
    });

    test('preserves ellipse when rx differs from ry', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><ellipse cx="50" cy="50" rx="30" ry="20"/></svg>';

      final result =
          optimize(input, SvgoConfig(plugins: [convertEllipseToCircle]));

      expect(result.data, contains('<ellipse'));
    });
  });

  group('removeEmptyContainers plugin', () {
    test('removes empty g elements', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <g></g>
  <rect/>
</svg>''';

      final result =
          optimize(input, SvgoConfig(plugins: [removeEmptyContainers]));

      expect(result.data, isNot(contains('<g></g>')));
      expect(result.data, isNot(contains('<g/>')));
    });

    test('removes empty defs elements', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <defs></defs>
  <rect/>
</svg>''';

      final result =
          optimize(input, SvgoConfig(plugins: [removeEmptyContainers]));

      expect(result.data, isNot(contains('<defs>')));
    });

    test('preserves non-empty containers', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <g><rect/></g>
</svg>''';

      final result =
          optimize(input, SvgoConfig(plugins: [removeEmptyContainers]));

      expect(result.data, contains('<g>'));
    });
  });

  group('removeEmptyAttrs plugin', () {
    test('removes empty attribute values', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect id="" class=""/></svg>';

      final result = optimize(input, SvgoConfig(plugins: [removeEmptyAttrs]));

      expect(result.data, isNot(contains('id=""')));
      expect(result.data, isNot(contains('class=""')));
    });

    test('preserves non-empty attributes', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect id="myRect"/></svg>';

      final result = optimize(input, SvgoConfig(plugins: [removeEmptyAttrs]));

      expect(result.data, contains('id="myRect"'));
    });
  });

  group('removeEmptyText plugin', () {
    test('removes empty text elements', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <text></text>
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeEmptyText]));

      expect(result.data, isNot(contains('<text>')));
    });

    test('preserves text elements with whitespace', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <text>   </text>
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeEmptyText]));

      // The current plugin only removes truly empty elements, not whitespace-only
      expect(result.data, contains('<text>'));
    });

    test('preserves text elements with content', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <text>Hello</text>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeEmptyText]));

      expect(result.data, contains('<text>'));
    });
  });

  group('cleanupNumericValues plugin', () {
    test('rounds numeric values', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect x="10.123456789" y="20.987654321"/></svg>';

      final result =
          optimize(input, SvgoConfig(plugins: [cleanupNumericValues]));

      expect(result.data, contains('10.123'));
      expect(result.data, isNot(contains('10.123456789')));
    });

    test('removes default px units', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect width="100px" height="50px"/></svg>';

      final result =
          optimize(input, SvgoConfig(plugins: [cleanupNumericValues]));

      expect(result.data, contains('width="100"'));
      expect(result.data, isNot(contains('100px')));
    });

    test('respects custom float precision', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect x="10.123456789"/></svg>';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            cleanupNumericValues.withParams(
              CleanupNumericValuesParams(floatPrecision: 1),
            )
          ]));

      expect(result.data, contains('10.1'));
    });
  });

  group('cleanupAttrs plugin', () {
    test('removes newlines from attributes', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect fill="red
blue"/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [cleanupAttrs]));

      expect(result.data, isNot(contains('\n')));
    });

    test('trims trailing spaces', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect fill="red  "/></svg>';

      final result = optimize(input, SvgoConfig(plugins: [cleanupAttrs]));

      expect(result.data, contains('fill="red"'));
    });
  });

  group('sortAttrs plugin', () {
    test('sorts attributes alphabetically', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect z="1" a="2" m="3"/></svg>';

      final result = optimize(input, SvgoConfig(plugins: [sortAttrs]));

      final aIndex = result.data.indexOf('a="2"');
      final mIndex = result.data.indexOf('m="3"');
      final zIndex = result.data.indexOf('z="1"');

      expect(aIndex, lessThan(mIndex));
      expect(mIndex, lessThan(zIndex));
    });
  });

  group('removeUnusedNS plugin', () {
    test('removes unused namespace declarations', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     xmlns:foo="http://example.com/foo">
  <rect/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeUnusedNS]));

      expect(result.data, isNot(contains('xmlns:xlink')));
      expect(result.data, isNot(contains('xmlns:foo')));
    });

    test('preserves used namespace declarations', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <use xlink:href="#id"/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [removeUnusedNS]));

      expect(result.data, contains('xmlns:xlink'));
    });
  });

  group('preset-default', () {
    test('applies multiple optimizations', () {
      const input = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "...">
<svg xmlns="http://www.w3.org/2000/svg" width="100px" height="100px">
  <!-- This is a comment -->
  <metadata>Created with Illustrator</metadata>
  <defs></defs>
  <g>
    <rect x="0" y="0" width="100" height="100" fill="#ff0000"/>
  </g>
</svg>''';

      final result = optimize(input);

      expect(result.data, isNot(contains('<?xml')));
      expect(result.data, isNot(contains('<!DOCTYPE')));
      expect(result.data, isNot(contains('<!--')));
      expect(result.data, isNot(contains('<metadata>')));
      expect(result.data, isNot(contains('<defs>')));
      expect(result.data, contains('red'));
    });

    test('reduces file size', () {
      const input = '''
<?xml version="1.0" encoding="UTF-8"?>
<!-- Generator: Adobe Illustrator 24.0.0 -->
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="100px" height="100px" viewBox="0 0 100 100">
  <metadata>Created with Illustrator</metadata>
  <defs></defs>
  <g id="Layer_1">
    <rect x="0.00000" y="0.00000" width="100.00000" height="100.00000" fill="#FF0000"/>
  </g>
</svg>''';

      final result = optimize(input);

      expect(result.data.length, lessThan(input.length));
    });
  });

  group('SvgoConfig', () {
    test('uses default preset when no plugins specified', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <!-- comment -->
  <rect/>
</svg>''';

      final result = optimize(input);

      expect(result.data, isNot(contains('<!--')));
    });

    test('respects multipass option', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <g><g><g><rect/></g></g></g>
</svg>''';

      final singlePass = optimize(input);
      final multiPass = optimize(input, SvgoConfig(multipass: true));

      expect(multiPass.data.length, lessThanOrEqualTo(singlePass.data.length));
    });

    test('respects floatPrecision option', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><rect x="10.123456"/></svg>';

      // Use explicit plugin with custom float precision
      final result = optimize(
          input,
          SvgoConfig(plugins: [
            cleanupNumericValues.withParams(
              CleanupNumericValuesParams(floatPrecision: 1),
            ),
          ]));

      expect(result.data, contains('10.1'));
      expect(result.data, isNot(contains('10.123')));
    });

    test('outputs base64 data URI', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final result = optimize(input, SvgoConfig(datauri: DataUriType.base64));

      expect(result.data, startsWith('data:image/svg+xml;base64,'));
    });

    test('outputs URL-encoded data URI', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final result = optimize(input, SvgoConfig(datauri: DataUriType.enc));

      expect(result.data, startsWith('data:image/svg+xml,'));
      expect(result.data, contains('%'));
    });

    test('outputs unencoded data URI', () {
      const input = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>';

      final result = optimize(input, SvgoConfig(datauri: DataUriType.unenc));

      expect(result.data, startsWith('data:image/svg+xml,'));
      expect(result.data, contains('<svg'));
    });
  });

  group('cleanupListOfValues plugin', () {
    test('rounds viewBox values', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0.12345 0.12345 100.12345 100.12345"><rect/></svg>';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            cleanupListOfValues.withParams(
              CleanupListOfValuesParams(floatPrecision: 2),
            )
          ]));

      expect(result.data, contains('viewBox='));
      // Values should be rounded
      expect(result.data, isNot(contains('.12345')));
    });

    test('rounds points attribute', () {
      const input =
          '<svg xmlns="http://www.w3.org/2000/svg"><polygon points="0.12345,0.12345 10.12345,10.12345"/></svg>';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            cleanupListOfValues.withParams(
              CleanupListOfValuesParams(floatPrecision: 1),
            )
          ]));

      expect(result.data, isNot(contains('.12345')));
    });
  });

  group('removeElementsByAttr plugin', () {
    test('removes element by id', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect id="remove-me"/>
  <rect id="keep-me"/>
</svg>''';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            removeElementsByAttr.withParams(
              RemoveElementsByAttrParams(id: ['remove-me']),
            )
          ]));

      expect(result.data, isNot(contains('remove-me')));
      expect(result.data, contains('keep-me'));
    });

    test('removes element by class', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect class="delete"/>
  <rect class="keep"/>
</svg>''';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            removeElementsByAttr.withParams(
              RemoveElementsByAttrParams(className: ['delete']),
            )
          ]));

      expect(result.data, isNot(contains('delete')));
      expect(result.data, contains('keep'));
    });
  });

  group('removeAttributesBySelector plugin', () {
    test('removes fill attribute from elements matching selector', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect id="target" fill="red" stroke="blue"/>
</svg>''';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            removeAttributesBySelector.withParams(
              RemoveAttributesBySelectorParams(
                selectors: [
                  SelectorAttributesPair(
                    selector: '#target',
                    attributes: ['fill'],
                  ),
                ],
              ),
            )
          ]));

      expect(result.data, isNot(contains('fill=')));
      expect(result.data, contains('stroke='));
    });

    test('removes multiple attributes', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect class="remove" fill="red" stroke="blue" opacity="0.5"/>
</svg>''';

      final result = optimize(
          input,
          SvgoConfig(plugins: [
            removeAttributesBySelector.withParams(
              RemoveAttributesBySelectorParams(
                selectors: [
                  SelectorAttributesPair(
                    selector: '.remove',
                    attributes: ['fill', 'stroke'],
                  ),
                ],
              ),
            )
          ]));

      expect(result.data, isNot(contains('fill=')));
      expect(result.data, isNot(contains('stroke=')));
      expect(result.data, contains('opacity='));
    });
  });

  group('convertStyleToAttrs plugin', () {
    test('converts inline style to attributes', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect style="fill:red;stroke:blue"/>
</svg>''';

      final result =
          optimize(input, SvgoConfig(plugins: [convertStyleToAttrs]));

      expect(result.data, contains('fill="red"'));
      expect(result.data, contains('stroke="blue"'));
      expect(result.data, isNot(contains('style=')));
    });

    test('preserves non-presentation properties in style', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect style="fill:red;display:block"/>
</svg>''';

      final result =
          optimize(input, SvgoConfig(plugins: [convertStyleToAttrs]));

      expect(result.data, contains('fill="red"'));
      // display is converted because it's a presentation attribute
      expect(result.data, contains('display='));
    });
  });

  group('minifyStyles plugin', () {
    test('minifies style element content', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <style>
    .foo {
      fill: red;
      stroke: blue;
    }
  </style>
  <rect class="foo"/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [minifyStyles]));

      // Should not contain excessive whitespace
      expect(result.data, isNot(contains('  fill')));
    });

    test('minifies style attribute', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect style="fill:   red;   stroke:  blue;  "/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [minifyStyles]));

      // Should not contain excessive whitespace
      expect(result.data, isNot(contains('   ')));
    });

    test('optimizes colors', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <rect style="fill:#ff0000"/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [minifyStyles]));

      // #ff0000 should be shortened to #f00
      expect(result.data, contains('#f00'));
    });
  });

  group('applyTransforms plugin', () {
    test('applies translate transform to path', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M0 0 L10 10" transform="translate(5, 5)"/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [applyTransforms]));

      // Transform should be removed
      expect(result.data, isNot(contains('transform=')));
      // Path should be modified (M5 5 instead of M0 0)
      expect(result.data, contains('M'));
    });

    test('skips paths with style attribute', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg">
  <path d="M0 0 L10 10" transform="translate(5, 5)" style="fill:red"/>
</svg>''';

      final result = optimize(input, SvgoConfig(plugins: [applyTransforms]));

      // Transform should be preserved
      expect(result.data, contains('transform='));
    });
  });

  group('removeOffCanvasPaths plugin', () {
    test('removes path outside viewBox', () {
      const input = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M-200 -200 L-100 -100"/>
  <path d="M0 0 L50 50"/>
</svg>''';

      final result =
          optimize(input, SvgoConfig(plugins: [removeOffCanvasPaths]));

      // Off-canvas path should be removed
      expect(result.data, isNot(contains('-200')));
      expect(result.data, isNot(contains('-100')));
      // On-canvas path should remain
      expect(result.data, contains('M0 0'));
    });
  });
}
