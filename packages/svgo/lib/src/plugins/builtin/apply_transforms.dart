/// Apply transforms to paths plugin.
///
/// Applies transformation matrices to path data and removes the transform attribute.
library;

import 'dart:math' as math;

import '../../collections/collections.dart';
import '../../path/path.dart';
import '../../style/style.dart';
import '../../types.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Parameters for the applyTransforms plugin.
class ApplyTransformsParams extends PluginParams {
  /// Precision for transform values. Default: 5
  final int transformPrecision;

  /// Apply transforms to stroked elements. Default: true
  final bool applyTransformsStroked;

  const ApplyTransformsParams({
    this.transformPrecision = 5,
    this.applyTransformsStroked = true,
  });
}

/// Apply transformation(s) to path data.
///
/// This plugin applies transform matrices directly to path coordinates
/// and removes the transform attribute.
///
/// **Example:**
/// ```xml
/// <!-- Before -->
/// <path d="M0 0 L10 10" transform="translate(10, 20)"/>
///
/// <!-- After -->
/// <path d="M10 20 L20 30"/>
/// ```
const applyTransforms = Plugin<ApplyTransformsParams>(
  name: 'applyTransforms',
  description: 'applies transformation to path data',
  defaultParams: ApplyTransformsParams(),
  fn: _applyTransformsFn,
);

final _regNumericValues = RegExp(r'[-+]?(\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');

Visitor? _applyTransformsFn(
  XastRoot ast,
  ApplyTransformsParams params,
  SvgoInfo info,
) {
  final transformPrecision = params.transformPrecision;
  final applyTransformsStroked = params.applyTransformsStroked;

  final stylesheet = collectStylesheet(ast);

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Only process path elements with 'd' attribute
        if (!node.attributes.containsKey('d')) {
          return null;
        }

        // Stroke and stroke-width can be redefined with <use>
        if (node.attributes.containsKey('id')) {
          return null;
        }

        // Skip if no transform or empty transform
        final transformAttr = node.attributes['transform'];
        if (transformAttr == null || transformAttr.isEmpty) {
          return null;
        }

        // Skip if style attribute is present (styles override)
        if (node.attributes.containsKey('style')) {
          return null;
        }

        // Skip if has references to other objects
        if (_hasReferences(node)) {
          return null;
        }

        final computedStyles = computeStyle(stylesheet, node);

        // Skip if transform is overridden in stylesheet
        final transformStyle = computedStyles['transform'];
        if (transformStyle != null &&
            transformStyle is StaticStyle &&
            transformStyle.value != transformAttr) {
          return null;
        }

        // Parse and multiply transforms
        final transforms = _parseTransforms(transformAttr);
        if (transforms.isEmpty) {
          return null;
        }

        final matrix = _transformsMultiply(transforms);

        // Get stroke info
        final strokeStyle = computedStyles['stroke'];
        final strokeWidthStyle = computedStyles['stroke-width'];

        final stroke = strokeStyle is StaticStyle ? strokeStyle.value : null;
        final strokeWidth =
            strokeWidthStyle is StaticStyle ? strokeWidthStyle.value : null;

        // Skip if stroke or stroke-width is dynamic
        if (strokeStyle is DynamicStyle || strokeWidthStyle is DynamicStyle) {
          return null;
        }

        // Calculate scale factor
        final scale = double.parse(
          math
              .sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1])
              .toStringAsFixed(transformPrecision),
        );

        // Handle stroked elements
        if (stroke != null && stroke != 'none') {
          if (!applyTransformsStroked) {
            return null;
          }

          // Check for uniform scaling
          final isUniformScale =
              (matrix[0] == matrix[3] && matrix[1] == -matrix[2]) ||
                  (matrix[0] == -matrix[3] && matrix[1] == matrix[2]);

          if (!isUniformScale) {
            return null;
          }

          // Apply transform to stroke properties
          if (scale != 1 &&
              node.attributes['vector-effect'] != 'non-scaling-stroke') {
            // Transform stroke-width
            final sw = strokeWidth ??
                attrsGroupsDefaults['presentation']?['stroke-width'] ??
                '1';
            node.attributes['stroke-width'] =
                sw.toString().trim().replaceAllMapped(_regNumericValues, (m) {
              final num = double.parse(m.group(0)!);
              return _removeLeadingZero(num * scale);
            });

            // Transform stroke-dashoffset
            if (node.attributes.containsKey('stroke-dashoffset')) {
              node.attributes['stroke-dashoffset'] = node
                  .attributes['stroke-dashoffset']!
                  .trim()
                  .replaceAllMapped(_regNumericValues, (m) {
                final num = double.parse(m.group(0)!);
                return _removeLeadingZero(num * scale);
              });
            }

            // Transform stroke-dasharray
            if (node.attributes.containsKey('stroke-dasharray')) {
              node.attributes['stroke-dasharray'] = node
                  .attributes['stroke-dasharray']!
                  .trim()
                  .replaceAllMapped(_regNumericValues, (m) {
                final num = double.parse(m.group(0)!);
                return _removeLeadingZero(num * scale);
              });
            }
          }
        }

        // Parse and transform path data
        final pathData = getPathData(node.attributes);
        if (pathData.isEmpty) {
          return null;
        }

        final transformedPath = _applyMatrixToPathData(pathData, matrix);

        // Store transformed path data in pathJS for use by convertPathData
        // This preserves full precision without string serialization
        node.pathJS = transformedPath;

        // Remove transform
        node.attributes.remove('transform');

        return null;
      },
    ),
  );
}

