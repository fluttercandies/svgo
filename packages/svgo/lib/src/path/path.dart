/// SVG path utilities for path manipulation and geometric operations.
///
/// Provides utilities for converting path data between coordinate systems,
/// computing intersections, and other path-related operations.
library;

import 'dart:math' as math;

import '../types.dart';
import 'path_parser.dart';
import 'path_stringifier.dart';

export 'path_parser.dart';
export 'path_stringifier.dart';

/// A 2D point.
typedef Point = (double x, double y);

/// A bounding box defined by min and max coordinates.
typedef BoundingBox = ({double minX, double minY, double maxX, double maxY});

/// Gets path data from an element's 'd' attribute.
///
/// Parses and caches the path data for performance.
/// First moveto is actually absolute per SVG spec, so we convert 'm' to 'M'.
List<PathDataItem> getPathData(Map<String, String> attributes) {
  final d = attributes['d'];
  if (d == null || d.isEmpty) return [];
  final pathData = parsePathData(d);
  // First moveto is actually absolute. This matches node_svgo behavior.
  if (pathData.isNotEmpty && pathData[0].command == PathDataCommand.m) {
    pathData[0] = PathDataItem(PathDataCommand.M, pathData[0].args);
  }
  return pathData;
}

/// Converts path data to a string and updates the element's attribute.
void setPathData(
  Map<String, String> attributes,
  List<PathDataItem> pathData, {
  int floatPrecision = 3,
  bool noSpaceAfterFlags = true,
}) {
  // Remove consecutive moveto commands (keep only the last one)
  final cleaned = <PathDataItem>[];
  for (final item in pathData) {
    if (cleaned.isNotEmpty &&
        (item.command == PathDataCommand.M ||
            item.command == PathDataCommand.m)) {
      final last = cleaned.last;
      if (last.command == PathDataCommand.M ||
          last.command == PathDataCommand.m) {
        cleaned.removeLast();
      }
    }
    cleaned.add(item);
  }

  attributes['d'] = stringifyPathData(
    cleaned,
    PathStringifyOptions(
      floatPrecision: floatPrecision,
      useShortArcFlags: noSpaceAfterFlags,
    ),
  );
}

/// Converts relative path commands to absolute coordinates.
///
/// Example:
/// ```dart
/// final relPath = [
///   PathDataItem(PathDataCommand.M, [10, 10]),
///   PathDataItem(PathDataCommand.l, [20, 20]),  // relative
/// ];
/// final absPath = convertRelativeToAbsolute(relPath);
/// // absPath[1].command == PathDataCommand.L
/// // absPath[1].args == [30, 30]
/// ```
List<PathDataItem> convertRelativeToAbsolute(List<PathDataItem> data) {
  final result = <PathDataItem>[];
  var startX = 0.0;
  var startY = 0.0;
  var cursorX = 0.0;
  var cursorY = 0.0;

  for (final item in data) {
    var command = item.command;
    final args = List<double>.from(item.args);

    switch (command) {
      case PathDataCommand.m:
        args[0] += cursorX;
        args[1] += cursorY;
        command = PathDataCommand.M;
      case PathDataCommand.M:
        break;
      case PathDataCommand.h:
        args[0] += cursorX;
        command = PathDataCommand.H;
      case PathDataCommand.H:
        break;
      case PathDataCommand.v:
        args[0] += cursorY;
        command = PathDataCommand.V;
      case PathDataCommand.V:
        break;
      case PathDataCommand.l:
        args[0] += cursorX;
        args[1] += cursorY;
        command = PathDataCommand.L;
      case PathDataCommand.L:
        break;
      case PathDataCommand.c:
        args[0] += cursorX;
        args[1] += cursorY;
        args[2] += cursorX;
        args[3] += cursorY;
        args[4] += cursorX;
        args[5] += cursorY;
        command = PathDataCommand.C;
      case PathDataCommand.C:
        break;
      case PathDataCommand.s:
        args[0] += cursorX;
        args[1] += cursorY;
        args[2] += cursorX;
        args[3] += cursorY;
        command = PathDataCommand.S;
      case PathDataCommand.S:
        break;
      case PathDataCommand.q:
        args[0] += cursorX;
        args[1] += cursorY;
        args[2] += cursorX;
        args[3] += cursorY;
        command = PathDataCommand.Q;
      case PathDataCommand.Q:
        break;
      case PathDataCommand.t:
        args[0] += cursorX;
        args[1] += cursorY;
        command = PathDataCommand.T;
      case PathDataCommand.T:
        break;
      case PathDataCommand.a:
        args[5] += cursorX;
        args[6] += cursorY;
        command = PathDataCommand.A;
      case PathDataCommand.A:
        break;
      case PathDataCommand.z:
      case PathDataCommand.Z:
        cursorX = startX;
        cursorY = startY;
        command = PathDataCommand.z;
    }

    // Update cursor position
    if (command == PathDataCommand.M) {
      cursorX = args[0];
      cursorY = args[1];
      startX = cursorX;
      startY = cursorY;
    } else if (command == PathDataCommand.H) {
      cursorX = args[0];
    } else if (command == PathDataCommand.V) {
      cursorY = args[0];
    } else if (command == PathDataCommand.L || command == PathDataCommand.T) {
      cursorX = args[0];
      cursorY = args[1];
    } else if (command == PathDataCommand.C) {
      cursorX = args[4];
      cursorY = args[5];
    } else if (command == PathDataCommand.S || command == PathDataCommand.Q) {
      cursorX = args[2];
      cursorY = args[3];
    } else if (command == PathDataCommand.A) {
      cursorX = args[5];
      cursorY = args[6];
    }

    result.add(PathDataItem(command, args));
  }

  return result;
}

