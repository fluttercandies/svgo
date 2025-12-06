/// Optimizes path data: writes in shorter form, applies transformations.
library;

import 'dart:math' as math;

import '../../collections/collections.dart';
import '../../path/path.dart';
import '../../style/style.dart';
import '../../types.dart';
import '../../xast/visitor.dart';
import '../../xast/xast.dart';
import '../plugin.dart';
import 'apply_transforms.dart' as apply_transforms_plugin;

const convertPathData = Plugin(
  name: 'convertPathData',
  description:
      'optimizes path data: writes in shorter form, applies transformations',
  params: {
    'applyTransforms': true,
    'applyTransformsStroked': true,
    'makeArcs': {
      'threshold': 2.5, // coefficient of rounding error
      'tolerance': 0.5, // percentage of radius
    },
    'straightCurves': true,
    'convertToQ': true,
    'lineShorthands': true,
    'convertToZ': true,
    'curveSmoothShorthands': true,
    'floatPrecision': 3,
    'transformPrecision': 5,
    'smartArcRounding': true,
    'removeUseless': true,
    'collapseRepeated': true,
    'utilizeAbsolute': true,
    'leadingZero': true,
    'negativeExtraSpace': true,
    'noSpaceAfterFlags': false,
    'forceAbsolutePath': false,
  },
  fn: _convertPathDataFn,
);

Visitor? _convertPathDataFn(
  XastRoot ast,
  PluginParams params,
  SvgoInfo info,
) {
  // Handle applyTransforms parameter
  final doApplyTransforms = params['applyTransforms'] != false;
  final applyTransformsStroked = params['applyTransformsStroked'] != false;
  final transformPrecision = (params['transformPrecision'] as int?) ?? 5;

  final straightCurves = params['straightCurves'] != false;
  final convertToQ = params['convertToQ'] != false;
  final lineShorthands = params['lineShorthands'] != false;
  final convertToZ = params['convertToZ'] != false;
  final curveSmoothShorthands = params['curveSmoothShorthands'] != false;
  final floatPrecision = (params['floatPrecision'] as int?) ?? 3;
  final removeUseless = params['removeUseless'] != false;
  final collapseRepeated = params['collapseRepeated'] != false;
  final utilizeAbsolute = params['utilizeAbsolute'] != false;
  final leadingZero = params['leadingZero'] != false;
  final negativeExtraSpace = params['negativeExtraSpace'] != false;
  final noSpaceAfterFlags = params['noSpaceAfterFlags'] == true;
  final smartArcRounding = params['smartArcRounding'] != false;
  final forceAbsolutePath = params['forceAbsolutePath'] == true;

  // Parse makeArcs parameters
  final makeArcsParam = params['makeArcs'];
  _MakeArcsConfig? makeArcs;
  if (makeArcsParam != null && makeArcsParam != false) {
    if (makeArcsParam is Map) {
      makeArcs = _MakeArcsConfig(
        threshold: (makeArcsParam['threshold'] as num?)?.toDouble() ?? 2.5,
        tolerance: (makeArcsParam['tolerance'] as num?)?.toDouble() ?? 0.5,
      );
    } else {
      makeArcs = const _MakeArcsConfig(threshold: 2.5, tolerance: 0.5);
    }
  }

  // Match node_svgo: error = +Math.pow(0.1, precision).toFixed(precision)
  // When floatPrecision >= 0, use the formula; otherwise use 1e-2 as default
  final error = floatPrecision >= 0
      ? double.parse(
          math.pow(0.1, floatPrecision).toStringAsFixed(floatPrecision))
      : 1e-2;

  // Invoke applyTransforms plugin before processing paths
  if (doApplyTransforms) {
    final applyTransformsVisitor = apply_transforms_plugin.applyTransforms.fn(
      ast,
      {
        'transformPrecision': transformPrecision,
        'applyTransformsStroked': applyTransformsStroked,
      },
      info,
    );
    if (applyTransformsVisitor != null) {
      _visitAst(ast, applyTransformsVisitor);
    }
  }

  final stylesheet = collectStylesheet(ast);

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        if (!pathElems.contains(node.name)) return null;
        final d = node.attributes['d'];
        if (d == null || d.isEmpty) return null;

        final computedStyle = computeStyle(stylesheet, node);
        final hasMarkerMid = computedStyle['marker-mid'] != null;

        final maybeHasStroke = computedStyle['stroke'] != null &&
            (computedStyle['stroke'] is DynamicStyle ||
                (computedStyle['stroke'] as StaticStyle?)?.value != 'none');
        final maybeHasLinecap = computedStyle['stroke-linecap'] != null &&
            (computedStyle['stroke-linecap'] is DynamicStyle ||
                (computedStyle['stroke-linecap'] as StaticStyle?)?.value !=
                    'butt');
        final maybeHasStrokeAndLinecap = maybeHasStroke && maybeHasLinecap;

        final isSafeToUseZ = maybeHasStroke
            ? (computedStyle['stroke-linecap'] is StaticStyle &&
                    (computedStyle['stroke-linecap'] as StaticStyle).value ==
                        'round') &&
                (computedStyle['stroke-linejoin'] is StaticStyle &&
                    (computedStyle['stroke-linejoin'] as StaticStyle).value ==
                        'round')
            : true;

        try {
          // Use cached pathJS if available (from applyTransforms),
          // otherwise parse from d attribute
          List<PathDataItem> pathData;
          if (node.pathJS != null) {
            pathData = node.pathJS!.cast<PathDataItem>();
            // Clear the cache after use
            node.pathJS = null;
          } else {
            pathData = parsePathData(d);
          }
          if (pathData.isEmpty) return null;

          // Check if original path includes vertices (commands other than M/m)
          final includesVertices = pathData.any((item) =>
              item.command != PathDataCommand.M &&
              item.command != PathDataCommand.m);

          // Remove consecutive moveto commands (keep only the last one)
          // This must be done before convertToRelative to preserve absolute coordinates
          pathData = _removeConsecutiveMoveToCommands(pathData);

          pathData = _convertToRelative(pathData);

          pathData = _filterPathData(
            pathData,
            error: error.toDouble(),
            straightCurves: straightCurves,
            convertToQ: convertToQ,
            lineShorthands: lineShorthands,
            convertToZ: convertToZ && isSafeToUseZ,
            isSafeToUseZ: isSafeToUseZ,
            curveSmoothShorthands: curveSmoothShorthands,
            removeUseless: removeUseless,
            maybeHasStrokeAndLinecap: maybeHasStrokeAndLinecap,
            collapseRepeated: collapseRepeated && !hasMarkerMid,
            floatPrecision: floatPrecision,
            makeArcs: makeArcs,
            smartArcRounding: smartArcRounding,
          );

          if (utilizeAbsolute) {
            pathData = _convertToMixed(
              pathData,
              floatPrecision: floatPrecision,
              leadingZero: leadingZero,
              negativeExtraSpace: negativeExtraSpace,
              forceAbsolutePath: forceAbsolutePath,
            );
          }

          // Handle markers-only path: if path originally had vertices
          // but now only has M/m commands, add z to preserve vertices for markers
          final hasMarker = node.attributes.containsKey('marker-start') ||
              node.attributes.containsKey('marker-end');
          final isMarkersOnlyPath = hasMarker &&
              includesVertices &&
              pathData.every((item) =>
                  item.command == PathDataCommand.M ||
                  item.command == PathDataCommand.m);
          if (isMarkersOnlyPath) {
            pathData = [...pathData, PathDataItem(PathDataCommand.z, [])];
          }

          node.attributes['d'] = stringifyPathData(
            pathData,
            PathStringifyOptions(
              floatPrecision: floatPrecision,
              removeLeadingSpace: true,
              leadingZero: leadingZero,
              useShortArcFlags: noSpaceAfterFlags,
              negativeExtraSpace: negativeExtraSpace,
            ),
          );
        } catch (_) {
          // Keep original path on parse error
        }

        return null;
      },
    ),
  );
}

/// Helper function to visit the AST with a visitor
void _visitAst(XastRoot ast, Visitor visitor) {
  void visitNode(XastNode node, XastParent? parent) {
    if (node is XastElement) {
      visitor.element?.enter?.call(node, parent);
      for (final child in node.children) {
        visitNode(child, node);
      }
      visitor.element?.exit?.call(node, parent);
    } else if (node is XastRoot) {
      visitor.root?.enter?.call(node);
      for (final child in node.children) {
        visitNode(child, node);
      }
      visitor.root?.exit?.call(node);
    }
  }

  visitNode(ast, null);
}

