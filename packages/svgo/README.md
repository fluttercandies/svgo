<p align="center">
  <img src="https://raw.githubusercontent.com/fluttercandies/svgo/main/svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<h1 align="center">SVGO</h1>

<p align="center">
  <a href="README.zh.md">🇨🇳 中文</a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/svgo"><img src="https://img.shields.io/pub/v/svgo.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo" alt="license"></a>
</p>

<p align="center">
A comprehensive SVG optimization library for Dart, inspired by proven optimization techniques in the ecosystem.
</p>

## Features

- Parse SVG files into an Abstract Syntax Tree (XAST)
- Apply various optimization plugins
- Serialize optimized AST back to SVG string
- Fully configurable plugin system
- Multipass optimization support
- 54 builtin optimization plugins with comprehensive optimization coverage
- CSS style parsing and computation using csslib
- Path data manipulation utilities
- CSS selector matching

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  svgo: ^1.1.0
```

Or run:

```bash
dart pub add svgo
```

## Usage

### Basic Usage

```dart
import 'package:svgo/svgo.dart';

void main() {
  final input = '''
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
      <!-- A red rectangle -->
      <rect x="0" y="0" width="100" height="100" fill="red"/>
    </svg>
  ''';

  final result = optimize(input);
  print(result.data);
}
```

### With Configuration

```dart
final result = optimize(input, SvgoConfig(
  multipass: true,
  plugins: [presetDefault],
));
```

### Custom Plugin Selection

```dart
final result = optimize(input, SvgoConfig(
  plugins: [
    removeComments,
    convertColors,
    cleanupNumericValues,
  ],
));
```

### Plugin with Custom Parameters

```dart
final result = optimize(input, SvgoConfig(
  plugins: [
    removeComments,
    cleanupNumericValues.withParams(
      CleanupNumericValuesParams(floatPrecision: 2),
    ),
    convertPathData.withParams(
      ConvertPathDataParams(
        floatPrecision: 2,
        makeArcs: MakeArcsConfig(threshold: 2.5),
      ),
    ),
  ],
));
```

### Data URI Output

```dart
final result = optimize(input, SvgoConfig(
  datauri: DataUriType.base64,
));
// result.data: data:image/svg+xml;base64,...
```

### Working with AST

```dart
// Parse SVG to AST
final ast = parseSvg(svgString);

// Traverse and modify AST
for (final child in ast.children) {
  if (child is XastElement && child.name == 'rect') {
    child.attributes['fill'] = 'blue';
  }
}

// Convert AST back to string
final output = stringifySvg(ast);
```

### CSS Style Computation

```dart
final ast = parseSvg(svgWithStyles);
final stylesheet = collectStylesheet(ast);
final styles = computeStyle(stylesheet, element);

if (styles['fill'] case StaticStyle(:final value)) {
  print('Fill color: $value');
}
```

### Path Data Utilities

```dart
// Parse path data
final pathData = parsePathData('M10 20 L30 40 Z');

// Convert to absolute coordinates
final absolute = convertRelativeToAbsolute(pathData);

