import 'package:csslib/parser.dart' as css_parser;
import 'package:csslib/visitor.dart' as css_visitor;
import 'package:test/test.dart';

void main() {
  test('span text', () {
    final css = '.test { fill: blue; color: #f00; }';
    final ast = css_parser.parse(css);

    for (final topLevel in ast.topLevels) {
      if (topLevel is css_visitor.RuleSet) {
        for (final decl in topLevel.declarationGroup.declarations) {
          if (decl is css_visitor.Declaration) {
            final expr = decl.expression;
            print('Property: ${decl.property}');
            print('Expression span: ${expr?.span}');
            print('Expression span text: "${expr?.span?.text}"');

            // Try CssPrinter
            if (expr != null) {
              final printer = css_visitor.CssPrinter();
              expr.visit(printer);
              print('CssPrinter: "$printer"');
            }
            print('---');
          }
        }
      }
    }
  });
}
