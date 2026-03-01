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
}