/// Removes consecutive moveto commands, merging their coordinates.
/// For example: M1 1m1 1 -> M2 2
/// This matches node_svgo's js2path behavior.
List<PathDataItem> _removeConsecutiveMoveToCommands(
    List<PathDataItem> pathData) {
  if (pathData.isEmpty) return pathData;

  final result = <PathDataItem>[];
  // Track current position for relative moveto calculations
  var cursorX = 0.0;
  var cursorY = 0.0;
  var startX = 0.0;
  var startY = 0.0;

  for (var i = 0; i < pathData.length; i++) {
    final item = pathData[i];
    final command = item.command;
    final args = item.args;

    if (command == PathDataCommand.M) {
      // Absolute moveto
      cursorX = args[0];
      cursorY = args[1];
      startX = cursorX;
      startY = cursorY;

      // Check if previous was also a moveto
      if (result.isNotEmpty) {
        final last = result.last;
        if (last.command == PathDataCommand.M ||
            last.command == PathDataCommand.m) {
          result.removeLast();
        }
      }
      result.add(PathDataItem(PathDataCommand.M, [cursorX, cursorY]));
    } else if (command == PathDataCommand.m) {
      // Relative moveto
      cursorX += args[0];
      cursorY += args[1];
      startX = cursorX;
      startY = cursorY;

      // Check if previous was also a moveto or Z
      if (result.isNotEmpty) {
        final last = result.last;
        if (last.command == PathDataCommand.M ||
            last.command == PathDataCommand.m) {
          // Merge with previous moveto - convert to absolute M
          result.removeLast();
          result.add(PathDataItem(PathDataCommand.M, [cursorX, cursorY]));
        } else if (last.command == PathDataCommand.Z ||
            last.command == PathDataCommand.z) {
          // After Z, check if Z is immediately preceded by M (no drawing between M and Z)
          // Pattern: M...Z m... where Z follows M directly -> remove Z, merge M
          if (result.length >= 2) {
            final beforeZ = result[result.length - 2];
            if (beforeZ.command == PathDataCommand.M ||
                beforeZ.command == PathDataCommand.m) {
              // M followed by Z means empty subpath, remove both and merge
              result.removeLast(); // Remove Z
              result.removeLast(); // Remove M
              result.add(PathDataItem(PathDataCommand.M, [cursorX, cursorY]));
            } else {
              // Z follows drawing commands, keep Z and add new M
              result.add(PathDataItem(PathDataCommand.M, [cursorX, cursorY]));
            }
          } else {
            // Only Z in result, just add M
            result.add(PathDataItem(PathDataCommand.M, [cursorX, cursorY]));
          }
        } else {
          // Keep as relative m
          result.add(PathDataItem(PathDataCommand.m, [args[0], args[1]]));
        }
      } else {
        // First command - keep as M with absolute coords
        result.add(PathDataItem(PathDataCommand.M, [cursorX, cursorY]));
      }
    } else if (command == PathDataCommand.Z || command == PathDataCommand.z) {
      // Z resets cursor to start position
      cursorX = startX;
      cursorY = startY;
      result.add(item);
    } else {
      // Update cursor based on command
      _updateCursorPosition(command, args, cursorX, cursorY, startX, startY,
          (x, y, sx, sy) {
        cursorX = x;
        cursorY = y;
        startX = sx;
        startY = sy;
      });
      result.add(item);
    }
  }

  return result;
}

/// Helper to update cursor position based on command
void _updateCursorPosition(
  PathDataCommand command,
  List<double> args,
  double cursorX,
  double cursorY,
  double startX,
  double startY,
  void Function(double x, double y, double sx, double sy) update,
) {
  switch (command) {
    case PathDataCommand.H:
      update(args[0], cursorY, startX, startY);
    case PathDataCommand.h:
      update(cursorX + args[0], cursorY, startX, startY);
    case PathDataCommand.V:
      update(cursorX, args[0], startX, startY);
    case PathDataCommand.v:
      update(cursorX, cursorY + args[0], startX, startY);
    case PathDataCommand.L:
      update(args[0], args[1], startX, startY);
    case PathDataCommand.l:
      update(cursorX + args[0], cursorY + args[1], startX, startY);
    case PathDataCommand.C:
      update(args[4], args[5], startX, startY);
    case PathDataCommand.c:
      update(cursorX + args[4], cursorY + args[5], startX, startY);
    case PathDataCommand.S:
    case PathDataCommand.Q:
      update(args[2], args[3], startX, startY);
    case PathDataCommand.s:
    case PathDataCommand.q:
      update(cursorX + args[2], cursorY + args[3], startX, startY);
    case PathDataCommand.T:
      update(args[0], args[1], startX, startY);
    case PathDataCommand.t:
      update(cursorX + args[0], cursorY + args[1], startX, startY);
    case PathDataCommand.A:
      update(args[5], args[6], startX, startY);
    case PathDataCommand.a:
      update(cursorX + args[5], cursorY + args[6], startX, startY);
    default:
      break;
  }
}

List<PathDataItem> _convertToRelative(List<PathDataItem> pathData) {
  final start = [0.0, 0.0];
  final cursor = [0.0, 0.0];
  final result = <PathDataItem>[];
  List<double> prevCoords = [0.0, 0.0];

  for (var i = 0; i < pathData.length; i++) {
    final item = pathData[i];
    var command = item.command;
    final args = List<double>.from(item.args);

    switch (command) {
      case PathDataCommand.m:
        cursor[0] += args[0];
        cursor[1] += args[1];
        start[0] = cursor[0];
        start[1] = cursor[1];
      case PathDataCommand.M:
        if (i != 0) command = PathDataCommand.m;
        args[0] -= cursor[0];
        args[1] -= cursor[1];
        cursor[0] += args[0];
        cursor[1] += args[1];
        start[0] = cursor[0];
        start[1] = cursor[1];
      case PathDataCommand.l:
        cursor[0] += args[0];
        cursor[1] += args[1];
      case PathDataCommand.L:
        command = PathDataCommand.l;
        args[0] -= cursor[0];
        args[1] -= cursor[1];
        cursor[0] += args[0];
        cursor[1] += args[1];
      case PathDataCommand.h:
        cursor[0] += args[0];
      case PathDataCommand.H:
        command = PathDataCommand.h;
        args[0] -= cursor[0];
        cursor[0] += args[0];
      case PathDataCommand.v:
        cursor[1] += args[0];
      case PathDataCommand.V:
        command = PathDataCommand.v;
        args[0] -= cursor[1];
        cursor[1] += args[0];
      case PathDataCommand.c:
        cursor[0] += args[4];
        cursor[1] += args[5];
      case PathDataCommand.C:
        command = PathDataCommand.c;
        for (var j = 0; j < 6; j += 2) {
          args[j] -= cursor[0];
          args[j + 1] -= cursor[1];
        }
        cursor[0] += args[4];
        cursor[1] += args[5];
      case PathDataCommand.s:
        cursor[0] += args[2];
        cursor[1] += args[3];
      case PathDataCommand.S:
        command = PathDataCommand.s;
        for (var j = 0; j < 4; j += 2) {
          args[j] -= cursor[0];
          args[j + 1] -= cursor[1];
        }
        cursor[0] += args[2];
        cursor[1] += args[3];
      case PathDataCommand.q:
        cursor[0] += args[2];
        cursor[1] += args[3];
      case PathDataCommand.Q:
        command = PathDataCommand.q;
        for (var j = 0; j < 4; j += 2) {
          args[j] -= cursor[0];
          args[j + 1] -= cursor[1];
        }
        cursor[0] += args[2];
        cursor[1] += args[3];
      case PathDataCommand.t:
        cursor[0] += args[0];
        cursor[1] += args[1];
      case PathDataCommand.T:
        command = PathDataCommand.t;
        args[0] -= cursor[0];
        args[1] -= cursor[1];
        cursor[0] += args[0];
        cursor[1] += args[1];
      case PathDataCommand.a:
        cursor[0] += args[5];
        cursor[1] += args[6];
      case PathDataCommand.A:
        command = PathDataCommand.a;
        args[5] -= cursor[0];
        args[6] -= cursor[1];
        cursor[0] += args[5];
        cursor[1] += args[6];
      case PathDataCommand.Z:
      case PathDataCommand.z:
        cursor[0] = start[0];
        cursor[1] = start[1];
    }

    final newItem = PathDataItem(command, args);
    // Store absolute coordinates for later use in filters
    // base is the position before this command, coords is position after
    newItem.base = prevCoords;
    newItem.coords = [cursor[0], cursor[1]];
    // prevCoords should reference the same list for next iteration
    prevCoords = newItem.coords!;
    result.add(newItem);
  }

  return result;
}