/// Converts absolute path commands to relative coordinates.
///
/// Example:
/// ```dart
/// final absPath = [
///   PathDataItem(PathDataCommand.M, [10, 10]),
///   PathDataItem(PathDataCommand.L, [30, 30]),  // absolute
/// ];
/// final relPath = convertAbsoluteToRelative(absPath);
/// // relPath[1].command == PathDataCommand.l
/// // relPath[1].args == [20, 20]
/// ```
List<PathDataItem> convertAbsoluteToRelative(List<PathDataItem> data) {
  final result = <PathDataItem>[];
  var startX = 0.0;
  var startY = 0.0;
  var cursorX = 0.0;
  var cursorY = 0.0;

  for (var i = 0; i < data.length; i++) {
    final item = data[i];
    var command = item.command;
    final args = List<double>.from(item.args);

    // First moveto should stay absolute
    if (i == 0 &&
        (command == PathDataCommand.M || command == PathDataCommand.m)) {
      if (command == PathDataCommand.m) {
        command = PathDataCommand.M;
      }
      cursorX = args[0];
      cursorY = args[1];
      startX = cursorX;
      startY = cursorY;
      result.add(PathDataItem(command, args));
      continue;
    }

    switch (command) {
      case PathDataCommand.M:
        final relArgs = [args[0] - cursorX, args[1] - cursorY];
        cursorX = args[0];
        cursorY = args[1];
        startX = cursorX;
        startY = cursorY;
        result.add(PathDataItem(PathDataCommand.m, relArgs));
      case PathDataCommand.m:
        cursorX += args[0];
        cursorY += args[1];
        startX = cursorX;
        startY = cursorY;
        result.add(PathDataItem(command, args));
      case PathDataCommand.H:
        final relArgs = [args[0] - cursorX];
        cursorX = args[0];
        result.add(PathDataItem(PathDataCommand.h, relArgs));
      case PathDataCommand.h:
        cursorX += args[0];
        result.add(PathDataItem(command, args));
      case PathDataCommand.V:
        final relArgs = [args[0] - cursorY];
        cursorY = args[0];
        result.add(PathDataItem(PathDataCommand.v, relArgs));
      case PathDataCommand.v:
        cursorY += args[0];
        result.add(PathDataItem(command, args));
      case PathDataCommand.L:
        final relArgs = [args[0] - cursorX, args[1] - cursorY];
        cursorX = args[0];
        cursorY = args[1];
        result.add(PathDataItem(PathDataCommand.l, relArgs));
      case PathDataCommand.l:
        cursorX += args[0];
        cursorY += args[1];
        result.add(PathDataItem(command, args));
      case PathDataCommand.C:
        final relArgs = [
          args[0] - cursorX,
          args[1] - cursorY,
          args[2] - cursorX,
          args[3] - cursorY,
          args[4] - cursorX,
          args[5] - cursorY,
        ];
        cursorX = args[4];
        cursorY = args[5];
        result.add(PathDataItem(PathDataCommand.c, relArgs));
      case PathDataCommand.c:
        cursorX += args[4];
        cursorY += args[5];
        result.add(PathDataItem(command, args));
      case PathDataCommand.S:
        final relArgs = [
          args[0] - cursorX,
          args[1] - cursorY,
          args[2] - cursorX,
          args[3] - cursorY,
        ];
        cursorX = args[2];
        cursorY = args[3];
        result.add(PathDataItem(PathDataCommand.s, relArgs));
      case PathDataCommand.s:
        cursorX += args[2];
        cursorY += args[3];
        result.add(PathDataItem(command, args));
      case PathDataCommand.Q:
        final relArgs = [
          args[0] - cursorX,
          args[1] - cursorY,
          args[2] - cursorX,
          args[3] - cursorY,
        ];
        cursorX = args[2];
        cursorY = args[3];
        result.add(PathDataItem(PathDataCommand.q, relArgs));
      case PathDataCommand.q:
        cursorX += args[2];
        cursorY += args[3];
        result.add(PathDataItem(command, args));
      case PathDataCommand.T:
        final relArgs = [args[0] - cursorX, args[1] - cursorY];
        cursorX = args[0];
        cursorY = args[1];
        result.add(PathDataItem(PathDataCommand.t, relArgs));
      case PathDataCommand.t:
        cursorX += args[0];
        cursorY += args[1];
        result.add(PathDataItem(command, args));
      case PathDataCommand.A:
        final relArgs = [
          args[0], // rx
          args[1], // ry
          args[2], // rotation
          args[3], // large-arc
          args[4], // sweep
          args[5] - cursorX,
          args[6] - cursorY,
        ];
        cursorX = args[5];
        cursorY = args[6];
        result.add(PathDataItem(PathDataCommand.a, relArgs));
      case PathDataCommand.a:
        cursorX += args[5];
        cursorY += args[6];
        result.add(PathDataItem(command, args));
      case PathDataCommand.Z:
      case PathDataCommand.z:
        cursorX = startX;
        cursorY = startY;
        result.add(PathDataItem(PathDataCommand.z, []));
    }
  }

  return result;
}

