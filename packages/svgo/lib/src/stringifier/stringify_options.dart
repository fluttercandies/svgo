/// SVG stringification options.
library;

/// Line ending style for output.
enum EndOfLine {
  /// Unix-style line endings (LF).
  lf,

  /// Windows-style line endings (CRLF).
  crlf,
}

/// Options for stringifying XAST to SVG string.
class StringifyOptions {
  /// Doctype start delimiter.
  final String doctypeStart;

  /// Doctype end delimiter.
  final String doctypeEnd;

  /// Processing instruction start delimiter.
  final String procInstStart;

  /// Processing instruction end delimiter.
  final String procInstEnd;

  /// Tag open start delimiter.
  final String tagOpenStart;

  /// Tag open end delimiter.
  final String tagOpenEnd;

  /// Tag close start delimiter.
  final String tagCloseStart;

  /// Tag close end delimiter.
  final String tagCloseEnd;

  /// Self-closing tag start delimiter.
  final String tagShortStart;

  /// Self-closing tag end delimiter.
  final String tagShortEnd;

  /// Attribute value start delimiter.
  final String attrStart;

  /// Attribute value end delimiter.
  final String attrEnd;

  /// Comment start delimiter.
  final String commentStart;

  /// Comment end delimiter.
  final String commentEnd;

  /// CDATA start delimiter.
  final String cdataStart;

  /// CDATA end delimiter.
  final String cdataEnd;

  /// Text start delimiter.
  final String textStart;

  /// Text end delimiter.
  final String textEnd;

  /// Number of spaces or string for indentation.
  ///
  /// If a number is provided:
  /// - Negative values use tab character
  /// - Non-negative values use that many spaces
  final Object indent;

  /// Whether to pretty print with indentation and newlines.
  final bool pretty;

  /// Whether to use self-closing tags for empty elements.
  final bool useShortTags;

  /// Line ending style.
  final EndOfLine eol;

  /// Whether to add a final newline at end of output.
  final bool finalNewline;

  const StringifyOptions({
    this.doctypeStart = '<!DOCTYPE',
    this.doctypeEnd = '>',
    this.procInstStart = '<?',
    this.procInstEnd = '?>',
    this.tagOpenStart = '<',
    this.tagOpenEnd = '>',
    this.tagCloseStart = '</',
    this.tagCloseEnd = '>',
    this.tagShortStart = '<',
    this.tagShortEnd = '/>',
    this.attrStart = '="',
    this.attrEnd = '"',
    this.commentStart = '<!--',
    this.commentEnd = '-->',
    this.cdataStart = '<![CDATA[',
    this.cdataEnd = ']]>',
    this.textStart = '',
    this.textEnd = '',
    this.indent = 4,
    this.pretty = false,
    this.useShortTags = true,
    this.eol = EndOfLine.lf,
    this.finalNewline = false,
  });

  /// Default stringify options.
  static const StringifyOptions defaults = StringifyOptions();

  /// Creates options with pretty printing enabled.
  factory StringifyOptions.pretty({
    int indent = 2,
    EndOfLine eol = EndOfLine.lf,
    bool finalNewline = true,
    bool useShortTags = true,
  }) {
    return StringifyOptions(
      indent: indent,
      pretty: true,
      eol: eol,
      finalNewline: finalNewline,
      useShortTags: useShortTags,
    );
  }

  /// Creates a copy with the given fields replaced.
  StringifyOptions copyWith({
    String? doctypeStart,
    String? doctypeEnd,
    String? procInstStart,
    String? procInstEnd,
    String? tagOpenStart,
    String? tagOpenEnd,
    String? tagCloseStart,
    String? tagCloseEnd,
    String? tagShortStart,
    String? tagShortEnd,
    String? attrStart,
    String? attrEnd,
    String? commentStart,
    String? commentEnd,
    String? cdataStart,
    String? cdataEnd,
    String? textStart,
    String? textEnd,
    Object? indent,
    bool? pretty,
    bool? useShortTags,
    EndOfLine? eol,
    bool? finalNewline,
  }) {
    return StringifyOptions(
      doctypeStart: doctypeStart ?? this.doctypeStart,
      doctypeEnd: doctypeEnd ?? this.doctypeEnd,
      procInstStart: procInstStart ?? this.procInstStart,
      procInstEnd: procInstEnd ?? this.procInstEnd,
      tagOpenStart: tagOpenStart ?? this.tagOpenStart,
      tagOpenEnd: tagOpenEnd ?? this.tagOpenEnd,
      tagCloseStart: tagCloseStart ?? this.tagCloseStart,
      tagCloseEnd: tagCloseEnd ?? this.tagCloseEnd,
      tagShortStart: tagShortStart ?? this.tagShortStart,
      tagShortEnd: tagShortEnd ?? this.tagShortEnd,
      attrStart: attrStart ?? this.attrStart,
      attrEnd: attrEnd ?? this.attrEnd,
      commentStart: commentStart ?? this.commentStart,
      commentEnd: commentEnd ?? this.commentEnd,
      cdataStart: cdataStart ?? this.cdataStart,
      cdataEnd: cdataEnd ?? this.cdataEnd,
      textStart: textStart ?? this.textStart,
      textEnd: textEnd ?? this.textEnd,
      indent: indent ?? this.indent,
      pretty: pretty ?? this.pretty,
      useShortTags: useShortTags ?? this.useShortTags,
      eol: eol ?? this.eol,
      finalNewline: finalNewline ?? this.finalNewline,
    );
  }
}