List<PathDataItem> _filterPathData(
  List<PathDataItem> pathData, {
  required double error,
  required bool straightCurves,
  required bool convertToQ,
  required bool lineShorthands,
  required bool convertToZ,
  required bool isSafeToUseZ,
  required bool curveSmoothShorthands,
  required bool removeUseless,
  required bool maybeHasStrokeAndLinecap,
  required bool collapseRepeated,
  required int floatPrecision,
  required _MakeArcsConfig? makeArcs,
  required bool smartArcRounding,
}) {
  final result = <PathDataItem>[];
  final pathBase = [0.0, 0.0];
  // relSubpoint tracks the rounded relative subpoint position (for accumulating error calculation)
  final relSubpoint = [0.0, 0.0];
  PathDataItem? prev;

  // For tracking quadratic Bézier curve control point (absolute coordinates)
  // Used for t + q → t + t conversion
  List<double>? prevQControlPoint;

  // arcThreshold and arcTolerance for makeArcs
  final arcThreshold = makeArcs?.threshold ?? 2.5;
  final arcTolerance = makeArcs?.tolerance ?? 0.5;

  for (var i = 0; i < pathData.length; i++) {
    final item = pathData[i];
    var command = item.command;
    var args = List<double>.from(item.args);
    // Keep original unrounded args for makeArcs - must be before any rounding
    final originalArgs = List<double>.from(item.args);

    // Use item.base which was set in convertToRelative
    // This is the unrounded absolute position before this command
    final base = item.base ?? [0.0, 0.0];

    if (command != PathDataCommand.Z && command != PathDataCommand.z) {
      // Calculate sdata for 's' command (convert shorthand to longhand form)
      // Only valid if previous command is 'c' or 's'
      List<double>? sdata;
      final prevIsCubic = prev != null &&
          (prev.command == PathDataCommand.c ||
              prev.command == PathDataCommand.s ||
              prev.command == PathDataCommand.C ||
              prev.command == PathDataCommand.S);

      if (command == PathDataCommand.s && prevIsCubic) {
        final pdata = prev.args;
        final n = pdata.length;
        // (-x, -y) of the prev tangent point relative to the current point
        sdata = [
          pdata[n - 2] - pdata[n - 4],
          pdata[n - 1] - pdata[n - 3],
          ...args,
        ];
      } else if (command == PathDataCommand.s) {
        // s without preceding c/s uses (0,0) as first control point
        sdata = [0, 0, ...args];
      }

      // makeArcs: convert cubic curves to arcs
      // This must be done BEFORE straightCurves and convertToQ to match node_svgo behavior
      // This matches node_svgo's approach: check current curve, then look
      // forward/backward to find consecutive curves on the same arc
      if (makeArcs != null &&
          (item.command == PathDataCommand.c ||
              item.command == PathDataCommand.s)) {
        // Get sdata (longhand curve data) - use originalArgs (unrounded) like node_svgo
        List<double> makeArcsSdata;
        if (item.command == PathDataCommand.s && prev != null) {
          // For prev.args, we need the original unrounded args
          // If prev has sdata, use that; otherwise use prev.args
          final pdata = prev.sdata ?? prev.args;
          final n = pdata.length;
          // Need at least 4 values to calculate the reflection (control point of cubic curve)
          if (n < 4) {
            // Previous command doesn't have enough data for s curve reflection
            // This can happen if previous curve was converted to a line
            // In this case, first control point is (0,0) relative to current position
            makeArcsSdata = [0, 0, ...originalArgs];
          } else {
            makeArcsSdata = [
              pdata[n - 2] - pdata[n - 4],
              pdata[n - 1] - pdata[n - 3],
              ...originalArgs,
            ];
          }
        } else if (item.command == PathDataCommand.c) {
          makeArcsSdata = originalArgs;
        } else {
          makeArcsSdata = [0, 0, ...originalArgs];
        }

        // Check if this curve can form an arc
        if (_isConvex(makeArcsSdata)) {
          final circle =
              _findCircle(makeArcsSdata, arcThreshold, arcTolerance, error);
          if (circle != null) {
            // Found a circle, try to build an arc
            final arcResult = _convertCurvesToArc(
              pathData: pathData,
              currentIndex: i,
              sdata: makeArcsSdata,
              circle: circle,
              item: item,
              prev: prev,
              arcThreshold: arcThreshold,
              arcTolerance: arcTolerance,
              error: error,
              floatPrecision: floatPrecision,
              smartArcRounding: smartArcRounding,
            );

            if (arcResult != null) {
              // Check if arc representation is shorter than curves
              // Add suffix for 's' commands that couldn't merge (like Node.js)
              final arcString =
                  _stringifyPathItems(arcResult.arcs, floatPrecision) +
                      arcResult.suffix;
              final curvesString =
                  _stringifyPathItems(arcResult.curves, floatPrecision);

              if (arcString.length < curvesString.length) {
                // Apply smartArcRounding to all arcs after the string comparison
                // This matches Node.js behavior where smartArcRounding is applied
                // after the arc is accepted
                for (final arc in arcResult.arcs) {
                  _applySmartArcRounding(
                      arc.args, floatPrecision, error, smartArcRounding);
                }

                // Like Node.js, apply straightCurves check to each arc
                // This converts arcs with small sagitta to lines
                if (straightCurves) {
                  for (var arcIdx = 0;
                      arcIdx < arcResult.arcs.length;
                      arcIdx++) {
                    final arc = arcResult.arcs[arcIdx];
                    bool convertedToLine = false;
                    double roundedCoordsX = 0;
                    double roundedCoordsY = 0;

                    if (arc.args[0] == 0 || arc.args[1] == 0) {
                      arc.command = PathDataCommand.l;
                      convertedToLine = true;
                      // Calculate rounded base and coords
                      final roundedBaseX = _round(arc.base![0], floatPrecision);
                      final roundedBaseY = _round(arc.base![1], floatPrecision);
                      roundedCoordsX = _round(arc.coords![0], floatPrecision);
                      roundedCoordsY = _round(arc.coords![1], floatPrecision);
                      // args = roundedCoords - roundedBase
                      // This ensures roundedBase + args = roundedCoords in _convertToMixed
                      arc.args = [
                        roundedCoordsX - roundedBaseX,
                        roundedCoordsY - roundedBaseY,
                      ];
                      arc.base = [roundedBaseX, roundedBaseY];
                      arc.coords = [roundedCoordsX, roundedCoordsY];
                    } else {
                      final sagitta = _calculateSagitta(arc.args, error);
                      if (sagitta != null && sagitta < error) {
                        arc.command = PathDataCommand.l;
                        convertedToLine = true;
                        // Calculate rounded base and coords
                        final roundedBaseX =
                            _round(arc.base![0], floatPrecision);
                        final roundedBaseY =
                            _round(arc.base![1], floatPrecision);
                        roundedCoordsX = _round(arc.coords![0], floatPrecision);
                        roundedCoordsY = _round(arc.coords![1], floatPrecision);
                        // args = roundedCoords - roundedBase
                        arc.args = [
                          roundedCoordsX - roundedBaseX,
                          roundedCoordsY - roundedBaseY,
                        ];
                        arc.base = [roundedBaseX, roundedBaseY];
                        arc.coords = [roundedCoordsX, roundedCoordsY];
                      } else {
                        // Arc not converted, but still round coords for subsequent arcs
                        roundedCoordsX = _round(arc.coords![0], floatPrecision);
                        roundedCoordsY = _round(arc.coords![1], floatPrecision);
                      }
                    }

                    // Update subsequent arc's base to this arc's new coords
                    // This is critical when an arc is converted to a line
                    if (convertedToLine && arcIdx + 1 < arcResult.arcs.length) {
                      final nextArc = arcResult.arcs[arcIdx + 1];
                      nextArc.base = [roundedCoordsX, roundedCoordsY];
                    }
                  }
                }

                // Apply lineShorthands to converted lines
                // This must be done after straightCurves since arcs were just converted
                if (lineShorthands) {
                  for (final arc in arcResult.arcs) {
                    if (arc.command == PathDataCommand.l) {
                      if (arc.args[1] == 0) {
                        arc.command = PathDataCommand.h;
                        arc.args = [arc.args[0]];
                      } else if (arc.args[0] == 0) {
                        arc.command = PathDataCommand.v;
                        arc.args = [arc.args[1]];
                      }
                    }
                  }
                }

                // Use arc instead of curves
                // Update prev if it was consumed
                if (arcResult.consumedPrev && result.isNotEmpty) {
                  result.removeLast();
                  // Update relSubpoint for consumed prev
                  // The prev item is being replaced, adjust relSubpoint
                  if (prev != null) {
                    final prevEndX = prev.args.length >= 2
                        ? prev.args[prev.args.length - 2]
                        : 0.0;
                    final prevEndY = prev.args.isNotEmpty
                        ? prev.args[prev.args.length - 1]
                        : 0.0;
                    relSubpoint[0] -= prevEndX;
                    relSubpoint[1] -= prevEndY;
                  }

                  // Use the first arc item as the new prev
                  if (arcResult.arcs.isNotEmpty) {
                    final firstArc = arcResult.arcs[0];
                    result.add(firstArc);
                    prev = firstArc;
                    // Only store sdata if arc contains exactly one curve (like Node.js)
                    // AND the arc was not converted to a line (command is still 'a')
                    // This prevents incorrect arc joining when multiple curves were merged
                    if (arcResult.curves.length == 1 &&
                        prev.command == PathDataCommand.a) {
                      prev.sdata = makeArcsSdata;
                    }
                    // Update relSubpoint with the arc's endpoint
                    // Handle h/v commands which have only 1 arg
                    if (firstArc.command == PathDataCommand.h) {
                      relSubpoint[0] += firstArc.args[0];
                    } else if (firstArc.command == PathDataCommand.v) {
                      relSubpoint[1] += firstArc.args[0];
                    } else {
                      relSubpoint[0] += firstArc.args[firstArc.args.length - 2];
                      relSubpoint[1] += firstArc.args[firstArc.args.length - 1];
                    }
                    // Add remaining arcs
                    for (var j = 1; j < arcResult.arcs.length; j++) {
                      result.add(arcResult.arcs[j]);
                      prev = arcResult.arcs[j];
                      // Handle h/v commands which have only 1 arg
                      if (prev.command == PathDataCommand.h) {
                        relSubpoint[0] += prev.args[0];
                      } else if (prev.command == PathDataCommand.v) {
                        relSubpoint[1] += prev.args[0];
                      } else {
                        relSubpoint[0] += prev.args[prev.args.length - 2];
                        relSubpoint[1] += prev.args[prev.args.length - 1];
                      }
                    }
                  }
                } else {
                  // Add all arcs to result
                  for (final arc in arcResult.arcs) {
                    result.add(arc);
                    prev = arc;
                    // Only store sdata if arc contains exactly one curve (like Node.js)
                    // AND the arc was not converted to a line
                    if (arcResult.curves.length == 1 &&
                        prev.command == PathDataCommand.a) {
                      prev.sdata = makeArcsSdata;
                    }
                  }
                  // Update relSubpoint with the arc's endpoint
                  if (arcResult.arcs.isNotEmpty) {
                    final lastArc = arcResult.arcs.last;
                    // Handle h/v commands which have only 1 arg
                    if (lastArc.command == PathDataCommand.h) {
                      relSubpoint[0] += lastArc.args[0];
                    } else if (lastArc.command == PathDataCommand.v) {
                      relSubpoint[1] += lastArc.args[0];
                    } else {
                      relSubpoint[0] += lastArc.args[lastArc.args.length - 2];
                      relSubpoint[1] += lastArc.args[lastArc.args.length - 1];
                    }
                  }
                }

                // Skip consumed items
                if (arcResult.consumedCount > 0) {
                  i += arcResult.consumedCount;
                }

                // Update next item's base to the last arc's rounded coords
                // This is critical for correct coordinate calculation when
                // the arc was converted to a line with rounded coords
                if (prev != null &&
                    prev.coords != null &&
                    i + 1 < pathData.length) {
                  final lastCoords = prev.coords!;
                  // Round the coords
                  final roundedX = _round(lastCoords[0], floatPrecision);
                  final roundedY = _round(lastCoords[1], floatPrecision);
                  // Update next item's base
                  pathData[i + 1].base = [roundedX, roundedY];
                }

                // Fix up next 's' command if we consumed any items
                if (i + 1 < pathData.length &&
                    pathData[i + 1].command == PathDataCommand.s &&
                    prev != null) {
                  _makeLonghandInPlace(pathData, i + 1, prev.args);
                }

                continue; // Skip normal item add since we added arcs
              }
            }
          }
        }
      }

      // Convert straight curves into lines
      if (straightCurves) {
        if ((command == PathDataCommand.c &&
                _isCurveStraightLine(args, error)) ||
            (command == PathDataCommand.s &&
                sdata != null &&
                _isCurveStraightLine(sdata, error))) {
          // Fix up next curve if it's an 's' command
          if (i + 1 < pathData.length &&
              pathData[i + 1].command == PathDataCommand.s) {
            _makeLonghandInPlace(pathData, i + 1, args);
          }
          command = PathDataCommand.l;
          args = args.sublist(args.length - 2);
        } else if (command == PathDataCommand.q &&
            _isCurveStraightLine(args, error)) {
          // Fix up next curve if it's a 't' command
          if (i + 1 < pathData.length &&
              pathData[i + 1].command == PathDataCommand.t) {
            _makeLonghandInPlace(pathData, i + 1, args);
          }
          command = PathDataCommand.l;
          args = args.sublist(2);
        } else if (command == PathDataCommand.t &&
            prev != null &&
            prev.command != PathDataCommand.q &&
            prev.command != PathDataCommand.t) {
          // t without a preceding q or t is a straight line
          command = PathDataCommand.l;
          args = args.sublist(args.length - 2);
        } else if (command == PathDataCommand.a) {
          // Convert arc to line if rx or ry is 0, or sagitta is small enough
          if (args[0] == 0 || args[1] == 0) {
            command = PathDataCommand.l;
            args = args.sublist(5);
          } else {
            final sagitta = _calculateSagitta(args, error);
            if (sagitta != null && sagitta < error) {
              command = PathDataCommand.l;
              args = args.sublist(5);
            }
          }
        }
      }

      // Rounding relative coordinates, taking into account accumulating error
      // to get closer to absolute coordinates. Sum of rounded values remains same:
      // l .25 3 .25 2 .25 3 .25 2 -> l .3 3 .2 2 .3 3 .2 2
      // Note: floatPrecision >= 0 (including 0) triggers rounding, matching node_svgo
      if (floatPrecision >= 0) {
        if (command == PathDataCommand.m ||
            command == PathDataCommand.l ||
            command == PathDataCommand.t ||
            command == PathDataCommand.q ||
            command == PathDataCommand.s ||
            command == PathDataCommand.c) {
          // Adjust args based on difference between unrounded base and rounded relSubpoint
          for (var j = args.length; j-- > 0;) {
            args[j] += base[j % 2] - relSubpoint[j % 2];
          }
        } else if (command == PathDataCommand.h) {
          args[0] += base[0] - relSubpoint[0];
        } else if (command == PathDataCommand.v) {
          args[0] += base[1] - relSubpoint[1];
        } else if (command == PathDataCommand.a) {
          args[5] += base[0] - relSubpoint[0];
          args[6] += base[1] - relSubpoint[1];
        }

        // Round args using strongRound
        _strongRound(args, floatPrecision, error);

        // Smart arc radius rounding
        // eg m 0 0 a 1234.567 1234.567 0 0 1 10 0 -> m 0 0 a 1235 1235 0 0 1 10 0
        if (smartArcRounding && command == PathDataCommand.a) {
          final sagitta = _calculateSagitta(args, error);
          if (sagitta != null) {
            for (var precisionNew = floatPrecision;
                precisionNew >= 0;
                precisionNew--) {
              final radius = _round(args[0], precisionNew);
              final sagittaNew = _calculateSagitta(
                [radius, radius, ...args.sublist(2)],
                error,
              );
              if (sagittaNew != null && (sagitta - sagittaNew).abs() < error) {
                args[0] = radius;
                args[1] = radius;
              } else {
                break;
              }
            }
          }
        }

        // Update relSubpoint based on rounded values
        if (command == PathDataCommand.h) {
          relSubpoint[0] += args[0];
        } else if (command == PathDataCommand.v) {
          relSubpoint[1] += args[0];
        } else if (command != PathDataCommand.a) {
          relSubpoint[0] += args[args.length - 2];
          relSubpoint[1] += args[args.length - 1];
        } else {
          relSubpoint[0] += args[5];
          relSubpoint[1] += args[6];
        }

        // Round relSubpoint using strongRound
        _strongRound(relSubpoint, floatPrecision, error);

        // Update pathBase for moveto
        if (command == PathDataCommand.M || command == PathDataCommand.m) {
          pathBase[0] = relSubpoint[0];
          pathBase[1] = relSubpoint[1];
        }
      } else {
        // No precision rounding, just update relSubpoint normally
        _updateRelSubpoint(command, args, relSubpoint, pathBase);
      }

      // Degree-lower cubic bezier to quadratic when possible
      // m 0 12 C 4 4 8 4 12 12 → M 0 12 Q 6 0 12 12
      if (convertToQ && command == PathDataCommand.c) {
        // Calculate if cubic can be represented as quadratic
        // For a cubic curve, the control points of an equivalent quadratic
        // can be computed. If they match within error, we can use quadratic.
        // Use base directly (absolute coordinates of current point)
        // This matches node_svgo which uses item.base directly
        final baseX = base[0];
        final baseY = base[1];

        // x1 = 0.75 * (base[0] + data[0]) - 0.25 * base[0]
        final x1 = 0.75 * (baseX + args[0]) - 0.25 * baseX;
        // x2 = 0.75 * (base[0] + data[2]) - 0.25 * (base[0] + data[4])
        final x2 = 0.75 * (baseX + args[2]) - 0.25 * (baseX + args[4]);

        if ((x1 - x2).abs() < error * 2) {
          final y1 = 0.75 * (baseY + args[1]) - 0.25 * baseY;
          final y2 = 0.75 * (baseY + args[3]) - 0.25 * (baseY + args[5]);

          if ((y1 - y2).abs() < error * 2) {
            // Calculate new quadratic control point
            final newQx = x1 + x2 - baseX;
            final newQy = y1 + y2 - baseY;
            final newArgs = [newQx, newQy, args[4], args[5]];

            // Round if needed
            if (floatPrecision > 0) {
              for (var j = 0; j < newArgs.length; j++) {
                newArgs[j] = _round(newArgs[j], floatPrecision);
              }
            }

            // Check if quadratic is shorter
            final originalLength = _cleanupOutDataLength(args, floatPrecision);
            final newLength = _cleanupOutDataLength(newArgs, floatPrecision);

            if (newLength < originalLength) {
              command = PathDataCommand.q;
              args = newArgs;

              // Fix up next curve if it's an 's' command
              if (i + 1 < pathData.length &&
                  pathData[i + 1].command == PathDataCommand.s) {
                // Convert s to c (make longhand)
                final nextItem = pathData[i + 1];
                final nextArgs = List<double>.from(nextItem.args);
                // The first control point of 's' is reflection of previous
                // second control point. For quadratic, recalculate.
                final cx = args[2] - args[0];
                final cy = args[3] - args[1];
                final newItem = PathDataItem(
                  PathDataCommand.c,
                  [cx, cy, ...nextArgs],
                );
                // Preserve base from original s command for accurate convertToQ check
                newItem.base = nextItem.base;
                pathData[i + 1] = newItem;
              }
            }
          }
        }
      }

      // Line shorthands: l 50 0 -> h 50, l 0 50 -> v 50
      if (lineShorthands && command == PathDataCommand.l) {
        if (args[1] == 0) {
          command = PathDataCommand.h;
          args = [args[0]];
        } else if (args[0] == 0) {
          command = PathDataCommand.v;
          args = [args[1]];
        }
      }

      // Collapse repeated commands: h 20 h 30 -> h 50
      if (collapseRepeated && prev != null) {
        final prevCmd = prev.command;
        if ((command == PathDataCommand.m && prevCmd == PathDataCommand.m) ||
            (command == PathDataCommand.M && prevCmd == PathDataCommand.m)) {
          final newArgs = [prev.args[0] + args[0], prev.args[1] + args[1]];
          result[result.length - 1] = PathDataItem(prev.command, newArgs);
          prev = result.last;
          continue;
        } else if ((command == PathDataCommand.h ||
                command == PathDataCommand.v) &&
            command == prevCmd &&
            (prev.args[0] >= 0) == (args[0] >= 0)) {
          final newArgs = [prev.args[0] + args[0]];
          result[result.length - 1] = PathDataItem(prev.command, newArgs);
          prev = result.last;
          continue;
        }
      }

      // Convert curves to smooth shorthands
      if (curveSmoothShorthands && prev != null) {
        if (command == PathDataCommand.c && prev.command == PathDataCommand.c) {
          // c + c → c + s
          final px = prev.args;
          if ((args[0] - (-(px[2] - px[4]))).abs() < error &&
              (args[1] - (-(px[3] - px[5]))).abs() < error) {
            command = PathDataCommand.s;
            args = args.sublist(2);
          }
        } else if (command == PathDataCommand.c &&
            prev.command == PathDataCommand.s) {
          // s + c → s + s
          final px = prev.args;
          if ((args[0] - (-(px[0] - px[2]))).abs() < error &&
              (args[1] - (-(px[1] - px[3]))).abs() < error) {
            command = PathDataCommand.s;
            args = args.sublist(2);
          }
        } else if (command == PathDataCommand.c &&
            prev.command != PathDataCommand.c &&
            prev.command != PathDataCommand.s) {
          // [^cs] + c → [^cs] + s (if first control point is near origin)
          if (args[0].abs() < error && args[1].abs() < error) {
            command = PathDataCommand.s;
            args = args.sublist(2);
          }
        } else if (command == PathDataCommand.q &&
            prev.command == PathDataCommand.q) {
          // q + q → q + t
          final px = prev.args;
          if ((args[0] - (px[2] - px[0])).abs() < error &&
              (args[1] - (px[3] - px[1])).abs() < error) {
            command = PathDataCommand.t;
            args = args.sublist(2);
          }
        } else if (command == PathDataCommand.q &&
            prev.command == PathDataCommand.t &&
            prevQControlPoint != null) {
          // t + q → t + t (if first control point is reflection)
          // Calculate the predicted control point by reflecting prevQControlPoint over base
          final predictedControlPoint = [
            2 * base[0] - prevQControlPoint[0],
            2 * base[1] - prevQControlPoint[1],
          ];
          // The actual control point in absolute coords
          final realControlPoint = [
            args[0] + base[0],
            args[1] + base[1],
          ];
          if ((predictedControlPoint[0] - realControlPoint[0]).abs() < error &&
              (predictedControlPoint[1] - realControlPoint[1]).abs() < error) {
            command = PathDataCommand.t;
            args = args.sublist(2);
          }
        } else if (command == PathDataCommand.q &&
            prev.command != PathDataCommand.q &&
            prev.command != PathDataCommand.t) {
          // [^qt] + q → [^qt] + t (if first control point is near origin)
          if (args[0].abs() < error && args[1].abs() < error) {
            command = PathDataCommand.t;
            args = args.sublist(2);
          }
        }
      }

      // Remove useless path segments: l 0,0 / h 0 / v 0
      // Only when !maybeHasStrokeAndLinecap to preserve visual appearance of strokes
      if (removeUseless && !maybeHasStrokeAndLinecap) {
        if ((command == PathDataCommand.l ||
                command == PathDataCommand.h ||
                command == PathDataCommand.v ||
                command == PathDataCommand.q ||
                command == PathDataCommand.t ||
                command == PathDataCommand.c ||
                command == PathDataCommand.s) &&
            args.every((v) => v == 0)) {
          continue;
        }
        if (command == PathDataCommand.a && args[5] == 0 && args[6] == 0) {
          continue;
        }
      }

      // Convert going home to z
      // m 0 0 h 5 v 5 l -5 -5 -> m 0 0 h 5 v 5 z
      // Also convert if next command is z (even if isSafeToUseZ is false)
      // Note: relSubpoint has already been updated by this point to reflect
      // the position after executing this command
      final nextIsZ = i + 1 < pathData.length &&
          (pathData[i + 1].command == PathDataCommand.z ||
              pathData[i + 1].command == PathDataCommand.Z);
      if ((convertToZ || nextIsZ) &&
          (command == PathDataCommand.l ||
              command == PathDataCommand.h ||
              command == PathDataCommand.v)) {
        // Check if the endpoint (relSubpoint) is at the path start (going home)
        if ((pathBase[0] - relSubpoint[0]).abs() < error &&
            (pathBase[1] - relSubpoint[1]).abs() < error) {
          command = PathDataCommand.z;
          args = [];
        }
      }
    } else {
      // Handle z command: update relSubpoint to match pathBase
      relSubpoint[0] = pathBase[0];
      relSubpoint[1] = pathBase[1];

      // Remove duplicate z
      if (prev != null &&
          (prev.command == PathDataCommand.Z ||
              prev.command == PathDataCommand.z)) {
        continue;
      }

      // Remove useless z: if we're already at the path base, z does nothing
      // Only remove if isSafeToUseZ is true (to preserve z for stroke rendering)
      // Note: This check uses the original removeUseless setting, not the
      // maybeHasStrokeAndLinecap-modified one (that's only for l/h/v/q/t/c/s/a)
      if (removeUseless &&
          isSafeToUseZ &&
          (base[0] - pathBase[0]).abs() < error / 10 &&
          (base[1] - pathBase[1]).abs() < error / 10) {
        continue;
      }
    }

    final newItem = PathDataItem(command, args)
      ..base = item.base
      ..coords = item.coords;
    result.add(newItem);
    prev = newItem;

    // Update prevQControlPoint for quadratic Bézier curve tracking
    if (command == PathDataCommand.q || command == PathDataCommand.Q) {
      // For q: control point = base + args[0,1]
      prevQControlPoint = [args[0] + base[0], args[1] + base[1]];
    } else if (command == PathDataCommand.t || command == PathDataCommand.T) {
      if (prevQControlPoint != null) {
        // Reflect the previous control point over the current base
        prevQControlPoint = [
          2 * base[0] - prevQControlPoint[0],
          2 * base[1] - prevQControlPoint[1],
        ];
      } else {
        // No previous control point, use the current endpoint (item.coords)
        final coords = item.coords ?? [0.0, 0.0];
        prevQControlPoint = [coords[0], coords[1]];
      }
    } else {
      // Reset for non-quadratic commands
      prevQControlPoint = null;
    }
  }

  return result;
}

