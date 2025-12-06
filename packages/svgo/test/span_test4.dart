import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css_visitor;
import 'package:test/test.dart';

void main() {
  test('declaration with space', () {
    // Note the space after "red" - just like in the test fixture
    final css = '.st1{fill:red; }';
    final ast = css_parser.parse(css);

    for (final topLevel in ast.topLevels) {
      if (topLevel is css_visitor.RuleSet) {
        for (final decl in topLevel.declarationGroup.declarations) {
          if (decl is css_visitor.Declaration) {
            print('Declaration span: "${decl.span.text}"');
            final colonIndex = decl.span.text.indexOf(':');
            if (colonIndex != -1) {
              var value = decl.span.text.substring(colonIndex + 1).trim();
              print('Extracted value: "$value"');
            }
          }
        }
      }
    }
  });
}
