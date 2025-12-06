/// Merges multiple paths into one if possible.
library;

import 'dart:math' as math;

import '../../path/path.dart';
import '../../style/style.dart';
import '../../types.dart';
import '../../xast/xast.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

const mergePaths = Plugin(
  name: 'mergePaths',
  description: 'merges multiple paths in one if possible',
  params: {
    'force': false,
    'floatPrecision': 3,
    'noSpaceAfterFlags': false,
  },
  fn: _mergePathsFn,
);

bool _elementHasUrl(Map<String, ComputedStyle> computedStyle, String attName) {
  final style = computedStyle[attName];
  if (style is StaticStyle) {
    return style.value.contains('url(');
  }
  return false;
}

Visitor? _mergePathsFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  final force = params['force'] == true;
  final floatPrecision = (params['floatPrecision'] as int?) ?? 3;
  final noSpaceAfterFlags = params['noSpaceAfterFlags'] == true;

  final stylesheet = collectStylesheet(ast);

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (node.children.length <= 1) return null;

        final elementsToRemove = <XastChild>{};
        XastChild prevChild = node.children[0];
        List<PathDataItem>? prevPathData;

        void updatePreviousPath(
            XastElement child, List<PathDataItem> pathData) {
          // Remove moveto commands which are followed by moveto commands
          final cleanedPathData = <PathDataItem>[];
          for (final item in pathData) {
            if (cleanedPathData.isNotEmpty &&
                (item.command == PathDataCommand.M ||
                    item.command == PathDataCommand.m)) {
              final last = cleanedPathData.last;
              if (last.command == PathDataCommand.M ||
                  last.command == PathDataCommand.m) {
                cleanedPathData.removeLast();
              }
            }
            cleanedPathData.add(item);
          }

          child.attributes['d'] = stringifyPathData(
            cleanedPathData,
            PathStringifyOptions(
              floatPrecision: floatPrecision,
              useShortArcFlags: noSpaceAfterFlags,
            ),
          );
          prevPathData = null;
        }

        for (var i = 1; i < node.children.length; i++) {
          final child = node.children[i];

          if (prevChild is! XastElement ||
              prevChild.name != 'path' ||
              prevChild.children.isNotEmpty ||
              prevChild.attributes['d'] == null) {
            if (prevPathData != null && prevChild is XastElement) {
              updatePreviousPath(prevChild, prevPathData!);
            }
            prevChild = child;
            continue;
          }

          if (child is! XastElement ||
              child.name != 'path' ||
              child.children.isNotEmpty ||
              child.attributes['d'] == null) {
            if (prevPathData != null) {
              updatePreviousPath(prevChild, prevPathData!);
            }
            prevChild = child;
            continue;
          }

          final computedStyle = computeStyle(stylesheet, child);
          if (computedStyle['marker-start'] != null ||
              computedStyle['marker-mid'] != null ||
              computedStyle['marker-end'] != null ||
              computedStyle['clip-path'] != null ||
              computedStyle['mask'] != null ||
              computedStyle['mask-image'] != null ||
              _elementHasUrl(computedStyle, 'fill') ||
              _elementHasUrl(computedStyle, 'filter') ||
              _elementHasUrl(computedStyle, 'stroke')) {
            if (prevPathData != null) {
              updatePreviousPath(prevChild, prevPathData!);
            }
            prevChild = child;
            continue;
          }

          final prevElement = prevChild;
          final childAttrs = child.attributes.keys.toList();
          if (childAttrs.length != prevElement.attributes.length) {
            if (prevPathData != null) {
              updatePreviousPath(prevElement, prevPathData!);
            }
            prevChild = child;
            continue;
          }

          final areAttrsEqual = childAttrs.any((attr) {
            return attr != 'd' &&
                prevElement.attributes[attr] != child.attributes[attr];
          });

          if (areAttrsEqual) {
            if (prevPathData != null) {
              updatePreviousPath(prevElement, prevPathData!);
            }
            prevChild = child;
            continue;
          }

          final hasPrevPath = prevPathData != null;
          List<PathDataItem> currentPathData;
          try {
            // Use a map to get path data - getPathData converts first 'm' to 'M'
            currentPathData = getPathData({'d': child.attributes['d']!});
            prevPathData ??= getPathData({'d': prevElement.attributes['d']!});
          } catch (_) {
            if (hasPrevPath) {
              updatePreviousPath(prevElement, prevPathData!);
            }
            prevChild = child;
            prevPathData = null;
            continue;
          }

          if (force || !_intersects(prevPathData!, currentPathData)) {
            prevPathData!.addAll(currentPathData);
            elementsToRemove.add(child);
            continue;
          }

          if (hasPrevPath) {
            updatePreviousPath(prevElement, prevPathData!);
          }

          prevChild = child;
          prevPathData = null;
        }

        if (prevPathData != null && prevChild is XastElement) {
          updatePreviousPath(prevChild, prevPathData!);
        }

        node.children.removeWhere((child) => elementsToRemove.contains(child));

        return null;
      },
    ),
  );
}