/// Computes the bounding box of path data.
///
/// Returns null if the path is empty.
BoundingBox? computePathBoundingBox(List<PathDataItem> pathData) {
  if (pathData.isEmpty) return null;

  final absPath = convertRelativeToAbsolute(pathData);
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  var hasPoints = false;

  void addPoint(double x, double y) {
    hasPoints = true;
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }

  var cursorX = 0.0;
  var cursorY = 0.0;

  for (final item in absPath) {
    final args = item.args;

    switch (item.command) {
      case PathDataCommand.M:
        cursorX = args[0];
        cursorY = args[1];
        addPoint(cursorX, cursorY);
      case PathDataCommand.H:
        cursorX = args[0];
        addPoint(cursorX, cursorY);
      case PathDataCommand.V:
        cursorY = args[0];
        addPoint(cursorX, cursorY);
      case PathDataCommand.L:
      case PathDataCommand.T:
        cursorX = args[0];
        cursorY = args[1];
        addPoint(cursorX, cursorY);
      case PathDataCommand.C:
        // Add control points for approximation
        addPoint(args[0], args[1]);
        addPoint(args[2], args[3]);
        cursorX = args[4];
        cursorY = args[5];
        addPoint(cursorX, cursorY);
      case PathDataCommand.S:
        addPoint(args[0], args[1]);
        cursorX = args[2];
        cursorY = args[3];
        addPoint(cursorX, cursorY);
      case PathDataCommand.Q:
        addPoint(args[0], args[1]);
        cursorX = args[2];
        cursorY = args[3];
        addPoint(cursorX, cursorY);
      case PathDataCommand.A:
        // For arcs, include the endpoint
        cursorX = args[5];
        cursorY = args[6];
        addPoint(cursorX, cursorY);
      default:
        break;
    }
  }

  if (!hasPoints) return null;

  return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

// Internal types for intersection detection

class _PointSet {
  final List<List<double>> list;
  int minX;
  int minY;
  int maxX;
  int maxY;

  _PointSet()
      : list = [],
        minX = 0,
        minY = 0,
        maxX = 0,
        maxY = 0;
}

class _Points {
  final List<_PointSet> list;
  double minX;
  double minY;
  double maxX;
  double maxY;

  _Points()
      : list = [],
        minX = 0,
        minY = 0,
        maxX = 0,
        maxY = 0;
}

List<double>? _prevCtrlPoint;

/// Checks if two paths intersect using GJK collision detection algorithm.
///
/// Uses convex hulls and the Gilbert-Johnson-Keerthi distance algorithm.
///
/// @see https://web.archive.org/web/20180822200027/http://entropyinteractive.com/2011/04/gjk-algorithm/
bool pathsIntersect(List<PathDataItem> path1, List<PathDataItem> path2) {
  final points1 = _gatherPoints(convertRelativeToAbsolute(path1));
  final points2 = _gatherPoints(convertRelativeToAbsolute(path2));

  // AABB check
  if (points1.maxX <= points2.minX ||
      points2.maxX <= points1.minX ||
      points1.maxY <= points2.minY ||
      points2.maxY <= points1.minY) {
    return false;
  }

  // Check each subpath pair
  if (points1.list.every((set1) {
    return points2.list.every((set2) {
      return set1.list[set1.maxX][0] <= set2.list[set2.minX][0] ||
          set2.list[set2.maxX][0] <= set1.list[set1.minX][0] ||
          set1.list[set1.maxY][1] <= set2.list[set2.minY][1] ||
          set2.list[set2.maxY][1] <= set1.list[set1.minY][1];
    });
  })) {
    return false;
  }

  // Convex hull collision detection
  final hullNest1 = points1.list.map(_convexHull).toList();
  final hullNest2 = points2.list.map(_convexHull).toList();

  return hullNest1.any((hull1) {
    if (hull1.list.length < 3) return false;

    return hullNest2.any((hull2) {
      if (hull2.list.length < 3) return false;

      final simplex = <List<double>>[
        _getSupport(hull1, hull2, [1.0, 0.0])
      ];
      final direction = _minus(simplex[0]);

      var iterations = 10000;
      while (true) {
        if (--iterations == 0) return true;

        simplex.add(_getSupport(hull1, hull2, direction));
        if (_dot(direction, simplex.last) <= 0) {
          return false;
        }
        if (_processSimplex(simplex, direction)) {
          return true;
        }
      }
    });
  });
}

List<double> _getSupport(_PointSet a, _PointSet b, List<double> direction) {
  return _sub(_supportPoint(a, direction), _supportPoint(b, _minus(direction)));
}

List<double> _supportPoint(_PointSet polygon, List<double> direction) {
  int index;
  if (direction[1] >= 0) {
    index = direction[0] < 0 ? polygon.maxY : polygon.maxX;
  } else {
    index = direction[0] < 0 ? polygon.minX : polygon.minY;
  }

  var max = double.negativeInfinity;
  double value;
  while ((value = _dot(polygon.list[index], direction)) > max) {
    max = value;
    index = (index + 1) % polygon.list.length;
  }
  return polygon.list[(index == 0 ? polygon.list.length : index) - 1];
}

bool _processSimplex(List<List<double>> simplex, List<double> direction) {
  if (simplex.length == 2) {
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
    final a = simplex[2];
    final b = simplex[1];
    final c = simplex[0];
    final ab = _sub(b, a);
    final ac = _sub(c, a);
    final ao = _minus(a);
    final acb = _orth(ab, ac);
    final abc = _orth(ac, ab);

    if (_dot(acb, ao) > 0) {
      if (_dot(ab, ao) > 0) {
        _set(direction, acb);
        simplex.removeAt(0);
      } else {
        _set(direction, ao);
        simplex.removeRange(0, 2);
      }
    } else if (_dot(abc, ao) > 0) {
      if (_dot(ac, ao) > 0) {
        _set(direction, abc);
        simplex.removeAt(1);
      } else {
        _set(direction, ao);
        simplex.removeRange(0, 2);
      }
    } else {
      return true;
    }
  }
  return false;
}

void _set(List<double> dest, List<double> source) {
  dest[0] = source[source.length - 2];
  dest[1] = source[source.length - 1];
}

List<double> _minus(List<double> v) => [-v[0], -v[1]];

List<double> _sub(List<double> v1, List<double> v2) =>
    [v1[0] - v2[0], v1[1] - v2[1]];

double _dot(List<double> v1, List<double> v2) => v1[0] * v2[0] + v1[1] * v2[1];

List<double> _orth(List<double> v, List<double> from) {
  final o = [-v[1], v[0]];
  return _dot(o, _minus(from)) < 0 ? _minus(o) : o;
}

_Points _gatherPoints(List<PathDataItem> pathData) {
  final points = _Points();
  _prevCtrlPoint = null;

  void addPoint(_PointSet path, List<double> point) {
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
    var basePoint = subPath.list.isEmpty ? null : subPath.list.last;
    final data = pathDataItem.args;
    var ctrlPoint = basePoint;

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
                prev.command == PathDataCommand.T) &&
            _prevCtrlPoint != null) {
          ctrlPoint = [
            basePoint[0] + _prevCtrlPoint![0],
            basePoint[1] + _prevCtrlPoint![1],
          ];
          addPoint(subPath, ctrlPoint);
          _prevCtrlPoint = [data[0] - ctrlPoint[0], data[1] - ctrlPoint[1]];
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
                prev.command == PathDataCommand.S) &&
            _prevCtrlPoint != null) {
          addPoint(subPath, [
            basePoint[0] + 0.5 * _prevCtrlPoint![0],
            basePoint[1] + 0.5 * _prevCtrlPoint![1],
          ]);
          ctrlPoint = [
            basePoint[0] + _prevCtrlPoint![0],
            basePoint[1] + _prevCtrlPoint![1],
          ];
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
          final curves = _arcToCubic(
            basePoint[0],
            basePoint[1],
            data[0],
            data[1],
            data[2],
            data[3].toInt(),
            data[4].toInt(),
            data[5],
            data[6],
          );
          var curBase = basePoint;
          for (var j = 0; j < curves.length; j += 6) {
            final cData = [
              curves[j],
              curves[j + 1],
              curves[j + 2],
              curves[j + 3],
              curves[j + 4],
              curves[j + 5],
            ];
            addPoint(subPath, [
              0.5 * (curBase[0] + cData[0]),
              0.5 * (curBase[1] + cData[1]),
            ]);
            addPoint(subPath, [
              0.5 * (cData[0] + cData[2]),
              0.5 * (cData[1] + cData[3]),
            ]);
            addPoint(subPath, [
              0.5 * (cData[2] + cData[4]),
              0.5 * (cData[3] + cData[5]),
            ]);
            curBase = [cData[4], cData[5]];
          }
        }
      default:
        break;
    }

    // Save final point
    if (data.length >= 2) {
      addPoint(subPath, [data[data.length - 2], data[data.length - 1]]);
    }
  }

  return points;
}

