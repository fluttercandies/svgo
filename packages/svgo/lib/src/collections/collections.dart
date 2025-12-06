/// SVG element and attribute collections.
///
/// This file contains comprehensive definitions of SVG elements, attributes,
/// their relationships, and default values based on the SVG 1.1 and 2.0 specifications.
///
/// @see https://www.w3.org/TR/SVG11/intro.html#Definitions
library;

export 'elems.dart';

// =============================================================================
// Element Groups
// =============================================================================

/// Groups of SVG elements by category.
class ElemsGroups {
  const ElemsGroups._();

  /// Animation elements.
  static const animation = {
    'animate',
    'animateColor',
    'animateMotion',
    'animateTransform',
    'set',
  };

  /// Descriptive elements.
  static const descriptive = {'desc', 'metadata', 'title'};

  /// Shape elements.
  static const shape = {
    'circle',
    'ellipse',
    'line',
    'path',
    'polygon',
    'polyline',
    'rect',
  };

  /// Structural elements.
  static const structural = {'defs', 'g', 'svg', 'symbol', 'use'};

  /// Paint server elements.
  static const paintServer = {
    'hatch',
    'linearGradient',
    'meshGradient',
    'pattern',
    'radialGradient',
    'solidColor',
  };

  /// Non-rendering elements.
  static const nonRendering = {
    'clipPath',
    'filter',
    'linearGradient',
    'marker',
    'mask',
    'pattern',
    'radialGradient',
    'solidColor',
    'symbol',
  };

  /// Container elements.
  static const container = {
    'a',
    'defs',
    'foreignObject',
    'g',
    'marker',
    'mask',
    'missing-glyph',
    'pattern',
    'svg',
    'switch',
    'symbol',
  };

  /// Text content elements.
  static const textContent = {
    'a',
    'altGlyph',
    'altGlyphDef',
    'altGlyphItem',
    'glyph',
    'glyphRef',
    'text',
    'textPath',
    'tref',
    'tspan',
  };

  /// Text content child elements.
  static const textContentChild = {'altGlyph', 'textPath', 'tref', 'tspan'};

  /// Light source elements.
  static const lightSource = {
    'feDiffuseLighting',
    'feDistantLight',
    'fePointLight',
    'feSpecularLighting',
    'feSpotLight',
  };

  /// Filter primitive elements.
  static const filterPrimitive = {
    'feBlend',
    'feColorMatrix',
    'feComponentTransfer',
    'feComposite',
    'feConvolveMatrix',
    'feDiffuseLighting',
    'feDisplacementMap',
    'feDropShadow',
    'feFlood',
    'feFuncA',
    'feFuncB',
    'feFuncG',
    'feFuncR',
    'feGaussianBlur',
    'feImage',
    'feMerge',
    'feMergeNode',
    'feMorphology',
    'feOffset',
    'feSpecularLighting',
    'feTile',
    'feTurbulence',
  };
}

/// Elements where whitespace is significant.
///
/// @see https://developer.mozilla.org/en-US/docs/Web/HTML/Element/pre
const textElems = {
  ...ElemsGroups.textContent,
  'pre',
  'title',
};

/// Elements that can have path data.
const pathElems = {'glyph', 'missing-glyph', 'path'};

// =============================================================================
// Attribute Groups
// =============================================================================

/// Groups of SVG attributes by category.
class AttrsGroups {
  const AttrsGroups._();

  /// Animation addition attributes.
  static const animationAddition = {'additive', 'accumulate'};

  /// Animation attribute target attributes.
  static const animationAttributeTarget = {'attributeType', 'attributeName'};

  /// Animation event attributes.
  static const animationEvent = {'onbegin', 'onend', 'onrepeat', 'onload'};

  /// Animation timing attributes.
  static const animationTiming = {
    'begin',
    'dur',
    'end',
    'fill',
    'max',
    'min',
    'repeatCount',
    'repeatDur',
    'restart',
  };

  /// Animation value attributes.
  static const animationValue = {
    'by',
    'calcMode',
    'from',
    'keySplines',
    'keyTimes',
    'to',
    'values',
  };

  /// Conditional processing attributes.
  static const conditionalProcessing = {
    'requiredExtensions',
    'requiredFeatures',
    'systemLanguage',
  };

  /// Core attributes.
  static const core = {'id', 'tabindex', 'xml:base', 'xml:lang', 'xml:space'};