// ============================================================================
// GJK (Gilbert-Johnson-Keerthi) Convex Hull Collision Detection Algorithm
// Based on: https://web.archive.org/web/20180822200027/http://entropyinteractive.com/2011/04/gjk-algorithm/
// ============================================================================

/// A 2D point/vector.
typedef Vec2 = List<double>;

/// Represents a set of points with extrema indices.
class _PointSet {
  _PointSet() : list = [];

  final List<Vec2> list;
  int minX = 0;
  int minY = 0;
  int maxX = 0;
  int maxY = 0;
}

/// Represents a collection of point sets with global extrema.
class _PointsCollection {
  _PointsCollection() : list = [];

  final List<_PointSet> list;
  double minX = 0;
  double minY = 0;
  double maxX = 0;
  double maxY = 0;
}

/// Saved control point for smooth curves.
Vec2? _prevCtrlPoint;

/// Convert relative path data to absolute coordinates.
List<PathDataItem> _convertRelativeToAbsolute(List<PathDataItem> data) {
  final newData = <PathDataItem>[];
  final start = [0.0, 0.0];
  final cursor = [0.0, 0.0];

  for (var item in data) {
    var command = item.command;
    final args = List<double>.from(item.args);

    // moveto (x y)
    if (command == PathDataCommand.m) {
      args[0] += cursor[0];
      args[1] += cursor[1];
      command = PathDataCommand.M;
    }
    if (command == PathDataCommand.M) {
      cursor[0] = args[0];
      cursor[1] = args[1];
      start[0] = cursor[0];
      start[1] = cursor[1];
    }

    // horizontal lineto (x)
    if (command == PathDataCommand.h) {
      args[0] += cursor[0];
      command = PathDataCommand.H;
    }
    if (command == PathDataCommand.H) {
      cursor[0] = args[0];
    }

    // vertical lineto (y)
    if (command == PathDataCommand.v) {
      args[0] += cursor[1];
      command = PathDataCommand.V;
    }
    if (command == PathDataCommand.V) {
      cursor[1] = args[0];
    }

    // lineto (x y)
    if (command == PathDataCommand.l) {
      args[0] += cursor[0];
      args[1] += cursor[1];
      command = PathDataCommand.L;
    }
    if (command == PathDataCommand.L) {
      cursor[0] = args[0];
      cursor[1] = args[1];
    }

    // curveto (x1 y1 x2 y2 x y)
    if (command == PathDataCommand.c) {
      args[0] += cursor[0];
      args[1] += cursor[1];
      args[2] += cursor[0];
      args[3] += cursor[1];
      args[4] += cursor[0];
      args[5] += cursor[1];
      command = PathDataCommand.C;
    }
    if (command == PathDataCommand.C) {
      cursor[0] = args[4];
      cursor[1] = args[5];
    }

    // smooth curveto (x2 y2 x y)
    if (command == PathDataCommand.s) {
      args[0] += cursor[0];
      args[1] += cursor[1];
      args[2] += cursor[0];
      args[3] += cursor[1];
      command = PathDataCommand.S;
    }
    if (command == PathDataCommand.S) {
      cursor[0] = args[2];
      cursor[1] = args[3];
    }

    // quadratic Bézier curveto (x1 y1 x y)
    if (command == PathDataCommand.q) {
      args[0] += cursor[0];
      args[1] += cursor[1];
      args[2] += cursor[0];
      args[3] += cursor[1];
      command = PathDataCommand.Q;
    }
    if (command == PathDataCommand.Q) {
      cursor[0] = args[2];
      cursor[1] = args[3];
    }

    // smooth quadratic Bézier curveto (x y)
    if (command == PathDataCommand.t) {
      args[0] += cursor[0];
      args[1] += cursor[1];
      command = PathDataCommand.T;
    }
    if (command == PathDataCommand.T) {
      cursor[0] = args[0];
      cursor[1] = args[1];
    }

    // elliptical arc (rx ry x-axis-rotation large-arc-flag sweep-flag x y)
    if (command == PathDataCommand.a) {
      args[5] += cursor[0];
      args[6] += cursor[1];
      command = PathDataCommand.A;
    }
    if (command == PathDataCommand.A) {
      cursor[0] = args[5];
      cursor[1] = args[6];
    }

    // closepath
    if (command == PathDataCommand.z || command == PathDataCommand.Z) {
      cursor[0] = start[0];
      cursor[1] = start[1];
      command = PathDataCommand.z;
    }

    newData.add(PathDataItem(command, args));
  }
  return newData;
}

