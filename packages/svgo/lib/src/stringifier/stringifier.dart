/// XAST to SVG string conversion.
///
/// Converts an XAST tree back to an SVG string with configurable formatting.
library;

import '../collections/collections.dart';
import '../xast/xast.dart';
import 'stringify_options.dart';

export 'stringify_options.dart';

/// XML entity mappings.
const _entities = {
  '&': '&amp;',
  "'": '&apos;',
  '"': '&quot;',
  '>': '&gt;',
  '<': '&lt;',
};

/// Regex for entities in text content.
final _regEntities = RegExp(r'''[&'"<>]''');

/// Regex for entities in attribute values.
final _regValEntities = RegExp(r'[&"<>]');

/// Encodes a character as an XML entity.
String _encodeEntity(Match match) {
  return _entities[match.group(0)] ?? match.group(0)!;
}

/// Internal state for stringification.
class _State {
  String indent;
  XastElement? textContext;
  int indentLevel = 0;

  _State({required this.indent});
}

/// Converts an XAST tree to an SVG string.
///
/// Example:
/// ```dart
/// final svg = stringifySvg(root);
/// // Returns: '<svg>...</svg>'
///
/// // With pretty printing:
/// final prettySvg = stringifySvg(root, StringifyOptions.pretty());
/// // Returns formatted SVG with indentation
/// ```
///
/// [data] The XAST root node to stringify.
/// [options] Options controlling the output format.
String stringifySvg(XastRoot data, [StringifyOptions? options]) {
  final config = options ?? StringifyOptions.defaults;

  // Compute indent string
  String indentStr;
  final indent = config.indent;
  if (indent is int) {
    if (indent.isNaN) {
      indentStr = '    ';
    } else if (indent < 0) {
      indentStr = '\t';
    } else {
      indentStr = ' ' * indent;
    }
  } else if (indent is String) {
    indentStr = indent;
  } else {
    indentStr = '    ';
  }

  final state = _State(indent: indentStr);
  final eol = config.eol == EndOfLine.crlf ? '\r\n' : '\n';

  // Apply EOL to delimiters in pretty mode
  final effectiveConfig =
      config.pretty ? _ConfigWithEol(config, eol) : _ConfigWithEol(config, '');

  var svg = _stringifyNode(data, effectiveConfig, state);

  if (config.finalNewline && svg.isNotEmpty && !svg.endsWith('\n')) {
    svg += eol;
  }

  return svg;
}

/// Config wrapper that includes computed EOL suffixes for pretty printing.
class _ConfigWithEol {
  final StringifyOptions config;
  final String doctypeEnd;
  final String procInstEnd;
  final String commentEnd;
  final String cdataEnd;
  final String tagShortEnd;
  final String tagOpenEnd;
  final String tagCloseEnd;
  final String textEnd;

  _ConfigWithEol(this.config, String eol)
      : doctypeEnd = config.doctypeEnd + eol,
        procInstEnd = config.procInstEnd + eol,
        commentEnd = config.commentEnd + eol,
        cdataEnd = config.cdataEnd + eol,
        tagShortEnd = config.tagShortEnd + eol,
        tagOpenEnd = config.tagOpenEnd + eol,
        tagCloseEnd = config.tagCloseEnd + eol,
        textEnd = config.textEnd + eol;
}

/// Stringifies children of a parent node.
String _stringifyNode(XastParent data, _ConfigWithEol config, _State state) {
  final buffer = StringBuffer();
  state.indentLevel++;

  for (final item in data.children) {
    switch (item) {
      case XastElement():
        buffer.write(_stringifyElement(item, config, state));
      case XastText():
        buffer.write(_stringifyText(item, config, state));
      case XastDoctype():
        buffer.write(_stringifyDoctype(item, config));
      case XastInstruction():
        buffer.write(_stringifyInstruction(item, config));
      case XastComment():
        buffer.write(_stringifyComment(item, config));
      case XastCdata():
        buffer.write(_stringifyCdata(item, config, state));
    }
  }

  state.indentLevel--;
  return buffer.toString();
}