  /// Graphical event attributes.
  static const graphicalEvent = {
    'onactivate',
    'onclick',
    'onfocusin',
    'onfocusout',
    'onload',
    'onmousedown',
    'onmousemove',
    'onmouseout',
    'onmouseover',
    'onmouseup',
  };

  /// Presentation attributes.
  static const presentation = {
    'alignment-baseline',
    'baseline-shift',
    'clip-path',
    'clip-rule',
    'clip',
    'color-interpolation-filters',
    'color-interpolation',
    'color-profile',
    'color-rendering',
    'color',
    'cursor',
    'direction',
    'display',
    'dominant-baseline',
    'enable-background',
    'fill-opacity',
    'fill-rule',
    'fill',
    'filter',
    'flood-color',
    'flood-opacity',
    'font-family',
    'font-size-adjust',
    'font-size',
    'font-stretch',
    'font-style',
    'font-variant',
    'font-weight',
    'glyph-orientation-horizontal',
    'glyph-orientation-vertical',
    'image-rendering',
    'letter-spacing',
    'lighting-color',
    'marker-end',
    'marker-mid',
    'marker-start',
    'mask',
    'opacity',
    'overflow',
    'paint-order',
    'pointer-events',
    'shape-rendering',
    'stop-color',
    'stop-opacity',
    'stroke-dasharray',
    'stroke-dashoffset',
    'stroke-linecap',
    'stroke-linejoin',
    'stroke-miterlimit',
    'stroke-opacity',
    'stroke-width',
    'stroke',
    'text-anchor',
    'text-decoration',
    'text-overflow',
    'text-rendering',
    'transform-origin',
    'transform',
    'unicode-bidi',
    'vector-effect',
    'visibility',
    'word-spacing',
    'writing-mode',
  };

  /// XLink attributes.
  static const xlink = {
    'xlink:actuate',
    'xlink:arcrole',
    'xlink:href',
    'xlink:role',
    'xlink:show',
    'xlink:title',
    'xlink:type',
  };

  /// Document event attributes.
  static const documentEvent = {
    'onabort',
    'onerror',
    'onresize',
    'onscroll',
    'onunload',
    'onzoom',
  };

  /// Document element event attributes.
  static const documentElementEvent = {'oncopy', 'oncut', 'onpaste'};

  /// Global event attributes.
  static const globalEvent = {
    'oncancel',
    'oncanplay',
    'oncanplaythrough',
    'onchange',
    'onclick',
    'onclose',
    'oncuechange',
    'ondblclick',
    'ondrag',
    'ondragend',
    'ondragenter',
    'ondragleave',
    'ondragover',
    'ondragstart',
    'ondrop',
    'ondurationchange',
    'onemptied',
    'onended',
    'onerror',
    'onfocus',
    'oninput',
    'oninvalid',
    'onkeydown',
    'onkeypress',
    'onkeyup',
    'onload',
    'onloadeddata',
    'onloadedmetadata',
    'onloadstart',
    'onmousedown',
    'onmouseenter',
    'onmouseleave',
    'onmousemove',
    'onmouseout',
    'onmouseover',
    'onmouseup',
    'onmousewheel',
    'onpause',
    'onplay',
    'onplaying',
    'onprogress',
    'onratechange',
    'onreset',
    'onresize',
    'onscroll',
    'onseeked',
    'onseeking',
    'onselect',
    'onshow',
    'onstalled',
    'onsubmit',
    'onsuspend',
    'ontimeupdate',
    'ontoggle',
    'onvolumechange',
    'onwaiting',
  };

  /// Filter primitive attributes.
  static const filterPrimitive = {'x', 'y', 'width', 'height', 'result'};

  /// Transfer function attributes.
  static const transferFunction = {
    'amplitude',
    'exponent',
    'intercept',
    'offset',
    'slope',
    'tableValues',
    'type',
  };
}

// =============================================================================
// Attribute Group Defaults
// =============================================================================