/// Arc to cubic bezier conversion.
/// Based on code from Snap.svg (Apache 2 license).
List<double> _a2c(
  double x1,
  double y1,
  double rx,
  double ry,
  double angle,
  double largeArcFlag,
  double sweepFlag,
  double x2,
  double y2, [
  List<double>? recursive,
]) {
  final rad = (math.pi / 180) * angle;
  var res = <double>[];

  double rotateX(double x, double y, double rad) {
    return x * math.cos(rad) - y * math.sin(rad);
  }

  double rotateY(double x, double y, double rad) {
    return x * math.sin(rad) + y * math.cos(rad);
  }

  double cx, cy, f1, f2;

  if (recursive == null) {
    x1 = rotateX(x1, y1, -rad);
    y1 = rotateY(x1, y1, -rad);
    x2 = rotateX(x2, y2, -rad);
    y2 = rotateY(x2, y2, -rad);

    final x = (x1 - x2) / 2;
    final y = (y1 - y2) / 2;
    var h = (x * x) / (rx * rx) + (y * y) / (ry * ry);

    if (h > 1) {
      h = math.sqrt(h);
      rx = h * rx;
      ry = h * ry;
    }

    final rx2 = rx * rx;
    final ry2 = ry * ry;
    final k = (largeArcFlag == sweepFlag ? -1 : 1) *
        math.sqrt(((rx2 * ry2 - rx2 * y * y - ry2 * x * x) /
                (rx2 * y * y + ry2 * x * x))
            .abs());

    cx = (k * rx * y) / ry + (x1 + x2) / 2;
    cy = (k * -ry * x) / rx + (y1 + y2) / 2;

    f1 = math.asin(double.parse(((y1 - cy) / ry).toStringAsFixed(9)));
    f2 = math.asin(double.parse(((y2 - cy) / ry).toStringAsFixed(9)));

    f1 = x1 < cx ? math.pi - f1 : f1;
    f2 = x2 < cx ? math.pi - f2 : f2;

    if (f1 < 0) f1 = math.pi * 2 + f1;
    if (f2 < 0) f2 = math.pi * 2 + f2;

    if (sweepFlag != 0 && f1 > f2) {
      f1 = f1 - math.pi * 2;
    }
    if (sweepFlag == 0 && f2 > f1) {
      f2 = f2 - math.pi * 2;
    }
  } else {
    f1 = recursive[0];
    f2 = recursive[1];
    cx = recursive[2];
    cy = recursive[3];
  }

  var df = f2 - f1;
  if (df.abs() > 120) {
    final f2old = f2;
    final x2old = x2;
    final y2old = y2;
    f2 = f1 + 120 * (sweepFlag != 0 && f2 > f1 ? 1 : -1);
    x2 = cx + rx * math.cos(f2);
    y2 = cy + ry * math.sin(f2);
    res = _a2c(x2, y2, rx, ry, angle, 0, sweepFlag, x2old, y2old, [
      f2,
      f2old,
      cx,
      cy,
    ]);
  }

  df = f2 - f1;
  final c1 = math.cos(f1);
  final s1 = math.sin(f1);
  final c2 = math.cos(f2);
  final s2 = math.sin(f2);
  final t = math.tan(df / 4);
  final hx = (4 / 3) * rx * t;
  final hy = (4 / 3) * ry * t;

  final m = [
    -hx * s1,
    hy * c1,
    x2 + hx * s2 - x1,
    y2 - hy * c2 - y1,
    x2 - x1,
    y2 - y1,
  ];

  if (recursive != null) {
    return [...m, ...res];
  } else {
    res = [...m, ...res];
    final newres = <double>[];
    for (var i = 0; i < res.length; i++) {
      newres.add(i % 2 != 0
          ? rotateY(res[i - 1], res[i], rad)
          : rotateX(res[i], res[i + 1], rad));
    }
    return newres;
  }
}