bool _hasReferences(XastElement node) {
  for (final entry in node.attributes.entries) {
    if (referencesProps.contains(entry.key)) {
      if (entry.value.contains('url(')) {
        return true;
      }
    }
  }
  return false;
}

String _removeLeadingZero(double num) {
  var str = num.toString();
  // Remove unnecessary precision
  if (str.contains('.') && str.length > 10) {
    str = num.toStringAsFixed(6);
  }
  // Remove trailing zeros
  if (str.contains('.')) {
    str = str.replaceAll(RegExp(r'0+$'), '');
    str = str.replaceAll(RegExp(r'\.$'), '');
  }
  // Remove leading zero
  if (str.startsWith('0.')) {
    str = str.substring(1);
  }
  if (str.startsWith('-0.')) {
    str = '-${str.substring(2)}';
  }
  return str;
}

class _Transform {
  const _Transform(this.name, this.data);
  final String name;
  final List<double> data;
}

List<_Transform> _parseTransforms(String str) {
  final transforms = <_Transform>[];
  final regex = RegExp(
    r'(matrix|translate|scale|rotate|skewX|skewY)\s*\(\s*([^)]*)\s*\)',
    caseSensitive: false,
  );

  for (final match in regex.allMatches(str)) {
    final name = match.group(1)!.toLowerCase();
    final args = match.group(2)!;
    final data = args
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => double.tryParse(s) ?? 0.0)
        .toList();
    transforms.add(_Transform(name, data));
  }

  return transforms;
}

List<double> _transformsMultiply(List<_Transform> transforms) {
  var result = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

  for (final transform in transforms) {
    final matrix = _transformToMatrix(transform);
    result = _multiplyMatrices(result, matrix);
  }

  return result;
}

List<double> _transformToMatrix(_Transform transform) {
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
      final angle = (data.isNotEmpty ? data[0] : 0.0) * math.pi / 180;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      if (data.length >= 3) {
        final cx = data[1];
        final cy = data[2];
        return [
          cos,
          sin,
          -sin,
          cos,
          (1 - cos) * cx + sin * cy,
          (1 - cos) * cy - sin * cx,
        ];
      }
      return [cos, sin, -sin, cos, 0.0, 0.0];
    case 'skewx':
      final angle = (data.isNotEmpty ? data[0] : 0.0) * math.pi / 180;
      return [1.0, 0.0, math.tan(angle), 1.0, 0.0, 0.0];
    case 'skewy':
      final angle = (data.isNotEmpty ? data[0] : 0.0) * math.pi / 180;
      return [1.0, math.tan(angle), 0.0, 1.0, 0.0, 0.0];
    default:
      return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
  }
}

List<double> _multiplyMatrices(List<double> a, List<double> b) {
  return [
    a[0] * b[0] + a[2] * b[1],
    a[1] * b[0] + a[3] * b[1],
    a[0] * b[2] + a[2] * b[3],
    a[1] * b[2] + a[3] * b[3],
    a[0] * b[4] + a[2] * b[5] + a[4],
    a[1] * b[4] + a[3] * b[5] + a[5],
  ];
}

