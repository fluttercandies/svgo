/// Convert shape to path plugin.
///
/// Converts basic shapes to more compact path form.
library;

import '../../path/path.dart';
import '../../types.dart';
import '../../xast/visitor.dart';
import '../../xast/xast.dart';
import '../../xast/xast_utils.dart';
import '../plugin.dart';

/// Parameters for the convertShapeToPath plugin.
class ConvertShapeToPathParams extends PluginParams {
  /// Convert circle and ellipse to path. Default: false
  final bool convertArcs;

  /// Number of decimal places for coordinates. Default: 3
  final int floatPrecision;

  const ConvertShapeToPathParams({
    this.convertArcs = false,
    this.floatPrecision = 3,
  });
}

/// Plugin that converts basic shapes to more compact path form.
///
/// Converts `<rect>`, `<line>`, `<polyline>`, and `<polygon>` elements to
/// `<path>` elements. Optionally converts `<circle>` and `<ellipse>` elements
/// when the `convertArcs` parameter is true.
///
/// This allows further optimizations like combining paths with similar
/// attributes.
///
/// Example:
/// ```dart
/// final plugin = convertShapeToPath;
/// // Before: <rect x="10" y="20" width="100" height="50"/>
/// // After: <path d="M10 20H110V70H10z"/>
/// ```
///
/// References:
/// - SVG Basic Shapes: https://www.w3.org/TR/SVG11/shapes.html
const convertShapeToPath = Plugin<ConvertShapeToPathParams>(
  name: 'convertShapeToPath',
  description: 'converts basic shapes to more compact path form',
  defaultParams: ConvertShapeToPathParams(),
  fn: _convertShapeToPathFn,
);

/// Regular expression to extract numbers from a string.
final _regNumber = RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');

Visitor? _convertShapeToPathFn(
    XastRoot root, ConvertShapeToPathParams params, SvgoInfo info) {
  final convertArcs = params.convertArcs;
  final precision = params.floatPrecision;
  final stringifyOptions = PathStringifyOptions(
    floatPrecision: precision,
  );

  return Visitor(
    element: VisitorNode(
      enter: (node, parentNode) {
        // Convert rect to path (only rects without rounded corners)
        if (node.name == 'rect' &&
            node.attributes.containsKey('width') &&
            node.attributes.containsKey('height') &&
            !node.attributes.containsKey('rx') &&
            !node.attributes.containsKey('ry')) {
          final x = _parseNumber(node.attributes['x']);
          final y = _parseNumber(node.attributes['y']);
          final width = _parseNumber(node.attributes['width']);
          final height = _parseNumber(node.attributes['height']);

          // Skip if any value is NaN (e.g., percentage values)
          if (x.isNaN || y.isNaN || width.isNaN || height.isNaN) {
            return null;
          }

          final pathData = [
            PathDataItem(PathDataCommand.M, [x, y]),
            PathDataItem(PathDataCommand.H, [x + width]),
            PathDataItem(PathDataCommand.V, [y + height]),
            PathDataItem(PathDataCommand.H, [x]),
            PathDataItem(PathDataCommand.z, []),
          ];

          node.name = 'path';
          node.attributes['d'] = stringifyPathData(pathData, stringifyOptions);
          node.attributes.remove('x');
          node.attributes.remove('y');
          node.attributes.remove('width');
          node.attributes.remove('height');
        }

        // Convert line to path
        if (node.name == 'line') {
          final x1 = _parseNumber(node.attributes['x1']);
          final y1 = _parseNumber(node.attributes['y1']);
          final x2 = _parseNumber(node.attributes['x2']);
          final y2 = _parseNumber(node.attributes['y2']);

          if (x1.isNaN || y1.isNaN || x2.isNaN || y2.isNaN) {
            return null;
          }

          final pathData = [
            PathDataItem(PathDataCommand.M, [x1, y1]),
            PathDataItem(PathDataCommand.L, [x2, y2]),
          ];

          node.name = 'path';
          node.attributes['d'] = stringifyPathData(pathData, stringifyOptions);
          node.attributes.remove('x1');
          node.attributes.remove('y1');
          node.attributes.remove('x2');
          node.attributes.remove('y2');
        }

        // Convert polyline and polygon to path
        if ((node.name == 'polyline' || node.name == 'polygon') &&
            node.attributes.containsKey('points')) {
          final pointsStr = node.attributes['points']!;
          final coords = _regNumber
              .allMatches(pointsStr)
              .map((m) => double.parse(m.group(0)!))
              .toList();

          // Need at least 2 points (4 coordinates)
          if (coords.length < 4) {
            detachNodeFromParent(node, parentNode);
            return null;
          }

          final pathData = <PathDataItem>[];
          for (var i = 0; i < coords.length; i += 2) {
            if (i + 1 < coords.length) {
              pathData.add(PathDataItem(
                i == 0 ? PathDataCommand.M : PathDataCommand.L,
                [coords[i], coords[i + 1]],
              ));
            }
          }

          // Close the path for polygon
          if (node.name == 'polygon') {
            pathData.add(PathDataItem(PathDataCommand.z, []));
          }

          node.name = 'path';
          node.attributes['d'] = stringifyPathData(pathData, stringifyOptions);
          node.attributes.remove('points');
        }

        // Optionally convert circle to path
        if (node.name == 'circle' && convertArcs) {
          final cx = _parseNumber(node.attributes['cx']);
          final cy = _parseNumber(node.attributes['cy']);
          final r = _parseNumber(node.attributes['r']);

          if (cx.isNaN || cy.isNaN || r.isNaN) {
            return null;
          }

          // Draw circle as two arcs
          final pathData = [
            PathDataItem(PathDataCommand.M, [cx, cy - r]),
            PathDataItem(PathDataCommand.A, [r, r, 0, 1, 0, cx, cy + r]),
            PathDataItem(PathDataCommand.A, [r, r, 0, 1, 0, cx, cy - r]),
            PathDataItem(PathDataCommand.z, []),
          ];

          node.name = 'path';
          node.attributes['d'] = stringifyPathData(pathData, stringifyOptions);
          node.attributes.remove('cx');
          node.attributes.remove('cy');
          node.attributes.remove('r');
        }

        // Optionally convert ellipse to path
        if (node.name == 'ellipse' && convertArcs) {
          final cx = _parseNumber(node.attributes['cx']);
          final cy = _parseNumber(node.attributes['cy']);
          final rx = _parseNumber(node.attributes['rx']);
          final ry = _parseNumber(node.attributes['ry']);

          if (cx.isNaN || cy.isNaN || rx.isNaN || ry.isNaN) {
            return null;
          }

          // Draw ellipse as two arcs
          final pathData = [
            PathDataItem(PathDataCommand.M, [cx, cy - ry]),
            PathDataItem(PathDataCommand.A, [rx, ry, 0, 1, 0, cx, cy + ry]),
            PathDataItem(PathDataCommand.A, [rx, ry, 0, 1, 0, cx, cy - ry]),
            PathDataItem(PathDataCommand.z, []),
          ];

          node.name = 'path';
          node.attributes['d'] = stringifyPathData(pathData, stringifyOptions);
          node.attributes.remove('cx');
          node.attributes.remove('cy');
          node.attributes.remove('rx');
          node.attributes.remove('ry');
        }

        return null;
      },
    ),
  );
}

/// Parses a numeric attribute value, returning 0 for null/empty values.
double _parseNumber(String? value) {
  if (value == null || value.isEmpty) return 0.0;
  return double.tryParse(value) ?? double.nan;
}
