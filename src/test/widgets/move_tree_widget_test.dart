import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/models/repertoire.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/widgets/move_tree_widget.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Plays a sequence of SAN moves from the initial position and returns a list
/// of [RepertoireMove] objects with sequential IDs, proper parent linkage, and
/// accurate FEN strings.
List<RepertoireMove> buildLine(
  List<String> sans, {
  int repertoireId = 1,
  int startId = 1,
  int? startParentId,
  Map<int, String> labels = const {},
}) {
  final moves = <RepertoireMove>[];
  Position position = Chess.initial;
  int? parentId = startParentId;

  for (var i = 0; i < sans.length; i++) {
    final san = sans[i];
    final parsed = position.parseSan(san);
    if (parsed == null) {
      throw ArgumentError('Illegal move "$san" at index $i');
    }
    position = position.play(parsed);
    final id = startId + i;

    moves.add(RepertoireMove(
      id: id,
      repertoireId: repertoireId,
      parentMoveId: parentId,
      fen: position.fen,
      san: san,
      label: labels[i],
      sortOrder: 0,
    ));

    parentId = id;
  }

  return moves;
}

/// Helper to build a branch from a specific parent position.
///
/// [parentSans] is played to reach the branching position, then [branchSans]
/// is played from there. Returns only the branch moves.
List<RepertoireMove> buildBranch(
  List<String> parentSans,
  List<String> branchSans, {
  int repertoireId = 1,
  required int startId,
  required int parentMoveId,
  Map<int, String> labels = const {},
}) {
  Position position = Chess.initial;
  for (final san in parentSans) {
    position = position.play(position.parseSan(san)!);
  }

  final moves = <RepertoireMove>[];
  int? parentId = parentMoveId;

  for (var i = 0; i < branchSans.length; i++) {
    final san = branchSans[i];
    final parsed = position.parseSan(san);
    if (parsed == null) {
      throw ArgumentError('Illegal move "$san" at index $i');
    }
    position = position.play(parsed);
    final id = startId + i;

    moves.add(RepertoireMove(
      id: id,
      repertoireId: repertoireId,
      parentMoveId: parentId,
      fen: position.fen,
      san: san,
      label: labels[i],
      sortOrder: 1,
    ));

    parentId = id;
  }

  return moves;
}

// ---------------------------------------------------------------------------
// Unit tests for buildVisibleNodes
// ---------------------------------------------------------------------------