(double, double) _transformAbsolutePoint(List<double> m, double x, double y) {
  final newX = m[0] * x + m[2] * y + m[4];
  final newY = m[1] * x + m[3] * y + m[5];
  return (newX, newY);
}

(double, double) _transformRelativePoint(List<double> m, double x, double y) {
  final newX = m[0] * x + m[2] * y;
  final newY = m[1] * x + m[3] * y;
  return (newX, newY);
}

List<PathDataItem> _applyMatrixToPathData(
    List<PathDataItem> pathData, List<double> matrix) {
  var startX = 0.0;
  var startY = 0.0;
  var cursorX = 0.0;
  var cursorY = 0.0;

  final result = <PathDataItem>[];

  for (final item in pathData) {
    var command = item.command;
    final args = List<double>.from(item.args);

    // moveto (x y)
    if (command == PathDataCommand.M) {
      cursorX = args[0];
      cursorY = args[1];
      startX = cursorX;
      startY = cursorY;
      final (x, y) = _transformAbsolutePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    } else if (command == PathDataCommand.m) {
      cursorX += args[0];
      cursorY += args[1];
      startX = cursorX;
      startY = cursorY;
      final (x, y) = _transformRelativePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    }

    // horizontal lineto (x) - convert to lineto
    else if (command == PathDataCommand.H) {
      command = PathDataCommand.L;
      final targetX = args[0];
      args.clear();
      args.addAll([targetX, cursorY]);
      cursorX = targetX;
      final (x, y) = _transformAbsolutePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    } else if (command == PathDataCommand.h) {
      command = PathDataCommand.l;
      final dx = args[0];
      args.clear();
      args.addAll([dx, 0]);
      cursorX += dx;
      final (x, y) = _transformRelativePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    }

    // vertical lineto (y) - convert to lineto
    else if (command == PathDataCommand.V) {
      command = PathDataCommand.L;
      final targetY = args[0];
      args.clear();
      args.addAll([cursorX, targetY]);
      cursorY = targetY;
      final (x, y) = _transformAbsolutePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    } else if (command == PathDataCommand.v) {
      command = PathDataCommand.l;
      final dy = args[0];
      args.clear();
      args.addAll([0, dy]);
      cursorY += dy;
      final (x, y) = _transformRelativePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    }

    // lineto (x y)
    else if (command == PathDataCommand.L) {
      cursorX = args[0];
      cursorY = args[1];
      final (x, y) = _transformAbsolutePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    } else if (command == PathDataCommand.l) {
      cursorX += args[0];
      cursorY += args[1];
      final (x, y) = _transformRelativePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    }

    // curveto (x1 y1 x2 y2 x y)
    else if (command == PathDataCommand.C) {
      cursorX = args[4];
      cursorY = args[5];
      final (x1, y1) = _transformAbsolutePoint(matrix, args[0], args[1]);
      final (x2, y2) = _transformAbsolutePoint(matrix, args[2], args[3]);
      final (x, y) = _transformAbsolutePoint(matrix, args[4], args[5]);
      args[0] = x1;
      args[1] = y1;
      args[2] = x2;
      args[3] = y2;
      args[4] = x;
      args[5] = y;
    } else if (command == PathDataCommand.c) {
      cursorX += args[4];
      cursorY += args[5];
      final (x1, y1) = _transformRelativePoint(matrix, args[0], args[1]);
      final (x2, y2) = _transformRelativePoint(matrix, args[2], args[3]);
      final (x, y) = _transformRelativePoint(matrix, args[4], args[5]);
      args[0] = x1;
      args[1] = y1;
      args[2] = x2;
      args[3] = y2;
      args[4] = x;
      args[5] = y;
    }

    // smooth curveto (x2 y2 x y)
    else if (command == PathDataCommand.S) {
      cursorX = args[2];
      cursorY = args[3];
      final (x2, y2) = _transformAbsolutePoint(matrix, args[0], args[1]);
      final (x, y) = _transformAbsolutePoint(matrix, args[2], args[3]);
      args[0] = x2;
      args[1] = y2;
      args[2] = x;
      args[3] = y;
    } else if (command == PathDataCommand.s) {
      cursorX += args[2];
      cursorY += args[3];
      final (x2, y2) = _transformRelativePoint(matrix, args[0], args[1]);
      final (x, y) = _transformRelativePoint(matrix, args[2], args[3]);
      args[0] = x2;
      args[1] = y2;
      args[2] = x;
      args[3] = y;
    }

    // quadratic Bezier curveto (x1 y1 x y)
    else if (command == PathDataCommand.Q) {
      cursorX = args[2];
      cursorY = args[3];
      final (x1, y1) = _transformAbsolutePoint(matrix, args[0], args[1]);
      final (x, y) = _transformAbsolutePoint(matrix, args[2], args[3]);
      args[0] = x1;
      args[1] = y1;
      args[2] = x;
      args[3] = y;
    } else if (command == PathDataCommand.q) {
      cursorX += args[2];
      cursorY += args[3];
      final (x1, y1) = _transformRelativePoint(matrix, args[0], args[1]);
      final (x, y) = _transformRelativePoint(matrix, args[2], args[3]);
      args[0] = x1;
      args[1] = y1;
      args[2] = x;
      args[3] = y;
    }

    // smooth quadratic Bezier curveto (x y)
    else if (command == PathDataCommand.T) {
      cursorX = args[0];
      cursorY = args[1];
      final (x, y) = _transformAbsolutePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    } else if (command == PathDataCommand.t) {
      cursorX += args[0];
      cursorY += args[1];
      final (x, y) = _transformRelativePoint(matrix, args[0], args[1]);
      args[0] = x;
      args[1] = y;
    }

    // elliptical arc (rx ry x-axis-rotation large-arc-flag sweep-flag x y)
    else if (command == PathDataCommand.A) {
      _transformArc([cursorX, cursorY], args, matrix);
      cursorX = args[5];
      cursorY = args[6];
      // Reduce number of digits in rotation angle
      if (args[2].abs() > 80) {
        final a = args[0];
        final rotation = args[2];
        args[0] = args[1];
        args[1] = a;
        args[2] = rotation + (rotation > 0 ? -90 : 90);
      }
      final (x, y) = _transformAbsolutePoint(matrix, args[5], args[6]);
      args[5] = x;
      args[6] = y;
    } else if (command == PathDataCommand.a) {
      _transformArc([0, 0], args, matrix);
      cursorX += args[5];
      cursorY += args[6];
      // Reduce number of digits in rotation angle
      if (args[2].abs() > 80) {
        final a = args[0];
        final rotation = args[2];
        args[0] = args[1];
        args[1] = a;
        args[2] = rotation + (rotation > 0 ? -90 : 90);
      }
      final (x, y) = _transformRelativePoint(matrix, args[5], args[6]);
      args[5] = x;
      args[6] = y;
    }

    // closepath
    else if (command == PathDataCommand.z || command == PathDataCommand.Z) {
      cursorX = startX;
      cursorY = startY;
    }

    result.add(PathDataItem(command, args));
  }

  return result;
}

/// Transform arc parameters.
void _transformArc(
    List<double> cursor, List<double> arc, List<double> transform) {
  final x = arc[5] - cursor[0];
  final y = arc[6] - cursor[1];
  var a = arc[0];
  var b = arc[1];
  final rot = arc[2] * math.pi / 180;
  final cos = math.cos(rot);
  final sin = math.sin(rot);

  // Skip if radius is 0
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
  final m = _multiplyMatrices(transform, ellipse);

  // Decompose the new ellipse matrix
  final lastCol = m[2] * m[2] + m[3] * m[3];
  final squareSum = m[0] * m[0] + m[1] * m[1] + lastCol;
  final root = math.sqrt((m[0] - m[3]).abs() * (m[0] - m[3]).abs() +
          (m[1] + m[2]).abs() * (m[1] + m[2]).abs()) *
      math.sqrt((m[0] + m[3]).abs() * (m[0] + m[3]).abs() +
          (m[1] - m[2]).abs() * (m[1] - m[2]).abs());

  if (root == 0) {
    // Circle
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

  // Flip the sweep flag if coordinates are being flipped horizontally XOR vertically
  if ((transform[0] < 0) != (transform[3] < 0)) {
    arc[4] = 1 - arc[4];
  }
}
