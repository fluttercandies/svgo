/// Collapses multiple transformations and optimizes them.
///
/// This plugin converts matrices to the short aliases, converts long
/// translate, scale or rotate transform notations to the short ones,
/// converts transforms to the matrices and multiplies them all into one,
/// and removes useless transforms.
///
/// Based on node-svgo's convertTransform plugin with full QR decomposition.
/// @see https://www.w3.org/TR/SVG11/coords.html#TransformMatrixDefined
/// @see https://frederic-wang.fr/2013/12/01/decomposition-of-2d-transform-matrices/
library;

import 'dart:math' as math;

import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const convertTransform = Plugin(
  name: 'convertTransform',
  description: 'collapses multiple transformations and optimizes it',
  params: {
    'convertToShorts': true,
    'degPrecision': null,
    'floatPrecision': 3,
    'transformPrecision': 5,
    'matrixToTransform': true,
    'shortTranslate': true,
    'shortScale': true,
    'shortRotate': true,
    'removeUseless': true,
    'collapseIntoOne': true,
    'leadingZero': true,
    'negativeExtraSpace': false,
  },
  fn: _convertTransformFn,
);

/// Transform parameters for processing.
class _TransformParams {
  _TransformParams({
    required this.convertToShorts,
    required this.degPrecision,
    required this.floatPrecision,
    required this.transformPrecision,
    required this.matrixToTransform,
    required this.shortTranslate,
    required this.shortScale,
    required this.shortRotate,
    required this.removeUseless,
    required this.collapseIntoOne,
    required this.leadingZero,
    required this.negativeExtraSpace,
  });

  final bool convertToShorts;
  int? degPrecision;
  final int floatPrecision;
  int transformPrecision;
  final bool matrixToTransform;
  final bool shortTranslate;
  final bool shortScale;
  final bool shortRotate;
  final bool removeUseless;
  final bool collapseIntoOne;
  final bool leadingZero;
  final bool negativeExtraSpace;

  _TransformParams copy() => _TransformParams(
        convertToShorts: convertToShorts,
        degPrecision: degPrecision,
        floatPrecision: floatPrecision,
        transformPrecision: transformPrecision,
        matrixToTransform: matrixToTransform,
        shortTranslate: shortTranslate,
        shortScale: shortScale,
        shortRotate: shortRotate,
        removeUseless: removeUseless,
        collapseIntoOne: collapseIntoOne,
        leadingZero: leadingZero,
        negativeExtraSpace: negativeExtraSpace,
      );
}

Visitor? _convertTransformFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final baseParams = _TransformParams(
    convertToShorts: params['convertToShorts'] != false,
    degPrecision: params['degPrecision'] as int?,
    floatPrecision: params['floatPrecision'] as int? ?? 3,
    transformPrecision: params['transformPrecision'] as int? ?? 5,
    matrixToTransform: params['matrixToTransform'] != false,
    shortTranslate: params['shortTranslate'] != false,
    shortScale: params['shortScale'] != false,
    shortRotate: params['shortRotate'] != false,
    removeUseless: params['removeUseless'] != false,
    collapseIntoOne: params['collapseIntoOne'] != false,
    leadingZero: params['leadingZero'] != false,
    negativeExtraSpace: params['negativeExtraSpace'] == true,
  );

  void processTransform(XastElement node, String attrName) {
    final value = node.attributes[attrName];
    if (value == null || value.isEmpty) return;

    var transforms = _transform2js(value);
    if (transforms.isEmpty) return;

    // Clone and adjust params for this specific transform
    final transformParams = _definePrecision(transforms, baseParams);

    // Collapse all transforms into one matrix
    if (transformParams.collapseIntoOne && transforms.length > 1) {
      transforms = [_transformsMultiply(transforms)];
    }

    // Convert to shorts
    if (transformParams.convertToShorts) {
      transforms = _convertToShorts(transforms, transformParams);
    } else {
      for (final t in transforms) {
        _roundTransform(t, transformParams);
      }
    }

    // Remove useless transforms
    if (transformParams.removeUseless) {
      transforms = _removeUseless(transforms);
    }

    // Stringify
    if (transforms.isEmpty) {
      node.attributes.remove(attrName);
    } else {
      node.attributes[attrName] = _js2transform(transforms, transformParams);
    }
  }

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.attributes.containsKey('transform')) {
          processTransform(node, 'transform');
        }
        if (node.attributes.containsKey('gradientTransform')) {
          processTransform(node, 'gradientTransform');
        }
        if (node.attributes.containsKey('patternTransform')) {
          processTransform(node, 'patternTransform');
        }
        return null;
      },
    ),
  );
}

