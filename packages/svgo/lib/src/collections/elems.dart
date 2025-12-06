/// Complete SVG element definitions.
///
/// This file contains comprehensive definitions of SVG elements including
/// their allowed attributes, attribute groups, default values, deprecated
/// attributes, and allowed content.
///
/// Based on https://www.w3.org/TR/SVG11/eltindex.html
library;

import 'collections.dart';

/// Configuration for a single SVG element.
class SvgElementConfig {
  const SvgElementConfig({
    required this.attrsGroups,
    this.attrs,
    this.defaults,
    this.deprecated,
    this.contentGroups,
    this.content,
  });

  /// Attribute groups this element supports.
  final Set<String> attrsGroups;

  /// Additional element-specific attributes.
  final Set<String>? attrs;

  /// Default attribute values for this element.
  final Map<String, String>? defaults;

  /// Deprecated attributes for this element.
  /// Contains 'safe' (can be safely removed) and 'unsafe' (need explicit consent).
  final Map<String, Set<String>>? deprecated;

  /// Content groups this element can contain.
  final Set<String>? contentGroups;

  /// Specific elements this element can contain.
  final Set<String>? content;
}

/// Complete SVG element definitions.
///
/// Maps element names to their configuration including allowed attributes,
/// attribute groups, defaults, and allowed children.
///
/// @see https://www.w3.org/TR/SVG11/eltindex.html
const elems = <String, SvgElementConfig>{
  'a': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
      'xlink',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'style',
      'target',
      'transform',
    },
    defaults: {
      'target': '_self',
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
      // not spec compliant
      'tspan',
    },
  ),
  'altGlyph': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
      'xlink',
    },
    attrs: {
      'class',
      'dx',
      'dy',
      'externalResourcesRequired',
      'format',
      'glyphRef',
      'rotate',
      'style',
      'x',
      'y',
    },
  ),
  'altGlyphDef': SvgElementConfig(
    attrsGroups: {'core'},
    content: {'glyphRef'},
  ),
  'altGlyphItem': SvgElementConfig(
    attrsGroups: {'core'},
    content: {'glyphRef', 'altGlyphItem'},
  ),
  'animate': SvgElementConfig(
    attrsGroups: {
      'animationAddition',
      'animationAttributeTarget',
      'animationEvent',
      'animationTiming',
      'animationValue',
      'conditionalProcessing',
      'core',
      'presentation',
      'xlink',
    },
    attrs: {'externalResourcesRequired'},
    contentGroups: {'descriptive'},
  ),
  'animateColor': SvgElementConfig(
    attrsGroups: {
      'animationAddition',
      'animationAttributeTarget',
      'animationEvent',
      'animationTiming',
      'animationValue',
      'conditionalProcessing',
      'core',
      'presentation',
      'xlink',
    },
    attrs: {'externalResourcesRequired'},
    contentGroups: {'descriptive'},
  ),
  'animateMotion': SvgElementConfig(
    attrsGroups: {
      'animationAddition',
      'animationEvent',
      'animationTiming',
      'animationValue',
      'conditionalProcessing',
      'core',
      'xlink',
    },
    attrs: {
      'externalResourcesRequired',
      'keyPoints',
      'origin',
      'path',
      'rotate',
    },
    defaults: {
      'rotate': '0',
    },
    contentGroups: {'descriptive'},
    content: {'mpath'},
  ),
  'animateTransform': SvgElementConfig(
    attrsGroups: {
      'animationAddition',
      'animationAttributeTarget',
      'animationEvent',
      'animationTiming',
      'animationValue',
      'conditionalProcessing',
      'core',
      'xlink',
    },
    attrs: {'externalResourcesRequired', 'type'},
    contentGroups: {'descriptive'},
  ),
  'circle': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'cx',
      'cy',
      'externalResourcesRequired',
      'r',
      'style',
      'transform',
    },
    defaults: {
      'cx': '0',
      'cy': '0',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'clipPath': SvgElementConfig(
    attrsGroups: {'conditionalProcessing', 'core', 'presentation'},
    attrs: {
      'class',
      'clipPathUnits',
      'externalResourcesRequired',
      'style',
      'transform',
    },
    defaults: {
      'clipPathUnits': 'userSpaceOnUse',
    },
    contentGroups: {'animation', 'descriptive', 'shape'},
    content: {'text', 'use'},
  ),
  'color-profile': SvgElementConfig(
    attrsGroups: {'core', 'xlink'},
    attrs: {'local', 'name', 'rendering-intent'},
    defaults: {
      'name': 'sRGB',
      'rendering-intent': 'auto',
    },
    deprecated: {
      'unsafe': {'name'},
    },
    contentGroups: {'descriptive'},
  ),
  'cursor': SvgElementConfig(
    attrsGroups: {'core', 'conditionalProcessing', 'xlink'},
    attrs: {'externalResourcesRequired', 'x', 'y'},
    defaults: {
      'x': '0',
      'y': '0',
    },
    contentGroups: {'descriptive'},
  ),
  'defs': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'style',
      'transform',
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'desc': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'class', 'style'},
  ),
  'ellipse': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'cx',
      'cy',
      'externalResourcesRequired',
      'rx',
      'ry',
      'style',
      'transform',
    },
    defaults: {
      'cx': '0',
      'cy': '0',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'feBlend': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'class',
      'style',
      'in',
      'in2',
      'mode',
    },
    defaults: {
      'mode': 'normal',
    },
    content: {'animate', 'set'},
  ),
  'feColorMatrix': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style', 'in', 'type', 'values'},
    defaults: {
      'type': 'matrix',
    },
    content: {'animate', 'set'},
  ),
  'feComponentTransfer': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style', 'in'},
    content: {'feFuncA', 'feFuncB', 'feFuncG', 'feFuncR'},
  ),
  'feComposite': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'class',
      'in',
      'in2',
      'k1',
      'k2',
      'k3',
      'k4',
      'operator',
      'style',
    },
    defaults: {
      'operator': 'over',
      'k1': '0',
      'k2': '0',
      'k3': '0',
      'k4': '0',
    },
    content: {'animate', 'set'},
  ),
  'feConvolveMatrix': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'class',
      'in',
      'kernelMatrix',
      'order',
      'style',
      'bias',
      'divisor',
      'edgeMode',
      'targetX',
      'targetY',
      'kernelUnitLength',
      'preserveAlpha',
    },
    defaults: {
      'order': '3',
      'bias': '0',
      'edgeMode': 'duplicate',
      'preserveAlpha': 'false',
    },
    content: {'animate', 'set'},
  ),
  'feDiffuseLighting': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'class',
      'diffuseConstant',
      'in',
      'kernelUnitLength',
      'style',
      'surfaceScale',
    },
    defaults: {
      'surfaceScale': '1',
      'diffuseConstant': '1',
    },
    contentGroups: {'descriptive'},
    content: {
      'feDistantLight',
      'fePointLight',
      'feSpotLight',
    },
  ),
  'feDisplacementMap': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'class',
      'in',
      'in2',
      'scale',
      'style',
      'xChannelSelector',
      'yChannelSelector',
    },
    defaults: {
      'scale': '0',
      'xChannelSelector': 'A',
      'yChannelSelector': 'A',
    },
    content: {'animate', 'set'},
  ),
  'feDistantLight': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'azimuth', 'elevation'},
    defaults: {
      'azimuth': '0',
      'elevation': '0',
    },
    content: {'animate', 'set'},
  ),
  'feDropShadow': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'class',
      'style',
      'in',
      'stdDeviation',
      'dx',
      'dy',
    },
    defaults: {
      'stdDeviation': '2',
      'dx': '2',
      'dy': '2',
    },
    content: {'animate', 'set'},
  ),
  'feFlood': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style'},
    content: {'animate', 'animateColor', 'set'},
  ),
  'feFuncA': SvgElementConfig(
    attrsGroups: {'core', 'transferFunction'},
    content: {'set', 'animate'},
  ),
  'feFuncB': SvgElementConfig(
    attrsGroups: {'core', 'transferFunction'},
    content: {'set', 'animate'},
  ),
  'feFuncG': SvgElementConfig(
    attrsGroups: {'core', 'transferFunction'},
    content: {'set', 'animate'},
  ),
  'feFuncR': SvgElementConfig(
    attrsGroups: {'core', 'transferFunction'},
    content: {'set', 'animate'},
  ),
  'feGaussianBlur': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style', 'in', 'stdDeviation'},
    defaults: {
      'stdDeviation': '0',
    },
    content: {'set', 'animate'},
  ),
  'feImage': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive', 'xlink'},
    attrs: {
      'class',
      'externalResourcesRequired',
      'href',
      'preserveAspectRatio',
      'style',
      'xlink:href',
    },
    defaults: {
      'preserveAspectRatio': 'xMidYMid meet',
    },
    content: {'animate', 'animateTransform', 'set'},
  ),
  'feMerge': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style'},
    content: {'feMergeNode'},
  ),
  'feMergeNode': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'in'},
    content: {'animate', 'set'},
  ),
  'feMorphology': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style', 'in', 'operator', 'radius'},
    defaults: {
      'operator': 'erode',
      'radius': '0',
    },
    content: {'animate', 'set'},
  ),
  'feOffset': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style', 'in', 'dx', 'dy'},
    defaults: {
      'dx': '0',
      'dy': '0',
    },
    content: {'animate', 'set'},
  ),
  'fePointLight': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'x', 'y', 'z'},
    defaults: {
      'x': '0',
      'y': '0',
      'z': '0',
    },
    content: {'animate', 'set'},
  ),
  'feSpecularLighting': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'class',
      'in',
      'kernelUnitLength',
      'specularConstant',
      'specularExponent',
      'style',
      'surfaceScale',
    },
    defaults: {
      'surfaceScale': '1',
      'specularConstant': '1',
      'specularExponent': '1',
    },
    contentGroups: {
      'descriptive',
      'lightSource',
    },
  ),
  'feSpotLight': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {
      'limitingConeAngle',
      'pointsAtX',
      'pointsAtY',
      'pointsAtZ',
      'specularExponent',
      'x',
      'y',
      'z',
    },
    defaults: {
      'x': '0',
      'y': '0',
      'z': '0',
      'pointsAtX': '0',
      'pointsAtY': '0',
      'pointsAtZ': '0',
      'specularExponent': '1',
    },
    content: {'animate', 'set'},
  ),
  'feTile': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {'class', 'style', 'in'},
    content: {'animate', 'set'},
  ),
  'feTurbulence': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'filterPrimitive'},
    attrs: {
      'baseFrequency',
      'class',
      'numOctaves',
      'seed',
      'stitchTiles',
      'style',
      'type',
    },
    defaults: {
      'baseFrequency': '0',
      'numOctaves': '1',
      'seed': '0',
      'stitchTiles': 'noStitch',
      'type': 'turbulence',
    },
    content: {'animate', 'set'},
  ),
  'filter': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'xlink'},
    attrs: {
      'class',
      'externalResourcesRequired',
      'filterRes',
      'filterUnits',
      'height',
      'href',
      'primitiveUnits',
      'style',
      'width',
      'x',
      'xlink:href',
      'y',
    },
    defaults: {
      'primitiveUnits': 'userSpaceOnUse',
      'x': '-10%',
      'y': '-10%',
      'width': '120%',
      'height': '120%',
    },
    deprecated: {
      'unsafe': {'filterRes'},
    },
    contentGroups: {'descriptive', 'filterPrimitive'},
    content: {'animate', 'set'},
  ),
  'font': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {
      'class',
      'externalResourcesRequired',
      'horiz-adv-x',
      'horiz-origin-x',
      'horiz-origin-y',
      'style',
      'vert-adv-y',
      'vert-origin-x',
      'vert-origin-y',
    },
    defaults: {
      'horiz-origin-x': '0',
      'horiz-origin-y': '0',
    },
    deprecated: {
      'unsafe': {
        'horiz-origin-x',
        'horiz-origin-y',
        'vert-adv-y',
        'vert-origin-x',
        'vert-origin-y',
      },
    },
    contentGroups: {'descriptive'},
    content: {'font-face', 'glyph', 'hkern', 'missing-glyph', 'vkern'},
  ),
  'font-face': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {
      'font-family',
      'font-style',
      'font-variant',
      'font-weight',
      'font-stretch',
      'font-size',
      'unicode-range',
      'units-per-em',
      'panose-1',
      'stemv',
      'stemh',
      'slope',
      'cap-height',
      'x-height',
      'accent-height',
      'ascent',
      'descent',
      'widths',
      'bbox',
      'ideographic',
      'alphabetic',
      'mathematical',
      'hanging',
      'v-ideographic',
      'v-alphabetic',
      'v-mathematical',
      'v-hanging',
      'underline-position',
      'underline-thickness',
      'strikethrough-position',
      'strikethrough-thickness',
      'overline-position',
      'overline-thickness',
    },
    defaults: {
      'font-style': 'all',
      'font-variant': 'normal',
      'font-weight': 'all',
      'font-stretch': 'normal',
      'unicode-range': 'U+0-10FFFF',
      'units-per-em': '1000',
      'panose-1': '0 0 0 0 0 0 0 0 0 0',
      'slope': '0',
    },
    deprecated: {
      'unsafe': {
        'accent-height',
        'alphabetic',
        'ascent',
        'bbox',
        'cap-height',
        'descent',
        'hanging',
        'ideographic',
        'mathematical',
        'panose-1',
        'slope',
        'stemh',
        'stemv',
        'unicode-range',
        'units-per-em',
        'v-alphabetic',
        'v-hanging',
        'v-ideographic',
        'v-mathematical',
        'widths',
        'x-height',
      },
    },
    contentGroups: {'descriptive'},
    content: {
      'font-face-src',
    },
  ),
  'font-face-format': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'string'},
    deprecated: {
      'unsafe': {'string'},
    },
  ),
  'font-face-name': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'name'},
    deprecated: {
      'unsafe': {'name'},
    },
  ),
  'font-face-src': SvgElementConfig(
    attrsGroups: {'core'},
    content: {'font-face-name', 'font-face-uri'},
  ),
  'font-face-uri': SvgElementConfig(
    attrsGroups: {'core', 'xlink'},
    attrs: {'href', 'xlink:href'},
    content: {'font-face-format'},
  ),
  'foreignObject': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'height',
      'style',
      'transform',
      'width',
      'x',
      'y',
    },
    defaults: {
      'x': '0',
      'y': '0',
    },
  ),
  'g': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'style',
      'transform',
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'glyph': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {
      'arabic-form',
      'class',
      'd',
      'glyph-name',
      'horiz-adv-x',
      'lang',
      'orientation',
      'style',
      'unicode',
      'vert-adv-y',
      'vert-origin-x',
      'vert-origin-y',
    },
    defaults: {
      'arabic-form': 'initial',
    },
    deprecated: {
      'unsafe': {
        'arabic-form',
        'glyph-name',
        'horiz-adv-x',
        'orientation',
        'unicode',
        'vert-adv-y',
        'vert-origin-x',
        'vert-origin-y',
      },
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'glyphRef': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {
      'class',
      'd',
      'horiz-adv-x',
      'style',
      'vert-adv-y',
      'vert-origin-x',
      'vert-origin-y',
    },
    deprecated: {
      'unsafe': {
        'horiz-adv-x',
        'vert-adv-y',
        'vert-origin-x',
        'vert-origin-y',
      },
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'hatch': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'xlink'},
    attrs: {
      'class',
      'hatchContentUnits',
      'hatchUnits',
      'pitch',
      'rotate',
      'style',
      'transform',
      'x',
      'y',
    },
    defaults: {
      'hatchUnits': 'objectBoundingBox',
      'hatchContentUnits': 'userSpaceOnUse',
      'x': '0',
      'y': '0',
      'pitch': '0',
      'rotate': '0',
    },
    contentGroups: {'animation', 'descriptive'},
    content: {'hatchPath'},
  ),
  'hatchPath': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'xlink'},
    attrs: {'class', 'style', 'd', 'offset'},
    defaults: {
      'offset': '0',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'hkern': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'u1', 'g1', 'u2', 'g2', 'k'},
    deprecated: {
      'unsafe': {'g1', 'g2', 'k', 'u1', 'u2'},
    },
  ),
  'image': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
      'xlink',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'height',
      'href',
      'preserveAspectRatio',
      'style',
      'transform',
      'width',
      'x',
      'xlink:href',
      'y',
    },
    defaults: {
      'x': '0',
      'y': '0',
      'preserveAspectRatio': 'xMidYMid meet',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'line': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'style',
      'transform',
      'x1',
      'x2',
      'y1',
      'y2',
    },
    defaults: {
      'x1': '0',
      'y1': '0',
      'x2': '0',
      'y2': '0',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'linearGradient': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'xlink'},
    attrs: {
      'class',
      'externalResourcesRequired',
      'gradientTransform',
      'gradientUnits',
      'href',
      'spreadMethod',
      'style',
      'x1',
      'x2',
      'xlink:href',
      'y1',
      'y2',
    },
    defaults: {
      'x1': '0',
      'y1': '0',
      'x2': '100%',
      'y2': '0',
      'spreadMethod': 'pad',
    },
    contentGroups: {'descriptive'},
    content: {'animate', 'animateTransform', 'set', 'stop'},
  ),
  'marker': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {
      'class',
      'externalResourcesRequired',
      'markerHeight',
      'markerUnits',
      'markerWidth',
      'orient',
      'preserveAspectRatio',
      'refX',
      'refY',
      'style',
      'viewBox',
    },
    defaults: {
      'markerUnits': 'strokeWidth',
      'refX': '0',
      'refY': '0',
      'markerWidth': '3',
      'markerHeight': '3',
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'mask': SvgElementConfig(
    attrsGroups: {'conditionalProcessing', 'core', 'presentation'},
    attrs: {
      'class',
      'externalResourcesRequired',
      'height',
      'mask-type',
      'maskContentUnits',
      'maskUnits',
      'style',
      'width',
      'x',
      'y',
    },
    defaults: {
      'maskUnits': 'objectBoundingBox',
      'maskContentUnits': 'userSpaceOnUse',
      'x': '-10%',
      'y': '-10%',
      'width': '120%',
      'height': '120%',
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'metadata': SvgElementConfig(
    attrsGroups: {'core'},
  ),
  'missing-glyph': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {
      'class',
      'd',
      'horiz-adv-x',
      'style',
      'vert-adv-y',
      'vert-origin-x',
      'vert-origin-y',
    },
    deprecated: {
      'unsafe': {
        'horiz-adv-x',
        'vert-adv-y',
        'vert-origin-x',
        'vert-origin-y',
      },
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'mpath': SvgElementConfig(
    attrsGroups: {'core', 'xlink'},
    attrs: {'externalResourcesRequired', 'href', 'xlink:href'},
    contentGroups: {'descriptive'},
  ),
  'path': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'd',
      'externalResourcesRequired',
      'pathLength',
      'style',
      'transform',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'pattern': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'presentation',
      'xlink',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'height',
      'href',
      'patternContentUnits',
      'patternTransform',
      'patternUnits',
      'preserveAspectRatio',
      'style',
      'viewBox',
      'width',
      'x',
      'xlink:href',
      'y',
    },
    defaults: {
      'patternUnits': 'objectBoundingBox',
      'patternContentUnits': 'userSpaceOnUse',
      'x': '0',
      'y': '0',
      'width': '0',
      'height': '0',
      'preserveAspectRatio': 'xMidYMid meet',
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'polygon': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'points',
      'style',
      'transform',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'polyline': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'points',
      'style',
      'transform',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'radialGradient': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'xlink'},
    attrs: {
      'class',
      'cx',
      'cy',
      'externalResourcesRequired',
      'fr',
      'fx',
      'fy',
      'gradientTransform',
      'gradientUnits',
      'href',
      'r',
      'spreadMethod',
      'style',
      'xlink:href',
    },
    defaults: {
      'gradientUnits': 'objectBoundingBox',
      'cx': '50%',
      'cy': '50%',
      'r': '50%',
    },
    contentGroups: {'descriptive'},
    content: {'animate', 'animateTransform', 'set', 'stop'},
  ),
  'meshGradient': SvgElementConfig(
    attrsGroups: {'core', 'presentation', 'xlink'},
    attrs: {'class', 'style', 'x', 'y', 'gradientUnits', 'transform'},
    contentGroups: {'descriptive', 'paintServer', 'animation'},
    content: {'meshRow'},
  ),
  'meshRow': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {'class', 'style'},
    contentGroups: {'descriptive'},
    content: {'meshPatch'},
  ),
  'meshPatch': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {'class', 'style'},
    contentGroups: {'descriptive'},
    content: {'stop'},
  ),
  'rect': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'height',
      'rx',
      'ry',
      'style',
      'transform',
      'width',
      'x',
      'y',
    },
    defaults: {
      'x': '0',
      'y': '0',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'script': SvgElementConfig(
    attrsGroups: {'core', 'xlink'},
    attrs: {'externalResourcesRequired', 'type', 'href', 'xlink:href'},
  ),
  'set': SvgElementConfig(
    attrsGroups: {
      'animation',
      'animationAttributeTarget',
      'animationTiming',
      'conditionalProcessing',
      'core',
      'xlink',
    },
    attrs: {'externalResourcesRequired', 'to'},
    contentGroups: {'descriptive'},
  ),
  'solidColor': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {'class', 'style'},
    contentGroups: {'paintServer'},
  ),
  'stop': SvgElementConfig(
    attrsGroups: {'core', 'presentation'},
    attrs: {'class', 'style', 'offset', 'path'},
    content: {'animate', 'animateColor', 'set'},
  ),
  'style': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'type', 'media', 'title'},
    defaults: {
      'type': 'text/css',
    },
  ),
  'svg': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'documentEvent',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'baseProfile',
      'class',
      'contentScriptType',
      'contentStyleType',
      'height',
      'preserveAspectRatio',
      'style',
      'version',
      'viewBox',
      'width',
      'x',
      'y',
      'zoomAndPan',
    },
    defaults: {
      'x': '0',
      'y': '0',
      'width': '100%',
      'height': '100%',
      'preserveAspectRatio': 'xMidYMid meet',
      'zoomAndPan': 'magnify',
      'version': '1.1',
      'baseProfile': 'none',
      'contentScriptType': 'application/ecmascript',
      'contentStyleType': 'text/css',
    },
    deprecated: {
      'safe': {'version'},
      'unsafe': {
        'baseProfile',
        'contentScriptType',
        'contentStyleType',
        'zoomAndPan',
      },
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'switch': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'style',
      'transform',
    },
    contentGroups: {'animation', 'descriptive', 'shape'},
    content: {
      'a',
      'foreignObject',
      'g',
      'image',
      'svg',
      'switch',
      'text',
      'use',
    },
  ),
  'symbol': SvgElementConfig(
    attrsGroups: {'core', 'graphicalEvent', 'presentation'},
    attrs: {
      'class',
      'externalResourcesRequired',
      'preserveAspectRatio',
      'refX',
      'refY',
      'style',
      'viewBox',
    },
    defaults: {
      'refX': '0',
      'refY': '0',
    },
    contentGroups: {
      'animation',
      'descriptive',
      'paintServer',
      'shape',
      'structural',
    },
    content: {
      'a',
      'altGlyphDef',
      'clipPath',
      'color-profile',
      'cursor',
      'filter',
      'font-face',
      'font',
      'foreignObject',
      'image',
      'marker',
      'mask',
      'pattern',
      'script',
      'style',
      'switch',
      'text',
      'view',
    },
  ),
  'text': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'dx',
      'dy',
      'externalResourcesRequired',
      'lengthAdjust',
      'rotate',
      'style',
      'textLength',
      'transform',
      'x',
      'y',
    },
    defaults: {
      'x': '0',
      'y': '0',
      'lengthAdjust': 'spacing',
    },
    contentGroups: {'animation', 'descriptive', 'textContentChild'},
    content: {'a'},
  ),
  'textPath': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
      'xlink',
    },
    attrs: {
      'class',
      'd',
      'externalResourcesRequired',
      'href',
      'method',
      'spacing',
      'startOffset',
      'style',
      'xlink:href',
    },
    defaults: {
      'startOffset': '0',
      'method': 'align',
      'spacing': 'exact',
    },
    contentGroups: {'descriptive'},
    content: {
      'a',
      'altGlyph',
      'animate',
      'animateColor',
      'set',
      'tref',
      'tspan',
    },
  ),
  'title': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'class', 'style'},
  ),
  'tref': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
      'xlink',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'href',
      'style',
      'xlink:href',
    },
    contentGroups: {'descriptive'},
    content: {'animate', 'animateColor', 'set'},
  ),
  'tspan': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
    },
    attrs: {
      'class',
      'dx',
      'dy',
      'externalResourcesRequired',
      'lengthAdjust',
      'rotate',
      'style',
      'textLength',
      'x',
      'y',
    },
    contentGroups: {'descriptive'},
    content: {
      'a',
      'altGlyph',
      'animate',
      'animateColor',
      'set',
      'tref',
      'tspan',
    },
  ),
  'use': SvgElementConfig(
    attrsGroups: {
      'conditionalProcessing',
      'core',
      'graphicalEvent',
      'presentation',
      'xlink',
    },
    attrs: {
      'class',
      'externalResourcesRequired',
      'height',
      'href',
      'style',
      'transform',
      'width',
      'x',
      'xlink:href',
      'y',
    },
    defaults: {
      'x': '0',
      'y': '0',
    },
    contentGroups: {'animation', 'descriptive'},
  ),
  'view': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {
      'externalResourcesRequired',
      'preserveAspectRatio',
      'viewBox',
      'viewTarget',
      'zoomAndPan',
    },
    deprecated: {
      'unsafe': {'viewTarget', 'zoomAndPan'},
    },
    contentGroups: {'descriptive'},
  ),
  'vkern': SvgElementConfig(
    attrsGroups: {'core'},
    attrs: {'u1', 'g1', 'u2', 'g2', 'k'},
    deprecated: {
      'unsafe': {'g1', 'g2', 'k', 'u1', 'u2'},
    },
  ),
};

