/// Removes unused IDs and minifies used IDs.
library;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const _generateIdChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

final _regReferences = RegExp(
  r'url\(#([^\s")\]]+)\)',
);

// Matches animation timing references like "id.begin" or "id.end+2s"
final _regAnimationRef = RegExp(
  r'([a-zA-Z][\w-]*)\.(begin|end)',
);

const cleanupIds = Plugin(
  name: 'cleanupIds',
  description: 'removes unused IDs and minifies used',
  params: {
    'remove': true,
    'minify': true,
    'preserve': <String>[],
    'preservePrefixes': <String>[],
    'force': false,
  },
  fn: _cleanupIdsFn,
);

/// Checks if SVG consists only of defs (symbols, gradients, etc.) and no renderable content.
bool _isDefsOnly(XastRoot ast) {
  XastElement? svg;
  for (final child in ast.children) {
    if (child is XastElement && child.name == 'svg') {
      svg = child;
      break;
    }
  }
  if (svg == null) return false;

  for (final child in svg.children) {
    if (child is XastElement) {
      // Skip defs, style, metadata, desc, title
      if (child.name == 'defs' ||
          child.name == 'style' ||
          child.name == 'metadata' ||
          child.name == 'desc' ||
          child.name == 'title') {
        continue;
      }
      // Found renderable content
      return false;
    }
  }

  return true;
}

Visitor? _cleanupIdsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final remove = params['remove'] != false;
  final minify = params['minify'] != false;
  final preserveParam = params['preserve'];
  final preserve = preserveParam is String
      ? [preserveParam]
      : (preserveParam as List?)?.cast<String>() ?? [];
  final preservePrefixesParam = params['preservePrefixes'];
  final preservePrefixes = preservePrefixesParam is String
      ? [preservePrefixesParam]
      : (preservePrefixesParam as List?)?.cast<String>() ?? [];
  final force = params['force'] == true;

  // Skip if SVG consists only of defs (external symbol library)
  if (_isDefsOnly(ast)) {
    return null;
  }

  final preserveIds = Set<String>.from(preserve);
  final nodeById = <String, XastElement>{};
  final referencesById = <String, List<_Reference>>{};
  var deoptimized = false;

  bool isIdPreserved(String id) {
    if (preserveIds.contains(id)) return true;
    for (final prefix in preservePrefixes) {
      if (id.startsWith(prefix)) return true;
    }
    return false;
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (!force) {
          // Check for style or script elements
          if ((node.name == 'style' && node.children.isNotEmpty) ||
              node.name == 'script' ||
              node.attributes.containsKey('onload') ||
              node.attributes.containsKey('onclick')) {
            deoptimized = true;
            return null;
          }
        }

        // Collect IDs and references
        for (final entry in node.attributes.entries) {
          final name = entry.key;
          final value = entry.value;

          if (name == 'id') {
            final id = value;
            if (nodeById.containsKey(id)) {
              // Remove duplicate ID
              node.attributes.remove('id');
            } else {
              nodeById[id] = node;
            }
          } else {
            // Find ID references in attribute values
            final ids = _findReferences(name, value);
            for (final id in ids) {
              referencesById.putIfAbsent(id, () => []).add(
                    _Reference(element: node, name: name),
                  );
            }
          }
        }

        return null;
      },
    ),
    root: VisitorRoot(
      exit: (root) {
        if (deoptimized) return;

        List<int>? currentId;

        // Process referenced IDs
        for (final entry in referencesById.entries) {
          final id = entry.key;
          final refs = entry.value;
          final node = nodeById[id];

          if (node != null) {
            // Replace referenced IDs with minified ones
            if (minify && !isIdPreserved(id)) {
              String? currentIdString;
              do {
                currentId = _generateId(currentId);
                currentIdString = _getIdString(currentId);
              } while (isIdPreserved(currentIdString) ||
                  (referencesById.containsKey(currentIdString) &&
                      !nodeById.containsKey(currentIdString)));

              node.attributes['id'] = currentIdString;
              for (final ref in refs) {
                final value = ref.element.attributes[ref.name];
                if (value != null && value.contains('#')) {
                  // Replace id in href and url()
                  ref.element.attributes[ref.name] = value
                      .replaceAll(
                          '#${Uri.encodeComponent(id)}', '#$currentIdString')
                      .replaceAll('#$id', '#$currentIdString');
                } else if (value != null) {
                  // Replace id in begin attribute
                  ref.element.attributes[ref.name] =
                      value.replaceAll('$id.', '$currentIdString.');
                }
              }
            }

            // Keep referenced node
            nodeById.remove(id);
          }
        }

        // Remove unreferenced IDs
        if (remove) {
          for (final entry in nodeById.entries) {
            final id = entry.key;
            final node = entry.value;
            if (!isIdPreserved(id)) {
              node.attributes.remove('id');
            }
          }
        }
      },
    ),
  );
}

class _Reference {
  const _Reference({
    required this.element,
    required this.name,
  });

  final XastElement element;
  final String name;
}

List<String> _findReferences(String name, String value) {
  final ids = <String>[];

  // Check href attributes (including namespaced like xlink:href, x:href)
  if (name == 'href' || name.endsWith(':href')) {
    if (value.startsWith('#')) {
      var id = value.substring(1);
      // Try to decode URI-encoded ID
      try {
        id = Uri.decodeComponent(id);
      } catch (_) {
        // Keep original if decode fails
      }
      ids.add(id);
    }
    return ids;
  }

  // Check animation begin/end references like "id.begin" or "id.end"
  if (name == 'begin' || name == 'end') {
    for (final match in _regAnimationRef.allMatches(value)) {
      final id = match.group(1);
      if (id != null) {
        ids.add(id);
      }
    }
    return ids;
  }

  // Check url() references
  for (final match in _regReferences.allMatches(value)) {
    final rawId = match.group(1);
    if (rawId != null) {
      var id = rawId;
      // Try to decode URI-encoded ID
      try {
        id = Uri.decodeComponent(rawId);
      } catch (_) {
        // Keep original if decode fails
      }
      ids.add(id);
    }
  }

  return ids;
}

List<int> _generateId(List<int>? currentId) {
  if (currentId == null) {
    return [0];
  }

  final maxIndex = _generateIdChars.length - 1;
  currentId[currentId.length - 1]++;

  for (var i = currentId.length - 1; i > 0; i--) {
    if (currentId[i] > maxIndex) {
      currentId[i] = 0;
      currentId[i - 1]++;
    }
  }

  if (currentId[0] > maxIndex) {
    currentId[0] = 0;
    currentId.insert(0, 0);
  }

  return currentId;
}

String _getIdString(List<int> arr) {
  return arr.map((i) => _generateIdChars[i]).join('');
}