/// Transform item with name and data.
class _TransformItem {
  _TransformItem(this.name, this.data);
  final String name;
  List<double> data;
}

/// Math utilities for angle conversions.
double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;
double _cosD(double deg) => math.cos(_rad(deg));
double _sinD(double deg) => math.sin(_rad(deg));
double _tanD(double deg) => math.tan(_rad(deg));

/// Parse transform string to JS representation.
List<_TransformItem> _transform2js(String transformString) {
  final transforms = <_TransformItem>[];
  final regNumericValues = RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');

  _TransformItem? currentTransform;

  // Split by transform functions
  final regTransformSplit = RegExp(
    r'(matrix|translate|scale|rotate|skewX|skewY)',
    caseSensitive: false,
  );

  var lastEnd = 0;
  for (final match in regTransformSplit.allMatches(transformString)) {
    // Process previous transform's arguments
    if (currentTransform != null) {
      final argsStr = transformString.substring(lastEnd, match.start);
      _parseArgs(argsStr, currentTransform, regNumericValues);
    }

    currentTransform = _TransformItem(match.group(0)!.toLowerCase(), []);
    transforms.add(currentTransform);
    lastEnd = match.end;
  }

  // Process last transform's arguments
  if (currentTransform != null) {
    final argsStr = transformString.substring(lastEnd);
    _parseArgs(argsStr, currentTransform, regNumericValues);
  }

  if (currentTransform == null || currentTransform.data.isEmpty) {
    return [];
  }

  return transforms;
}

void _parseArgs(
    String argsStr, _TransformItem transform, RegExp regNumericValues) {
  for (final match in regNumericValues.allMatches(argsStr)) {
    final num = double.tryParse(match.group(0)!);
    if (num != null) {
      transform.data.add(num);
    }
  }
}

/// Multiply transforms into one matrix.
_TransformItem _transformsMultiply(List<_TransformItem> transforms) {
  final matrixData = transforms.map((transform) {
    if (transform.name == 'matrix') {
      return transform.data;
    }
    return _transformToMatrix(transform);
  }).toList();

  final result = matrixData.isNotEmpty
      ? matrixData.reduce(_multiplyTransformMatrices)
      : <double>[];

  return _TransformItem('matrix', result);
}

/// Multiply two transformation matrices.
List<double> _multiplyTransformMatrices(List<double> a, List<double> b) {
  return [
    a[0] * b[0] + a[2] * b[1],
    a[1] * b[0] + a[3] * b[1],
    a[0] * b[2] + a[2] * b[3],
    a[1] * b[2] + a[3] * b[3],
    a[0] * b[4] + a[2] * b[5] + a[4],
    a[1] * b[4] + a[3] * b[5] + a[5],
  ];
}