/// Default values for attribute groups.
const attrsGroupsDefaults = {
  'core': {'xml:space': 'default'},
  'presentation': {
    'clip': 'auto',
    'clip-path': 'none',
    'clip-rule': 'nonzero',
    'mask': 'none',
    'opacity': '1',
    'stop-color': '#000',
    'stop-opacity': '1',
    'fill-opacity': '1',
    'fill-rule': 'nonzero',
    'fill': '#000',
    'stroke': 'none',
    'stroke-width': '1',
    'stroke-linecap': 'butt',
    'stroke-linejoin': 'miter',
    'stroke-miterlimit': '4',
    'stroke-dasharray': 'none',
    'stroke-dashoffset': '0',
    'stroke-opacity': '1',
    'paint-order': 'normal',
    'vector-effect': 'none',
    'display': 'inline',
    'visibility': 'visible',
    'marker-start': 'none',
    'marker-mid': 'none',
    'marker-end': 'none',
    'color-interpolation': 'sRGB',
    'color-interpolation-filters': 'linearRGB',
    'color-rendering': 'auto',
    'shape-rendering': 'auto',
    'text-rendering': 'auto',
    'image-rendering': 'auto',
    'font-style': 'normal',
    'font-variant': 'normal',
    'font-weight': 'normal',
    'font-stretch': 'normal',
    'font-size': 'medium',
    'font-size-adjust': 'none',
    'kerning': 'auto',
    'letter-spacing': 'normal',
    'word-spacing': 'normal',
    'text-decoration': 'none',
    'text-anchor': 'start',
    'text-overflow': 'clip',
    'writing-mode': 'lr-tb',
    'glyph-orientation-vertical': 'auto',
    'glyph-orientation-horizontal': '0deg',
    'direction': 'ltr',
    'unicode-bidi': 'normal',
    'dominant-baseline': 'auto',
    'alignment-baseline': 'baseline',
    'baseline-shift': 'baseline',
  },
  'transferFunction': {
    'slope': '1',
    'intercept': '0',
    'amplitude': '1',
    'exponent': '1',
    'offset': '0',
  },
};

// =============================================================================
// Deprecated Attribute Groups
// =============================================================================

/// Deprecated attributes organized by attribute group.
///
/// Contains 'safe' and 'unsafe' sub-maps:
/// - 'safe': Can be safely removed
/// - 'unsafe': Should only be removed with explicit user consent
const attrsGroupsDeprecated = <String, Map<String, Set<String>>>{
  'animationAttributeTarget': {
    'unsafe': {'attributeType'},
  },
  'conditionalProcessing': {
    'unsafe': {'requiredFeatures'},
  },
  'core': {
    'unsafe': {'xml:base', 'xml:lang', 'xml:space'},
  },
  'presentation': {
    'unsafe': {
      'clip',
      'color-profile',
      'enable-background',
      'glyph-orientation-horizontal',
      'glyph-orientation-vertical',
      'kerning',
    },
  },
};

// =============================================================================
// Editor Namespaces
// =============================================================================

/// Namespaces used by various SVG editors.
///
/// @see https://wiki.inkscape.org/wiki/index.php/Inkscape-specific_XML_attributes
const editorNamespaces = {
  'http://creativecommons.org/ns#',
  'http://inkscape.sourceforge.net/DTD/sodipodi-0.dtd',
  'http://krita.org/namespaces/svg/krita',
  'http://ns.adobe.com/AdobeIllustrator/10.0/',
  'http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/',
  'http://ns.adobe.com/Extensibility/1.0/',
  'http://ns.adobe.com/Flows/1.0/',
  'http://ns.adobe.com/GenericCustomNamespace/1.0/',
  'http://ns.adobe.com/Graphs/1.0/',
  'http://ns.adobe.com/ImageReplacement/1.0/',
  'http://ns.adobe.com/SaveForWeb/1.0/',
  'http://ns.adobe.com/Variables/1.0/',
  'http://ns.adobe.com/XPath/1.0/',
  'http://purl.org/dc/elements/1.1/',
  'http://schemas.microsoft.com/visio/2003/SVGExtensions/',
  'http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd',
  'http://taptrix.com/vectorillustrator/svg_extensions',
  'http://www.bohemiancoding.com/sketch/ns',
  'http://www.figma.com/figma/ns',
  'http://www.inkscape.org/namespaces/inkscape',
  'http://www.serif.com/',
  'http://www.vector.evaxdesign.sk',
  'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
  'https://boxy-svg.com',
};

// =============================================================================
// Reference Properties
// =============================================================================

/// Properties that can contain URL references.
///
/// @see https://www.w3.org/TR/SVG11/linking.html#processingIRI
const referencesProps = {
  'clip-path',
  'color-profile',
  'fill',
  'filter',
  'marker-end',
  'marker-mid',
  'marker-start',
  'mask',
  'stroke',
  'style',
};

// =============================================================================
// Inheritable Attributes
// =============================================================================

