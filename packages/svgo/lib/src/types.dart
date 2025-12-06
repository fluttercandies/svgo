/// Type definitions for SVGO.
///
/// This file contains all core type definitions used throughout the SVGO library,
/// including AST node types, plugin types, and configuration types.
library;

// =============================================================================
// Path Data Types
// =============================================================================

/// Valid SVG path commands.
///
/// Commands are case-sensitive:
/// - Uppercase commands use absolute coordinates
/// - Lowercase commands use relative coordinates
enum PathDataCommand {
  /// Moveto (absolute)
  M,

  /// Moveto (relative)
  m,

  /// Closepath (absolute)
  Z,

  /// Closepath (relative)
  z,

  /// Lineto (absolute)
  L,

  /// Lineto (relative)
  l,

  /// Horizontal lineto (absolute)
  H,

  /// Horizontal lineto (relative)
  h,

  /// Vertical lineto (absolute)
  V,

  /// Vertical lineto (relative)
  v,

  /// Curveto (absolute)
  C,

  /// Curveto (relative)
  c,

  /// Smooth curveto (absolute)
  S,

  /// Smooth curveto (relative)
  s,

  /// Quadratic Bézier curveto (absolute)
  Q,

  /// Quadratic Bézier curveto (relative)
  q,

  /// Smooth quadratic Bézier curveto (absolute)
  T,

  /// Smooth quadratic Bézier curveto (relative)
  t,

  /// Elliptical arc (absolute)
  A,

  /// Elliptical arc (relative)
  a;

  /// Returns the command character.
  String get value => name;

  /// Creates a command from a character.
  static PathDataCommand? fromChar(String char) {
    return switch (char) {
      'M' => PathDataCommand.M,
      'm' => PathDataCommand.m,
      'Z' => PathDataCommand.Z,
      'z' => PathDataCommand.z,
      'L' => PathDataCommand.L,
      'l' => PathDataCommand.l,
      'H' => PathDataCommand.H,
      'h' => PathDataCommand.h,
      'V' => PathDataCommand.V,
      'v' => PathDataCommand.v,
      'C' => PathDataCommand.C,
      'c' => PathDataCommand.c,
      'S' => PathDataCommand.S,
      's' => PathDataCommand.s,
      'Q' => PathDataCommand.Q,
      'q' => PathDataCommand.q,
      'T' => PathDataCommand.T,
      't' => PathDataCommand.t,
      'A' => PathDataCommand.A,
      'a' => PathDataCommand.a,
      _ => null,
    };
  }

  /// Returns the expected number of arguments for this command.
  int get argsCount => switch (this) {
        PathDataCommand.M || PathDataCommand.m => 2,
        PathDataCommand.Z || PathDataCommand.z => 0,
        PathDataCommand.L || PathDataCommand.l => 2,
        PathDataCommand.H || PathDataCommand.h => 1,
        PathDataCommand.V || PathDataCommand.v => 1,
        PathDataCommand.C || PathDataCommand.c => 6,
        PathDataCommand.S || PathDataCommand.s => 4,
        PathDataCommand.Q || PathDataCommand.q => 4,
        PathDataCommand.T || PathDataCommand.t => 2,
        PathDataCommand.A || PathDataCommand.a => 7,
      };

  /// Returns true if this is a relative command.
  bool get isRelative => name.toLowerCase() == name;

  /// Returns true if this is an absolute command.
  bool get isAbsolute => !isRelative;

  /// Returns the absolute version of this command.
  PathDataCommand get toAbsolute => isAbsolute
      ? this
      : PathDataCommand.values.firstWhere((c) => c.name == name.toUpperCase());

  /// Returns the relative version of this command.
  PathDataCommand get toRelative => isRelative
      ? this
      : PathDataCommand.values.firstWhere((c) => c.name == name.toLowerCase());
}

/// A single path data item consisting of a command and its arguments.
///
/// Example:
/// ```dart
/// final item = PathDataItem(PathDataCommand.M, [10, 20]);
/// print(item); // M 10 20
/// ```
class PathDataItem {
  /// Creates a new path data item.
  PathDataItem(this.command, this.args);

  /// The path command.
  PathDataCommand command;

  /// The arguments for the command.
  List<double> args;

  /// The absolute base coordinates before this command (for precision tracking).
  /// Set by convertToRelative and used by filters for accurate rounding.
  List<double>? base;

  /// The absolute end coordinates after this command (for precision tracking).
  /// Set by convertToRelative and used by filters for accurate rounding.
  List<double>? coords;

  /// Original curve data preserved for arc detection (used by makeArcs).
  List<double>? sdata;