// =============================================================================
// Helper functions for accessing element configuration
// =============================================================================

/// Gets the default value for an attribute on a specific element.
///
/// Returns the element-specific default if defined, otherwise checks
/// the attribute group defaults.
String? getElementAttrDefault(String elementName, String attrName) {
  final config = elems[elementName];
  if (config == null) return null;

  // Check element-specific defaults first
  if (config.defaults != null && config.defaults!.containsKey(attrName)) {
    return config.defaults![attrName];
  }

  // Check attribute group defaults
  for (final groupName in config.attrsGroups) {
    final groupDefaults = attrsGroupsDefaults[groupName];
    if (groupDefaults != null && groupDefaults.containsKey(attrName)) {
      return groupDefaults[attrName];
    }
  }

  return null;
}

/// Gets all allowed attributes for a specific element.
///
/// This includes attributes from attribute groups and element-specific attributes.
Set<String> getElementAllowedAttrs(String elementName) {
  final config = elems[elementName];
  if (config == null) return {};

  final attrs = <String>{};

  // Add element-specific attributes
  if (config.attrs != null) {
    attrs.addAll(config.attrs!);
  }

  // Add attributes from attribute groups
  for (final groupName in config.attrsGroups) {
    final group = attrsGroups[groupName];
    if (group != null) {
      attrs.addAll(group);
    }
  }

  return attrs;
}

/// Gets all allowed children for a specific element.
///
/// This includes elements from content groups and element-specific content.
Set<String> getElementAllowedChildren(String elementName) {
  final config = elems[elementName];
  if (config == null) return {};

  final children = <String>{};

  // Add element-specific content
  if (config.content != null) {
    children.addAll(config.content!);
  }

  // Add elements from content groups
  if (config.contentGroups != null) {
    for (final groupName in config.contentGroups!) {
      final group = elemsGroups[groupName];
      if (group != null) {
        children.addAll(group);
      }
    }
  }

  return children;
}

/// Gets all default values for a specific element.
///
/// This includes element-specific defaults and attribute group defaults.
Map<String, String> getElementDefaults(String elementName) {
  final config = elems[elementName];
  if (config == null) return {};

  final defaults = <String, String>{};

  // Add attribute group defaults
  for (final groupName in config.attrsGroups) {
    final groupDefaults = attrsGroupsDefaults[groupName];
    if (groupDefaults != null) {
      defaults.addAll(groupDefaults);
    }
  }

  // Add element-specific defaults (override group defaults)
  if (config.defaults != null) {
    defaults.addAll(config.defaults!);
  }

  return defaults;
}