/// Gathers points from path data for convex hull construction.
_PointsCollection _gatherPoints(List<PathDataItem> pathData) {
  final points = _PointsCollection();

  void addPoint(_PointSet path, Vec2 point) {
    if (path.list.isEmpty || point[1] > path.list[path.maxY][1]) {
      path.maxY = path.list.length;
      points.maxY =
          points.list.isNotEmpty ? math.max(point[1], points.maxY) : point[1];
    }
    if (path.list.isEmpty || point[0] > path.list[path.maxX][0]) {
      path.maxX = path.list.length;
      points.maxX =
          points.list.isNotEmpty ? math.max(point[0], points.maxX) : point[0];
    }
    if (path.list.isEmpty || point[1] < path.list[path.minY][1]) {
      path.minY = path.list.length;
      points.minY =
          points.list.isNotEmpty ? math.min(point[1], points.minY) : point[1];
    }
    if (path.list.isEmpty || point[0] < path.list[path.minX][0]) {
      path.minX = path.list.length;
      points.minX =
          points.list.isNotEmpty ? math.min(point[0], points.minX) : point[0];
    }
    path.list.add(point);
  }

  for (var i = 0; i < pathData.length; i++) {
    final pathDataItem = pathData[i];
    var subPath = points.list.isEmpty ? _PointSet() : points.list.last;
    final prev = i == 0 ? null : pathData[i - 1];
    Vec2? basePoint = subPath.list.isEmpty ? null : subPath.list.last;
    final data = pathDataItem.args;
    Vec2? ctrlPoint = basePoint;

    double toAbsolute(double n, int idx) =>
        n + (basePoint == null ? 0 : basePoint[idx % 2]);

    switch (pathDataItem.command) {
      case PathDataCommand.M:
        subPath = _PointSet();
        points.list.add(subPath);

      case PathDataCommand.H:
        if (basePoint != null) {
          addPoint(subPath, [data[0], basePoint[1]]);
        }

      case PathDataCommand.V:
        if (basePoint != null) {
          addPoint(subPath, [basePoint[0], data[0]]);
        }

      case PathDataCommand.Q:
        addPoint(subPath, [data[0], data[1]]);
        _prevCtrlPoint = [data[2] - data[0], data[3] - data[1]];

      case PathDataCommand.T:
        if (basePoint != null &&
            prev != null &&
            (prev.command == PathDataCommand.Q ||
                prev.command == PathDataCommand.T)) {
          if (_prevCtrlPoint != null) {
            ctrlPoint = [
              basePoint[0] + _prevCtrlPoint![0],
              basePoint[1] + _prevCtrlPoint![1],
            ];
            addPoint(subPath, ctrlPoint);
            _prevCtrlPoint = [data[0] - ctrlPoint[0], data[1] - ctrlPoint[1]];
          }
        }

      case PathDataCommand.C:
        if (basePoint != null) {
          addPoint(subPath, [
            0.5 * (basePoint[0] + data[0]),
            0.5 * (basePoint[1] + data[1]),
          ]);
        }
        addPoint(subPath, [
          0.5 * (data[0] + data[2]),
          0.5 * (data[1] + data[3]),
        ]);
        addPoint(subPath, [
          0.5 * (data[2] + data[4]),
          0.5 * (data[3] + data[5]),
        ]);
        _prevCtrlPoint = [data[4] - data[2], data[5] - data[3]];

      case PathDataCommand.S:
        if (basePoint != null &&
            prev != null &&
            (prev.command == PathDataCommand.C ||
                prev.command == PathDataCommand.S)) {
          if (_prevCtrlPoint != null) {
            addPoint(subPath, [
              basePoint[0] + 0.5 * _prevCtrlPoint![0],
              basePoint[1] + 0.5 * _prevCtrlPoint![1],
            ]);
            ctrlPoint = [
              basePoint[0] + _prevCtrlPoint![0],
              basePoint[1] + _prevCtrlPoint![1],
            ];
          }
        }
        if (ctrlPoint != null) {
          addPoint(subPath, [
            0.5 * (ctrlPoint[0] + data[0]),
            0.5 * (ctrlPoint[1] + data[1]),
          ]);
        }
        addPoint(subPath, [
          0.5 * (data[0] + data[2]),
          0.5 * (data[1] + data[3]),
        ]);
        _prevCtrlPoint = [data[2] - data[0], data[3] - data[1]];

      case PathDataCommand.A:
        if (basePoint != null) {
          final curves = _a2c(
            basePoint[0],
            basePoint[1],
            data[0],
            data[1],
            data[2],
            data[3],
            data[4],
            data[5],
            data[6],
          );

          var curveData = <double>[];
          var curveIdx = 0;
          while (curveIdx < curves.length) {
            curveData = [];
            for (var j = 0;
                j < 6 && curveIdx < curves.length;
                j++, curveIdx++) {
              curveData.add(toAbsolute(curves[curveIdx], j));
            }
            if (curveData.length == 6) {
              if (basePoint != null) {
                addPoint(subPath, [
                  0.5 * (basePoint[0] + curveData[0]),
                  0.5 * (basePoint[1] + curveData[1]),
                ]);
              }
              addPoint(subPath, [
                0.5 * (curveData[0] + curveData[2]),
                0.5 * (curveData[1] + curveData[3]),
              ]);
              addPoint(subPath, [
                0.5 * (curveData[2] + curveData[4]),
                0.5 * (curveData[3] + curveData[5]),
              ]);
              if (curveIdx < curves.length) {
                basePoint = [curveData[4], curveData[5]];
                addPoint(subPath, basePoint);
              }
            }
          }
        }

      default:
        break;
    }

    // Save final command coordinates
    if (data.length >= 2) {
      addPoint(subPath, [data[data.length - 2], data[data.length - 1]]);
    }
  }

  return points;
}

