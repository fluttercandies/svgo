/// Remove off-canvas paths plugin.
///
/// Removes elements that are drawn outside of the viewBox.
library;

import '../../path/path.dart';
import '../../types.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../../xast/visitor.dart';
import '../plugin.dart';

/// Removes elements that are drawn outside of the viewBox.
///
/// This plugin detects path elements that are completely outside
/// the visible viewBox area and removes them to reduce file size.
///
/// **Note:** Elements with transforms are skipped as they may still
/// be visible after transformation.
///
/// **Example:**
/// ```xml
/// <!-- Before -->
/// <svg viewBox="0 0 100 100">
///   <path d="M-50 -50 L-40 -40"/> <!-- completely outside -->
///   <path d="M0 0 L50 50"/>         <!-- inside viewBox -->
/// </svg>
///
/// <!-- After -->
/// <svg viewBox="0 0 100 100">
///   <path d="M0 0 L50 50"/>
/// </svg>
/// ```
const removeOffCanvasPaths = Plugin(
  name: 'removeOffCanvasPaths',
  description: 'removes elements that are drawn outside of the viewBox',
  fn: _removeOffCanvasPathsFn,
);

class _ViewBoxData {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double width;
  final double height;

  _ViewBoxData({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
  });
}

Visitor? _removeOffCanvasPathsFn(
    XastRoot ast, PluginParams params, SvgoInfo info) {
  _ViewBoxData? viewBoxData;

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Parse viewBox from svg element
        if (node.name == 'svg' && parentNode is XastRoot) {
          String viewBox = '';

          if (node.attributes.containsKey('viewBox')) {
            viewBox = node.attributes['viewBox']!;
          } else if (node.attributes.containsKey('height') &&
              node.attributes.containsKey('width')) {
            viewBox =
                '0 0 ${node.attributes['width']} ${node.attributes['height']}';
          }

          // Parse viewBox
          viewBox = viewBox
              .replaceAll(RegExp(r'[,+]|px'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

          final match =
              RegExp(r'^(-?\d*\.?\d+) (-?\d*\.?\d+) (\d*\.?\d+) (\d*\.?\d+)$')
                  .firstMatch(viewBox);

          if (match == null) {
            return null;
          }

          final left = double.parse(match.group(1)!);
          final top = double.parse(match.group(2)!);
          final width = double.parse(match.group(3)!);
          final height = double.parse(match.group(4)!);

          viewBoxData = _ViewBoxData(
            left: left,
            top: top,
            right: left + width,
            bottom: top + height,
            width: width,
            height: height,
          );
        }

        // Skip elements with transform attribute
        if (node.attributes.containsKey('transform')) {
          return null; // Can't determine position after transform
        }

        // Check path elements
        if (node.name == 'path' &&
            node.attributes.containsKey('d') &&
            viewBoxData != null) {
          try {
            final pathData = parsePathData(node.attributes['d']!);

            // Check if any M command is within the viewBox
            bool hasVisiblePoint = false;
            for (final item in pathData) {
              if (item.command == PathDataCommand.M && item.args.length >= 2) {
                final x = item.args[0];
                final y = item.args[1];
                if (x >= viewBoxData!.left &&
                    x <= viewBoxData!.right &&
                    y >= viewBoxData!.top &&
                    y <= viewBoxData!.bottom) {
                  hasVisiblePoint = true;
                  break;
                }
              }
            }

            if (hasVisiblePoint) {
              return null; // Keep the element
            }

            // Compute bounding box of the path
            final bbox = _computePathBoundingBox(pathData);
            if (bbox == null) {
              return null; // Can't compute bbox, keep the element
            }

            // Check if bounding box intersects with viewBox
            final intersects = !(bbox.maxX < viewBoxData!.left ||
                bbox.minX > viewBoxData!.right ||
                bbox.maxY < viewBoxData!.top ||
                bbox.minY > viewBoxData!.bottom);

            if (!intersects) {
              // Remove the element
              detachNodeFromParent(node, parentNode);
            }
          } catch (_) {
            // If path parsing fails, keep the element
          }
        }

        return null;
      },
    ),
  );
}

class _BoundingBox {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  _BoundingBox({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}

/// Computes a simple bounding box for a path.
_BoundingBox? _computePathBoundingBox(List<PathDataItem> pathData) {
  double? minX, minY, maxX, maxY;
  double cursorX = 0, cursorY = 0;
  double startX = 0, startY = 0;

  void updateBounds(double x, double y) {
    minX = minX == null ? x : (x < minX! ? x : minX!);
    minY = minY == null ? y : (y < minY! ? y : minY!);
    maxX = maxX == null ? x : (x > maxX! ? x : maxX!);
    maxY = maxY == null ? y : (y > maxY! ? y : maxY!);
  }

  for (final item in pathData) {
    final args = item.args;

    switch (item.command) {
      case PathDataCommand.M:
        if (args.length >= 2) {
          cursorX = args[0];
          cursorY = args[1];
          startX = cursorX;
          startY = cursorY;
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.m:
        if (args.length >= 2) {
          cursorX += args[0];
          cursorY += args[1];
          startX = cursorX;
          startY = cursorY;
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.L:
        if (args.length >= 2) {
          cursorX = args[0];
          cursorY = args[1];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.l:
        if (args.length >= 2) {
          cursorX += args[0];
          cursorY += args[1];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.H:
        if (args.isNotEmpty) {
          cursorX = args[0];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.h:
        if (args.isNotEmpty) {
          cursorX += args[0];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.V:
        if (args.isNotEmpty) {
          cursorY = args[0];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.v:
        if (args.isNotEmpty) {
          cursorY += args[0];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.C:
        if (args.length >= 6) {
          // Control points
          updateBounds(args[0], args[1]);
          updateBounds(args[2], args[3]);
          // End point
          cursorX = args[4];
          cursorY = args[5];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.c:
        if (args.length >= 6) {
          updateBounds(cursorX + args[0], cursorY + args[1]);
          updateBounds(cursorX + args[2], cursorY + args[3]);
          cursorX += args[4];
          cursorY += args[5];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.S:
        if (args.length >= 4) {
          updateBounds(args[0], args[1]);
          cursorX = args[2];
          cursorY = args[3];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.s:
        if (args.length >= 4) {
          updateBounds(cursorX + args[0], cursorY + args[1]);
          cursorX += args[2];
          cursorY += args[3];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.Q:
        if (args.length >= 4) {
          updateBounds(args[0], args[1]);
          cursorX = args[2];
          cursorY = args[3];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.q:
        if (args.length >= 4) {
          updateBounds(cursorX + args[0], cursorY + args[1]);
          cursorX += args[2];
          cursorY += args[3];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.T:
        if (args.length >= 2) {
          cursorX = args[0];
          cursorY = args[1];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.t:
        if (args.length >= 2) {
          cursorX += args[0];
          cursorY += args[1];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.A:
        if (args.length >= 7) {
          cursorX = args[5];
          cursorY = args[6];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.a:
        if (args.length >= 7) {
          cursorX += args[5];
          cursorY += args[6];
          updateBounds(cursorX, cursorY);
        }
        break;

      case PathDataCommand.Z:
      case PathDataCommand.z:
        cursorX = startX;
        cursorY = startY;
        break;
    }
  }

  if (minX == null || minY == null || maxX == null || maxY == null) {
    return null;
  }

  return _BoundingBox(
    minX: minX!,
    minY: minY!,
    maxX: maxX!,
    maxY: maxY!,
  );
}
