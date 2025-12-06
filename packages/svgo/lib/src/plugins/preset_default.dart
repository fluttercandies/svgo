/// Default preset for SVGO.
///
/// Contains the default set of plugins that are run when optimizing SVGs.
library;

import 'plugin.dart';
import 'builtin/apply_transforms.dart';
import 'builtin/cleanup_attrs.dart';
import 'builtin/cleanup_enable_background.dart';
import 'builtin/cleanup_ids.dart';
import 'builtin/cleanup_list_of_values.dart';
import 'builtin/cleanup_numeric_values.dart';
import 'builtin/collapse_groups.dart';
import 'builtin/convert_colors.dart';
import 'builtin/convert_ellipse_to_circle.dart';
import 'builtin/convert_path_data.dart';
import 'builtin/convert_shape_to_path.dart';
import 'builtin/convert_style_to_attrs.dart';
import 'builtin/convert_transform.dart';
import 'builtin/inline_styles.dart';
import 'builtin/merge_paths.dart';
import 'builtin/merge_styles.dart';
import 'builtin/minify_styles.dart';
import 'builtin/move_elems_attrs_to_group.dart';
import 'builtin/move_group_attrs_to_elems.dart';
import 'builtin/remove_attributes_by_selector.dart';
import 'builtin/remove_comments.dart';
import 'builtin/remove_deprecated_attrs.dart';
import 'builtin/remove_desc.dart';
import 'builtin/remove_doctype.dart';
import 'builtin/remove_editors_ns_data.dart';
import 'builtin/remove_elements_by_attr.dart';
import 'builtin/remove_empty_attrs.dart';
import 'builtin/remove_empty_containers.dart';
import 'builtin/remove_empty_text.dart';
import 'builtin/remove_hidden_elems.dart';
import 'builtin/remove_metadata.dart';
import 'builtin/remove_non_inheritable_group_attrs.dart';
import 'builtin/remove_off_canvas_paths.dart';
import 'builtin/remove_title.dart';
import 'builtin/remove_unknowns_and_defaults.dart';
import 'builtin/remove_unused_ns.dart';
import 'builtin/remove_useless_defs.dart';
import 'builtin/remove_useless_stroke_and_fill.dart';
import 'builtin/remove_xml_proc_inst.dart';
import 'builtin/reuse_paths.dart';
import 'builtin/sort_attrs.dart';
import 'builtin/sort_defs_children.dart';

/// The default preset plugin.
///
/// This preset includes a curated list of plugins that optimize SVGs safely.
/// Use this as a starting point and customize with overrides as needed.
///
/// Example usage:
/// ```dart
/// final config = SvgoConfig(
///   plugins: [presetDefault],
/// );
///
/// // With overrides:
/// final config = SvgoConfig(
///   plugins: [
///     presetDefault.withOverrides({
///       'removeComments': false, // Disable removeComments
///       'cleanupNumericValues': {'floatPrecision': 2}, // Customize params
///     }),
///   ],
/// );
/// ```
final presetDefault = createPreset(
  name: 'preset-default',
  description: 'Default SVGO preset with safe optimizations',
  plugins: [
    removeDoctype,
    removeXMLProcInst,
    removeComments,
    removeDeprecatedAttrs,
    removeMetadata,
    removeEditorsNSData,
    cleanupAttrs,
    mergeStyles,
    inlineStyles,
    minifyStyles,
    cleanupIds,
    removeUselessDefs,
    cleanupNumericValues,
    convertColors,
    removeUnknownsAndDefaults,
    removeNonInheritableGroupAttrs,
    removeUselessStrokeAndFill,
    cleanupEnableBackground,
    removeHiddenElems,
    removeEmptyText,
    convertShapeToPath,
    convertEllipseToCircle,
    moveElemsAttrsToGroup,
    moveGroupAttrsToElems,
    collapseGroups,
    convertPathData,
    convertTransform,
    removeEmptyAttrs,
    removeEmptyContainers,
    mergePaths,
    removeUnusedNS,
    sortAttrs,
    sortDefsChildren,
    removeDesc,
  ],
);

/// List of all builtin plugins.
final builtinPlugins = <Plugin>[
  presetDefault,
  // Core plugins
  applyTransforms,
  cleanupAttrs,
  cleanupEnableBackground,
  cleanupIds,
  cleanupListOfValues,
  cleanupNumericValues,
  collapseGroups,
  convertColors,
  convertEllipseToCircle,
  convertPathData,
  convertShapeToPath,
  convertStyleToAttrs,
  convertTransform,
  inlineStyles,
  mergePaths,
  mergeStyles,
  minifyStyles,
  moveElemsAttrsToGroup,
  moveGroupAttrsToElems,
  removeAttributesBySelector,
  removeComments,
  removeDeprecatedAttrs,
  removeDesc,
  removeDoctype,
  removeEditorsNSData,
  removeElementsByAttr,
  removeEmptyAttrs,
  removeEmptyContainers,
  removeEmptyText,
  removeHiddenElems,
  removeMetadata,
  removeNonInheritableGroupAttrs,
  removeOffCanvasPaths,
  removeTitle,
  removeUnknownsAndDefaults,
  removeUnusedNS,
  removeUselessDefs,
  removeUselessStrokeAndFill,
  removeXMLProcInst,
  reusePaths,
  sortAttrs,
  sortDefsChildren,
];