/// Cross product for convex hull calculation.
double _cross(Vec2 o, Vec2 a, Vec2 b) {
  return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
}

/// Forms a convex hull from set of points using monotone chain algorithm.
/// https://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Convex_hull/Monotone_chain
_PointSet _convexHull(_PointSet points) {
  points.list.sort((a, b) =>
      a[0] == b[0] ? (a[1] - b[1]).sign.toInt() : (a[0] - b[0]).sign.toInt());

  final lower = <Vec2>[];
  var minY = 0;
  var bottom = 0;
  for (var i = 0; i < points.list.length; i++) {
    while (lower.length >= 2 &&
        _cross(lower[lower.length - 2], lower[lower.length - 1],
                points.list[i]) <=
            0) {
      lower.removeLast();
    }
    if (points.list[i][1] < points.list[minY][1]) {
      minY = i;
      bottom = lower.length;
    }
    lower.add(points.list[i]);
  }

  final upper = <Vec2>[];
  var maxY = points.list.length - 1;
  var top = 0;
  for (var i = points.list.length - 1; i >= 0; i--) {
    while (upper.length >= 2 &&
        _cross(upper[upper.length - 2], upper[upper.length - 1],
                points.list[i]) <=
            0) {
      upper.removeLast();
    }
    if (points.list[i][1] > points.list[maxY][1]) {
      maxY = i;
      top = upper.length;
    }
    upper.add(points.list[i]);
  }

  // Last points are equal to starting points of the other part
  if (upper.isNotEmpty) upper.removeLast();
  if (lower.isNotEmpty) lower.removeLast();

  final hullList = [...lower, ...upper];

  final hull = _PointSet();
  hull.list.addAll(hullList);
  hull.minX = 0; // by sorting
  hull.maxX = lower.length;
  hull.minY = bottom;
  hull.maxY = hullList.isNotEmpty ? (lower.length + top) % hullList.length : 0;

  return hull;
}

/// Vector negation.
Vec2 _minus(Vec2 v) {
  return [-v[0], -v[1]];
}

/// Vector subtraction.
Vec2 _sub(Vec2 v1, Vec2 v2) {
  return [v1[0] - v2[0], v1[1] - v2[1]];
}

/// Dot product.
double _dot(Vec2 v1, Vec2 v2) {
  return v1[0] * v2[0] + v1[1] * v2[1];
}

/// Get orthogonal vector facing away from a point.
Vec2 _orth(Vec2 v, Vec2 from) {
  final o = [-v[1], v[0]];
  return _dot(o, _minus(from)) < 0 ? _minus(o) : o;
}

/// Set destination vector from source.
void _set(Vec2 dest, Vec2 source) {
  dest[0] = source[source.length - 2];
  dest[1] = source[source.length - 1];
}