/// Attributes that are inherited from parent elements.
///
/// @see https://www.w3.org/TR/SVG11/propidx.html
const inheritableAttrs = {
  'clip-rule',
  'color-interpolation-filters',
  'color-interpolation',
  'color-profile',
  'color-rendering',
  'color',
  'cursor',
  'direction',
  'dominant-baseline',
  'fill-opacity',
  'fill-rule',
  'fill',
  'font-family',
  'font-size-adjust',
  'font-size',
  'font-stretch',
  'font-style',
  'font-variant',
  'font-weight',
  'font',
  'glyph-orientation-horizontal',
  'glyph-orientation-vertical',
  'image-rendering',
  'letter-spacing',
  'marker-end',
  'marker-mid',
  'marker-start',
  'marker',
  'paint-order',
  'pointer-events',
  'shape-rendering',
  'stroke-dasharray',
  'stroke-dashoffset',
  'stroke-linecap',
  'stroke-linejoin',
  'stroke-miterlimit',
  'stroke-opacity',
  'stroke-width',
  'stroke',
  'text-anchor',
  'text-rendering',
  'transform',
  'visibility',
  'word-spacing',
  'writing-mode',
};

/// Presentation attributes that are not inherited on groups.
const presentationNonInheritableGroupAttrs = {
  'clip-path',
  'display',
  'filter',
  'mask',
  'opacity',
  'text-decoration',
  'transform',
  'unicode-bidi',
};

// =============================================================================
// Color Names
// =============================================================================

