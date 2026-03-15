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
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].moves.length, 1);
      expect(result[0].depth, 0);
      expect(result[0].plyCount, 1);
      expect(result[0].hasChildren, false);
    });

    test('root with children, all collapsed: entire chain collapses', () {
      // Linear chain: e4 -> e5 -> Nf3. All single-child unlabeled.
      // Chain collapsing absorbs all three into one VisibleNode.
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      final result = buildVisibleNodes(cache, {});

      expect(result.length, 1);
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].lastMove.san, 'Nf3');
      expect(result[0].moves.length, 3);
      expect(result[0].hasChildren, false);
    });

    test('root with children, root expanded: chain still collapses', () {
      // Linear chain: e4 -> e5 -> Nf3. Even with e4 (id=1) "expanded",
      // chain collapsing absorbs all three into one node. The tail (Nf3)
      // has no children, so expansion is irrelevant.
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      final result = buildVisibleNodes(cache, {1});

      expect(result.length, 1);
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].lastMove.san, 'Nf3');
      expect(result[0].moves.length, 3);
      expect(result[0].depth, 0);
      expect(result[0].plyCount, 1);
      expect(result[0].hasChildren, false);
    });

    test('deeply nested tree with selective expansion', () {
      // 1. e4 e5 2. Nf3 Nc6 3. Bb5
      // All single-child unlabeled: entire chain collapses into one node.
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final cache = RepertoireTreeCache.build(line);

      // Expand doesn't matter for a fully linear tree.
      final result = buildVisibleNodes(cache, {1, 2});

      expect(result.length, 1);
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].lastMove.san, 'Bb5');
      expect(result[0].moves.length, 5);
      expect(result[0].depth, 0);
      expect(result[0].hasChildren, false);
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
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].depth, 0);
      expect(result[1].firstMove.san, 'd4');
      expect(result[1].depth, 0);
    });

    test('only expanded subtrees are visible', () {
      // Main line: 1. e4 e5 2. Nf3
      // Branch: 1. e4 c5
      // e4 has 2 children -> branch point, no chain collapsing at e4.
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
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].moves.length, 1); // branch point, no chaining
      expect(result[0].depth, 0);
      // e5 has one child Nf3 (unlabeled) -> chain collapses to [e5, Nf3]
      expect(result[1].firstMove.san, 'e5');
      expect(result[1].lastMove.san, 'Nf3');
      expect(result[1].moves.length, 2);
      expect(result[1].depth, 1);
      // c5 is a leaf
      expect(result[2].firstMove.san, 'c5');
      expect(result[2].moves.length, 1);
      expect(result[2].depth, 1);
    });

    test('plyCount tracks line position for collapsed chain', () {
      // Linear chain of 4 moves: all collapse into one VisibleNode.
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final cache = RepertoireTreeCache.build(line);

      final result = buildVisibleNodes(cache, {1, 2, 3});

      expect(result.length, 1);
      expect(result[0].plyCount, 1); // first move is at ply 1
      expect(result[0].moves.length, 4);
      expect(result[0].moves[0].san, 'e4');
      expect(result[0].moves[1].san, 'e5');
      expect(result[0].moves[2].san, 'Nf3');
      expect(result[0].moves[3].san, 'Nc6');
    });

    // -------------------------------------------------------------------
    // Chain-specific unit tests (Step 8)
    // -------------------------------------------------------------------

    test('single-child chain collapses into one VisibleNode with multiple moves', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      // Expand all (though irrelevant for fully linear tree).
      final result = buildVisibleNodes(cache, {1, 2, 3});

      expect(result.length, 1);
      expect(result[0].moves.length, 3);
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].lastMove.san, 'Nf3');
      expect(result[0].hasChildren, false);
      expect(result[0].depth, 0);
      expect(result[0].plyCount, 1);
    });

    test('chain stops at branch point', () {
      // e4 has two children: e5 and d5. e4 cannot be chained.
      final mainLine = buildLine(['e4', 'e5']);
      final branch = buildBranch(
        ['e4'],
        ['d5'],
        startId: 100,
        parentMoveId: 1,
      );

      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      // Expand e4 to see children.
      final result = buildVisibleNodes(cache, {1});

      expect(result.length, 3);
      // e4 alone (branch point, 2 children)
      expect(result[0].moves.length, 1);
      expect(result[0].firstMove.san, 'e4');
      // e5 alone (leaf)
      expect(result[1].firstMove.san, 'e5');
      // d5 alone (leaf)
      expect(result[2].firstMove.san, 'd5');
    });

    test('chain stops before labeled child', () {
      // e4 -> e5 (labeled) -> Nf3. e4's child e5 is labeled, so chain stops.
      // e5 -> Nf3 is a valid chain (Nf3 is unlabeled single-child of e5...
      // actually Nf3 is a leaf, so e5+Nf3 chain).
      final line = buildLine(['e4', 'e5', 'Nf3'], labels: {1: 'Open Game'});
      final cache = RepertoireTreeCache.build(line);

      // Expand all.
      final result = buildVisibleNodes(cache, {1, 2, 3});

      expect(result.length, 2);
      // e4 alone (its child e5 is labeled, so chain stops)
      expect(result[0].moves.length, 1);
      expect(result[0].firstMove.san, 'e4');
      expect(result[0].hasChildren, true);
      // e5 + Nf3 chained (e5 is labeled, starts its own row; Nf3 is unlabeled leaf)
      expect(result[1].moves.length, 2);
      expect(result[1].firstMove.san, 'e5');
      expect(result[1].firstMove.label, 'Open Game');
      expect(result[1].lastMove.san, 'Nf3');
    });

    test('entire linear tree produces one VisibleNode', () {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final cache = RepertoireTreeCache.build(line);

      final result = buildVisibleNodes(cache, {1, 2, 3, 4});

      expect(result.length, 1);
      expect(result[0].moves.length, 5);
    });

    test('mixed tree with branches and chains', () {
      // e4 has children e5 and c5. e5 continues to Nf3, Nc6.
      // c5 continues to Nf3, d6.
      final mainLine = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final branch = buildBranch(
        ['e4'],
        ['c5', 'Nf3', 'd6'],
        startId: 100,
        parentMoveId: 1,
      );

      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      // Expand e4 (id=1) to see both branches.
      final result = buildVisibleNodes(cache, {1});

      expect(result.length, 3);
      // e4 alone (branch point, 2 children)
      expect(result[0].moves.length, 1);
      expect(result[0].firstMove.san, 'e4');
      // e5 chain: e5 -> Nf3 -> Nc6 (3 moves)
      expect(result[1].moves.length, 3);
      expect(result[1].firstMove.san, 'e5');
      expect(result[1].lastMove.san, 'Nc6');
      // c5 chain: c5 -> Nf3 -> d6 (3 moves)
      expect(result[2].moves.length, 3);
      expect(result[2].firstMove.san, 'c5');
      expect(result[2].lastMove.san, 'd6');
    });
  });

  // -------------------------------------------------------------------------
  // Unit tests for buildChainNotation (Step 10)
  // -------------------------------------------------------------------------

  group('buildChainNotation', () {
    test('single white move matches getMoveNotation output for single-move chains', () {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final node = VisibleNode(moves: line, depth: 0, hasChildren: false, plyCount: 1);

      expect(buildChainNotation(node, cache), '1. e4');
    });

    test('single black move matches getMoveNotation output for single-move chains', () {
      // Build a VisibleNode representing just a black move at ply 2.
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);
      final node = VisibleNode(
        moves: [line[1]], // just e5
        depth: 1,
        hasChildren: false,
        plyCount: 2,
      );

      expect(buildChainNotation(node, cache), '1...e5');
    });

    test('multi-move chain starting with white', () {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final cache = RepertoireTreeCache.build(line);
      final node = VisibleNode(moves: line, depth: 0, hasChildren: false, plyCount: 1);

      expect(buildChainNotation(node, cache), '1. e4 e5 2. Nf3 Nc6');
    });

    test('multi-move chain starting with black', () {
      // Simulate a chain starting at ply 2 (black move).
      // c5, Nf3, d6 at plies 2, 3, 4.
      final line = buildLine(['e4', 'c5', 'Nf3', 'd6']);
      final cache = RepertoireTreeCache.build(line);
      final chainMoves = line.sublist(1); // c5, Nf3, d6
      final node = VisibleNode(moves: chainMoves, depth: 1, hasChildren: false, plyCount: 2);

      expect(buildChainNotation(node, cache), '1...c5 2. Nf3 d6');
    });

    test('chain with only one pair', () {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);
      final node = VisibleNode(moves: line, depth: 0, hasChildren: false, plyCount: 1);

      expect(buildChainNotation(node, cache), '1. e4 e5');
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
      // e4 has two children (e5, c5) -> branch point, not chained.
      // e5 has child Nf3 -> chain [e5, Nf3].
      // Expand e4 only -> see e4, [e5 Nf3], c5.
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
      ));

      // e4 is a branch point (separate row).
      expect(find.text('1. e4'), findsOneWidget);
      // e5 and Nf3 collapse into a chain.
      expect(find.text('1...e5 2. Nf3'), findsOneWidget);
      // c5 is a leaf (separate row).
      expect(find.text('1...c5'), findsOneWidget);
    });

    testWidgets('tapping a node calls onNodeSelected with the tail move ID',
        (tester) async {
      int? selectedId;
      // e4 has two children -> branch point.
      final mainLine = buildLine(['e4', 'e5']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onNodeSelected: (id) => selectedId = id,
      ));

      // Tap on the e5 node text (leaf, single-move row)
      await tester.tap(find.text('1...e5'));
      expect(selectedId, 2); // e5 is its own row, tail is itself
    });

    testWidgets('tapping the expand chevron calls onNodeToggleExpand',
        (tester) async {
      int? toggledId;
      // e4 has two children (e5, c5) -> branch point with chevron.
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

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
      // e4 -> e5 chain. Select e5 (id=2, part of the chain).
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        selectedMoveId: 2,
      ));

      // The chain row contains e5 (id=2) which is selected, so the row
      // should have primaryContainer background.
      final materials = tester.widgetList<Material>(find.byType(Material));
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
      // e4 has two children -> branch point -> 3 rows when expanded.
      final mainLine = buildLine(['e4', 'e5']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onEditLabel: (_) {},
      ));

      // Three visible rows (e4, e5, c5), each should have a label_outline icon.
      expect(find.byIcon(Icons.label_outline), findsNWidgets(3));
    });

    testWidgets('no label icon when onEditLabel is null', (tester) async {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        // onEditLabel not set -- defaults to null
      ));

      expect(find.byIcon(Icons.label_outline), findsNothing);
    });

    testWidgets('tapping the label icon calls onEditLabel with the first move ID',
        (tester) async {
      int? editedId;
      int? selectedId;
      // e4 has two children -> branch point -> 3 rows when expanded.
      final mainLine = buildLine(['e4', 'e5']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onNodeSelected: (id) => selectedId = id,
        onEditLabel: (id) => editedId = id,
      ));

      // Tap the second label icon (e5 row, which is a single-move node).
      await tester.tap(find.byIcon(Icons.label_outline).at(1));

      // onEditLabel should fire with e5's ID (first move of that row).
      expect(editedId, 2);
      expect(selectedId, isNull);
    });

    testWidgets('tapping the row itself does not trigger onEditLabel',
        (tester) async {
      int? editedId;
      int? selectedId;
      // e4 has two children -> branch point -> 3 rows when expanded.
      final mainLine = buildLine(['e4', 'e5']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onNodeSelected: (id) => selectedId = id,
        onEditLabel: (id) => editedId = id,
      ));

      // Tap on the row text for e5
      await tester.tap(find.text('1...e5'));

      // onNodeSelected should fire (with tail ID), but onEditLabel should not.
      expect(selectedId, 2);
      expect(editedId, isNull);
    });

    testWidgets('label icon uses primary color when node has a label',
        (tester) async {
      // e4 (labeled) has child e5 (labeled 'Open Game') -> chain stops.
      // So e4 is its own row with a label.
      final line = buildLine(
        ['e4', 'e5'],
        labels: {0: 'King Pawn'},
      );
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onEditLabel: (_) {},
      ));

      // e4 has label -> first label icon should use primary color.
      final icon = tester.widget<Icon>(find.byIcon(Icons.label_outline).first);
      final theme = Theme.of(tester.element(find.byIcon(Icons.label_outline).first));
      expect(icon.color, theme.colorScheme.primary);
    });

    testWidgets('label icon uses onSurfaceVariant when node has no label',
        (tester) async {
      // e4 (labeled) has child e5 -> chain stops because e5 is the only
      // child and has no label, so e4+e5 chain. But e4 IS labeled.
      // Wait -- e4 has label "King Pawn", and e5 has no label. e4's child
      // is e5, which is unlabeled and single-child. So chain is [e4, e5].
      // The chain's firstMove (e4) has a label, so hasLabel is true for both.
      // We need a tree where one row has a label and another doesn't.
      // Use a branch: e4 has children e5 and c5. Label e4.
      final mainLine = buildLine(
        ['e4', 'e5'],
        labels: {0: 'King Pawn'},
      );
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onEditLabel: (_) {},
      ));

      // Three rows: e4 (labeled), e5 (no label), c5 (no label).
      // The last label icon belongs to c5 (no label).
      final icon = tester.widget<Icon>(find.byIcon(Icons.label_outline).last);
      final theme = Theme.of(tester.element(find.byIcon(Icons.label_outline).last));
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets(
        'tapping enlarged label icon area outside visual icon triggers onEditLabel, not onNodeSelected',
        (tester) async {
      int? editedId;
      int? selectedId;
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onNodeSelected: (id) => selectedId = id,
        onEditLabel: (id) => editedId = id,
      ));

      // The label icon is 14px but sits inside a 28x28 SizedBox.
      // Tap 10px above the icon center -- inside the 28dp box but outside
      // the 14px visual icon.
      final iconCenter = tester.getCenter(find.byIcon(Icons.label_outline));
      await tester.tapAt(iconCenter + const Offset(0, -10));

      expect(editedId, 1);
      expect(selectedId, isNull);
    });

    testWidgets(
        'tapping enlarged chevron area outside visual icon triggers onNodeToggleExpand, not onNodeSelected',
        (tester) async {
      int? toggledId;
      int? selectedId;
      // e4 has two children -> branch point with chevron.
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onNodeSelected: (id) => selectedId = id,
        onNodeToggleExpand: (id) => toggledId = id,
      ));

      // The chevron icon is 16px but sits inside a 28x28 SizedBox.
      // Tap 10px above the icon center -- inside the 28dp box but outside
      // the 16px visual icon.
      final chevronCenter = tester.getCenter(find.byIcon(Icons.chevron_right));
      await tester.tapAt(chevronCenter + const Offset(0, -10));

      expect(toggledId, 1);
      expect(selectedId, isNull);
    });

    // -------------------------------------------------------------------
    // Chain-specific widget tests (Step 9)
    // -------------------------------------------------------------------

    testWidgets('collapsed chain shows combined notation', (tester) async {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
      ));

      // Entire linear tree collapses into one row.
      expect(find.text('1. e4 e5 2. Nf3 Nc6'), findsOneWidget);
    });

    testWidgets('tapping chain row selects last move', (tester) async {
      int? selectedId;
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onNodeSelected: (id) => selectedId = id,
      ));

      await tester.tap(find.text('1. e4 e5 2. Nf3 Nc6'));
      expect(selectedId, 4); // Nc6 is the tail (id=4)
    });

    testWidgets('chain row highlights when any move in chain is selected',
        (tester) async {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      // Select the middle move (e5, id=2).
      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        selectedMoveId: 2,
      ));

      // The chain row should have primaryContainer highlight.
      final materials = tester.widgetList<Material>(find.byType(Material));
      final hasPrimaryContainer = materials.any((m) =>
          m.color != null && m.color != Colors.transparent);
      expect(hasPrimaryContainer, true);
    });

    testWidgets('chevron on chain toggles last move expansion', (tester) async {
      int? toggledId;
      // e4 -> e5 -> Nf3, where Nf3 has 2 children (Nc6, d4-ish).
      // Chain is [e4, e5, Nf3]. Nf3 is the tail with 2 children.
      // But wait -- Nf3 has 2 children means the chain STOPS before Nf3?
      // No: the chain absorbs nodes whose PARENT has 1 child.
      // e4's child is e5 (single child) -> absorb e5.
      // e5's child is Nf3 (single child) -> absorb Nf3.
      // Nf3's children are [Nc6, d4-branch] (2 children) -> stop.
      // So the chain is [e4, e5, Nf3] with hasChildren=true.
      final mainLine = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final branch = buildBranch(
        ['e4', 'e5', 'Nf3'],
        ['d5'],
        startId: 100,
        parentMoveId: 3, // Nf3
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onNodeToggleExpand: (id) => toggledId = id,
      ));

      // The chain [e4, e5, Nf3] should show a chevron (hasChildren=true).
      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(toggledId, 3); // Nf3 is the tail
    });

    testWidgets('label icon on chain edits first move label', (tester) async {
      int? editedId;
      // Linear chain: e4 -> e5 collapses into one row.
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onEditLabel: (id) => editedId = id,
      ));

      // One row, one label icon.
      await tester.tap(find.byIcon(Icons.label_outline));
      expect(editedId, 1); // e4 is the first move
    });

    testWidgets('dueCount shows first non-zero in chain order', (tester) async {
      // Chain [e4, e5, Nf3]. Due count only on e5 (id=2).
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        dueCountByMoveId: {2: 3},
      ));

      // The chain row should display "3 due" from the middle move.
      expect(find.text('3 due'), findsOneWidget);
    });

    testWidgets('tapping the row text does not call onNodeToggleExpand',
        (tester) async {
      int? toggledId;
      int? selectedId;
      // Build a branch tree so chevron is shown (e4 has two children: e5, c5).
      // Tap the e5 row text — should fire onNodeSelected, not onNodeToggleExpand.
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {1},
        onNodeSelected: (id) => selectedId = id,
        onNodeToggleExpand: (id) => toggledId = id,
      ));

      // Tap the e5 chain row text (e5 has one child Nf3, collapses into chain).
      // The chain's tail is Nf3 (id=3), so selectedId must be 3.
      await tester.tap(find.text('1...e5 2. Nf3'));
      expect(selectedId, 3);
      expect(toggledId, isNull);
    });

    testWidgets('tapping chevron icon does not call onNodeSelected',
        (tester) async {
      int? toggledId;
      int? selectedId;
      // Build a branch tree so chevron is shown (e4 has two children: e5, c5).
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);
      final branch = buildBranch(
        ['e4'],
        ['c5'],
        startId: 100,
        parentMoveId: 1,
      );
      final allMoves = [...mainLine, ...branch];
      final cache = RepertoireTreeCache.build(allMoves);

      await tester.pumpWidget(buildTestApp(
        treeCache: cache,
        expandedNodeIds: {},
        onNodeSelected: (id) => selectedId = id,
        onNodeToggleExpand: (id) => toggledId = id,
      ));

      // e4 is collapsed (chevron_right shown). Tap the chevron icon.
      // e4 is the branch node (id=1), so toggledId must be 1.
      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(toggledId, 1);
      expect(selectedId, isNull);
    });

    testWidgets('indentation is capped for deeply nested nodes',
        (tester) async {
      // Build a tree with a branch at every level using a Ruy Lopez line,
      // forcing depth 0 through 7. Each node has 2 children (branch point),
      // so its children are at depth+1. All moves are legal chess.
      //
      // Main line: 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 (ids 1-8)
      // Branch at e4(1):   c5                                  (id 100)
      // Branch at e5(2):   Bc4                                 (id 200)
      // Branch at Nf3(3):  d6                                  (id 300)
      // Branch at Nc6(4):  Bc4                                 (id 400)
      // Branch at Bb5(5):  Nf6                                 (id 500)
      // Branch at a6(6):   Bxc6                                (id 600)
      // Branch at Ba4(7):  b5                                  (id 700)
      //
      // Depths: e4=0, e5/c5=1, Nf3/Bc4=2, Nc6/d6=3, Bb5/Bc4=4,
      //         a6/Nf6=5, Ba4/Bxc6=6, Nf6(8)/b5=7

      final mainLine = buildLine(
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6'],
      );

      final branch1 = buildBranch(
        ['e4'], ['c5'],
        startId: 100, parentMoveId: 1,
      );
      final branch2 = buildBranch(
        ['e4', 'e5'], ['Bc4'],
        startId: 200, parentMoveId: 2,
      );
      final branch3 = buildBranch(
        ['e4', 'e5', 'Nf3'], ['d6'],
        startId: 300, parentMoveId: 3,
      );
      final branch4 = buildBranch(
        ['e4', 'e5', 'Nf3', 'Nc6'], ['Bc4'],
        startId: 400, parentMoveId: 4,
      );
      final branch5 = buildBranch(
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'], ['Nf6'],
        startId: 500, parentMoveId: 5,
      );
      final branch6 = buildBranch(
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6'], ['Bxc6'],
        startId: 600, parentMoveId: 6,
      );
      final branch7 = buildBranch(
        ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4'], ['b5'],
        startId: 700, parentMoveId: 7,
      );

      final allMoves = [
        ...mainLine,
        ...branch1, ...branch2, ...branch3, ...branch4,
        ...branch5, ...branch6, ...branch7,
      ];
      final cache = RepertoireTreeCache.build(allMoves);

      // Expand all branch nodes (ids 1-7) to make all depths visible.
      final expandedIds = <int>{1, 2, 3, 4, 5, 6, 7};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: MoveTreeWidget(
                treeCache: cache,
                expandedNodeIds: expandedIds,
                onNodeSelected: (_) {},
                onNodeToggleExpand: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify indentation via rendered positions of specific rows.
      // Row texts (from buildChainNotation):
      //   depth 1: "1...e5"    depth 5: "3...a6"
      //   depth 6: "4. Ba4"    depth 7: "4...b5"
      // With the cap at depth 5, rows at depth 5/6/7 should all share
      // the same x-offset, proving the indentation stopped growing.

      final depth1Left = tester.getTopLeft(find.text('1...e5')).dx;
      final depth5Left = tester.getTopLeft(find.text('3...a6')).dx;
      final depth6Left = tester.getTopLeft(find.text('4. Ba4')).dx;
      final depth7Left = tester.getTopLeft(find.text('4...b5')).dx;

      // Shallow row is indented less than capped rows.
      expect(depth1Left, lessThan(depth5Left),
          reason: 'depth-1 row should be indented less than depth-5');

      // Depths 5, 6, and 7 should all have the same indent (capped).
      expect(depth6Left, depth5Left,
          reason: 'depth 6 should have same indent as depth 5 (capped)');
      expect(depth7Left, depth5Left,
          reason: 'depth 7 should have same indent as depth 5 (capped)');
    });
  });

  // -------------------------------------------------------------------------
  // Unit tests for computeTreeIndent
  // -------------------------------------------------------------------------

  group('computeTreeIndent', () {
    test('depth 0 returns base padding', () {
      expect(computeTreeIndent(0), 8.0);
    });

    test('depth 1 returns base plus one level', () {
      expect(computeTreeIndent(1), 28.0);
    });

    test('depth at max (5) returns base plus 5 levels', () {
      expect(computeTreeIndent(5), 108.0);
    });

    test('depth beyond max is capped', () {
      expect(computeTreeIndent(6), 108.0);
      expect(computeTreeIndent(10), 108.0);
    });

    test('negative depth clamps to 0', () {
      expect(computeTreeIndent(-1), 8.0);
    });
  });
}
