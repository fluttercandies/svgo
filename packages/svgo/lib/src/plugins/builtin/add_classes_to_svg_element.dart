/// Adds class names to an outer <svg> element.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Parameters for the addClassesToSVGElement plugin.
class AddClassesToSVGElementParams extends PluginParams {
  /// Class names to add to the SVG element.
  final List<String> classNames;

  const AddClassesToSVGElementParams({
    this.classNames = const [],
  });
}

const addClassesToSVGElement = Plugin<AddClassesToSVGElementParams>(
  name: 'addClassesToSVGElement',
  description: 'adds classnames to an outer <svg> element',
  defaultParams: AddClassesToSVGElementParams(),
  fn: _addClassesToSVGElementFn,
);

Visitor? _addClassesToSVGElementFn(
  XastRoot ast,
  AddClassesToSVGElementParams params,
  SvgoInfo info,
) {
  final classNames = params.classNames;

  if (classNames.isEmpty) {
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
          classList.addAll(classNames);
          node.attributes['class'] = classList.join(' ');
        }
        return null;
      },
    ),
  );
}
