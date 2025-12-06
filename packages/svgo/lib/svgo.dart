/// SVGO - SVG Optimizer for Dart
///
/// A comprehensive library for optimizing SVG files by removing redundant
/// information, cleaning up code, and reducing file size while maintaining
/// visual fidelity.
///
/// ## Features
///
/// - Parse SVG files into an Abstract Syntax Tree (XAST)
/// - Apply various optimization plugins
/// - Serialize optimized AST back to SVG string
/// - Fully configurable with plugin system
/// - Multipass optimization support
///
/// ## Usage
///
/// ```dart
/// import 'package:svgo/svgo.dart';
///
/// void main() {
///   final result = optimize('''
///     <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
///       <rect x="0" y="0" width="100" height="100" fill="red"/>
///     </svg>
///   ''');
///   print(result.data);
/// }
/// ```
library svgo;

// Core exports
export 'src/svgo.dart';
export 'src/types.dart' hide PluginInfo;

// Parser exports
export 'src/parser/parser.dart';
export 'src/parser/parser_error.dart';

// AST exports
export 'src/xast/xast.dart';
export 'src/xast/visitor.dart';
export 'src/xast/xast_utils.dart';

// Stringifier exports
export 'src/stringifier/stringifier.dart';
export 'src/stringifier/stringify_options.dart';

// Path data exports
export 'src/path/path.dart';

// Style exports
export 'src/style/style.dart' hide ComputedStyles;

// CSS selector exports
export 'src/css_select/css_select.dart';

// Plugin system exports
export 'src/plugins/plugin.dart';
export 'src/plugins/builtin.dart';
export 'src/plugins/preset_default.dart';

// Collections exports
export 'src/collections/collections.dart'
    hide presentationNonInheritableGroupAttrs;
