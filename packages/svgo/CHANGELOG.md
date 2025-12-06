# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-06

### Added

- Initial release of SVGO Dart library
- Complete SVG parser with XAST (Abstract Syntax Tree) generation
- Visitor pattern for AST traversal and manipulation
- Comprehensive plugin system with preset support
- **54 builtin optimization plugins** (full parity with node SVGO):

#### Cleanup Plugins
- `cleanupAttrs` - Cleanup attributes from newlines, trailing spaces, etc.
- `cleanupEnableBackground` - Remove or fix deprecated enable-background attribute
- `cleanupIds` - Remove or minify unused IDs
- `cleanupListOfValues` - Round numeric values in list-like attributes
- `cleanupNumericValues` - Round numeric values and remove default units

#### Remove Plugins
- `removeAttrs` - Remove specified attributes
- `removeAttributesBySelector` - Remove attributes by CSS selector
- `removeComments` - Remove comments
- `removeDeprecatedAttrs` - Remove deprecated SVG attributes
- `removeDesc` - Remove `<desc>` elements
- `removeDimensions` - Remove width/height, add viewBox if missing
- `removeDoctype` - Remove DOCTYPE declaration
- `removeEditorsNSData` - Remove editor-specific namespaces and elements
- `removeElementsByAttr` - Remove elements by attribute values
- `removeEmptyAttrs` - Remove empty attributes
- `removeEmptyContainers` - Remove empty container elements
- `removeEmptyText` - Remove empty text elements
- `removeHiddenElems` - Remove hidden elements
- `removeMetadata` - Remove `<metadata>` elements
- `removeNonInheritableGroupAttrs` - Remove non-inheritable group attributes
- `removeOffCanvasPaths` - Remove paths outside viewBox
- `removeRasterImages` - Remove raster image elements
- `removeScripts` - Remove script elements and event handlers
- `removeStyleElement` - Remove `<style>` elements
- `removeTitle` - Remove `<title>` elements
- `removeUnknownsAndDefaults` - Remove unknown elements and default values
- `removeUnusedNS` - Remove unused namespace declarations
- `removeUselessDefs` - Remove elements in `<defs>` without id
- `removeUselessStrokeAndFill` - Remove useless stroke and fill attributes
- `removeViewBox` - Remove viewBox when width/height present
- `removeXlink` - Remove deprecated xlink namespace
- `removeXMLNS` - Remove xmlns attribute (for embedded SVGs)
- `removeXMLProcInst` - Remove XML processing instructions

#### Convert Plugins
- `convertColors` - Convert color values to shorter formats
- `convertEllipseToCircle` - Convert non-eccentric ellipses to circles
- `convertOneStopGradients` - Convert single-stop gradients to solid colors
- `convertPathData` - Optimize path data
- `convertShapeToPath` - Convert basic shapes to path
- `convertStyleToAttrs` - Convert inline styles to presentation attributes
- `convertTransform` - Optimize transform attributes

#### Merge & Move Plugins
- `collapseGroups` - Collapse useless groups
- `mergePaths` - Merge adjacent path elements
- `mergeStyles` - Merge multiple style elements
- `moveElemsAttrsToGroup` - Move common element attributes to parent group
- `moveGroupAttrsToElems` - Move group transform attributes to children

#### Sort Plugins
- `sortAttrs` - Sort element attributes for better compression
- `sortDefsChildren` - Sort children of `<defs>` for better gzip compression

#### Style Plugins
- `inlineStyles` - Inline CSS styles from `<style>` elements to elements
- `minifyStyles` - Minify CSS in style elements and attributes

#### Other Plugins
- `addAttributesToSVGElement` - Add attributes to SVG element
- `addClassesToSVGElement` - Add classes to SVG element
- `applyTransforms` - Apply transforms to path data
- `prefixIds` - Add prefix to IDs
- `reusePaths` - Replace duplicate paths with `<use>` references

### Features

- Default preset (`preset-default`) with safe optimizations
- Multipass optimization support
- SVG path data parsing and manipulation utilities
- CSS style parsing and computation using csslib
- CSS selector matching (supports tag, class, ID, attribute selectors)
- Configurable float precision
- Data URI encoding support (base64, URL-encoded, unencoded)
- Complete type-safe Dart API

### Technical Features

- Full XAST (XML Abstract Syntax Tree) implementation
- CSS selector matching for style computation
- Style specificity calculation
- CSS inheritance handling
- Path data parsing and stringification
- Path conversion between absolute and relative coordinates
- Bounding box computation for paths
- 184 unit tests with 100% pass rate

## [Unreleased]

### Planned

- Performance benchmarks and optimizations
- Streaming API for large files
- Additional path optimization algorithms
