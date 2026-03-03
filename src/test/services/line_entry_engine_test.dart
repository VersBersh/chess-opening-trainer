import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/models/repertoire.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/services/line_entry_engine.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Plays a sequence of SAN moves from the initial position and returns a list
/// of [RepertoireMove] objects with sequential IDs, proper parent linkage, and
/// accurate FEN strings.
///
/// Reused from drill_engine_test.dart pattern.
List<RepertoireMove> buildLine(
  List<String> sans, {
  int repertoireId = 1,
  int startId = 1,
  int? startParentId,
  String? label,
  int sortOrder = 0,
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
      sortOrder: i == 0 ? sortOrder : 0,
    ));

    parentId = id;
  }

  return moves;
}

/// Builds a line with a label on the specified move (by SAN).
List<RepertoireMove> buildLineWithLabel(
  List<String> sans, {
  required String labelOnSan,
  required String label,
  int repertoireId = 1,
  int startId = 1,
  int? startParentId,
  int sortOrder = 0,
}) {
  final moves = buildLine(
    sans,
    repertoireId: repertoireId,
    startId: startId,
    startParentId: startParentId,
    sortOrder: sortOrder,
  );

  return moves.map((m) {
    if (m.san == labelOnSan) {
      return RepertoireMove(
        id: m.id,
        repertoireId: m.repertoireId,
        parentMoveId: m.parentMoveId,
        fen: m.fen,
        san: m.san,
        label: label,
        sortOrder: m.sortOrder,
      );
    }
    return m;
  }).toList();
}

