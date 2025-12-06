/// Cleanup attributes plugin.
///
/// Cleans up attribute values from newlines, trailing and repeating spaces.
///
/// @author Kir Belevich (original JavaScript)
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

final _regNewlinesNeedSpace = RegExp(r'(\S)\r?\n(\S)');
final _regNewlines = RegExp(r'\r?\n');
final _regSpaces = RegExp(r'\s{2,}');

/// Cleans up attribute values from newlines, trailing and repeating spaces.
///
/// Example input:
/// ```xml
/// <svg>
///   <rect class=" foo
///     bar
///      baz "/>
/// </svg>
/// ```
///
/// Example output:
/// ```xml
/// <svg>
///   <rect class="foo bar baz"/>
/// </svg>
/// ```
///
/// Parameters:
/// - `newlines`: Remove newlines from attributes. Default: true
/// - `trim`: Trim leading/trailing whitespace. Default: true
/// - `spaces`: Collapse multiple spaces to single space. Default: true
const cleanupAttrs = Plugin(
  name: 'cleanupAttrs',
  description:
      'cleanups attributes from newlines, trailing and repeating spaces',
  params: {
    'newlines': true,
    'trim': true,
    'spaces': true,
  },
  fn: _cleanupAttrsFn,
);

Visitor? _cleanupAttrsFn(XastRoot ast, PluginParams params, SvgoInfo info) {
  final newlines = params['newlines'] != false;
  final trim = params['trim'] != false;
  final spaces = params['spaces'] != false;

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        for (final name in node.attributes.keys.toList()) {
          var value = node.attributes[name]!;

          if (newlines) {
            // Replace newline which requires a space instead
            value = value.replaceAllMapped(
              _regNewlinesNeedSpace,
              (m) => '${m.group(1)} ${m.group(2)}',
            );
            // Remove simple newlines
            value = value.replaceAll(_regNewlines, '');
          }

          if (trim) {
            value = value.trim();
          }

          if (spaces) {
            value = value.replaceAll(_regSpaces, ' ');
          }

          node.attributes[name] = value;
        }
        return null;
      },
    ),
  );
}