void _updateCursor(
  PathDataCommand command,
  List<double> args,
  List<double> cursor,
  List<double> pathBase,
) {
  switch (command) {
    case PathDataCommand.M:
      cursor[0] = args[0];
      cursor[1] = args[1];
      pathBase[0] = cursor[0];
      pathBase[1] = cursor[1];
    case PathDataCommand.m:
      cursor[0] += args[0];
      cursor[1] += args[1];
      pathBase[0] = cursor[0];
      pathBase[1] = cursor[1];
    case PathDataCommand.L:
    case PathDataCommand.T:
      cursor[0] = args[0];
      cursor[1] = args[1];
    case PathDataCommand.l:
    case PathDataCommand.t:
      cursor[0] += args[0];
      cursor[1] += args[1];
    case PathDataCommand.H:
      cursor[0] = args[0];
    case PathDataCommand.h:
      cursor[0] += args[0];
    case PathDataCommand.V:
      cursor[1] = args[0];
    case PathDataCommand.v:
      cursor[1] += args[0];
    case PathDataCommand.C:
      cursor[0] = args[4];
      cursor[1] = args[5];
    case PathDataCommand.c:
      cursor[0] += args[4];
      cursor[1] += args[5];
    case PathDataCommand.S:
    case PathDataCommand.Q:
      cursor[0] = args[2];
      cursor[1] = args[3];
    case PathDataCommand.s:
    case PathDataCommand.q:
      cursor[0] += args[2];
      cursor[1] += args[3];
    case PathDataCommand.A:
      cursor[0] = args[5];
      cursor[1] = args[6];
    case PathDataCommand.a:
      cursor[0] += args[5];
      cursor[1] += args[6];
    case PathDataCommand.z:
    case PathDataCommand.Z:
      cursor[0] = pathBase[0];
      cursor[1] = pathBase[1];
  }
}

