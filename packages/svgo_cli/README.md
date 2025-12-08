<p align="center">
  <img src="https://raw.githubusercontent.com/fluttercandies/svgo/main/svgo.png" alt="SVGO Logo" width="160" height="160">
</p>

<h1 align="center">SVGO CLI</h1>

<p align="center">
  <a href="README.zh.md">🇨🇳 中文</a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/svgo_cli"><img src="https://img.shields.io/pub/v/svgo_cli.svg" alt="pub package"></a>
  <a href="https://github.com/fluttercandies/svgo/blob/main/LICENSE"><img src="https://img.shields.io/github/license/fluttercandies/svgo" alt="license"></a>
</p>

<p align="center">
  Command-line interface for <a href="https://pub.dev/packages/svgo">SVGO</a> - the SVG optimizer.
</p>

## Installation

```bash
dart pub global activate svgo_cli
```

## Usage

```bash
# Optimize a single file (overwrites input)
svgo input.svg

# Optimize to output directory
svgo -o dist input.svg

# Optimize multiple files
svgo icon1.svg icon2.svg icon3.svg

# Optimize all SVGs in a directory (using glob pattern)
svgo "src/**/*.svg"

# Multipass optimization
svgo -m input.svg

# Custom precision (2 decimal places)
svgo -p 2 input.svg

# Quiet mode (no output messages)
svgo -q input.svg

# Show help
svgo --help

# Show version
svgo --version
```

## Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Show help message |
| `--version` | `-v` | Show version information |
| `--output <DIR>` | `-o` | Output directory (default: overwrite input) |
| `--quiet` | `-q` | Suppress output messages |
| `--recursive` | `-r` | Process directories recursively |
| `--precision <NUM>` | `-p` | Float precision (default: 3) |
| `--multipass` | `-m` | Run optimizations multiple times |
| `--config <FILE>` | `-c` | Use custom config file |
| `--no-config` | | Disable automatic config file loading |

## Examples

### Optimize a single file

```bash
svgo logo.svg
```

Output:
```
logo.svg → logo.svg (1234 → 789 bytes, 36.1% saved)

Processed 1 file(s), saved 445 bytes total.
```

### Batch processing

```bash
svgo -o optimized "assets/**/*.svg"
```

### CI/CD Usage

```bash
# Quiet mode for scripts
svgo -q -o dist *.svg
```

## Configuration

SVGO CLI supports YAML configuration files for customizing optimization settings.

### Configuration File Discovery

Configuration files are loaded in the following priority order:

1. **Explicit config file** (`--config` flag)
2. **svgo.yaml** in current directory
3. **svgo.yml** in current directory
4. **pubspec.yaml** (reads `svgo:` key)

Use `--no-config` to disable automatic configuration file loading.

### Configuration File Format

Create a `svgo.yaml` file in your project root:

```yaml
# Float precision for path data
precision: 3

# Run multiple optimization passes
multipass: true

# Output formatting
pretty: false
indent: 2
finalNewline: true
eol: lf  # or 'crlf'
useShortTags: true

# Plugins configuration
plugins:
  # Disable a plugin
  - name: removeViewBox
    enabled: false
  
  # Enable a plugin with default params
  - name: removeDimensions
  
  # Configure plugin with custom params
  - name: cleanupNumericValues
    params:
      floatPrecision: 3
      leadingZero: true
      defaultPx: true
      convertToPx: true
  
  - name: convertColors
    params:
      currentColor: true
      names2hex: true
      rgb2hex: true
      convertCase: lower  # or 'upper'
      shorthex: true
      shortname: true
  
  - name: convertPathData
    params:
      applyTransforms: true
      applyTransformsStroked: true
      makeArcs:
        threshold: 2.5
        tolerance: 0.5
      straightCurves: true
      convertToQ: true
      lineShorthands: true
      convertToZ: true
      curveSmoothShorthands: true
      floatPrecision: 3
      transformPrecision: 5
      smartArcRounding: true
      removeUseless: true
      collapseRepeated: true
      utilizeAbsolute: true
      negativeExtraSpace: true
      forceAbsolutePath: false
  
  - name: cleanupIds
    params:
      remove: true
      minify: true
      preserve:
        - id1
        - id2
      preservePrefixes:
        - icon-
      force: false
  
  - name: removeAttrs
    params:
      attrs:
        - fill
        - stroke
      elemSeparator: ':'
      preserveCurrentColor: false
  
  - name: addAttributesToSVGElement
    params:
      attributes:
        - xmlns:xlink=http://www.w3.org/1999/xlink
        - { role: img }
  
  - name: inlineStyles
    params:
      onlyMatchedOnce: true
      removeMatchedSelectors: true
      useMqs:
        - ""
        - screen
      usePseudos:
        - ""
  
  - name: removeUnknownsAndDefaults
    params:
      unknownContent: true
      unknownAttrs: true
      defaultAttrs: true
      defaultMarkupDeclarations: true
      uselessOverrides: true
      keepDataAttrs: true
      keepAriaAttrs: true
      keepRoleAttr: false
  
  - name: sortAttrs
    params:
      order:
        - id
        - width
        - height
        - viewBox
      xmlnsOrder: front  # or 'alphabetical'
```

