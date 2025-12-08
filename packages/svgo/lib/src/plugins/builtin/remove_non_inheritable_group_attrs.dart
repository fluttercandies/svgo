/// Removes non-inheritable group's presentation attributes.
library;

import '../../collections/collections.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeNonInheritableGroupAttrs = Plugin<EmptyParams>(
  name: 'removeNonInheritableGroupAttrs',
  description: "removes non-inheritable group's presentational attributes",
  defaultParams: EmptyParams(),
  fn: _removeNonInheritableGroupAttrsFn,
);

Visitor? _removeNonInheritableGroupAttrsFn(
  XastRoot ast,
  EmptyParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'g') {
          final attrsToRemove = <String>[];
          for (final name in node.attributes.keys) {
            if (AttrsGroups.presentation.contains(name) &&
                !inheritableAttrs.contains(name) &&
                !presentationNonInheritableGroupAttrs.contains(name)) {
              attrsToRemove.add(name);
            }
          }
          for (final attr in attrsToRemove) {
            node.attributes.remove(attr);
          }
        }
        return null;
      },
    ),
  );
}