/// Creates indent string based on current level.
String _createIndent(_ConfigWithEol config, _State state) {
  if (config.config.pretty && state.textContext == null) {
    return state.indent * (state.indentLevel - 1);
  }
  return '';
}

/// Stringifies a doctype node.
String _stringifyDoctype(XastDoctype node, _ConfigWithEol config) {
  return config.config.doctypeStart + node.doctype + config.doctypeEnd;
}

/// Stringifies a processing instruction node.
String _stringifyInstruction(XastInstruction node, _ConfigWithEol config) {
  return '${config.config.procInstStart}${node.name} ${node.value}${config.procInstEnd}';
}

/// Stringifies a comment node.
String _stringifyComment(XastComment node, _ConfigWithEol config) {
  return config.config.commentStart + node.value + config.commentEnd;
}

/// Stringifies a CDATA node.
String _stringifyCdata(XastCdata node, _ConfigWithEol config, _State state) {
  return _createIndent(config, state) +
      config.config.cdataStart +
      node.value +
      config.cdataEnd;
}

/// Stringifies an element node.
String _stringifyElement(
    XastElement node, _ConfigWithEol config, _State state) {
  // Empty element with short tag
  if (node.children.isEmpty) {
    if (config.config.useShortTags) {
      return _createIndent(config, state) +
          config.config.tagShortStart +
          node.name +
          _stringifyAttributes(node, config) +
          config.tagShortEnd;
    }

    return _createIndent(config, state) +
        config.config.tagShortStart +
        node.name +
        _stringifyAttributes(node, config) +
        config.tagOpenEnd +
        config.config.tagCloseStart +
        node.name +
        config.tagCloseEnd;
  }

  // Non-empty element
  String tagOpenStart = config.config.tagOpenStart;
  String tagOpenEnd = config.tagOpenEnd;
  String tagCloseStart = config.config.tagCloseStart;
  String tagCloseEnd = config.tagCloseEnd;
  String openIndent = _createIndent(config, state);
  String closeIndent = _createIndent(config, state);

  if (state.textContext != null) {
    // Inside text context, use non-pretty delimiters
    tagOpenStart = StringifyOptions.defaults.tagOpenStart;
    tagOpenEnd = StringifyOptions.defaults.tagOpenEnd;
    tagCloseStart = StringifyOptions.defaults.tagCloseStart;
    tagCloseEnd = StringifyOptions.defaults.tagCloseEnd;
    openIndent = '';
  } else if (textElems.contains(node.name)) {
    // Entering text context
    tagOpenEnd = StringifyOptions.defaults.tagOpenEnd;
    tagCloseStart = StringifyOptions.defaults.tagCloseStart;
    closeIndent = '';
    state.textContext = node;
  }

  final children = _stringifyNode(node, config, state);

  if (state.textContext == node) {
    state.textContext = null;
  }

  return openIndent +
      tagOpenStart +
      node.name +
      _stringifyAttributes(node, config) +
      tagOpenEnd +
      children +
      closeIndent +
      tagCloseStart +
      node.name +
      tagCloseEnd;
}

/// Stringifies element attributes.
String _stringifyAttributes(XastElement node, _ConfigWithEol config) {
  final buffer = StringBuffer();

  for (final entry in node.attributes.entries) {
    buffer.write(' ');
    buffer.write(entry.key);

    final value = entry.value;
    final encodedValue = value.replaceAllMapped(_regValEntities, _encodeEntity);
    buffer.write(config.config.attrStart);
    buffer.write(encodedValue);
    buffer.write(config.config.attrEnd);
  }

  return buffer.toString();
}

/// Stringifies a text node.
String _stringifyText(XastText node, _ConfigWithEol config, _State state) {
  final encodedValue = node.value.replaceAllMapped(_regEntities, _encodeEntity);

  return _createIndent(config, state) +
      config.config.textStart +
      encodedValue +
      (state.textContext != null ? '' : config.textEnd);
}