/// Plays a sequence of SAN moves from a given FEN position and returns FENs.
/// Useful for computing expected FENs in tests.
List<String> computeFens(List<String> sans, {String startFen = kInitialFEN}) {
  final fens = <String>[];
  Position position = Chess.fromSetup(Setup.parseFen(startFen));
  for (final san in sans) {
    final parsed = position.parseSan(san);
    position = position.play(parsed!);
    fens.add(position.fen);
  }
  return fens;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Follow existing branch', () {
    test('user plays a move that exists as a root move in the tree', () {
      // Tree: 1. e4
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      final result = engine.acceptMove('e4', line[0].fen);

      expect(result, isA<FollowedExistingMove>());
      expect(engine.followedMoves.length, 1);
      expect(engine.followedMoves.first.san, 'e4');
      expect(engine.bufferedMoves, isEmpty);
      expect(engine.hasDiverged, false);
    });
  });

  group('Diverge from existing branch', () {
    test('user follows two moves then plays a non-existing move', () {
      // Tree: 1. e4 e5 2. Nf3
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4 and e5
      engine.acceptMove('e4', line[0].fen);
      engine.acceptMove('e5', line[1].fen);
      expect(engine.hasDiverged, false);
      expect(engine.followedMoves.length, 2);

      // Play d4 (not in tree) -- diverge
      final fens = computeFens(['e4', 'e5', 'd4']);
      final result = engine.acceptMove('d4', fens[2]);

      expect(result, isA<NewMoveBuffered>());
      expect(engine.hasDiverged, true);
      expect(engine.bufferedMoves.length, 1);
      expect(engine.bufferedMoves.first.san, 'd4');
    });
  });

  group('Buffer multiple new moves', () {
    test('after diverging, all subsequent moves go into buffer', () {
      // Tree: 1. e4
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4
      engine.acceptMove('e4', line[0].fen);

      // Play d5 (not in tree -- diverge)
      final fens = computeFens(['e4', 'd5', 'Nf3']);
      engine.acceptMove('d5', fens[1]);
      expect(engine.hasDiverged, true);
      expect(engine.bufferedMoves.length, 1);

      // Play Nf3 (still buffered since we diverged)
      engine.acceptMove('Nf3', fens[2]);
      expect(engine.bufferedMoves.length, 2);
      expect(engine.bufferedMoves[1].san, 'Nf3');
    });
  });

  group('Start from a mid-tree position', () {
    test('engine starts from a deep node and follows children from there', () {
      // Tree: 1. e4 e5 2. Nf3 Nc6 3. Bb5
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final cache = RepertoireTreeCache.build(line);

      // Start from Nc6 (id=4)
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: 4,
      );

      // existingPath should be [e4, e5, Nf3, Nc6]
      expect(engine.existingPath.length, 4);
      expect(engine.existingPath.last.san, 'Nc6');
      expect(engine.lastExistingMoveId, 4);

      // Playing Bb5 (exists as child of Nc6) should follow it
      final result = engine.acceptMove('Bb5', line[4].fen);
      expect(result, isA<FollowedExistingMove>());
      expect(engine.followedMoves.length, 1);
    });
  });

  group('Start from root (null startingMoveId)', () {
    test('engine starts at initial position and checks root moves', () {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      expect(engine.existingPath, isEmpty);
      expect(engine.lastExistingMoveId, isNull);

      // Play e4 (exists as root move)
      final result = engine.acceptMove('e4', line[0].fen);
      expect(result, isA<FollowedExistingMove>());
      expect(engine.lastExistingMoveId, 1);
    });
  });

  group('Take-back removes buffered moves only', () {
    test('take-back 3 buffered moves returns correct FENs', () {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4
      engine.acceptMove('e4', line[0].fen);

      // Buffer 3 new moves
      final fens = computeFens(['e4', 'd5', 'exd5', 'Qxd5']);
      engine.acceptMove('d5', fens[1]);
      engine.acceptMove('exd5', fens[2]);
      engine.acceptMove('Qxd5', fens[3]);

      expect(engine.canTakeBack(), true);

      // Take back Qxd5 -> revert to exd5 FEN
      final r1 = engine.takeBack();
      expect(r1, isNotNull);
      expect(r1!.fen, fens[2]);
      expect(engine.bufferedMoves.length, 2);

      // Take back exd5 -> revert to d5 FEN
      final r2 = engine.takeBack();
      expect(r2!.fen, fens[1]);
      expect(engine.bufferedMoves.length, 1);

      // Take back d5 -> revert to e4 FEN (last followed move)
      final r3 = engine.takeBack();
      expect(r3!.fen, line[0].fen);
      expect(engine.bufferedMoves, isEmpty);

      // No more take-backs
      expect(engine.canTakeBack(), false);
    });
  });

  group('Take-back at branch boundary', () {
    test('canTakeBack is false when only following existing moves', () {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow existing moves
      engine.acceptMove('e4', line[0].fen);
      engine.acceptMove('e5', line[1].fen);

      expect(engine.canTakeBack(), false);
    });
  });

  group('Parity validation', () {
    test('matching: 3-ply line (white) with board oriented white', () {
      // Tree: 1. e4 e5 2. Nf3 (3 plies)
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow all 3 moves
      for (final m in line) {
        engine.acceptMove(m.san, m.fen);
      }

      expect(engine.totalPly, 3);
      final result = engine.validateParity(Side.white);
      expect(result, isA<ParityMatch>());
    });

    test('mismatch: 3-ply line (white) with board oriented black', () {
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      for (final m in line) {
        engine.acceptMove(m.san, m.fen);
      }

      final result = engine.validateParity(Side.black);
      expect(result, isA<ParityMismatch>());
      expect(
        (result as ParityMismatch).expectedOrientation,
        Side.white,
      );
    });

    test('even ply: 4-ply line (black) with board oriented black', () {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      for (final m in line) {
        engine.acceptMove(m.san, m.fen);
      }

      expect(engine.totalPly, 4);
      final result = engine.validateParity(Side.black);
      expect(result, isA<ParityMatch>());
    });
  });

  group('getConfirmData', () {
    test('isExtension true when last existing move is a leaf', () {
      // Tree: 1. e4 (leaf)
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4 (leaf), then buffer e5
      engine.acceptMove('e4', line[0].fen);
      final fens = computeFens(['e4', 'e5']);
      engine.acceptMove('e5', fens[1]);

      final data = engine.getConfirmData();
      expect(data.parentMoveId, 1);
      expect(data.isExtension, true);
    });

    test('isExtension false when last existing move has children', () {
      // Tree: 1. e4 e5 (e4 has child e5, so not a leaf)
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4, then buffer d5 (branching from non-leaf)
      engine.acceptMove('e4', line[0].fen);
      final fens = computeFens(['e4', 'd5']);
      engine.acceptMove('d5', fens[1]);

      final data = engine.getConfirmData();
      expect(data.parentMoveId, 1);
      expect(data.isExtension, false);
    });

    test('null parentMoveId when starting from root with no existing moves followed', () {
      // Empty tree
      final cache = RepertoireTreeCache.build([]);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Buffer a move from root
      final fens = computeFens(['e4']);
      engine.acceptMove('e4', fens[0]);

      final data = engine.getConfirmData();
      expect(data.parentMoveId, isNull);
      expect(data.isExtension, false);
    });

    test('sortOrder when branching from a parent with 2 existing children', () {
      // Tree: 1. e4 with children e5 and c5
      final mainLine = buildLine(['e4', 'e5']);
      // Get the FEN after e4 to compute branch correctly
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      pos = pos.play(pos.parseSan('c5')!);
      final c5WithCorrectFen = RepertoireMove(
        id: 10,
        repertoireId: 1,
        parentMoveId: 1,
        fen: pos.fen,
        san: 'c5',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, c5WithCorrectFen];
      final cache = RepertoireTreeCache.build(allMoves);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4, then diverge with d5
      engine.acceptMove('e4', mainLine[0].fen);
      final fens = computeFens(['e4', 'd5']);
      engine.acceptMove('d5', fens[1]);

      final data = engine.getConfirmData();
      // e4 has 2 children (e5, c5), so sortOrder is 2
      expect(data.sortOrder, 2);
    });

    test('sortOrder when inserting a new root move with 1 existing root', () {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Diverge immediately (play d4 instead of following e4)
      final fens = computeFens(['d4']);
      engine.acceptMove('d4', fens[0]);

      final data = engine.getConfirmData();
      expect(data.parentMoveId, isNull);
      // 1 existing root move (e4), so sortOrder is 1
      expect(data.sortOrder, 1);
    });

    test('sortOrder is 0 when extending a leaf (no siblings)', () {
      // Tree: 1. e4 (leaf, no siblings at child level)
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4 (leaf), then buffer e5
      engine.acceptMove('e4', line[0].fen);
      final fens = computeFens(['e4', 'e5']);
      engine.acceptMove('e5', fens[1]);

      final data = engine.getConfirmData();
      expect(data.isExtension, true);
      // e4 is a leaf with 0 children, so sortOrder is 0
      expect(data.sortOrder, 0);
    });
  });

  group('hasNewMoves', () {
    test('false when only following existing moves', () {
      final line = buildLine(['e4', 'e5']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      engine.acceptMove('e4', line[0].fen);
      engine.acceptMove('e5', line[1].fen);

      expect(engine.hasNewMoves, false);
    });

    test('true after buffering at least one move', () {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      engine.acceptMove('e4', line[0].fen);
      final fens = computeFens(['e4', 'e5']);
      engine.acceptMove('e5', fens[1]);

      expect(engine.hasNewMoves, true);
    });
  });

  group('Empty line entry', () {
    test('entering edit mode and immediately checking -- no new moves', () {
      final line = buildLine(['e4']);
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      expect(engine.hasNewMoves, false);
    });
  });

  group('totalPly', () {
    test('counts existingPath + followedMoves + bufferedMoves', () {
      // Tree: 1. e4 e5 2. Nf3
      final line = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(line);

      // Start from e5 (id=2)
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: 2,
      );

      // existingPath = [e4, e5] = 2
      expect(engine.existingPath.length, 2);

      // Follow Nf3
      engine.acceptMove('Nf3', line[2].fen);
      // followedMoves = [Nf3] = 1

      // Buffer Nc6
      final fens = computeFens(['e4', 'e5', 'Nf3', 'Nc6']);
      engine.acceptMove('Nc6', fens[3]);
      // bufferedMoves = [Nc6] = 1

      expect(engine.totalPly, 4); // 2 + 1 + 1
    });
  });

  group('getCurrentDisplayName', () {
    test('returns empty string when no existing moves followed', () {
      final cache = RepertoireTreeCache.build([]);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      expect(engine.getCurrentDisplayName(), '');
    });

    test('returns aggregate display name based on labels', () {
      final line = buildLineWithLabel(
        ['e4', 'e5'],
        labelOnSan: 'e4',
        label: 'King Pawn',
      );
      final cache = RepertoireTreeCache.build(line);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Follow e4
      engine.acceptMove('e4', line[0].fen);
      expect(engine.getCurrentDisplayName(), 'King Pawn');
    });
  });

  group('Take-back resets to initial position from root', () {
    test('take-back with no followed moves reverts to kInitialFEN', () {
      // Empty tree, buffer one move from root
      final cache = RepertoireTreeCache.build([]);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      final fens = computeFens(['e4']);
      engine.acceptMove('e4', fens[0]);
      expect(engine.canTakeBack(), true);

      final result = engine.takeBack();
      expect(result, isNotNull);
      expect(result!.fen, kInitialFEN);
      expect(engine.canTakeBack(), false);
    });
  });

  // ---- SAN computation integration tests (Step 11) -----------------------
  //
  // These verify the dartchess `makeSan` destructuring pattern used in the
  // browser screen's `_onEditModeMove` handler.

  group('Buffered move labels', () {
    test('setBufferedLabel mutates label on the correct buffered move', () {
      final cache = RepertoireTreeCache.build([]);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Buffer two moves.
      final fens = computeFens(['e4', 'e5']);
      engine.acceptMove('e4', fens[0]);
      engine.acceptMove('e5', fens[1]);

      expect(engine.bufferedMoves[0].label, isNull);
      expect(engine.bufferedMoves[1].label, isNull);

      // Set label on the first buffered move.
      engine.setBufferedLabel(0, 'King Pawn');

      expect(engine.bufferedMoves[0].label, 'King Pawn');
      expect(engine.bufferedMoves[1].label, isNull);

      // Set label on the second buffered move.
      engine.setBufferedLabel(1, 'Open Game');

      expect(engine.bufferedMoves[0].label, 'King Pawn');
      expect(engine.bufferedMoves[1].label, 'Open Game');
    });

    test('reapplyBufferedLabels restores labels after replay', () {
      final cache = RepertoireTreeCache.build([]);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Buffer two moves and label them.
      final fens = computeFens(['e4', 'e5']);
      engine.acceptMove('e4', fens[0]);
      engine.acceptMove('e5', fens[1]);
      engine.setBufferedLabel(0, 'King Pawn');
      engine.setBufferedLabel(1, 'Open Game');

      // Snapshot labels.
      final labels = engine.bufferedMoves.map((b) => b.label).toList();

      // Simulate replay: create fresh engine and re-buffer.
      final engine2 = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );
      engine2.acceptMove('e4', fens[0]);
      engine2.acceptMove('e5', fens[1]);

      // Fresh moves have no labels.
      expect(engine2.bufferedMoves[0].label, isNull);
      expect(engine2.bufferedMoves[1].label, isNull);

      // Reapply labels from snapshot.
      engine2.reapplyBufferedLabels(labels);

      expect(engine2.bufferedMoves[0].label, 'King Pawn');
      expect(engine2.bufferedMoves[1].label, 'Open Game');
    });

    test('buffered move labels survive take-back of later moves', () {
      final cache = RepertoireTreeCache.build([]);
      final engine = LineEntryEngine(
        treeCache: cache,
        repertoireId: 1,
        startingMoveId: null,
      );

      // Buffer three moves and label the first two.
      final fens = computeFens(['e4', 'e5', 'Nf3']);
      engine.acceptMove('e4', fens[0]);
      engine.acceptMove('e5', fens[1]);
      engine.acceptMove('Nf3', fens[2]);

      engine.setBufferedLabel(0, 'King Pawn');
      engine.setBufferedLabel(1, 'Open Game');

      // Take back Nf3.
      engine.takeBack();

      expect(engine.bufferedMoves.length, 2);
      expect(engine.bufferedMoves[0].label, 'King Pawn');
      expect(engine.bufferedMoves[1].label, 'Open Game');

      // Take back e5.
      engine.takeBack();

      expect(engine.bufferedMoves.length, 1);
      expect(engine.bufferedMoves[0].label, 'King Pawn');
    });
  });

  group('SAN computation from NormalMove + position', () {
    test('standard move: e2-e4 from initial position produces "e4"', () {
      final position = Chess.initial;
      final move = NormalMove(from: Square.e2, to: Square.e4);
      final (_, san) = position.makeSan(move);
      expect(san, 'e4');
    });

    test('knight move: Nf3 from initial position produces "Nf3"', () {
      // Play e4 e5 first, then Nf3
      Position pos = Chess.initial;
      pos = pos.play(NormalMove(from: Square.e2, to: Square.e4));
      pos = pos.play(NormalMove(from: Square.e7, to: Square.e5));
      final move = NormalMove(from: Square.g1, to: Square.f3);
      final (_, san) = pos.makeSan(move);
      expect(san, 'Nf3');
    });

    test('capture: exd5 produces correct SAN', () {
      // Play 1. e4 d5 to set up the capture
      Position pos = Chess.initial;
      pos = pos.play(NormalMove(from: Square.e2, to: Square.e4));
      pos = pos.play(NormalMove(from: Square.d7, to: Square.d5));
      final move = NormalMove(from: Square.e4, to: Square.d5);
      final (_, san) = pos.makeSan(move);
      expect(san, 'exd5');
    });

    test('promotion: a7-a8=Q produces "a8=Q"', () {
      // Set up a position where a white pawn is on a7 ready to promote
      // Black king on e6 is not on any line from a8 after promotion
      final setup = Setup.parseFen(
          '8/P7/4k3/8/8/8/8/4K3 w - - 0 1');
      final pos = Chess.fromSetup(setup);
      final move = NormalMove(
        from: Square.a7,
        to: Square.a8,
        promotion: Role.queen,
      );
      final (_, san) = pos.makeSan(move);
      expect(san, 'a8=Q');
    });

    test('bishop move: Bb5 in Ruy Lopez produces "Bb5" (no check)', () {
      // Play 1. e4 e5 2. Nf3 Nc6 to set up 3. Bb5
      Position pos = Chess.initial;
      pos = pos.play(NormalMove(from: Square.e2, to: Square.e4));
      pos = pos.play(NormalMove(from: Square.e7, to: Square.e5));
      pos = pos.play(NormalMove(from: Square.g1, to: Square.f3));
      pos = pos.play(NormalMove(from: Square.b8, to: Square.c6));
      final move = NormalMove(from: Square.f1, to: Square.b5);
      final (_, san) = pos.makeSan(move);
      expect(san, 'Bb5');
    });

    test('check: Qxf7+ produces SAN with + suffix', () {
      // Position with Qf3, after 1. e4 e5 2. Qf3. Qxf7 is check.
      final checkSetup = Setup.parseFen(
          'rnbqkbnr/pppp1ppp/8/4p3/4P3/5Q2/PPPP1PPP/RNB1KBNR w KQkq - 0 1');
      final checkPos = Chess.fromSetup(checkSetup);
      final checkMove = NormalMove(from: Square.f3, to: Square.f7);
      final (_, checkSan) = checkPos.makeSan(checkMove);
      expect(checkSan, 'Qxf7+');
    });
  });
}