  /// Creates a copy with modified values.
  PathDataItem copyWith({
    PathDataCommand? command,
    List<double>? args,
    List<double>? base,
    List<double>? coords,
    List<double>? sdata,
  }) {
    return PathDataItem(
      command ?? this.command,
      args ?? List.of(this.args),
    )
      ..base = base ?? (this.base != null ? List.of(this.base!) : null)
      ..coords = coords ?? (this.coords != null ? List.of(this.coords!) : null)
      ..sdata = sdata ?? (this.sdata != null ? List.of(this.sdata!) : null);
  }

  @override
  String toString() => '${command.value}${args.join(' ')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathDataItem &&
          runtimeType == other.runtimeType &&
          command == other.command &&
          _listEquals(args, other.args);

  @override
  int get hashCode => Object.hash(command, Object.hashAll(args));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// =============================================================================
// Data URI Types
// =============================================================================

/// Data URI encoding format.
enum DataUri {
  /// Base64 encoding.
  base64,

  /// URI encoded.
  enc,

  /// Unencoded (raw).
  unenc,
}

// =============================================================================
// Stylesheet Types
// =============================================================================

/// CSS selector specificity as [a, b, c] where:
/// - a = number of ID selectors
/// - b = number of class selectors, attribute selectors, and pseudo-classes
/// - c = number of type selectors and pseudo-elements
class Specificity {
  final int ids;
  final int classes;
  final int types;

  const Specificity(this.ids, this.classes, this.types);

  int operator [](int index) {
    switch (index) {
      case 0:
        return ids;
      case 1:
        return classes;
      case 2:
        return types;
      default:
        throw RangeError.index(index, this, 'index', null, 3);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Specificity &&
          ids == other.ids &&
          classes == other.classes &&
          types == other.types;

  @override
  int get hashCode => Object.hash(ids, classes, types);

  @override
  String toString() => 'Specificity($ids, $classes, $types)';
}

/// A CSS declaration.
///
/// Example:
/// ```dart
/// final decl = StylesheetDeclaration(
///   name: 'fill',
///   value: 'red',
///   important: false,
/// );
/// ```
class StylesheetDeclaration {
  /// Creates a new stylesheet declaration.
  const StylesheetDeclaration({
    required this.name,
    required this.value,
    required this.important,
  });

  /// The property name.
  final String name;

  /// The property value.
  final String value;

  /// Whether this declaration is marked as !important.
  final bool important;

  @override
  String toString() => '$name: $value${important ? ' !important' : ''}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StylesheetDeclaration &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value &&
          important == other.important;

  @override
  int get hashCode => Object.hash(name, value, important);
}

/// A CSS rule.
class StylesheetRule {
  /// Creates a new stylesheet rule.
  const StylesheetRule({
    required this.dynamic,
    required this.selector,
    required this.specificity,
    required this.declarations,
  });

  /// Whether this rule is dynamic (e.g., inside @media).
  final bool dynamic;

  /// The CSS selector string.
  final String selector;

  /// The selector specificity.
  final Specificity specificity;

  /// The declarations in this rule.
  final List<StylesheetDeclaration> declarations;

  @override
  String toString() => '$selector { ${declarations.join('; ')} }';
}

// =============================================================================
// Computed Style Types
// =============================================================================

/// Base type for computed styles.
sealed class ComputedStyle {
  const ComputedStyle({required this.inherited});

  /// Whether this style is inherited from a parent element.
  final bool inherited;
}

/// A statically computed style value.
class StaticStyle extends ComputedStyle {
  /// Creates a new static style.
  const StaticStyle({
    required super.inherited,
    required this.value,
  });

  /// The computed value.
  final String value;

  @override
  String toString() => 'StaticStyle($value, inherited: $inherited)';
}

/// A dynamically computed style (cannot be statically determined).
class DynamicStyle extends ComputedStyle {
  /// Creates a new dynamic style.
  const DynamicStyle({required super.inherited});

  @override
  String toString() => 'DynamicStyle(inherited: $inherited)';
}

/// Alias for StaticStyle.
typedef ComputedStyleStatic = StaticStyle;

/// Alias for DynamicStyle.
typedef ComputedStyleDynamic = DynamicStyle;

/// Map of computed styles for an element.
typedef ComputedStyles = Map<String, ComputedStyle>;

// =============================================================================
// Plugin Info Types
// =============================================================================

/// Information passed to plugins during optimization.
class PluginInfo {
  const PluginInfo({
    this.path,
    required this.multipassCount,
  });

  final String? path;
  final int multipassCount;

  @override
  String toString() =>
      'PluginInfo(path: $path, multipassCount: $multipassCount)';
}
