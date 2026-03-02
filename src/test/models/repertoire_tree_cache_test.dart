import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/models/repertoire.dart';
import 'package:chess_trainer/repositories/local/database.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Plays a sequence of SAN moves from the initial position and returns a list
/// of [RepertoireMove] objects with sequential IDs, proper parent linkage, and
/// accurate FEN strings.
///
/// Supports an optional [labels] map from index to label string.
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('getAggregateDisplayName', () {
    test('returns empty string for a node with no labels along its path', () {
      // 1. e4 e5 2. Nf3 -- no labels anywhere
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getAggregateDisplayName(3), '');
    });

    test('returns the single label for a node with one label on its path', () {
      // 1. e4 (label: "Sicilian") e5 2. Nf3
      final line = buildLine(
        ['e4', 'e5', 'Nf3'],
        labels: {0: 'Sicilian'},
      );
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getAggregateDisplayName(3), 'Sicilian');
    });

    test('joins multiple labels with em dash separator', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3 (label: "Open Sicilian") d6
      final line = buildLine(
        ['e4', 'c5', 'Nf3', 'd6'],
        labels: {0: 'Sicilian', 2: 'Open Sicilian'},
      );
      final cache = RepertoireTreeCache.build(line);

      expect(
        cache.getAggregateDisplayName(4),
        'Sicilian \u2014 Open Sicilian',
      );
    });

    test('only includes labels on the root-to-node path, not sibling branches',
        () {
      // Main line: 1. e4 (label: "King Pawn") e5 2. Nf3
      final mainLine = buildLine(
        ['e4', 'e5', 'Nf3'],
        labels: {0: 'King Pawn'},
      );

      // Branch from e4: 1. e4 c5 (label: "Sicilian")
      // c5 branches from e4 (id=1), so startParentId=1
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      final posAfterC5 = pos.play(pos.parseSan('c5')!);

      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: 1, // e4
        fen: posAfterC5.fen,
        san: 'c5',
        label: 'Sicilian',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, branchMove];
      final cache = RepertoireTreeCache.build(allMoves);

      // Querying the main line (Nf3, id=3) should only show "King Pawn",
      // not "Sicilian" from the sibling branch.
      expect(cache.getAggregateDisplayName(3), 'King Pawn');

      // Querying the branch (c5, id=100) should show "King Pawn -- Sicilian"
      // because c5's path goes through e4 (label) then c5 (label).
      expect(
        cache.getAggregateDisplayName(100),
        'King Pawn \u2014 Sicilian',
      );
    });

    test('returns label of the node itself if it is the only labeled node', () {
      // 1. e4 e5 2. Nf3 (label: "Main Line")
      final line = buildLine(
        ['e4', 'e5', 'Nf3'],
        labels: {2: 'Main Line'},
      );
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getAggregateDisplayName(3), 'Main Line');
    });
  });

  group('previewAggregateDisplayName', () {
    test('preview adding a label to an unlabeled node with no other labels', () {
      // 1. e4 e5 2. Nf3 -- no labels anywhere
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      // Preview adding a label to Nf3 (id=3)
      expect(cache.previewAggregateDisplayName(3, 'Main Line'), 'Main Line');
    });

    test('preview adding a label when ancestor has a label', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3
      final line = buildLine(
        ['e4', 'c5', 'Nf3'],
        labels: {0: 'Sicilian'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Preview adding label "Najdorf" to Nf3 (id=3)
      expect(
        cache.previewAggregateDisplayName(3, 'Najdorf'),
        'Sicilian \u2014 Najdorf',
      );
    });

    test('preview changing an existing label', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3 (label: "Open Sicilian")
      final line = buildLine(
        ['e4', 'c5', 'Nf3'],
        labels: {0: 'Sicilian', 2: 'Open Sicilian'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Preview changing Nf3's label from "Open Sicilian" to "Closed Sicilian"
      expect(
        cache.previewAggregateDisplayName(3, 'Closed Sicilian'),
        'Sicilian \u2014 Closed Sicilian',
      );
    });

    test('preview removing a label (null)', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3 (label: "Open Sicilian")
      final line = buildLine(
        ['e4', 'c5', 'Nf3'],
        labels: {0: 'Sicilian', 2: 'Open Sicilian'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Preview removing Nf3's label
      expect(cache.previewAggregateDisplayName(3, null), 'Sicilian');
    });

    test('preview on a deep node with multiple ancestor labels', () {
      // 1. e4 (label: "A") c5 (label: "B") 2. Nf3 d6 3. d4
      final line = buildLine(
        ['e4', 'c5', 'Nf3', 'd6', 'd4'],
        labels: {0: 'A', 1: 'B'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Preview adding label "C" to d4 (id=5)
      expect(
        cache.previewAggregateDisplayName(5, 'C'),
        'A \u2014 B \u2014 C',
      );
    });

    test('preview with empty string treated as no label', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3 (label: "Open Sicilian")
      final line = buildLine(
        ['e4', 'c5', 'Nf3'],
        labels: {0: 'Sicilian', 2: 'Open Sicilian'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Preview with empty string -- equivalent to removing the label
      expect(cache.previewAggregateDisplayName(3, ''), 'Sicilian');
    });
  });

  group('getMoveNotation', () {
    test('first move (ply 1) returns "1. e4" format', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getMoveNotation(1), '1. e4');
    });

    test('second move (ply 2) returns "1...e5" format', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getMoveNotation(2), '1...e5');
    });

    test('later moves compute correct move number', () {
      // 1. e4 e5 2. Nf3 Nc6 3. Bb5
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final cache = RepertoireTreeCache.build(line);

      // Ply 3 = move 2, white: "2. Nf3"
      expect(cache.getMoveNotation(3), '2. Nf3');
      // Ply 4 = move 2, black: "2...Nc6"
      expect(cache.getMoveNotation(4), '2...Nc6');
      // Ply 5 = move 3, white: "3. Bb5"
      expect(cache.getMoveNotation(5), '3. Bb5');
    });

    test('accepts plyCount parameter to avoid getLine call', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      // Pass plyCount=1 for the first move
      expect(cache.getMoveNotation(1, plyCount: 1), '1. e4');
      // Pass plyCount=2 for the second move
      expect(cache.getMoveNotation(2, plyCount: 2), '1...e5');
      // Pass plyCount=3 for the third move
      expect(cache.getMoveNotation(3, plyCount: 3), '2. Nf3');
    });

    test('works correctly for branching trees', () {
      // Main line: 1. e4 e5 2. Nf3
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);

      // Branch: 1. e4 c5 (from same parent as e5)
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      final posAfterC5 = pos.play(pos.parseSan('c5')!);

      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: 1, // e4
        fen: posAfterC5.fen,
        san: 'c5',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, branchMove];
      final cache = RepertoireTreeCache.build(allMoves);

      // c5 is at ply 2 (same as e5)
      expect(cache.getMoveNotation(100), '1...c5');
    });
  });

  group('getDescendantLabelImpact', () {
    test('returns empty list when no labeled descendants', () {
      // 1. e4 e5 2. Nf3 -- no labels anywhere
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getDescendantLabelImpact(1, 'King Pawn'), isEmpty);
    });

    test('returns one entry for a single labeled descendant', () {
      // 1. e4 (label: "A") e5 2. Nf3 (label: "B")
      final line = buildLine(
        ['e4', 'e5', 'Nf3'],
        labels: {0: 'A', 2: 'B'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Changing e4's label from "A" to "X"
      final impact = cache.getDescendantLabelImpact(1, 'X');

      expect(impact, hasLength(1));
      expect(impact[0].moveId, 3);
      expect(impact[0].before, 'A \u2014 B');
      expect(impact[0].after, 'X \u2014 B');
    });

    test('returns entries for multiple labeled descendants at different depths',
        () {
      // 1. e4 (label: "Root") e5 (label: "Mid") 2. Nf3 (label: "Leaf")
      final line = buildLine(
        ['e4', 'e5', 'Nf3'],
        labels: {0: 'Root', 1: 'Mid', 2: 'Leaf'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Changing e4's label from "Root" to "NewRoot"
      final impact = cache.getDescendantLabelImpact(1, 'NewRoot');

      expect(impact, hasLength(2));
      // e5 (id=2): "Root -- Mid" -> "NewRoot -- Mid"
      final e5Entry = impact.firstWhere((e) => e.moveId == 2);
      expect(e5Entry.before, 'Root \u2014 Mid');
      expect(e5Entry.after, 'NewRoot \u2014 Mid');
      // Nf3 (id=3): "Root -- Mid -- Leaf" -> "NewRoot -- Mid -- Leaf"
      final nf3Entry = impact.firstWhere((e) => e.moveId == 3);
      expect(nf3Entry.before, 'Root \u2014 Mid \u2014 Leaf');
      expect(nf3Entry.after, 'NewRoot \u2014 Mid \u2014 Leaf');
    });

    test('changing an existing label reflects before/after correctly', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3 (label: "Open")
      final line = buildLine(
        ['e4', 'c5', 'Nf3'],
        labels: {0: 'Sicilian', 2: 'Open'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Changing e4's label from "Sicilian" to "French"
      final impact = cache.getDescendantLabelImpact(1, 'French');

      expect(impact, hasLength(1));
      expect(impact[0].moveId, 3);
      expect(impact[0].before, 'Sicilian \u2014 Open');
      expect(impact[0].after, 'French \u2014 Open');
    });

    test('removing a label (null) causes descendants to lose the segment', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3 (label: "Open")
      final line = buildLine(
        ['e4', 'c5', 'Nf3'],
        labels: {0: 'Sicilian', 2: 'Open'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Removing e4's label
      final impact = cache.getDescendantLabelImpact(1, null);

      expect(impact, hasLength(1));
      expect(impact[0].moveId, 3);
      expect(impact[0].before, 'Sicilian \u2014 Open');
      expect(impact[0].after, 'Open');
    });

    test('no-op (same label) returns empty list', () {
      // 1. e4 (label: "Sicilian") c5 2. Nf3 (label: "Open")
      final line = buildLine(
        ['e4', 'c5', 'Nf3'],
        labels: {0: 'Sicilian', 2: 'Open'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Setting e4's label to the same value
      final impact = cache.getDescendantLabelImpact(1, 'Sicilian');

      expect(impact, isEmpty);
    });

    test('unlabeled descendants are not included', () {
      // 1. e4 (label: "A") e5 2. Nf3 -- e5 and Nf3 are unlabeled
      final line = buildLine(
        ['e4', 'e5', 'Nf3'],
        labels: {0: 'A'},
      );
      final cache = RepertoireTreeCache.build(line);

      // Changing e4's label from "A" to "B"
      final impact = cache.getDescendantLabelImpact(1, 'B');

      // e5 and Nf3 have no label of their own, so they're not reported
      expect(impact, isEmpty);
    });
  });

  group('findLabelConflicts', () {
    test('returns empty list when no other moves share the FEN', () {
      // 1. e4 e5 2. Nf3 -- all different FENs, no transpositions
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.findLabelConflicts(3, 'Some Label'), isEmpty);
    });

    test('returns empty list when other moves at same FEN have the same label',
        () {
      // Two lines reaching the same position with the same label.
      // 1. d4 Nf6 2. c4 e6 and 1. c4 e6 2. d4 Nf6 reach the same position.
      // Neither endpoint creates en-passant, so the normalized position keys match.
      final line1 =
          buildLine(['d4', 'Nf6', 'c4', 'e6'], labels: {3: 'Same'});
      final line2 = buildLine(['c4', 'e6', 'd4', 'Nf6'],
          startId: 100, labels: {3: 'Same'});
      final cache = RepertoireTreeCache.build([...line1, ...line2]);

      // e6 (id=4) and Nf6 (id=104) reach the same position; both labeled "Same"
      expect(cache.findLabelConflicts(4, 'Same'), isEmpty);
    });

    test('returns empty list when other moves at same FEN have null labels',
        () {
      // Two lines reaching the same position; the other has no label.
      final line1 = buildLine(['d4', 'Nf6', 'c4', 'e6']);
      final line2 =
          buildLine(['c4', 'e6', 'd4', 'Nf6'], startId: 100);
      final cache = RepertoireTreeCache.build([...line1, ...line2]);

      // e6 (id=4) and Nf6 (id=104) reach the same position; Nf6 has null label
      expect(cache.findLabelConflicts(4, 'New Label'), isEmpty);
    });

    test('detects conflict when another move at same FEN has a different label',
        () {
      // Two lines reaching the same position with different labels.
      final line1 = buildLine(['d4', 'Nf6', 'c4', 'e6'],
          labels: {3: 'QGD'});
      final line2 = buildLine(['c4', 'e6', 'd4', 'Nf6'],
          startId: 100, labels: {3: 'English'});
      final cache = RepertoireTreeCache.build([...line1, ...line2]);

      // From line1's e6 (id=4), wanting label "QGD"
      // line2's Nf6 (id=103) has label "English" at same position -> conflict
      final conflicts = cache.findLabelConflicts(4, 'QGD');
      expect(conflicts, hasLength(1));
      expect(conflicts.first.id, 103);
      expect(conflicts.first.label, 'English');
    });

    test('excludes the move itself from results', () {
      // A move should not conflict with itself.
      final line1 = buildLine(['d4', 'Nf6', 'c4', 'e6'],
          labels: {3: 'QGD'});
      final line2 = buildLine(['c4', 'e6', 'd4', 'Nf6'],
          startId: 100, labels: {3: 'English'});
      final cache = RepertoireTreeCache.build([...line1, ...line2]);

      // From line1's e6 (id=4), wanting label "Different"
      final conflicts = cache.findLabelConflicts(4, 'Different');
      // Only line2's Nf6 (id=103) should appear, not e6 (id=4) itself
      expect(conflicts, hasLength(1));
      expect(conflicts.first.id, 103);
    });

    test('returns multiple conflicts when multiple moves at same FEN have different labels',
        () {
      // Three lines reaching the same position, each with a different label.
      final line1 = buildLine(['d4', 'Nf6', 'c4', 'e6'],
          labels: {3: 'Label A'});
      final line2 = buildLine(['c4', 'e6', 'd4', 'Nf6'],
          startId: 100, labels: {3: 'Label B'});
      // Third line via different move order reaching same position:
      // 1. c4 Nf6 2. d4 e6
      final line3 = buildLine(['c4', 'Nf6', 'd4', 'e6'],
          startId: 200, labels: {3: 'Label C'});
      final cache =
          RepertoireTreeCache.build([...line1, ...line2, ...line3]);

      // From line1's e6 (id=4), wanting label "New"
      // line2's Nf6 (id=103, label "Label B") and line3's e6 (id=203, label "Label C")
      // are at the same position with different labels
      final conflicts = cache.findLabelConflicts(4, 'New');
      expect(conflicts, hasLength(2));
      final conflictIds = conflicts.map((c) => c.id).toSet();
      expect(conflictIds, containsAll([103, 203]));
    });

    test('returns empty list when newLabel is null', () {
      // Clearing a label should never be treated as a conflict.
      final line1 = buildLine(['d4', 'Nf6', 'c4', 'e6'],
          labels: {3: 'QGD'});
      final line2 = buildLine(['c4', 'e6', 'd4', 'Nf6'],
          startId: 100, labels: {3: 'English'});
      final cache = RepertoireTreeCache.build([...line1, ...line2]);

      expect(cache.findLabelConflicts(4, null), isEmpty);
    });

    test('returns empty list for unknown moveId', () {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.findLabelConflicts(999, 'Label'), isEmpty);
    });
  });

  group('getPathDescription', () {
    test('returns notation for a single move', () {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getPathDescription(1), '1. e4');
    });

    test('returns full path for a deep move', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getPathDescription(3), '1. e4 1...e5 2. Nf3');
    });

    test('returns correct notation for black moves', () {
      final line = buildLine(['e4', 'c5']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.getPathDescription(2), '1. e4 1...c5');
    });
  });

  group('countDescendantLeaves', () {
    test('a leaf node returns 1 (itself)', () {
      // 1. e4 e5 2. Nf3  -- Nf3 (id=3) is a leaf
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.countDescendantLeaves(3), 1);
    });

    test('a node with one child that is a leaf returns 1', () {
      // 1. e4 e5  -- e4 (id=1) has one child e5 (id=2) which is a leaf
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.countDescendantLeaves(1), 1);
    });

    test('a node with two children that are both leaves returns 2', () {
      // Main line: 1. e4 e5
      final mainLine = buildLine(['e4', 'e5']);

      // Branch from e4: 1. e4 c5
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      final posAfterC5 = pos.play(pos.parseSan('c5')!);

      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: 1, // e4
        fen: posAfterC5.fen,
        san: 'c5',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, branchMove];
      final cache = RepertoireTreeCache.build(allMoves);

      // e4 (id=1) has two children: e5 (leaf) and c5 (leaf)
      expect(cache.countDescendantLeaves(1), 2);
    });

    test('deep tree with branches returns correct count', () {
      // Main line: 1. e4 e5 2. Nf3
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);

      // Branch from e4: 1. e4 c5 2. Nf3
      // Must manually construct because buildLine always starts from initial.
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      final posAfterC5 = pos.play(pos.parseSan('c5')!);
      final posAfterC5Nf3 = posAfterC5.play(posAfterC5.parseSan('Nf3')!);

      final branch = [
        RepertoireMove(
          id: 100,
          repertoireId: 1,
          parentMoveId: 1, // branch from e4
          fen: posAfterC5.fen,
          san: 'c5',
          sortOrder: 1,
        ),
        RepertoireMove(
          id: 101,
          repertoireId: 1,
          parentMoveId: 100,
          fen: posAfterC5Nf3.fen,
          san: 'Nf3',
          sortOrder: 0,
        ),
      ];

      // Second branch from e4: 1. e4 d5
      final posAfterD5 = pos.play(pos.parseSan('d5')!);
      final branch2 = [
        RepertoireMove(
          id: 200,
          repertoireId: 1,
          parentMoveId: 1, // branch from e4
          fen: posAfterD5.fen,
          san: 'd5',
          sortOrder: 2,
        ),
      ];

      final allMoves = [...mainLine, ...branch, ...branch2];
      final cache = RepertoireTreeCache.build(allMoves);

      // e4 has 3 descendant leaves: Nf3 (id=3), Nf3 (id=101), d5 (id=200)
      expect(cache.countDescendantLeaves(1), 3);
    });

    test('root node of a multi-branch tree returns total number of leaves', () {
      // Two lines from the root:
      // Line 1: 1. e4 e5
      // Line 2: 1. d4 d5
      final line1 = buildLine(['e4', 'e5']);
      final line2 = buildLine(['d4', 'd5'], startId: 100);

      final allMoves = [...line1, ...line2];
      final cache = RepertoireTreeCache.build(allMoves);

      // e4 subtree has 1 leaf (e5), d4 subtree has 1 leaf (d5)
      // Each root is independent, so check each root individually:
      expect(cache.countDescendantLeaves(1), 1); // e4 -> e5 (leaf)
      expect(cache.countDescendantLeaves(100), 1); // d4 -> d5 (leaf)
    });

    test('returns 0 for unknown moveId', () {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);

      expect(cache.countDescendantLeaves(999), 0);
    });
  });
}