/// Update relative subpoint position (for accumulating error handling).
/// Only handles relative commands since the path is already relative at this point.
void _updateRelSubpoint(
  PathDataCommand command,
  List<double> args,
  List<double> relSubpoint,
  List<double> pathBase,
) {
  switch (command) {
    case PathDataCommand.M:
    case PathDataCommand.m:
      relSubpoint[0] += args[0];
      relSubpoint[1] += args[1];
      pathBase[0] = relSubpoint[0];
      pathBase[1] = relSubpoint[1];
    case PathDataCommand.L:
    case PathDataCommand.l:
    case PathDataCommand.T:
    case PathDataCommand.t:
      relSubpoint[0] += args[0];
      relSubpoint[1] += args[1];
    case PathDataCommand.H:
    case PathDataCommand.h:
      relSubpoint[0] += args[0];
    case PathDataCommand.V:
    case PathDataCommand.v:
      relSubpoint[1] += args[0];
    case PathDataCommand.C:
    case PathDataCommand.c:
      relSubpoint[0] += args[4];
      relSubpoint[1] += args[5];
    case PathDataCommand.S:
    case PathDataCommand.s:
    case PathDataCommand.Q:
    case PathDataCommand.q:
      relSubpoint[0] += args[2];
      relSubpoint[1] += args[3];
    case PathDataCommand.A:
    case PathDataCommand.a:
      relSubpoint[0] += args[5];
      relSubpoint[1] += args[6];
    case PathDataCommand.z:
    case PathDataCommand.Z:
      relSubpoint[0] = pathBase[0];
      relSubpoint[1] = pathBase[1];
  }
}