### Using pubspec.yaml

You can also add configuration to your `pubspec.yaml`:

```yaml
name: my_app
version: 1.0.0

svgo:
  precision: 3
  multipass: true
  plugins:
    - name: removeViewBox
      enabled: false
    - name: cleanupNumericValues
      params:
        floatPrecision: 3
```

### All Available Plugins

| Plugin | Description |
|--------|-------------|
| `addAttributesToSVGElement` | Add attributes to the root SVG element |
| `addClassesToSVGElement` | Add classes to the root SVG element |
| `cleanupAttrs` | Clean up attribute whitespace |
| `cleanupEnableBackground` | Remove enable-background attribute |
| `cleanupIds` | Remove or minify IDs |
| `cleanupListOfValues` | Clean up list-of-values attributes |
| `cleanupNumericValues` | Clean up numeric values |
| `collapseGroups` | Collapse useless groups |
| `convertColors` | Convert color formats |
| `convertEllipseToCircle` | Convert ellipse to circle when possible |
| `convertOneStopGradients` | Convert single-stop gradients |
| `convertPathData` | Optimize path data |
| `convertShapeToPath` | Convert shapes to paths |
| `convertStyleToAttrs` | Convert style to attributes |
| `convertTransform` | Optimize transforms |
| `inlineStyles` | Inline CSS styles |
| `mergePaths` | Merge multiple paths into one |
| `mergeStyles` | Merge style elements |
| `minifyStyles` | Minify CSS in style elements |
| `moveElemsAttrsToGroup` | Move elements' attributes to group |
| `moveGroupAttrsToElems` | Move group attributes to elements |
| `prefixIds` | Prefix IDs and references |
| `removeAttributesBySelector` | Remove attributes by CSS selector |
| `removeAttrs` | Remove specified attributes |
| `removeComments` | Remove comments |
| `removeDesc` | Remove desc elements |
| `removeDimensions` | Remove width/height, add viewBox |
| `removeDoctype` | Remove DOCTYPE |
| `removeEditorsNSData` | Remove editor namespaces |
| `removeElementsByAttr` | Remove elements by attribute |
| `removeEmptyAttrs` | Remove empty attributes |
| `removeEmptyContainers` | Remove empty containers |
| `removeEmptyText` | Remove empty text elements |
| `removeHiddenElems` | Remove hidden elements |
| `removeMetadata` | Remove metadata |
| `removeNonInheritableGroupAttrs` | Remove non-inheritable group attrs |
| `removeOffCanvasPaths` | Remove off-canvas paths |
| `removeRasterImages` | Remove raster images |
| `removeScripts` | Remove script elements |
| `removeStyleElement` | Remove style elements |
| `removeTitle` | Remove title elements |
| `removeUnknownsAndDefaults` | Remove unknowns and defaults |
| `removeUnusedNS` | Remove unused namespaces |
| `removeUselessDefs` | Remove useless defs |
| `removeUselessStrokeAndFill` | Remove useless stroke/fill |
| `removeViewBox` | Remove viewBox attribute |
| `removeXlink` | Remove xlink namespace |
| `removeXMLNS` | Remove xmlns attribute |
| `removeXMLProcInst` | Remove XML processing instructions |
| `reusePaths` | Replace duplicated paths with use |
| `sortAttrs` | Sort attributes |
| `sortDefsChildren` | Sort children of defs |

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Error (file not found, parse error, etc.) |

## License

MIT License - Copyright (c) 2025 iota9star