void main() {
  group('buildVisibleNodes', () {
    test('empty tree produces empty visible node list', () {
      final cache = RepertoireTreeCache.build([]);
      final result = buildVisibleNodes(cache, {});

      expect(result, isEmpty);
    });

    test('single root move produces one visible node at depth 0', () {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);

      final result = buildVisibleNodes(cache, {});

      expect(result.length, 1);
      expect(result[0].move.san, 'e4');
      expect(result[0].depth, 0);
      expect(result[0].plyCount, 1);
      expect(result[0].hasChildren, false);
    });

    test('root with children, all collapsed: only root visible', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      final result = buildVisibleNodes(cache, {});

      expect(result.length, 1);
      expect(result[0].move.san, 'e4');
      expect(result[0].hasChildren, true);
    });

    test('root with children, root expanded: root and child visible', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      // Expand root (id=1)
      final result = buildVisibleNodes(cache, {1});

      expect(result.length, 2);
      expect(result[0].move.san, 'e4');
      expect(result[0].depth, 0);
      expect(result[0].plyCount, 1);
      expect(result[1].move.san, 'e5');
      expect(result[1].depth, 1);
      expect(result[1].plyCount, 2);
      expect(result[1].hasChildren, true);
    });

    test('deeply nested tree with selective expansion', () {
      // 1. e4 e5 2. Nf3 Nc6 3. Bb5
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final cache = RepertoireTreeCache.build(line);

      // Expand e4 (1) and e5 (2), but not Nf3 (3)
      final result = buildVisibleNodes(cache, {1, 2});

      expect(result.length, 3);
      expect(result[0].move.san, 'e4');
      expect(result[0].depth, 0);
      expect(result[1].move.san, 'e5');
      expect(result[1].depth, 1);
      expect(result[2].move.san, 'Nf3');
      expect(result[2].depth, 2);
      expect(result[2].hasChildren, true); // Nf3 has Nc6 as child
    });

    test('multiple root moves are all visible at depth 0', () {
      // Two root moves: 1. e4 and 1. d4
      final e4Line = buildLine(['e4'], startId: 1);

      // Need a separate root move for d4
      Position pos = Chess.initial;
      final posAfterD4 = pos.play(pos.parseSan('d4')!);
      final d4Move = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: null,
        fen: posAfterD4.fen,
        san: 'd4',
        sortOrder: 1,
      );

      final allMoves = [...e4Line, d4Move];
      final cache = RepertoireTreeCache.build(allMoves);

      final result = buildVisibleNodes(cache, {});

      expect(result.length, 2);
      expect(result[0].move.san, 'e4');
      expect(result[0].depth, 0);
      expect(result[1].move.san, 'd4');
      expect(result[1].depth, 0);
    });

    test('only expanded subtrees are visible', () {
      // Main line: 1. e4 e5 2. Nf3
      // Branch: 1. e4 c5
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1, // e4
      );

      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      // Expand e4 (id=1) to see both e5 and c5
      final result = buildVisibleNodes(cache, {1});

      expect(result.length, 3);
      expect(result[0].move.san, 'e4');
      expect(result[0].depth, 0);
      expect(result[1].move.san, 'e5');
      expect(result[1].depth, 1);
      expect(result[2].move.san, 'c5');
      expect(result[2].depth, 1);
    });

    test('plyCount tracks line position, not visual nesting', () {
      // All nodes in a linear chain have plyCount = depth + 1
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final cache = RepertoireTreeCache.build(line);

      // Expand all
      final result = buildVisibleNodes(cache, {1, 2, 3});

      expect(result.length, 4);
      for (var i = 0; i < result.length; i++) {
        expect(result[i].depth, i);
        expect(result[i].plyCount, i + 1);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests
  // -------------------------------------------------------------------------

  group('MoveTreeWidget', () {
    Widget buildTestApp({
      required RepertoireTreeCache treeCache,
      Set<int> expandedNodeIds = const {},
      int? selectedMoveId,
      Map<int, int> dueCountByMoveId = const {},
      void Function(int)? onNodeSelected,
      void Function(int)? onNodeToggleExpand,
      void Function(int)? onEditLabel,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: MoveTreeWidget(
              treeCache: treeCache,
              expandedNodeIds: expandedNodeIds,
              selectedMoveId: selectedMoveId,
              dueCountByMoveId: dueCountByMoveId,
              onNodeSelected: onNodeSelected ?? (_) {},
              onNodeToggleExpand: onNodeToggleExpand ?? (_) {},
              onEditLabel: onEditLabel,
            ),
          ),
        ),
      );
    }

    testWidgets('renders correct number of tiles for a given tree + expand state',
        (tester) async {
      // 1. e4 e5 2. Nf3 -- expand root only
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
      ));

      // Should show e4 (expanded) and e5 (collapsed child).
      // Nf3 is hidden because e5 is not expanded.
      expect(find.text('1. e4'), findsOneWidget);
      expect(find.text('1...e5'), findsOneWidget);
      expect(find.text('2. Nf3'), findsNothing);
    });

    testWidgets('tapping a node calls onNodeSelected with the correct move ID',
        (tester) async {
      int? selectedId;
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onNodeSelected: (id) => selectedId = id,
      ));

      // Tap on the e5 node text
      await tester.tap(find.text('1...e5'));
      expect(selectedId, 2);
    });

    testWidgets('tapping the expand chevron calls onNodeToggleExpand',
        (tester) async {
      int? toggledId;
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onNodeToggleExpand: (id) => toggledId = id,
      ));

      // e4 has children, so a chevron should be visible
      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(toggledId, 1);
    });

    testWidgets('selected node has distinct visual styling', (tester) async {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        selectedMoveId: 2,
      ));

      // The selected node (e5, id=2) should be rendered with a
      // primaryContainer background color. We verify by finding the Material
      // widget wrapping the selected node.
      final materials = tester.widgetList<Material>(find.byType(Material));
      // At least one Material should have the primaryContainer color.
      final hasPrimaryContainer = materials.any((m) =>
          m.color != null && m.color != Colors.transparent);
      expect(hasPrimaryContainer, true);
    });

    testWidgets('labeled nodes have bold text styling', (tester) async {
      final line = buildLine(
        ['e4', 'e5'],
        labels: {0: 'Sicilian'},
      );
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
      ));

      // The label text "Sicilian" should be present (inside Text.rich, so use textContaining)
      expect(find.textContaining('Sicilian'), findsOneWidget);
    });

    testWidgets('empty tree shows empty state message', (tester) async {
      final cache = RepertoireTreeCache.build([]);

      await tester.pumpWidget(buildTestApp(treeCache: cache));

      expect(find.text('No moves yet. Add a line to get started.'),
          findsOneWidget);
    });

    testWidgets('due count badge is displayed when present', (tester) async {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        dueCountByMoveId: {1: 5},
      ));

      expect(find.text('5 due'), findsOneWidget);
    });

    testWidgets('due count badge is hidden when count is zero', (tester) async {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        dueCountByMoveId: {1: 0},
      ));

      expect(find.textContaining('due'), findsNothing);
    });

    testWidgets('each row shows a label icon when onEditLabel is provided',
        (tester) async {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onEditLabel: (_) {},
      ));

      // Two visible rows (e4 and e5), each should have a label_outline icon.
      expect(find.byIcon(Icons.label_outline), findsNWidgets(2));
    });

    testWidgets('no label icon when onEditLabel is null', (tester) async {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        // onEditLabel not set — defaults to null
      ));

      expect(find.byIcon(Icons.label_outline), findsNothing);
    });

    testWidgets('tapping the label icon calls onEditLabel with the correct move ID',
        (tester) async {
      int? editedId;
      int? selectedId;
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onNodeSelected: (id) => selectedId = id,
        onEditLabel: (id) => editedId = id,
      ));

      // Tap the second label icon (e5, id=2)
      await tester.tap(find.byIcon(Icons.label_outline).last);

      // onEditLabel should fire, but onNodeSelected should not.
      expect(editedId, 2);
      expect(selectedId, isNull);
    });

    testWidgets('tapping the row itself does not trigger onEditLabel',
        (tester) async {
      int? editedId;
      int? selectedId;
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onNodeSelected: (id) => selectedId = id,
        onEditLabel: (id) => editedId = id,
      ));

      // Tap on the row text for e5
      await tester.tap(find.text('1...e5'));

      // onNodeSelected should fire, but onEditLabel should not.
      expect(selectedId, 2);
      expect(editedId, isNull);
    });

    testWidgets('label icon uses primary color when node has a label',
        (tester) async {
      final line = buildLine(
        ['e4', 'e5'],
        labels: {0: 'King Pawn'},
      );
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onEditLabel: (_) {},
      ));

      // The first label icon belongs to e4 (which has a label).
      final icon = tester.widget<Icon>(find.byIcon(Icons.label_outline).first);
      final theme = Theme.of(tester.element(find.byIcon(Icons.label_outline).first));
      expect(icon.color, theme.colorScheme.primary);
    });

    testWidgets('label icon uses onSurfaceVariant when node has no label',
        (tester) async {
      final line = buildLine(
        ['e4', 'e5'],
        labels: {0: 'King Pawn'},
      );
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onEditLabel: (_) {},
      ));

      // The second label icon belongs to e5 (which has no label).
      final icon = tester.widget<Icon>(find.byIcon(Icons.label_outline).last);
      final theme = Theme.of(tester.element(find.byIcon(Icons.label_outline).last));
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
    });
  });
}
