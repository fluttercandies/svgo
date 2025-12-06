/// Removes scripts and event attributes.
library;

import '../../collections/collections.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const removeScripts = Plugin(
  name: 'removeScripts',
  description: 'removes scripts',
  fn: _removeScriptsFn,
);

final _eventAttrs = <String>{
  ...AttrsGroups.animationEvent,
  ...AttrsGroups.documentEvent,
  ...AttrsGroups.documentElementEvent,
  ...AttrsGroups.globalEvent,
  ...AttrsGroups.graphicalEvent,
};

Visitor? _removeScriptsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.name == 'script') {
          detachNodeFromParent(node, parentNode);
          return null;
        }

        for (final attr in _eventAttrs) {
          node.attributes.remove(attr);
        }

        return null;
      },
      exit: (node, parentNode) {
        if (node.name != 'a') return;

        for (final attr in node.attributes.keys.toList()) {
          if (attr == 'href' || attr.endsWith(':href')) {
            final value = node.attributes[attr];
            if (value != null && value.trimLeft().startsWith('javascript:')) {
              if (parentNode is XastElement) {
                final index = parentNode.children.indexOf(node);
                final usefulChildren =
                    node.children.where((c) => c is! XastText).toList();
                parentNode.children.removeAt(index);
                parentNode.children.insertAll(index, usefulChildren);
              }
            }
          }
        }
        return;
      },
    ),
  );
}