bool _isCurveStraightLine(List<double> data, double error) {
  final i = data.length - 2;
  if (i <= 1) return false;

  final a = -data[i + 1];
  final b = data[i];
  final d = 1 / (a * a + b * b);

  if (!d.isFinite) return false;

  for (var j = i - 2; j >= 0; j -= 2) {
    if (math.sqrt(math.pow(a * data[j] + b * data[j + 1], 2) * d) > error) {
      return false;
    }
  }

  return true;
}

/// Estimate the string length of path data for comparison.
int _cleanupOutDataLength(List<double> data, int precision) {
  var length = 0;
  for (final value in data) {
    final rounded = _round(value, precision);
    var str = rounded.toString();
    // Remove trailing zeros after decimal point
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    // Remove leading zero
    if (str.startsWith('0.')) {
      str = str.substring(1);
    } else if (str.startsWith('-0.')) {
      str = '-${str.substring(2)}';
    }
    length += str.length + 1; // +1 for separator
  }
  return length;
}

List<PathDataItem> _convertToMixed(
  List<PathDataItem> pathData, {
  required int floatPrecision,
  required bool leadingZero,
  required bool negativeExtraSpace,
  required bool forceAbsolutePath,
}) {
  final result = <PathDataItem>[];
  final cursor = [0.0, 0.0];
  final pathBase = [0.0, 0.0];
  // Calculate error threshold for strongRound
  final error = floatPrecision > 0
      ? double.parse(
          math.pow(0.1, floatPrecision).toStringAsFixed(floatPrecision))
      : 0.01;

  // Special case: single moveto command - prefer absolute form
  if (pathData.length == 1 &&
      (pathData[0].command == PathDataCommand.m ||
          pathData[0].command == PathDataCommand.M)) {
    final item = pathData[0];
    final args = item.args;
    // For single moveto at origin, M and m have same length, prefer M
    if (forceAbsolutePath || item.command == PathDataCommand.m) {
      final roundedArgs = args.map((v) => _round(v, floatPrecision)).toList();
      return [PathDataItem(PathDataCommand.M, roundedArgs)];
    }
    return pathData;
  }

  for (var i = 0; i < pathData.length; i++) {
    final item = pathData[i];
    var command = item.command;
    final args = List<double>.from(item.args);

    if (i == 0) {
      result.add(item);
      _updateCursor(command, args, cursor, pathBase);
      continue;
    }

    if (command == PathDataCommand.Z || command == PathDataCommand.z) {
      result.add(item);
      cursor[0] = pathBase[0];
      cursor[1] = pathBase[1];
      continue;
    }

    // Use item.base from convertToRelative for accurate absolute coordinate calculation
    // item.base contains the un-rounded absolute coordinates before this command
    final base = item.base ?? cursor;

    // Calculate absolute coordinates using item.base
    // base[i % 2] means: even indices (0,2,4) use base[0] (x), odd indices (1,3,5) use base[1] (y)
    final absArgs = List<double>.from(args);
    if (command == PathDataCommand.m ||
        command == PathDataCommand.l ||
        command == PathDataCommand.t ||
        command == PathDataCommand.q ||
        command == PathDataCommand.s ||
        command == PathDataCommand.c) {
      for (var j = 0; j < absArgs.length; j++) {
        absArgs[j] += base[j % 2];
      }
    } else if (command == PathDataCommand.h) {
      absArgs[0] += base[0];
    } else if (command == PathDataCommand.v) {
      absArgs[0] += base[1];
    } else if (command == PathDataCommand.a) {
      absArgs[5] += base[0];
      absArgs[6] += base[1];
    }

    // Round both sets using strongRound for precision optimization
    final roundedRel =
        _strongRound(List<double>.from(args), floatPrecision, error);
    final roundedAbs = _strongRound(absArgs, floatPrecision, error);

    // Compare string lengths
    final relStr = _stringifyArgs(roundedRel, leadingZero, negativeExtraSpace);
    final absStr = _stringifyArgs(roundedAbs, leadingZero, negativeExtraSpace);

    // Check if relative command can be merged with previous (negative space saving)
    // Don't convert to absolute if it fits following previous command
    // e.g., l20 30-10-50 instead of l20 30L20 30
    final prevItem = result.isNotEmpty ? result.last : null;
    final canMergeWithPrevious = negativeExtraSpace &&
        prevItem != null &&
        command == prevItem.command &&
        command.isRelative &&
        absStr.length == relStr.length - 1 &&
        (roundedRel.isNotEmpty &&
            (roundedRel[0] < 0 ||
                (roundedRel[0].truncate() == 0 &&
                    roundedRel[0] != roundedRel[0].truncateToDouble() &&
                    prevItem.args.isNotEmpty &&
                    prevItem.args.last !=
                        prevItem.args.last.truncateToDouble())));

    // Convert to absolute if shorter or forceAbsolutePath is true
    // But don't convert if it can merge with previous command
    if (forceAbsolutePath ||
        (absStr.length < relStr.length && !canMergeWithPrevious)) {
      result.add(PathDataItem(command.toAbsolute, roundedAbs));
    } else {
      result.add(PathDataItem(command, roundedRel));
    }

    _updateCursor(command, args, cursor, pathBase);
  }

  return result;
}

double _round(double value, int precision) {
  if (precision < 0) return value;
  final multiplier = math.pow(10, precision);
  return (value * multiplier).roundToDouble() / multiplier;
}

/// Smart rounding that tries to reduce precision when the error is within tolerance.
/// For example, 124.739 might become 124.74 if the error is small enough.
/// This matches node_svgo's strongRound function.
/// Note: This should only be used when precision > 0 && precision < 20.
/// For precision == 0, use _simpleRound instead (matching node_svgo behavior).
List<double> _strongRound(List<double> data, int precision, double error) {
  // When precision is 0, use simple rounding (like node_svgo's round function)
  if (precision <= 0) {
    return _simpleRound(data);
  }

  for (var i = data.length; i-- > 0;) {
    final fixed = _round(data[i], precision);
    if (fixed != data[i]) {
      final rounded = _round(data[i], precision - 1);
      final err = _round((rounded - data[i]).abs(), precision + 1);
      data[i] = err >= error ? fixed : rounded;
    }
  }
  return data;
}

/// Simple rounding function if precision is 0.
/// Matches node_svgo's round function.
List<double> _simpleRound(List<double> data) {
  for (var i = data.length; i-- > 0;) {
    data[i] = data[i].roundToDouble();
  }
  return data;
}