/// SVG color name keywords mapped to hex values.
///
/// @see https://www.w3.org/TR/SVG11/single-page.html#types-ColorKeywords
const colorsNames = {
  'aliceblue': '#f0f8ff',
  'antiquewhite': '#faebd7',
  'aqua': '#0ff',
  'aquamarine': '#7fffd4',
  'azure': '#f0ffff',
  'beige': '#f5f5dc',
  'bisque': '#ffe4c4',
  'black': '#000',
  'blanchedalmond': '#ffebcd',
  'blue': '#00f',
  'blueviolet': '#8a2be2',
  'brown': '#a52a2a',
  'burlywood': '#deb887',
  'cadetblue': '#5f9ea0',
  'chartreuse': '#7fff00',
  'chocolate': '#d2691e',
  'coral': '#ff7f50',
  'cornflowerblue': '#6495ed',
  'cornsilk': '#fff8dc',
  'crimson': '#dc143c',
  'cyan': '#0ff',
  'darkblue': '#00008b',
  'darkcyan': '#008b8b',
  'darkgoldenrod': '#b8860b',
  'darkgray': '#a9a9a9',
  'darkgreen': '#006400',
  'darkgrey': '#a9a9a9',
  'darkkhaki': '#bdb76b',
  'darkmagenta': '#8b008b',
  'darkolivegreen': '#556b2f',
  'darkorange': '#ff8c00',
  'darkorchid': '#9932cc',
  'darkred': '#8b0000',
  'darksalmon': '#e9967a',
  'darkseagreen': '#8fbc8f',
  'darkslateblue': '#483d8b',
  'darkslategray': '#2f4f4f',
  'darkslategrey': '#2f4f4f',
  'darkturquoise': '#00ced1',
  'darkviolet': '#9400d3',
  'deeppink': '#ff1493',
  'deepskyblue': '#00bfff',
  'dimgray': '#696969',
  'dimgrey': '#696969',
  'dodgerblue': '#1e90ff',
  'firebrick': '#b22222',
  'floralwhite': '#fffaf0',
  'forestgreen': '#228b22',
  'fuchsia': '#f0f',
  'gainsboro': '#dcdcdc',
  'ghostwhite': '#f8f8ff',
  'gold': '#ffd700',
  'goldenrod': '#daa520',
  'gray': '#808080',
  'green': '#008000',
  'greenyellow': '#adff2f',
  'grey': '#808080',
  'honeydew': '#f0fff0',
  'hotpink': '#ff69b4',
  'indianred': '#cd5c5c',
  'indigo': '#4b0082',
  'ivory': '#fffff0',
  'khaki': '#f0e68c',
  'lavender': '#e6e6fa',
  'lavenderblush': '#fff0f5',
  'lawngreen': '#7cfc00',
  'lemonchiffon': '#fffacd',
  'lightblue': '#add8e6',
  'lightcoral': '#f08080',
  'lightcyan': '#e0ffff',
  'lightgoldenrodyellow': '#fafad2',
  'lightgray': '#d3d3d3',
  'lightgreen': '#90ee90',
  'lightgrey': '#d3d3d3',
  'lightpink': '#ffb6c1',
  'lightsalmon': '#ffa07a',
  'lightseagreen': '#20b2aa',
  'lightskyblue': '#87cefa',
  'lightslategray': '#789',
  'lightslategrey': '#789',
  'lightsteelblue': '#b0c4de',
  'lightyellow': '#ffffe0',
  'lime': '#0f0',
  'limegreen': '#32cd32',
  'linen': '#faf0e6',
  'magenta': '#f0f',
  'maroon': '#800000',
  'mediumaquamarine': '#66cdaa',
  'mediumblue': '#0000cd',
  'mediumorchid': '#ba55d3',
  'mediumpurple': '#9370db',
  'mediumseagreen': '#3cb371',
  'mediumslateblue': '#7b68ee',
  'mediumspringgreen': '#00fa9a',
  'mediumturquoise': '#48d1cc',
  'mediumvioletred': '#c71585',
  'midnightblue': '#191970',
  'mintcream': '#f5fffa',
  'mistyrose': '#ffe4e1',
  'moccasin': '#ffe4b5',
  'navajowhite': '#ffdead',
  'navy': '#000080',
  'oldlace': '#fdf5e6',
  'olive': '#808000',
  'olivedrab': '#6b8e23',
  'orange': '#ffa500',
  'orangered': '#ff4500',
  'orchid': '#da70d6',
  'palegoldenrod': '#eee8aa',
  'palegreen': '#98fb98',
  'paleturquoise': '#afeeee',
  'palevioletred': '#db7093',
  'papayawhip': '#ffefd5',
  'peachpuff': '#ffdab9',
  'peru': '#cd853f',
  'pink': '#ffc0cb',
  'plum': '#dda0dd',
  'powderblue': '#b0e0e6',
  'purple': '#800080',
  'rebeccapurple': '#639',
  'red': '#f00',
  'rosybrown': '#bc8f8f',
  'royalblue': '#4169e1',
  'saddlebrown': '#8b4513',
  'salmon': '#fa8072',
  'sandybrown': '#f4a460',
  'seagreen': '#2e8b57',
  'seashell': '#fff5ee',
  'sienna': '#a0522d',
  'silver': '#c0c0c0',
  'skyblue': '#87ceeb',
  'slateblue': '#6a5acd',
  'slategray': '#708090',
  'slategrey': '#708090',
  'snow': '#fffafa',
  'springgreen': '#00ff7f',
  'steelblue': '#4682b4',
  'tan': '#d2b48c',
  'teal': '#008080',
  'thistle': '#d8bfd8',
  'tomato': '#ff6347',
  'turquoise': '#40e0d0',
  'violet': '#ee82ee',
  'wheat': '#f5deb3',
  'white': '#fff',
  'whitesmoke': '#f5f5f5',
  'yellow': '#ff0',
  'yellowgreen': '#9acd32',
};

/// Hex colors that have shorter named equivalents.
const colorsShortNames = {
  '#f0ffff': 'azure',
  '#f5f5dc': 'beige',
  '#ffe4c4': 'bisque',
  '#a52a2a': 'brown',
  '#ff7f50': 'coral',
  '#ffd700': 'gold',
  '#808080': 'gray',
  '#008000': 'green',
  '#4b0082': 'indigo',
  '#fffff0': 'ivory',
  '#f0e68c': 'khaki',
  '#faf0e6': 'linen',
  '#800000': 'maroon',
  '#000080': 'navy',
  '#808000': 'olive',
  '#ffa500': 'orange',
  '#da70d6': 'orchid',
  '#cd853f': 'peru',
  '#ffc0cb': 'pink',
  '#dda0dd': 'plum',
  '#800080': 'purple',
  '#f00': 'red',
  '#ff0000': 'red',
  '#fa8072': 'salmon',
  '#a0522d': 'sienna',
  '#c0c0c0': 'silver',
  '#fffafa': 'snow',
  '#d2b48c': 'tan',
  '#008080': 'teal',
  '#ff6347': 'tomato',
  '#ee82ee': 'violet',
  '#f5deb3': 'wheat',
};

/// Properties that can contain color values.
///
/// @see https://www.w3.org/TR/SVG11/single-page.html#types-DataTypeColor
const colorsProps = {
  'color',
  'fill',
  'flood-color',
  'lighting-color',
  'stop-color',
  'stroke',
};

