import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css_visitor;
import 'package:test/test.dart';

void main() {
  test('declaration span', () {
    final css = '.test { fill: blue; color: #f00; }';
    final ast = css_parser.parse(css);

    for (final topLevel in ast.topLevels) {
      if (topLevel is css_visitor.RuleSet) {
        for (final decl in topLevel.declarationGroup.declarations) {
          if (decl is css_visitor.Declaration) {
            print('Declaration span: ${decl.span}');
            print('Declaration span text: "${decl.span.text}"');
            print('---');
          }
        }
      }
    }
  });
}
