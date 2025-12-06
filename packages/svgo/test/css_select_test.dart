import 'package:svgo/svgo.dart';
import 'package:test/test.dart';

void main() {
  group('CSS Selector Matching', () {
    late XastRoot root;
    late Map<XastElement, XastParent> parents;

    setUp(() {
      // Create a simple test tree
      final svg = XastElement(
        name: 'svg',
        attributes: {'id': 'root', 'class': 'icon'},
        children: [
          XastElement(
            name: 'g',
            attributes: {'id': 'group1', 'class': 'container'},
            children: [
              XastElement(
                name: 'rect',
                attributes: {
                  'id': 'rect1',
                  'class': 'shape fill-red',
                  'fill': 'red',
                  'data-type': 'primary',
                },
                children: [],
              ),
              XastElement(
                name: 'circle',
                attributes: {'id': 'circle1', 'class': 'shape'},
                children: [],
              ),
            ],
          ),
          XastElement(
            name: 'path',
            attributes: {'id': 'path1', 'class': 'line'},
            children: [],
          ),
        ],
      );

      root = XastRoot(children: [svg]);
      parents = _buildParents(root);
    });

    test('matchesCssSelector matches tag name selector', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, 'rect', parents: parents), isTrue);
      expect(matchesCssSelector(rect, 'circle', parents: parents), isFalse);
    });

    test('matchesCssSelector matches universal selector', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, '*', parents: parents), isTrue);
    });

    test('matchesCssSelector matches ID selector', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, '#rect1', parents: parents), isTrue);
      expect(matchesCssSelector(rect, '#rect2', parents: parents), isFalse);
    });

    test('matchesCssSelector matches class selector', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, '.shape', parents: parents), isTrue);
      expect(matchesCssSelector(rect, '.fill-red', parents: parents), isTrue);
      expect(matchesCssSelector(rect, '.other', parents: parents), isFalse);
    });

    test('matchesCssSelector matches compound selector', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, 'rect.shape', parents: parents), isTrue);
      expect(matchesCssSelector(rect, 'rect#rect1', parents: parents), isTrue);
      expect(matchesCssSelector(rect, 'rect.shape.fill-red', parents: parents),
          isTrue);
      expect(
          matchesCssSelector(rect, 'circle.shape', parents: parents), isFalse);
    });

    test('matchesCssSelector matches attribute selector [attr]', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, '[fill]', parents: parents), isTrue);
      expect(matchesCssSelector(rect, '[stroke]', parents: parents), isFalse);
    });

    test('matchesCssSelector matches attribute selector [attr=value]', () {
      final rect = _findById(root, 'rect1')!;
      expect(
          matchesCssSelector(rect, '[fill="red"]', parents: parents), isTrue);
      expect(
          matchesCssSelector(rect, '[fill="blue"]', parents: parents), isFalse);
    });

    test('matchesCssSelector matches attribute selector [attr~=value]', () {
      final rect = _findById(root, 'rect1')!;
      // class="shape fill-red" contains "shape"
      expect(matchesCssSelector(rect, '[class~="shape"]', parents: parents),
          isTrue);
      expect(matchesCssSelector(rect, '[class~="other"]', parents: parents),
          isFalse);
    });

    test('matchesCssSelector matches attribute selector [attr^=value]', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, '[data-type^="prim"]', parents: parents),
          isTrue);
      expect(matchesCssSelector(rect, '[data-type^="sec"]', parents: parents),
          isFalse);
    });

    test(r'matchesCssSelector matches attribute selector [attr$=value]', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, r'[data-type$="ary"]', parents: parents),
          isTrue);
      expect(matchesCssSelector(rect, r'[data-type$="xxx"]', parents: parents),
          isFalse);
    });

    test('matchesCssSelector matches attribute selector [attr*=value]', () {
      final rect = _findById(root, 'rect1')!;
      expect(matchesCssSelector(rect, '[data-type*="rim"]', parents: parents),
          isTrue);
      expect(matchesCssSelector(rect, '[data-type*="xxx"]', parents: parents),
          isFalse);
    });

    test('matchesCssSelector matches selector list (comma-separated)', () {
      final rect = _findById(root, 'rect1')!;
      final circle = _findById(root, 'circle1')!;

      expect(
          matchesCssSelector(rect, 'rect, circle', parents: parents), isTrue);
      expect(
          matchesCssSelector(circle, 'rect, circle', parents: parents), isTrue);
      expect(
          matchesCssSelector(rect, 'path, polygon', parents: parents), isFalse);
    });

    test('querySelector finds first matching element', () {
      final result = querySelector(root, '.shape', parents: parents);
      expect(result, isNotNull);
      expect(result!.attributes['id'], equals('rect1'));
    });

    test('querySelectorAll finds all matching elements', () {
      final results = querySelectorAll(root, '.shape', parents: parents);
      expect(results.length, equals(2));
      expect(results[0].attributes['id'], equals('rect1'));
      expect(results[1].attributes['id'], equals('circle1'));
    });

    test('querySelector returns null when no match', () {
      final result = querySelector(root, '.nonexistent', parents: parents);
      expect(result, isNull);
    });

    test('querySelectorAll returns empty list when no match', () {
      final results = querySelectorAll(root, '.nonexistent', parents: parents);
      expect(results, isEmpty);
    });
  });
}

/// Builds a parent map for the tree.
Map<XastElement, XastParent> _buildParents(XastRoot root) {
  final parents = <XastElement, XastParent>{};

  void visit(XastParent node) {
    for (final child in node.children) {
      if (child is XastElement) {
        parents[child] = node;
        visit(child);
      }
    }
  }

  visit(root);
  return parents;
}

/// Finds an element by ID.
XastElement? _findById(XastParent node, String id) {
  for (final child in node.children) {
    if (child is XastElement) {
      if (child.attributes['id'] == id) {
        return child;
      }
      final found = _findById(child, id);
      if (found != null) return found;
    }
  }
  return null;
}