// Stringify back
final pathString = stringifyPathData(absolute);
```

## Available Plugins

### Cleanup Plugins

| Plugin | Description |
|--------|-------------|
| `cleanupAttrs` | Remove newlines, trailing spaces from attributes |
| `cleanupEnableBackground` | Remove or fix deprecated enable-background attribute |
| `cleanupIds` | Remove or minify unused IDs |
| `cleanupListOfValues` | Round numeric values in list-like attributes |
| `cleanupNumericValues` | Round numeric values, remove default units |

### Remove Plugins

| Plugin | Description |
|--------|-------------|
| `removeAttrs` | Remove specified attributes |
| `removeAttributesBySelector` | Remove attributes by CSS selector |
| `removeComments` | Remove XML comments |
| `removeDeprecatedAttrs` | Remove deprecated SVG attributes |
| `removeDesc` | Remove `<desc>` elements |
| `removeDimensions` | Remove width/height, add viewBox if missing |
| `removeDoctype` | Remove DOCTYPE declaration |
| `removeEditorsNSData` | Remove editor namespaces and elements |
| `removeElementsByAttr` | Remove elements by attribute values |
| `removeEmptyAttrs` | Remove empty attributes |
| `removeEmptyContainers` | Remove empty container elements |
| `removeEmptyText` | Remove empty text elements |
| `removeHiddenElems` | Remove hidden elements |
| `removeMetadata` | Remove `<metadata>` elements |
| `removeNonInheritableGroupAttrs` | Remove non-inheritable group attributes |
| `removeOffCanvasPaths` | Remove paths outside viewBox |
| `removeRasterImages` | Remove raster image elements |
| `removeScripts` | Remove script elements and event handlers |
| `removeStyleElement` | Remove `<style>` elements |
| `removeTitle` | Remove `<title>` elements |
| `removeUnknownsAndDefaults` | Remove unknown elements and default values |
| `removeUnusedNS` | Remove unused namespace declarations |
| `removeUselessDefs` | Remove elements in `<defs>` without id |
| `removeUselessStrokeAndFill` | Remove useless stroke and fill attributes |
| `removeViewBox` | Remove viewBox when width/height present |
| `removeXlink` | Remove deprecated xlink namespace |
| `removeXMLNS` | Remove xmlns attribute (for embedded SVGs) |
| `removeXMLProcInst` | Remove XML processing instructions |

### Convert Plugins

| Plugin | Description |
|--------|-------------|
| `convertColors` | Convert colors to shorter format |
| `convertEllipseToCircle` | Convert ellipse to circle when possible |
| `convertOneStopGradients` | Convert gradients with single stop to solid color |
| `convertPathData` | Optimize path data |
| `convertShapeToPath` | Convert basic shapes to path |
| `convertStyleToAttrs` | Convert style to presentation attributes |
| `convertTransform` | Optimize transform attributes |

### Merge & Move Plugins

| Plugin | Description |
|--------|-------------|
| `collapseGroups` | Collapse useless groups |
| `mergePaths` | Merge adjacent path elements |
| `mergeStyles` | Merge multiple style elements |
| `moveElemsAttrsToGroup` | Move common attributes to group |
| `moveGroupAttrsToElems` | Move group attributes to children |

### Sort Plugins

| Plugin | Description |
|--------|-------------|
| `sortAttrs` | Sort attributes for better compression |
| `sortDefsChildren` | Sort defs children for better compression |

### Style Plugins

| Plugin | Description |
|--------|-------------|
| `inlineStyles` | Inline CSS styles to elements |
| `minifyStyles` | Minify CSS in style elements |

### Other Plugins

| Plugin | Description |
|--------|-------------|
| `addAttributesToSVGElement` | Add attributes to SVG element |
| `addClassesToSVGElement` | Add classes to SVG element |
| `applyTransforms` | Apply transforms to path data |
| `prefixIds` | Add prefix to IDs |
| `reusePaths` | Replace duplicate paths with `<use>` |

## Presets

### preset-default

The default preset includes safe optimizations:

```dart
final result = optimize(input, SvgoConfig(
  plugins: [presetDefault],
));
```

You can customize specific plugins by combining the preset with custom configurations:

```dart
final result = optimize(input, SvgoConfig(
  plugins: [
    // Use preset minus specific plugins you want to customize
    removeDoctype,
    removeXMLProcInst,
    removeComments,
    // Custom cleanupNumericValues with specific precision
    cleanupNumericValues.withParams(
      CleanupNumericValuesParams(floatPrecision: 2),
    ),
    // More plugins...
  ],
));
```

## API Reference

### optimize(input, [config])

Optimizes an SVG string.

**Parameters:**
- `input` (String): The SVG string to optimize
- `config` (SvgoConfig?): Optional configuration

**Returns:** `SvgoOutput` with:
- `data` (String): The optimized SVG string

### parseSvg(input, [path])

Parses an SVG string into an XAST.

**Parameters:**
- `input` (String): The SVG string to parse
- `path` (String?): Optional file path for error messages

**Returns:** `XastRoot`

### stringifySvg(ast, [options])

Converts an XAST back to an SVG string.

**Parameters:**
- `ast` (XastRoot): The AST to stringify
- `options` (StringifyOptions?): Formatting options

**Returns:** String

### collectStylesheet(root)

Collects CSS rules from style elements.

**Parameters:**
- `root` (XastRoot): The parsed SVG AST

**Returns:** `Stylesheet`

### computeStyle(stylesheet, element)

Computes styles for an element.

**Parameters:**
- `stylesheet` (Stylesheet): The collected stylesheet
- `element` (XastElement): The target element

**Returns:** `Map<String, ComputedStyle>`

## License

MIT License - Copyright (c) 2025 iota9star

## Acknowledgments

Thanks to [SVGO](https://github.com/svg/svgo) for inspiration and reference.