_PointSet _convexHull(_PointSet points) {
  points.list.sort((a, b) {
    if (a[0] == b[0]) return a[1].compareTo(b[1]);
    return a[0].compareTo(b[0]);
  });

  final lower = <List<double>>[];
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

  final upper = <List<double>>[];
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

  if (upper.isNotEmpty) upper.removeLast();
  if (lower.isNotEmpty) lower.removeLast();

  final hullList = [...lower, ...upper];

  return _PointSet()
    ..list.addAll(hullList)
    ..minX = 0
    ..maxX = lower.length
    ..minY = bottom
    ..maxY = (lower.length + top) % (hullList.isEmpty ? 1 : hullList.length);
}

double _cross(List<double> o, List<double> a, List<double> b) {
  return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
}

/// Converts an arc to cubic bezier curves.
///
/// Based on Snap.svg implementation (Apache 2 license).
List<double> _arcToCubic(
  double x1,
  double y1,
  double rx,
  double ry,
  double angle,
  int largeArcFlag,
  int sweepFlag,
  double x2,
  double y2, [
  List<double>? recursive,
]) {
  const deg120 = math.pi * 120 / 180;
  final rad = math.pi / 180 * angle;
  final result = <double>[];

  double rotateX(double x, double y, double rad) =>
      x * math.cos(rad) - y * math.sin(rad);
  double rotateY(double x, double y, double rad) =>
      x * math.sin(rad) + y * math.cos(rad);

  double f1, f2, cx, cy;

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

    cx = k * rx * y / ry + (x1 + x2) / 2;
    cy = k * -ry * x / rx + (y1 + y2) / 2;
    f1 = math.asin(double.parse(((y1 - cy) / ry).toStringAsFixed(9)));
    f2 = math.asin(double.parse(((y2 - cy) / ry).toStringAsFixed(9)));

    f1 = x1 < cx ? math.pi - f1 : f1;
    f2 = x2 < cx ? math.pi - f2 : f2;
    if (f1 < 0) f1 = math.pi * 2 + f1;
    if (f2 < 0) f2 = math.pi * 2 + f2;
    if (sweepFlag != 0 && f1 > f2) f1 = f1 - math.pi * 2;
    if (sweepFlag == 0 && f2 > f1) f2 = f2 - math.pi * 2;
  } else {
    f1 = recursive[0];
    f2 = recursive[1];
    cx = recursive[2];
    cy = recursive[3];
  }

  var df = f2 - f1;
  if (df.abs() > deg120) {
    final f2old = f2;
    final x2old = x2;
    final y2old = y2;
    f2 = f1 + deg120 * (sweepFlag != 0 && f2 > f1 ? 1 : -1);
    x2 = cx + rx * math.cos(f2);
    y2 = cy + ry * math.sin(f2);
    result.addAll(_arcToCubic(x2, y2, rx, ry, angle, 0, sweepFlag, x2old, y2old,
        [f2, f2old, cx, cy]));
  }

  df = f2 - f1;
  final c1 = math.cos(f1);
  final s1 = math.sin(f1);
  final c2 = math.cos(f2);
  final s2 = math.sin(f2);
  final t = math.tan(df / 4);
  final hx = 4 / 3 * rx * t;
  final hy = 4 / 3 * ry * t;

  final m = <double>[
    -hx * s1,
    hy * c1,
    x2 + hx * s2 - x1,
    y2 - hy * c2 - y1,
    x2 - x1,
    y2 - y1,
  ];

  if (recursive != null) {
    return [...m, ...result];
  } else {
    final res = [...m, ...result];
    final newres = <double>[];
    for (var i = 0; i < res.length; i++) {
      newres.add(i % 2 != 0
          ? rotateY(res[i - 1], res[i], rad)
          : rotateX(res[i], res[i + 1], rad));
    }
    return newres;
  }
}