// =============================================================================
// Convenience Maps for Dynamic Access
// =============================================================================

/// Element groups as a Map for dynamic access.
///
/// Example:
/// ```dart
/// if (elemsGroups['nonRendering']!.contains(element.name)) {
///   // ...
/// }
/// ```
const elemsGroups = <String, Set<String>>{
  'animation': ElemsGroups.animation,
  'descriptive': ElemsGroups.descriptive,
  'shape': ElemsGroups.shape,
  'structural': ElemsGroups.structural,
  'paintServer': ElemsGroups.paintServer,
  'nonRendering': ElemsGroups.nonRendering,
  'container': ElemsGroups.container,
  'textContent': ElemsGroups.textContent,
  'textContentChild': ElemsGroups.textContentChild,
  'lightSource': ElemsGroups.lightSource,
  'filterPrimitive': ElemsGroups.filterPrimitive,
};

/// Attribute groups as a Map for dynamic access.
///
/// Example:
/// ```dart
/// if (attrsGroups['presentation']!.contains(attrName)) {
///   // ...
/// }
/// ```
const attrsGroups = <String, Set<String>>{
  'animationAddition': AttrsGroups.animationAddition,
  'animationAttributeTarget': AttrsGroups.animationAttributeTarget,
  'animationEvent': AttrsGroups.animationEvent,
  'animationTiming': AttrsGroups.animationTiming,
  'animationValue': AttrsGroups.animationValue,
  'conditionalProcessing': AttrsGroups.conditionalProcessing,
  'core': AttrsGroups.core,
  'graphicalEvent': AttrsGroups.graphicalEvent,
  'presentation': AttrsGroups.presentation,
  'xlink': AttrsGroups.xlink,
  'documentEvent': AttrsGroups.documentEvent,
  'documentElementEvent': AttrsGroups.documentElementEvent,
  'globalEvent': AttrsGroups.globalEvent,
  'filterPrimitive': AttrsGroups.filterPrimitive,
  'transferFunction': AttrsGroups.transferFunction,
};

// =============================================================================
// Pseudo-classes collections
// =============================================================================

/// Pseudo-classes categorized by type.
///
/// These are used by inlineStyles and other plugins to handle CSS pseudo-classes.
class PseudoClasses {
  const PseudoClasses._();

  /// Display state pseudo-classes
  static const displayState = {'fullscreen', 'modal', 'picture-in-picture'};

  /// Input pseudo-classes
  static const input = {
    'autofill',
    'blank',
    'checked',
    'default',
    'disabled',
    'enabled',
    'in-range',
    'indeterminate',
    'invalid',
    'optional',
    'out-of-range',
    'placeholder-shown',
    'read-only',
    'read-write',
    'required',
    'user-invalid',
    'valid',
  };

  /// Linguistic pseudo-classes
  static const linguistic = {'dir', 'lang'};

  /// Location pseudo-classes
  static const location = {
    'any-link',
    'link',
    'local-link',
    'scope',
    'target-within',
    'target',
    'visited',
  };

  /// Resource state pseudo-classes
  static const resourceState = {'playing', 'paused'};

  /// Time-dimensional pseudo-classes
  static const timeDimensional = {'current', 'past', 'future'};

  /// Tree-structural pseudo-classes
  static const treeStructural = {
    'empty',
    'first-child',
    'first-of-type',
    'last-child',
    'last-of-type',
    'nth-child',
    'nth-last-child',
    'nth-last-of-type',
    'nth-of-type',
    'only-child',
    'only-of-type',
    'root',
  };

  /// User action pseudo-classes
  static const userAction = {
    'active',
    'focus-visible',
    'focus-within',
    'focus',
    'hover',
  };

  /// Functional pseudo-classes
  static const functional = {'is', 'not', 'where', 'has'};
}

/// Pseudo-classes as a Map for dynamic access.
const pseudoClasses = <String, Set<String>>{
  'displayState': PseudoClasses.displayState,
  'input': PseudoClasses.input,
  'linguistic': PseudoClasses.linguistic,
  'location': PseudoClasses.location,
  'resourceState': PseudoClasses.resourceState,
  'timeDimensional': PseudoClasses.timeDimensional,
  'treeStructural': PseudoClasses.treeStructural,
  'userAction': PseudoClasses.userAction,
  'functional': PseudoClasses.functional,
};
