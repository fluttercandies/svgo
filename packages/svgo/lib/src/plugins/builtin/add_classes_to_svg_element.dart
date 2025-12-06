/// Adds class names to an outer <svg> element.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const addClassesToSVGElement = Plugin(
  name: 'addClassesToSVGElement',
  description: 'adds classnames to an outer <svg> element',
  params: {},
  fn: _addClassesToSVGElementFn,
);

Visitor? _addClassesToSVGElementFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final classNames = params['classNames'] as List<String>? ??
      (params['className'] != null ? [params['className'] as String] : null);

  if (classNames == null || classNames.isEmpty) {
    return null;
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'svg' && parentNode is XastRoot) {
          final classList = <String>{};
          final existingClass = node.attributes['class'];
          if (existingClass != null && existingClass.isNotEmpty) {
            classList.addAll(existingClass.split(RegExp(r'\s+')));
          }
          classList.addAll(classNames.whereType<String>());
          node.attributes['class'] = classList.join(' ');
        }
        return null;
      },
    ),
  );
}