/// Apply smart arc rounding to reduce arc radius precision when the sagitta
/// (arc height) change is within the error tolerance.
void _applySmartArcRounding(
  List<double> arcArgs,
  int floatPrecision,
  double error,
  bool smartArcRounding,
) {
  if (!smartArcRounding) return;

  final sagitta = _calculateSagitta(arcArgs, error);
  if (sagitta != null) {
    // Keep track of original radius to ensure we don't round too aggressively
    final originalRadius = arcArgs[0];

    for (var precisionNew = floatPrecision; precisionNew >= 0; precisionNew--) {
      final radius = _round(arcArgs[0], precisionNew);

      // Don't round to a significantly different value (more than 0.1% change)
      // This prevents aggressive rounding for very large radii
      if (originalRadius > 0 &&
          (originalRadius - radius).abs() / originalRadius > 0.001) {
        break;
      }

      final sagittaNew = _calculateSagitta(
        [radius, radius, ...arcArgs.sublist(2)],
        error,
      );
      if (sagittaNew != null && (sagitta - sagittaNew).abs() < error) {
        arcArgs[0] = radius;
        arcArgs[1] = radius;
      } else {
        break;
      }
    }
  }
}

String _stringifyArgs(
    List<double> args, bool leadingZero, bool negativeExtraSpace) {
  final buffer = StringBuffer();
  String? prevStr;

  for (final v in args) {
    var str = v.toString();
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'\.?0+$'), '');
    }
    if (leadingZero && str.startsWith('0.')) {
      str = str.substring(1);
    }
    if (leadingZero && str.startsWith('-0.')) {
      str = '-${str.substring(2)}';
    }

    // Determine if we need a separator
    if (prevStr != null) {
      // No space needed before negative numbers or decimals starting with .
      final needsSpace =
          !(negativeExtraSpace && (str.startsWith('-') || str.startsWith('.')));
      // Also no space if previous ends with exponent and current starts with sign
      if (needsSpace) {
        buffer.write(' ');
      }
    }

    buffer.write(str);
    prevStr = str;
  }

  return buffer.toString();
}

// ============================================================================
// makeArcs functionality - converts cubic bezier curves to arcs
// ============================================================================

/// Result of curve to arc conversion
class _CurveToArcResult {
  const _CurveToArcResult({
    required this.arcs,
    required this.curves,
    required this.consumedPrev,
    required this.consumedCount,
    this.suffix = '',
  });

  final List<PathDataItem> arcs;
  final List<PathDataItem> curves;
  final bool consumedPrev;
  final int consumedCount; // Number of items consumed after current index
  final String
      suffix; // Longhand suffix for 's' command that couldn't be merged
}

/// Stringify path items for length comparison
/// Uses the same compact format as Node.js (negativeExtraSpace, leadingZero)
String _stringifyPathItems(List<PathDataItem> items, int floatPrecision) {
  final buffer = StringBuffer();
  for (final item in items) {
    buffer.write(item.command.name);
    double? prevValue;
    for (var i = 0; i < item.args.length; i++) {
      var value = item.args[i];
      if (floatPrecision > 0) {
        value = _round(value, floatPrecision);
      }

      // Convert to string, removing trailing .0 for integers
      var str = value.toString();
      if (str.endsWith('.0')) {
        str = str.substring(0, str.length - 2);
      }

      // Remove leading zeros like Node.js
      if (value > 0 && value < 1 && str.startsWith('0')) {
        str = str.substring(1); // 0.5 -> .5
      } else if (value > -1 && value < 0 && str.length > 1 && str[1] == '0') {
        str = str[0] + str.substring(2); // -0.5 -> -.5
      }

      // Determine delimiter (same logic as Node.js cleanupOutData)
      String delimiter = ' ';
      if (i == 0) {
        delimiter = '';
      } else if (value < 0 ||
          (str.startsWith('.') && prevValue != null && prevValue % 1 != 0)) {
        // No extra space in front of negative number or
        // in front of a floating number if a previous number is floating too
        delimiter = '';
      }

      buffer.write(delimiter);
      buffer.write(str);
      prevValue = value;
    }
  }
  return buffer.toString();
}

/// Convert curves to arc, checking both forward and backward
_CurveToArcResult? _convertCurvesToArc({
  required List<PathDataItem> pathData,
  required int currentIndex,
  required List<double> sdata,
  required _Circle circle,
  required PathDataItem item,
  required PathDataItem? prev,
  required double arcThreshold,
  required double arcTolerance,
  required double error,
  required int floatPrecision,
  required bool smartArcRounding,
}) {
  // Round the radius using strongRound (same as node_svgo's roundData)
  final roundedRadius = _strongRound([circle.radius], floatPrecision, error);
  final r = roundedRadius[0];

  // Calculate initial arc angle
  var angle = _findArcAngle(sdata, circle);
  if (angle.isNaN || !angle.isFinite) return null;

  // Determine sweep direction based on cross product
  final sweep = sdata[5] * sdata[0] - sdata[4] * sdata[1] > 0 ? 1 : 0;

  // Track which curves are consumed and arc properties
  final arcCurves = <PathDataItem>[item];
  var hasPrev = false;
  var consumedCount = 0;

  // The arc's base is initially the current item's base (absolute coordinates)
  List<double> arcBase = item.base ?? [0.0, 0.0];
  // The arc's end coordinates (absolute) - calculate from base + relative offset
  List<double> arcCoords =
      item.coords ?? [arcBase[0] + sdata[4], arcBase[1] + sdata[5]];

  // Check if previous curve can be joined
  if (prev != null) {
    List<double>? prevData;
    if (prev.command == PathDataCommand.c && _isConvex(prev.args)) {
      prevData = prev.args;
    } else if (prev.command == PathDataCommand.a && prev.sdata != null) {
      prevData = prev.sdata;
    }

    if (prevData != null &&
        _isArcPrev(prevData, circle, arcThreshold, arcTolerance, error)) {
      arcCurves.insert(0, prev);
      hasPrev = true;

      // Update arc base to previous curve's base
      arcBase = prev.base ?? [0.0, 0.0];

      // Calculate previous curve's angle
      final prevAngle = _findArcAngle(
          prevData,
          _Circle(
            center: (
              prevData[4] + circle.center.$1,
              prevData[5] + circle.center.$2,
            ),
            radius: circle.radius,
          ));
      angle += prevAngle;
    }
  }

  // Check forward for more curves that fit this arc
  final relCenter = [
    circle.center.$1 - sdata[4],
    circle.center.$2 - sdata[5],
  ];
  var relCircle =
      _Circle(center: (relCenter[0], relCenter[1]), radius: circle.radius);
  String suffix = '';

  for (var j = currentIndex + 1; j < pathData.length; j++) {
    final next = pathData[j];
    if (next.command != PathDataCommand.c &&
        next.command != PathDataCommand.s) {
      break;
    }

    List<double> nextData;
    List<double>? longhandFirstTwo; // For suffix calculation when s can't merge
    if (next.command == PathDataCommand.s) {
      // Convert shorthand to longhand
      final prevItem = j > 0 ? pathData[j - 1] : null;
      final prevArgs = prevItem?.args ?? [];
      nextData = _makeLonghand(next.args, prevArgs);
      // Save first two args for suffix (the longhand control point 1)
      longhandFirstTwo = [nextData[0], nextData[1]];
      // Calculate suffix string in case this s can't be merged
      suffix = _stringifyPathItems([
        PathDataItem(PathDataCommand.c, List<double>.from(longhandFirstTwo))
      ], floatPrecision);
    } else {
      nextData = next.args;
    }

    if (!_isConvex(nextData)) break;
    if (!_isArc(nextData, relCircle, arcThreshold, arcTolerance, error)) break;

    // This curve merged successfully, clear suffix
    suffix = '';

    // Add this curve's angle
    final nextAngle = _findArcAngle(nextData, relCircle);
    angle += nextAngle;

    if (angle - 2 * math.pi > 1e-3) {
      // More than 360° - stop here
      break;
    }

    arcCurves.add(next);
    consumedCount++;
    // Update arcCoords to absolute position after this curve
    // If next.coords is set, use it; otherwise calculate from current arcCoords + relative offset
    arcCoords =
        next.coords ?? [arcCoords[0] + nextData[4], arcCoords[1] + nextData[5]];

    if (2 * math.pi - angle <= 1e-3) {
      // Full circle - create two half-circle arcs
      final halfX = 2 * (relCircle.center.$1 - nextData[4]);
      final halfY = 2 * (relCircle.center.$2 - nextData[5]);

      final arc1Args = [r, r, 0.0, 1.0, sweep.toDouble(), halfX, halfY];
      _strongRound(arc1Args, floatPrecision, error);

      final arc1EndX = arcBase[0] + halfX;
      final arc1EndY = arcBase[1] + halfY;
      final arc1 = PathDataItem(PathDataCommand.a, arc1Args)
        ..base = arcBase
        ..coords = [arc1EndX, arc1EndY];

      final arc2Args = [
        r,
        r,
        0.0,
        0.0,
        sweep.toDouble(),
        arcCoords[0] - arc1EndX,
        arcCoords[1] - arc1EndY
      ];
      _strongRound(arc2Args, floatPrecision, error);
      final arc2 = PathDataItem(PathDataCommand.a, arc2Args)
        ..base = [arc1EndX, arc1EndY]
        ..coords = arcCoords;

      return _CurveToArcResult(
        arcs: [arc1, arc2],
        curves: arcCurves,
        consumedPrev: hasPrev,
        consumedCount: consumedCount,
        suffix: suffix,
      );
    }

    // Update relative circle center for next iteration
    relCenter[0] -= nextData[4];
    relCenter[1] -= nextData[5];
    relCircle =
        _Circle(center: (relCenter[0], relCenter[1]), radius: circle.radius);
  }

  // Calculate arc endpoint relative to arc base
  final arcEndX = arcCoords[0] - arcBase[0];
  final arcEndY = arcCoords[1] - arcBase[1];

  // Determine large-arc flag based on total angle
  final largeArc = angle > math.pi ? 1.0 : 0.0;

  // Create arc arguments
  final arcArgs = [r, r, 0.0, largeArc, sweep.toDouble(), arcEndX, arcEndY];

  // Round the arc arguments
  _strongRound(arcArgs, floatPrecision, error);

  final arc = PathDataItem(PathDataCommand.a, arcArgs)
    ..base = arcBase
    ..coords = arcCoords;

  return _CurveToArcResult(
    arcs: [arc],
    curves: arcCurves,
    consumedPrev: hasPrev,
    consumedCount: consumedCount,
    suffix: suffix,
  );
}