/// Convert transform to matrix data.
List<double> _transformToMatrix(_TransformItem transform) {
  final data = transform.data;

  switch (transform.name) {
    case 'matrix':
      return data.length >= 6
          ? data.sublist(0, 6)
          : [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

    case 'translate':
      final tx = data.isNotEmpty ? data[0] : 0.0;
      final ty = data.length > 1 ? data[1] : 0.0;
      return [1.0, 0.0, 0.0, 1.0, tx, ty];

    case 'scale':
      final sx = data.isNotEmpty ? data[0] : 1.0;
      final sy = data.length > 1 ? data[1] : sx;
      return [sx, 0.0, 0.0, sy, 0.0, 0.0];

    case 'rotate':
      final angle = data.isNotEmpty ? data[0] : 0.0;
      final cos = _cosD(angle);
      final sin = _sinD(angle);
      final cx = data.length > 1 ? data[1] : 0.0;
      final cy = data.length > 2 ? data[2] : 0.0;
      return [
        cos,
        sin,
        -sin,
        cos,
        (1 - cos) * cx + sin * cy,
        (1 - cos) * cy - sin * cx,
      ];

    case 'skewx':
      final tan = _tanD(data.isNotEmpty ? data[0] : 0.0);
      return [1.0, 0.0, tan, 1.0, 0.0, 0.0];

    case 'skewy':
      final tan = _tanD(data.isNotEmpty ? data[0] : 0.0);
      return [1.0, tan, 0.0, 1.0, 0.0, 0.0];

    default:
      throw ArgumentError('Unknown transform: ${transform.name}');
  }
}

/// Defines precision to work with certain parts.
_TransformParams _definePrecision(
  List<_TransformItem> data,
  _TransformParams params,
) {
  final newParams = params.copy();
  final matrixData = <double>[];

  for (final item in data) {
    if (item.name == 'matrix') {
      matrixData.addAll(item.data.take(4));
    }
  }

  int numberOfDigits = newParams.transformPrecision;

  // Limit transform precision with matrix one
  if (matrixData.isNotEmpty) {
    newParams.transformPrecision = math.min(
      newParams.transformPrecision,
      matrixData.map(_floatDigits).reduce(math.max),
    );

    numberOfDigits = matrixData
        .map((n) => n.toString().replaceAll(RegExp(r'\D+'), '').length)
        .reduce(math.max);
  }

  // No sense in angle precision more than number of significant digits in matrix
  newParams.degPrecision ??= math.max(
    0,
    math.min(newParams.floatPrecision, numberOfDigits - 2),
  );

  return newParams;
}

/// Returns number of digits after the point.
int _floatDigits(double n) {
  final str = n.toString();
  final dotIndex = str.indexOf('.');
  if (dotIndex == -1) return 0;
  return str.length - dotIndex - 1;
}

/// Convert transforms to the shorthand alternatives.
List<_TransformItem> _convertToShorts(
  List<_TransformItem> transforms,
  _TransformParams params,
) {
  for (var i = 0; i < transforms.length; i++) {
    var transform = transforms[i];

    // Convert matrix to the short aliases
    if (params.matrixToTransform && transform.name == 'matrix') {
      final decomposed = _matrixToTransform(transform, params);
      final decomposedStr = _js2transform(decomposed, params);
      final originalStr = _js2transform([transform], params);

      if (decomposedStr.length <= originalStr.length) {
        transforms.replaceRange(i, i + 1, decomposed);
      }
      transform = transforms[i];
    }

    // Round transform
    _roundTransform(transform, params);

    // convert long translate transform notation to the short one
    if (params.shortTranslate &&
        transform.name == 'translate' &&
        transform.data.length == 2 &&
        transform.data[1] == 0) {
      transform.data.removeLast();
    }

    // convert long scale transform notation to the short one
    if (params.shortScale &&
        transform.name == 'scale' &&
        transform.data.length == 2 &&
        transform.data[0] == transform.data[1]) {
      transform.data.removeLast();
    }

    // convert long rotate transform notation to the short one
    if (params.shortRotate &&
        i >= 2 &&
        transforms[i - 2].name == 'translate' &&
        transforms[i - 1].name == 'rotate' &&
        transforms[i].name == 'translate' &&
        transforms[i - 2].data.length >= 2 &&
        transforms[i].data.length >= 2 &&
        transforms[i - 2].data[0] == -transforms[i].data[0] &&
        transforms[i - 2].data[1] == -transforms[i].data[1]) {
      final rotateData = [
        transforms[i - 1].data[0],
        transforms[i - 2].data[0],
        transforms[i - 2].data[1],
      ];
      transforms
          .replaceRange(i - 2, i + 1, [_TransformItem('rotate', rotateData)]);
      i -= 2;
    }
  }

  return transforms;
}

/// Get all possible decompositions of a matrix.
List<List<_TransformItem>> _getDecompositions(_TransformItem matrix) {
  final decompositions = <List<_TransformItem>>[];
  final qrab = _decomposeQRAB(matrix);
  final qrcd = _decomposeQRCD(matrix);

  if (qrab != null) decompositions.add(qrab);
  if (qrcd != null) decompositions.add(qrcd);

  return decompositions;
}

/// Decompose matrix using QRAB method.
List<_TransformItem>? _decomposeQRAB(_TransformItem matrix) {
  final data = matrix.data;
  if (data.length < 6) return null;

  final a = data[0];
  final b = data[1];
  final c = data[2];
  final d = data[3];
  final e = data[4];
  final f = data[5];

  final delta = a * d - b * c;
  if (delta == 0) return null;

  final r = math.sqrt(a * a + b * b);
  if (r == 0) return null;

  final decomposition = <_TransformItem>[];
  final cosOfRotationAngle = a / r;

  if (e != 0 || f != 0) {
    decomposition.add(_TransformItem('translate', [e, f]));
  }

  if (cosOfRotationAngle != 1) {
    final rotationAngleRads = math.acos(cosOfRotationAngle);
    decomposition.add(_TransformItem(
      'rotate',
      [_deg(b < 0 ? -rotationAngleRads : rotationAngleRads), 0.0, 0.0],
    ));
  }

  final sx = r;
  final sy = delta / sx;
  if (sx != 1 || sy != 1) {
    decomposition.add(_TransformItem('scale', [sx, sy]));
  }

  final acPlusBd = a * c + b * d;
  if (acPlusBd != 0) {
    decomposition.add(_TransformItem(
      'skewx',
      [_deg(math.atan(acPlusBd / (a * a + b * b)))],
    ));
  }

  return decomposition;
}

/// Decompose matrix using QRCD method.
List<_TransformItem>? _decomposeQRCD(_TransformItem matrix) {
  final data = matrix.data;
  if (data.length < 6) return null;

  final a = data[0];
  final b = data[1];
  final c = data[2];
  final d = data[3];
  final e = data[4];
  final f = data[5];

  final delta = a * d - b * c;
  if (delta == 0) return null;

  final s = math.sqrt(c * c + d * d);
  if (s == 0) return null;

  final decomposition = <_TransformItem>[];

  if (e != 0 || f != 0) {
    decomposition.add(_TransformItem('translate', [e, f]));
  }

  final rotationAngleRads = math.pi / 2 - (d < 0 ? -1 : 1) * math.acos(-c / s);
  decomposition.add(_TransformItem(
    'rotate',
    [_deg(rotationAngleRads), 0.0, 0.0],
  ));

  final sx = delta / s;
  final sy = s;
  if (sx != 1 || sy != 1) {
    decomposition.add(_TransformItem('scale', [sx, sy]));
  }

  final acPlusBd = a * c + b * d;
  if (acPlusBd != 0) {
    decomposition.add(_TransformItem(
      'skewy',
      [_deg(math.atan(acPlusBd / (c * c + d * d)))],
    ));
  }

  return decomposition;
}

/// Convert translate(tx,ty)rotate(a) to rotate(a,cx,cy).
_TransformItem _mergeTranslateAndRotate(double tx, double ty, double a) {
  final rotationAngleRads = _rad(a);
  final dd = 1 - math.cos(rotationAngleRads);
  final ee = math.sin(rotationAngleRads);
  final cy = (dd * ty + ee * tx) / (dd * dd + ee * ee);
  final cx = (tx - ee * cy) / dd;
  return _TransformItem('rotate', [a, cx, cy]);
}

/// Check if transform is identity.
bool _isIdentityTransform(_TransformItem t) {
  switch (t.name) {
    case 'rotate':
    case 'skewx':
    case 'skewy':
      return t.data.isNotEmpty && t.data[0] == 0;
    case 'scale':
      return t.data.length >= 2 && t.data[0] == 1 && t.data[1] == 1;
    case 'translate':
      return t.data.length >= 2 && t.data[0] == 0 && t.data[1] == 0;
    default:
      return false;
  }
}

/// Optimize list of transforms.
List<_TransformItem> _optimize(
  List<_TransformItem> roundedTransforms,
  List<_TransformItem> rawTransforms,
) {
  final optimizedTransforms = <_TransformItem>[];

  for (var index = 0; index < roundedTransforms.length; index++) {
    final roundedTransform = roundedTransforms[index];

    if (_isIdentityTransform(roundedTransform)) {
      continue;
    }

    final data = roundedTransform.data;

    switch (roundedTransform.name) {
      case 'rotate':
        if (data.isNotEmpty && (data[0] == 180 || data[0] == -180)) {
          if (index + 1 < roundedTransforms.length &&
              roundedTransforms[index + 1].name == 'scale') {
            final next = roundedTransforms[index + 1];
            optimizedTransforms.add(_createScaleTransform(
              next.data.map((v) => -v).toList(),
            ));
            index++;
          } else {
            optimizedTransforms.add(_TransformItem('scale', [-1.0]));
          }
          continue;
        }
        final hasCenter = data.length > 2 && (data[1] != 0 || data[2] != 0);
        optimizedTransforms.add(_TransformItem(
          'rotate',
          data.sublist(0, hasCenter ? 3 : 1),
        ));

      case 'scale':
        optimizedTransforms.add(_createScaleTransform(data));

      case 'skewx':
      case 'skewy':
        optimizedTransforms
            .add(_TransformItem(roundedTransform.name, [data[0]]));

      case 'translate':
        if (index + 1 < roundedTransforms.length &&
            roundedTransforms[index + 1].name == 'rotate') {
          final next = roundedTransforms[index + 1];
          if (next.data.isNotEmpty &&
              next.data[0] != 180 &&
              next.data[0] != -180 &&
              next.data[0] != 0 &&
              next.data.length >= 3 &&
              next.data[1] == 0 &&
              next.data[2] == 0) {
            final rawData = rawTransforms[index].data;
            optimizedTransforms.add(_mergeTranslateAndRotate(
              rawData[0],
              rawData.length > 1 ? rawData[1] : 0,
              rawTransforms[index + 1].data[0],
            ));
            index++;
            continue;
          }
        }
        final hasY = data.length > 1 && data[1] != 0;
        optimizedTransforms.add(_TransformItem(
          'translate',
          data.sublist(0, hasY ? 2 : 1),
        ));
    }
  }

  return optimizedTransforms.isNotEmpty
      ? optimizedTransforms
      : [
          _TransformItem('scale', [1.0])
        ];
}

/// Create scale transform with proper data length.
_TransformItem _createScaleTransform(List<double> data) {
  final scaleData = data.length >= 2 && data[0] == data[1]
      ? data.sublist(0, 1)
      : data.sublist(0, math.min(2, data.length));
  return _TransformItem('scale', scaleData);
}

/// Decompose matrix into simple transforms and optimize.
List<_TransformItem> _matrixToTransform(
  _TransformItem origMatrix,
  _TransformParams params,
) {
  final decomposed = _getDecompositions(origMatrix);

  List<_TransformItem>? shortest;
  int shortestLen = 0x7FFFFFFF;

  for (final decomposition in decomposed) {
    final roundedTransforms = decomposition.map((transformItem) {
      final transformCopy = _TransformItem(
        transformItem.name,
        List<double>.from(transformItem.data),
      );
      return _roundTransform(transformCopy, params);
    }).toList();

    final optimized = _optimize(roundedTransforms, decomposition);
    final len = _js2transform(optimized, params).length;

    if (len < shortestLen) {
      shortest = optimized;
      shortestLen = len;
    }
  }

  return shortest ?? [origMatrix];
}

/// Round transform values based on type.
_TransformItem _roundTransform(
    _TransformItem transform, _TransformParams params) {
  switch (transform.name) {
    case 'translate':
      transform.data = _floatRound(transform.data, params);

    case 'rotate':
      transform.data = [
        ..._degRound(transform.data.take(1).toList(), params),
        ..._floatRound(transform.data.skip(1).toList(), params),
      ];

    case 'skewx':
    case 'skewy':
      transform.data = _degRound(transform.data, params);

    case 'scale':
      transform.data = _transformRound(transform.data, params);

    case 'matrix':
      transform.data = [
        ..._transformRound(transform.data.take(4).toList(), params),
        ..._floatRound(transform.data.skip(4).toList(), params),
      ];
  }
  return transform;
}

/// Round degrees.
List<double> _degRound(List<double> data, _TransformParams params) {
  final degPrecision = params.degPrecision;
  if (degPrecision != null && degPrecision >= 1 && params.floatPrecision < 20) {
    return _smartRound(degPrecision, data);
  }
  return data.map((v) => v.roundToDouble()).toList();
}

/// Round floats.
List<double> _floatRound(List<double> data, _TransformParams params) {
  if (params.floatPrecision >= 1 && params.floatPrecision < 20) {
    return _smartRound(params.floatPrecision, data);
  }
  return data.map((v) => v.roundToDouble()).toList();
}

/// Round transform precision values.
List<double> _transformRound(List<double> data, _TransformParams params) {
  if (params.transformPrecision >= 1 && params.floatPrecision < 20) {
    return _smartRound(params.transformPrecision, data);
  }
  return data.map((v) => v.roundToDouble()).toList();
}

/// Smart round values keeping specified decimals.
List<double> _smartRound(int precision, List<double> data) {
  final result = List<double>.from(data);
  final tolerance = math.pow(0.1, precision);

  for (var i = result.length - 1; i >= 0; i--) {
    final fixed = _toFixed(result[i], precision);
    if (fixed != result[i]) {
      final rounded = double.parse(result[i].toStringAsFixed(precision - 1));
      result[i] = (rounded - result[i]).abs() >= tolerance
          ? double.parse(result[i].toStringAsFixed(precision))
          : rounded;
    }
  }

  return result;
}

/// Fixed precision number.
double _toFixed(double value, int precision) {
  return double.parse(value.toStringAsFixed(precision));
}

/// Remove useless transforms.
List<_TransformItem> _removeUseless(List<_TransformItem> transforms) {
  return transforms.where((transform) {
    if ((['translate', 'rotate', 'skewx', 'skewy'].contains(transform.name) &&
            (transform.data.length == 1 || transform.name == 'rotate') &&
            transform.data.isNotEmpty &&
            transform.data[0] == 0) ||
        (transform.name == 'translate' &&
            transform.data.length >= 2 &&
            transform.data[0] == 0 &&
            transform.data[1] == 0) ||
        (transform.name == 'scale' &&
            transform.data.isNotEmpty &&
            transform.data[0] == 1 &&
            (transform.data.length < 2 || transform.data[1] == 1)) ||
        (transform.name == 'matrix' &&
            transform.data.length >= 6 &&
            transform.data[0] == 1 &&
            transform.data[3] == 1 &&
            transform.data[1] == 0 &&
            transform.data[2] == 0 &&
            transform.data[4] == 0 &&
            transform.data[5] == 0)) {
      return false;
    }
    return true;
  }).toList();
}

/// Clean up output data for stringification.
String _cleanupOutData(List<double> data, _TransformParams params) {
  final result = <String>[];

  for (var i = 0; i < data.length; i++) {
    var str = data[i].toString();

    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'\.?0+$'), '');
    }

    if (params.leadingZero) {
      if (str.startsWith('0.')) {
        str = str.substring(1);
      } else if (str.startsWith('-0.')) {
        str = '-${str.substring(2)}';
      }
    }

    if (params.negativeExtraSpace && i > 0 && str.startsWith('-')) {
      result.add(str);
    } else if (i > 0) {
      result.add(' $str');
    } else {
      result.add(str);
    }
  }

  return result.join('');
}

