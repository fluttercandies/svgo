/// Prefix IDs and class names to avoid conflicts.
library;

import '../../collections/collections.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const prefixIds = Plugin(
  name: 'prefixIds',
  description: 'prefix IDs',
  params: {
    'delim': '__',
    'prefixIds': true,
    'prefixClassNames': true,
  },
  fn: _prefixIdsFn,
);

String _escapeIdentifierName(String str) {
  return str.replaceAll(RegExp(r'[. ]'), '_');
}

String _getBasename(String path) {
  final matched = RegExp(r'[/\\]?([^/\\]+)$').firstMatch(path);
  if (matched != null) {
    return matched.group(1) ?? '';
  }
  return '';
}

String _generatePrefix(
  String? prefix,
  String delim,
  String? path,
) {
  if (prefix is String) {
    return '$prefix$delim';
  }
  if (prefix == null && path != null && path.isNotEmpty) {
    return '${_escapeIdentifierName(_getBasename(path))}$delim';
  }
  return 'prefix$delim';
}

String _prefixId(String prefixStr, String body) {
  if (body.startsWith(prefixStr)) {
    return body;
  }
  return '$prefixStr$body';
}

String? _prefixReference(String prefixStr, String reference) {
  if (reference.startsWith('#')) {
    return '#${_prefixId(prefixStr, reference.substring(1))}';
  }
  return null;
}

Visitor? _prefixIdsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final delim = (params['delim'] as String?) ?? '__';
  final prefix = params['prefix'];
  final doPrefixIds = params['prefixIds'] != false;
  final doPrefixClassNames = params['prefixClassNames'] != false;

  final prefixStr = _generatePrefix(
    prefix is String ? prefix : null,
    delim,
    info.path,
  );

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Prefix style element content
        if (node.name == 'style' && node.children.isNotEmpty) {
          for (final child in node.children) {
            if (child is XastText) {
              child.value = _prefixStyleContent(
                child.value,
                prefixStr,
                doPrefixIds,
                doPrefixClassNames,
              );
            } else if (child is XastCdata) {
              child.value = _prefixStyleContent(
                child.value,
                prefixStr,
                doPrefixIds,
                doPrefixClassNames,
              );
            }
          }
        }

        // Prefix ID attribute
        if (doPrefixIds) {
          final id = node.attributes['id'];
          if (id != null && id.isNotEmpty) {
            node.attributes['id'] = _prefixId(prefixStr, id);
          }
        }

        // Prefix class attribute
        if (doPrefixClassNames) {
          final className = node.attributes['class'];
          if (className != null && className.isNotEmpty) {
            node.attributes['class'] = className
                .split(RegExp(r'\s+'))
                .map((name) => _prefixId(prefixStr, name))
                .join(' ');
          }
        }

        // Prefix href and xlink:href attributes
        for (final name in ['href', 'xlink:href']) {
          final value = node.attributes[name];
          if (value != null && value.isNotEmpty) {
            final prefixed = _prefixReference(prefixStr, value);
            if (prefixed != null) {
              node.attributes[name] = prefixed;
            }
          }
        }

        // Prefix URL references in presentation attributes
        for (final name in referencesProps) {
          final value = node.attributes[name];
          if (value != null && value.isNotEmpty) {
            node.attributes[name] = value.replaceAllMapped(
              RegExp(r'\burl\((["\x27])?(#.+?)\1\)', caseSensitive: false),
              (match) {
                final url = match.group(2);
                if (url != null) {
                  final prefixed = _prefixReference(prefixStr, url);
                  if (prefixed != null) {
                    return 'url($prefixed)';
                  }
                }
                return match.group(0)!;
              },
            );
          }
        }

        // Prefix begin/end animation attributes
        for (final name in ['begin', 'end']) {
          final value = node.attributes[name];
          if (value != null && value.isNotEmpty) {
            final parts = value.split(RegExp(r'\s*;\s+')).map((val) {
              if (val.endsWith('.end') || val.endsWith('.start')) {
                final dotIndex = val.lastIndexOf('.');
                final id = val.substring(0, dotIndex);
                final postfix = val.substring(dotIndex + 1);
                return '${_prefixId(prefixStr, id)}.$postfix';
              }
              return val;
            }).toList();
            node.attributes[name] = parts.join('; ');
          }
        }

        return null;
      },
    ),
  );
}

String _prefixStyleContent(
  String cssText,
  String prefixStr,
  bool prefixIds,
  bool prefixClassNames,
) {
  // Prefix #id selectors
  if (prefixIds) {
    cssText = cssText.replaceAllMapped(
      RegExp(r'#([\w-]+)'),
      (match) => '#${_prefixId(prefixStr, match.group(1)!)}',
    );
  }

  // Prefix .class selectors
  if (prefixClassNames) {
    cssText = cssText.replaceAllMapped(
      RegExp(r'\.([\w-]+)'),
      (match) => '.${_prefixId(prefixStr, match.group(1)!)}',
    );
  }

  // Prefix url(#id) references
  cssText = cssText.replaceAllMapped(
    RegExp(r"url\(([" "\"'])?#([\\w-]+)\\1\\)", caseSensitive: false),
    (match) {
      final quote = match.group(1) ?? '';
      final id = match.group(2)!;
      return 'url($quote#${_prefixId(prefixStr, id)}$quote)';
    },
  );

  return cssText;
}