/// Computes farthest polygon point in particular direction.
Vec2 _supportPoint(_PointSet polygon, Vec2 direction) {
  var index = direction[1] >= 0
      ? (direction[0] < 0 ? polygon.maxY : polygon.maxX)
      : (direction[0] < 0 ? polygon.minX : polygon.minY);

  var max = double.negativeInfinity;
  double value;
  while ((value = _dot(polygon.list[index], direction)) > max) {
    max = value;
    index = (index + 1) % polygon.list.length;
  }
  return polygon.list[(index == 0 ? polygon.list.length : index) - 1];
}

/// Get support point for Minkowski difference.
Vec2 _getSupport(_PointSet a, _PointSet b, Vec2 direction) {
  return _sub(_supportPoint(a, direction), _supportPoint(b, _minus(direction)));
}

/// Process simplex for GJK algorithm.
bool _processSimplex(List<Vec2> simplex, Vec2 direction) {
  if (simplex.length == 2) {
    // 1-simplex
    final a = simplex[1];
    final b = simplex[0];
    final ao = _minus(simplex[1]);
    final ab = _sub(b, a);

    if (_dot(ao, ab) > 0) {
      _set(direction, _orth(ab, a));
    } else {
      _set(direction, ao);
      simplex.removeAt(0);
    }
  } else {
    // 2-simplex
    final a = simplex[2];
    final b = simplex[1];
    final c = simplex[0];
    final ab = _sub(b, a);
    final ac = _sub(c, a);
    final ao = _minus(a);
    final acb = _orth(ab, ac); // perpendicular to AB facing away from C
    final abc = _orth(ac, ab); // perpendicular to AC facing away from B

    if (_dot(acb, ao) > 0) {
      if (_dot(ab, ao) > 0) {
        // region 4
        _set(direction, acb);
        simplex.removeAt(0); // simplex = [b, a]
      } else {
        // region 5
        _set(direction, ao);
        simplex.removeRange(0, 2); // simplex = [a]
      }
    } else if (_dot(abc, ao) > 0) {
      if (_dot(ac, ao) > 0) {
        // region 6
        _set(direction, abc);
        simplex.removeAt(1); // simplex = [c, a]
      } else {
        // region 5 (again)
        _set(direction, ao);
        simplex.removeRange(0, 2); // simplex = [a]
      }
    } else {
      // region 7
      return true;
    }
  }
  return false;
}

/// Checks if two paths have an intersection using GJK algorithm.
bool _intersects(List<PathDataItem> path1, List<PathDataItem> path2) {
  // Collect points of every subpath
  final points1 = _gatherPoints(_convertRelativeToAbsolute(path1));
  final points2 = _gatherPoints(_convertRelativeToAbsolute(path2));

  // Quick bounding box check
  if (points1.maxX <= points2.minX ||
      points2.maxX <= points1.minX ||
      points1.maxY <= points2.minY ||
      points2.maxY <= points1.minY) {
    return false;
  }

  // Check subpath bounding boxes
  if (points1.list.every((set1) {
    return points2.list.every((set2) {
      if (set1.list.isEmpty || set2.list.isEmpty) return true;
      return set1.list[set1.maxX][0] <= set2.list[set2.minX][0] ||
          set2.list[set2.maxX][0] <= set1.list[set1.minX][0] ||
          set1.list[set1.maxY][1] <= set2.list[set2.minY][1] ||
          set2.list[set2.maxY][1] <= set1.list[set1.minY][1];
    });
  })) {
    return false;
  }

  // Get convex hull from points of each subpath
  final hullNest1 = points1.list.map(_convexHull).toList();
  final hullNest2 = points2.list.map(_convexHull).toList();

  // Check intersection of every subpath of the first path with every subpath of the second
  return hullNest1.any((hull1) {
    if (hull1.list.length < 3) return false;

    return hullNest2.any((hull2) {
      if (hull2.list.length < 3) return false;

      // Create the initial simplex
      final simplex = [
        _getSupport(hull1, hull2, [1.0, 0.0])
      ];
      // Set the direction to point towards the origin
      final direction = _minus(simplex[0]);

      var iterations = 10000; // Infinite loop protection

      while (true) {
        if (--iterations == 0) {
          // Safety: assume intersection
          return true;
        }

        // Add a new point
        simplex.add(_getSupport(hull1, hull2, direction));

        // See if the new point was on the correct side of the origin
        if (_dot(direction, simplex.last) <= 0) {
          return false;
        }

        // Process the simplex
        if (_processSimplex(simplex, direction)) {
          return true;
        }
      }
    });
  });
}