/// Convert transforms JS representation to string.
String _js2transform(
    List<_TransformItem> transformJS, _TransformParams params) {
  return transformJS.map((transform) {
    _roundTransform(transform, params);
    return '${transform.name}(${_cleanupOutData(transform.data, params)})';
  }).join('');
}

/// Transform arc with matrix.
List<double> transformArc(
  List<double> cursor,
  List<double> arc,
  List<double> transform,
) {
  final x = arc[5] - cursor[0];
  final y = arc[6] - cursor[1];
  var a = arc[0];
  var b = arc[1];
  final rot = arc[2] * math.pi / 180;
  final cos = math.cos(rot);
  final sin = math.sin(rot);

  if (a > 0 && b > 0) {
    var h = math.pow(x * cos + y * sin, 2) / (4 * a * a) +
        math.pow(y * cos - x * sin, 2) / (4 * b * b);
    if (h > 1) {
      h = math.sqrt(h);
      a *= h;
      b *= h;
    }
  }

  final ellipse = [a * cos, a * sin, -b * sin, b * cos, 0.0, 0.0];
  final m = _multiplyTransformMatrices(transform, ellipse);

  final lastCol = m[2] * m[2] + m[3] * m[3];
  final squareSum = m[0] * m[0] + m[1] * m[1] + lastCol;
  final root = math.sqrt(
        (m[0] - m[3]) * (m[0] - m[3]) + (m[1] + m[2]) * (m[1] + m[2]),
      ) *
      math.sqrt(
        (m[0] + m[3]) * (m[0] + m[3]) + (m[1] - m[2]) * (m[1] - m[2]),
      );

  if (root == 0) {
    arc[0] = arc[1] = math.sqrt(squareSum / 2);
    arc[2] = 0;
  } else {
    final majorAxisSqr = (squareSum + root) / 2;
    final minorAxisSqr = (squareSum - root) / 2;
    final major = (majorAxisSqr - lastCol).abs() > 1e-6;
    final sub = (major ? majorAxisSqr : minorAxisSqr) - lastCol;
    final rowsSum = m[0] * m[2] + m[1] * m[3];
    final term1 = m[0] * sub + m[2] * rowsSum;
    final term2 = m[1] * sub + m[3] * rowsSum;
    arc[0] = math.sqrt(majorAxisSqr);
    arc[1] = math.sqrt(minorAxisSqr);
    arc[2] = ((major ? term2 < 0 : term1 > 0) ? -1 : 1) *
        math.acos((major ? term1 : term2) /
            math.sqrt(term1 * term1 + term2 * term2)) *
        180 /
        math.pi;
  }

  if ((transform[0] < 0) != (transform[3] < 0)) {
    arc[4] = 1 - arc[4];
  }

  return arc;
}