/// Configuration for makeArcs feature.
class _MakeArcsConfig {
  const _MakeArcsConfig({
    required this.threshold,
    required this.tolerance,
  });

  /// Coefficient of rounding error (default: 2.5)
  final double threshold;

  /// Percentage of radius (default: 0.5)
  final double tolerance;
}

/// Circle representation for arc conversion.
class _Circle {
  const _Circle({required this.center, required this.radius});

  final (double, double) center;
  final double radius;
}

/// Returns distance between two points.
double _getDistance((double, double) p1, (double, double) p2) {
  return math.sqrt(math.pow(p1.$1 - p2.$1, 2) + math.pow(p1.$2 - p2.$2, 2));
}

/// Returns coordinates of the cubic bezier curve point at parameter t.
/// Using formula: a·(1-t)³·P1 + 3·(1-t)²·t·P2 + 3·(1-t)·t²·P3 + t³·P4
/// where P1 is (0,0) due to relative coordinates.
(double, double) _getCubicBezierPoint(List<double> curve, double t) {
  final sqrT = t * t;
  final cubT = sqrT * t;
  final mt = 1 - t;
  final sqrMt = mt * mt;

  return (
    3 * sqrMt * t * curve[0] + 3 * mt * sqrT * curve[2] + cubT * curve[4],
    3 * sqrMt * t * curve[1] + 3 * mt * sqrT * curve[3] + cubT * curve[5],
  );
}

/// Computes line equations by two points and returns their intersection.
(double, double)? _getIntersection(List<double> coords) {
  // Line 1 equation: a1*x + b1*y + c1 = 0
  final a1 = coords[1] - coords[3]; // y1 - y2
  final b1 = coords[2] - coords[0]; // x2 - x1
  final c1 = coords[0] * coords[3] - coords[2] * coords[1]; // x1*y2 - x2*y1

  // Line 2 equation: a2*x + b2*y + c2 = 0
  final a2 = coords[5] - coords[7]; // y1 - y2
  final b2 = coords[6] - coords[4]; // x2 - x1
  final c2 = coords[4] * coords[7] - coords[6] * coords[5]; // x1*y2 - x2*y1

  final denom = a1 * b2 - a2 * b1;
  if (denom == 0) return null; // Parallel lines

  // Match Node.js formula exactly
  // Node.js uses: [(b1 * c2 - b2 * c1) / denom, (a1 * c2 - a2 * c1) / -denom]
  final x = (b1 * c2 - b2 * c1) / denom;
  final y = (a1 * c2 - a2 * c1) / -denom;

  if (x.isNaN || y.isNaN || !x.isFinite || !y.isFinite) {
    return null;
  }

  return (x, y);
}

/// Checks if a curve forms a convex quadrilateral.
bool _isConvex(List<double> data) {
  final center = _getIntersection([
    0,
    0,
    data[2],
    data[3],
    data[0],
    data[1],
    data[4],
    data[5],
  ]);

  if (center == null) return false;

  return (data[2] < center.$1) == (center.$1 < 0) &&
      (data[3] < center.$2) == (center.$2 < 0) &&
      (data[4] < center.$1) == (center.$1 < data[0]) &&
      (data[5] < center.$2) == (center.$2 < data[1]);
}

/// Finds circle passing through curve points.
_Circle? _findCircle(
  List<double> curve,
  double arcThreshold,
  double arcTolerance,
  double error,
) {
  final midPoint = _getCubicBezierPoint(curve, 0.5);
  final m1 = (midPoint.$1 / 2, midPoint.$2 / 2);
  final m2 = ((midPoint.$1 + curve[4]) / 2, (midPoint.$2 + curve[5]) / 2);

  final center = _getIntersection([
    m1.$1,
    m1.$2,
    m1.$1 + m1.$2,
    m1.$2 - m1.$1,
    m2.$1,
    m2.$2,
    m2.$1 + (m2.$2 - midPoint.$2),
    m2.$2 - (m2.$1 - midPoint.$1),
  ]);

  if (center == null) return null;

  final radius = _getDistance((0, 0), center);
  if (radius >= 1e15) return null;

  final tolerance = math.min(arcThreshold * error, arcTolerance * radius / 100);

  // Check points at 1/4 and 3/4 of the curve
  for (final t in [0.25, 0.75]) {
    final point = _getCubicBezierPoint(curve, t);
    if ((_getDistance(point, center) - radius).abs() > tolerance) {
      return null;
    }
  }

  return _Circle(center: center, radius: radius);
}

/// Checks if a curve fits the given circle.
bool _isArc(
  List<double> curve,
  _Circle circle,
  double arcThreshold,
  double arcTolerance,
  double error,
) {
  final tolerance =
      math.min(arcThreshold * error, arcTolerance * circle.radius / 100);

  for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
    final point = _getCubicBezierPoint(curve, t);
    if ((_getDistance(point, circle.center) - circle.radius).abs() >
        tolerance) {
      return false;
    }
  }

  return true;
}

/// Checks if a previous curve fits the given circle.
bool _isArcPrev(
  List<double> curve,
  _Circle circle,
  double arcThreshold,
  double arcTolerance,
  double error,
) {
  return _isArc(
    curve,
    _Circle(
      center: (
        circle.center.$1 + curve[4],
        circle.center.$2 + curve[5],
      ),
      radius: circle.radius,
    ),
    arcThreshold,
    arcTolerance,
    error,
  );
}

/// Finds arc angle for a curve.
double _findArcAngle(List<double> curve, _Circle relCircle) {
  final x1 = -relCircle.center.$1;
  final y1 = -relCircle.center.$2;
  final x2 = curve[4] - relCircle.center.$1;
  final y2 = curve[5] - relCircle.center.$2;

  return math.acos(
    (x1 * x2 + y1 * y2) / math.sqrt((x1 * x1 + y1 * y1) * (x2 * x2 + y2 * y2)),
  );
}

/// Converts shorthand curve 's' to longhand 'c'.
List<double> _makeLonghand(List<double> shortArgs, List<double> prevArgs) {
  final n = prevArgs.length;
  // Need at least 4 elements to calculate reflection
  if (n < 4) {
    // If previous command doesn't have enough points, use (0, 0) as first control point
    return [0, 0, ...shortArgs];
  }
  return [
    prevArgs[n - 2] - prevArgs[n - 4],
    prevArgs[n - 1] - prevArgs[n - 3],
    ...shortArgs,
  ];
}

/// Converts a shorthand curve to longhand in place.
/// For 's' -> 'c': adds reflected control point
/// For 't' -> 'q': adds reflected control point
void _makeLonghandInPlace(
    List<PathDataItem> pathData, int index, List<double> prevData) {
  final item = pathData[index];
  PathDataCommand newCommand;
  switch (item.command) {
    case PathDataCommand.s:
      newCommand = PathDataCommand.c;
    case PathDataCommand.t:
      newCommand = PathDataCommand.q;
    default:
      return;
  }

  final n = prevData.length;
  final newArgs = [
    prevData[n - 2] - prevData[n - 4],
    prevData[n - 1] - prevData[n - 3],
    ...item.args,
  ];

  final newItem = PathDataItem(newCommand, newArgs);
  // Preserve base and coords from original item
  newItem.base = item.base;
  newItem.coords = item.coords;
  pathData[index] = newItem;
}

/// Calculates the sagitta of an arc if possible.
/// Returns null if sagitta cannot be calculated.
/// @see https://wikipedia.org/wiki/Sagitta_(geometry)#Formulas
double? _calculateSagitta(List<double> data, double error) {
  // Large arc flag = 1 means we can't simplify
  if (data[3] == 1) {
    return null;
  }

  final rx = data[0];
  final ry = data[1];

  // Only works for circular arcs
  if ((rx - ry).abs() > error) {
    return null;
  }

  final chord = math.sqrt(data[5] * data[5] + data[6] * data[6]);

  // Chord can't be longer than diameter
  if (chord > rx * 2) {
    return null;
  }

  return rx - math.sqrt(rx * rx - 0.25 * chord * chord);
}
