/// SVG parser error.
///
/// Provides detailed error information including line number, column,
/// and source context to help locate parsing issues.
library;

/// An error that occurred during SVG parsing.
///
/// Example:
/// ```dart
/// try {
///   final ast = parseSvg(svgString);
/// } on SvgoParserError catch (e) {
///   print('Parse error at line ${e.line}, column ${e.column}');
///   print(e.toString()); // Shows formatted error with context
/// }
/// ```
class SvgoParserError extends Error {
  /// Creates a new parser error.
  ///
  /// - [message]: A short description of the error.
  /// - [line]: The 1-based line number where the error occurred.
  /// - [column]: The 1-based column number where the error occurred.
  /// - [source]: The full source string being parsed.
  /// - [file]: Optional filename for better error messages.
  SvgoParserError(
    this.message,
    this.line,
    this.column,
    this.source, [
    this.file,
  ]) : reason = message;

  /// The error message.
  final String message;

  /// The underlying reason for the error.
  final String reason;

  /// The 1-based line number where the error occurred.
  final int line;

  /// The 1-based column number where the error occurred.
  final int column;

  /// The source string being parsed.
  final String source;

  /// The file name (if known).
  final String? file;

  /// Returns a formatted error message with source context.
  @override
  String toString() {
    final lines = source.split(RegExp(r'\r?\n'));
    final startLine = (line - 3).clamp(0, lines.length);
    final endLine = (line + 2).clamp(0, lines.length);
    final lineNumberWidth = endLine.toString().length;
    final startColumn = (column - 54).clamp(0, 1000);
    final endColumn = (column + 20).clamp(0, 80);

    final buffer = StringBuffer();
    buffer.writeln(
        'SvgoParserError: ${file ?? '<input>'}:$line:$column: $message');
    buffer.writeln();

    for (var i = startLine; i < endLine; i++) {
      final lineContent = lines[i];
      var lineSlice = lineContent;
      var ellipsisPrefix = '';
      var ellipsisSuffix = '';

      if (startColumn > 0) {
        if (startColumn >= lineContent.length) {
          lineSlice = '';
          ellipsisPrefix = startColumn > lineContent.length - 1 ? ' ' : '…';
        } else {
          lineSlice = lineContent.substring(
            startColumn,
            endColumn.clamp(0, lineContent.length),
          );
          ellipsisPrefix = '…';
        }
      } else if (lineContent.length > endColumn) {
        lineSlice = lineContent.substring(0, endColumn);
        ellipsisSuffix = '…';
      }

      final number = i + 1;
      final gutter = ' ${number.toString().padLeft(lineNumberWidth)} | ';

      if (number == line) {
        final gutterSpacing = gutter.replaceAll(RegExp(r'[^|]'), ' ');
        final lineSpacing = (ellipsisPrefix +
                lineContent.substring(
                  startColumn.clamp(0, lineContent.length),
                  (column - 1).clamp(0, lineContent.length),
                ))
            .replaceAll(RegExp(r'[^\t]'), ' ');
        final spacing = gutterSpacing + lineSpacing;
        buffer.writeln('>$gutter$ellipsisPrefix$lineSlice$ellipsisSuffix');
        buffer.writeln(' $spacing^');
      } else {
        buffer.writeln(' $gutter$ellipsisPrefix$lineSlice$ellipsisSuffix');
      }
    }

    return buffer.toString();
  }
}
