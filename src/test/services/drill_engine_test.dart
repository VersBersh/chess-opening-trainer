import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/models/repertoire.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/services/drill_engine.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Plays a sequence of SAN moves from the initial position and returns a list
/// of [RepertoireMove] objects with sequential IDs, proper parent linkage, and
/// accurate FEN strings.
///
/// [repertoireId] defaults to 1. [startId] allows controlling the starting ID
/// (useful when building trees with multiple branches).
List<RepertoireMove> buildLine(
  List<String> sans, {
  int repertoireId = 1,
  int startId = 1,
  int? startParentId,
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
      sortOrder: 0,
    ));

    parentId = id;
  }

  return moves;
}

/// Creates a [ReviewCard] pointing to the leaf of the given [lineMoves].
ReviewCard buildReviewCard(List<RepertoireMove> lineMoves, {int cardId = 1}) {
  return ReviewCard(
    id: cardId,
    repertoireId: lineMoves.first.repertoireId,
    leafMoveId: lineMoves.last.id,
    easeFactor: 2.5,
    intervalDays: 0,
    repetitions: 0,
    nextReviewDate: DateTime(2026, 1, 1),
  );
}

/// Builds a [DrillEngine] for a single-card session using the given line.
///
/// [allMoves] should contain *all* moves in the tree (including branches).
/// [lineMoves] is the specific line being drilled.
DrillEngine buildEngine(
  List<RepertoireMove> allMoves,
  List<RepertoireMove> lineMoves, {
  bool isExtraPractice = false,
  int cardId = 1,
}) {
  final card = buildReviewCard(lineMoves, cardId: cardId);
  final cache = RepertoireTreeCache.build(allMoves);
  return DrillEngine(
    cards: [card],
    treeCache: cache,
    isExtraPractice: isExtraPractice,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // A reusable white line (9 plies, odd = white):
  // 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O
  // White (user) moves at indices 0, 2, 4, 6, 8 (e4, Nf3, Bb5, Ba4, O-O)
  // Black (opponent) moves at indices 1, 3, 5, 7 (e5, Nc6, a6, Nf6)
  final whiteLine9 =
      buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);

  // A white line with exactly 3 user moves (5 plies, odd = white):
  // 1. e4 e5 2. Nf3 Nc6 3. Bb5
  // 3 white user moves (e4, Nf3, Bb5). Cap = entire line auto-played.
  final whiteLine5 = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);

  // A short white line (3 plies, odd = white): 1. e4 e5 2. Nf3
  // 2 user moves (e4, Nf3), below the 3-move cap.
  final shortWhiteLine = buildLine(['e4', 'e5', 'Nf3']);

  // A single-move white line: 1. e4
  final singleMoveWhiteLine = buildLine(['e4']);

  // A black line (even ply count): 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6
  // 8 plies => even => black line.
  // Black user moves at indices 1, 3, 5, 7 (e5, Nc6, a6, Nf6)
  // White opponent moves at indices 0, 2, 4, 6 (e4, Nf3, Bb5, Ba4)
  final blackLine8Ply =
      buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6']);

  group('Intro move calculation', () {
    test('stops at first branch point for user color (white)', () {
      // White line (9 plies) with branch at index 4 (3. Bb5 vs 3. Bc4).
      // User is white (odd ply count), user moves at even indices.
      // The branch is at the user's 3rd move: parent Nc6 (id=4) has two children.
      final mainLine = whiteLine9;

      // Build the branch move starting from the same parent as Bb5.
      // Bb5's parent is Nc6 (id=4). We need a sibling move from the same
      // parent.
      // Play 1. e4 e5 2. Nf3 Nc6 to get the position after Nc6
      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      // Now play 3. Bc4 from this position
      final bc4Move = pos.parseSan('Bc4')!;
      final posAfterBc4 = pos.play(bc4Move);

      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: 4, // same parent as Bb5 (Nc6)
        fen: posAfterBc4.fen,
        san: 'Bc4',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, branchMove];
      final engine = buildEngine(allMoves, mainLine);
      engine.startCard();

      // Branch is at index 4 (white's 3rd move, Bb5 vs Bc4).
      // introEndIndex should be 4 — user plays from index 4 onward.
      expect(engine.introMoves.length, 4);
      expect(engine.currentCardState!.introEndIndex, 4);
      // Intro is: e4, e5, Nf3, Nc6 (the 4 moves before the branch)
      expect(engine.introMoves.map((m) => m.san).toList(),
          ['e4', 'e5', 'Nf3', 'Nc6']);
    });

    test('stops at cap (3 user moves) even without branch', () {
      // 9-ply white line with no branches. Cap is 3 user moves.
      // User moves (white) at even indices: 0 (e4), 2 (Nf3), 4 (Bb5).
      // After 3rd user move (Bb5, index 4), also auto-play opponent response
      // at index 5 (a6). Next user move is at index 6 (Ba4).
      // introEndIndex should be 6.
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      expect(engine.currentCardState!.introEndIndex, 6);
      expect(engine.introMoves.map((m) => m.san).toList(),
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6']);
    });

    test('line with single branch -- no intro ambiguity (stops at cap)', () {
      // Review issue #4: a line with no branches at all should stop at the
      // 3-user-move cap, not at a non-existent branch point.
      // 9 plies (odd = white): 1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3
      final straightLine =
          buildLine(['d4', 'd5', 'c4', 'e6', 'Nc3', 'Nf6', 'Bg5', 'Be7', 'e3']);
      final engine = buildEngine(straightLine, straightLine);
      engine.startCard();

      // White user moves at 0 (d4), 2 (c4), 4 (Nc3) -> cap reached.
      // Next user move after cap + opponent response is index 6 (Bg5).
      expect(engine.currentCardState!.introEndIndex, 6);
    });

    test('black lines: opponent moves first, cap counts user moves only', () {
      // 8-ply black line. User is black.
      // White (opponent) moves at indices 0, 2, 4, 6
      // Black (user) moves at indices 1, 3, 5, 7
      // User moves: index 1 (e5), 3 (Nc6), 5 (a6) -> 3 user moves at cap.
      // After cap, next user move: for j in 6..7, index 7 is user turn.
      // So also auto-play index 6 (Ba4, opponent). introEndIndex = 7.
      final engine = buildEngine(blackLine8Ply, blackLine8Ply);
      engine.startCard();

      expect(engine.userColor, Side.black);
      expect(engine.currentCardState!.introEndIndex, 7);
      expect(engine.introMoves.map((m) => m.san).toList(),
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4']);
    });

    test('very short line (fewer moves than cap): entire line is intro', () {
      // 3-ply white line: 1. e4 e5 2. Nf3. Only 2 user moves (e4, Nf3),
      // below the 3-move cap. Loop exits and returns lineMoves.length.
      final engine = buildEngine(shortWhiteLine, shortWhiteLine);
      engine.startCard();

      expect(engine.currentCardState!.introEndIndex, shortWhiteLine.length);
      expect(engine.introMoves.length, 3);
    });

    test('single move line is entirely auto-played', () {
      // 1-ply white line: 1. e4. Only 1 user move, no branches.
      final engine = buildEngine(singleMoveWhiteLine, singleMoveWhiteLine);
      engine.startCard();

      expect(engine.currentCardState!.introEndIndex, 1);
      expect(engine.currentCardState!.currentMoveIndex, 1);
      // Line starts already complete
      expect(
          engine.currentCardState!.currentMoveIndex >=
              engine.currentCardState!.lineMoves.length,
          true);
    });

    test(
        'entirely auto-played: line with exactly 3 user moves and no remaining '
        'user moves after cap (5-ply white line)', () {
      // Review issue #1: 5-ply white line 1. e4 e5 2. Nf3 Nc6 3. Bb5
      // White user moves: index 0 (e4), 2 (Nf3), 4 (Bb5) -> 3 user moves.
      // After cap, no more user moves -> introEndIndex = lineMoves.length = 5.
      // The card starts already complete.
      final engine = buildEngine(whiteLine5, whiteLine5);
      engine.startCard();

      expect(engine.currentCardState!.introEndIndex, 5);
      expect(
          engine.currentCardState!.currentMoveIndex >=
              engine.currentCardState!.lineMoves.length,
          true);
    });
  });

  group('submitMove -- correct move', () {
    test('returns CorrectMove with isLineComplete: false when line continues', () {
      // 9-ply white line, intro ends at index 6 (Ba4).
      // User plays Ba4 (index 6, white). Next is Nf6 (index 7, black = opponent).
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      final result = engine.submitMove('Ba4');

      expect(result, isA<CorrectMove>());
      final correct = result as CorrectMove;
      expect(correct.isLineComplete, false);
      // Opponent response auto-played (Nf6)
      expect(correct.opponentResponse, isNotNull);
      expect(correct.opponentResponse!.san, 'Nf6');
    });

    test('returns CorrectMove with opponentResponse when next move is opponent turn', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      // User plays Ba4 (index 6). Opponent response is Nf6 (index 7).
      final result = engine.submitMove('Ba4') as CorrectMove;
      expect(result.opponentResponse!.san, 'Nf6');
      // currentMoveIndex should now be at 8 (after auto-playing opponent)
      expect(engine.currentCardState!.currentMoveIndex, 8);
    });

    test('returns CorrectMove with isLineComplete: true on final move', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      // Play Ba4 -> opponent Nf6 auto-played. currentMoveIndex = 8.
      engine.submitMove('Ba4');
      // Play O-O (index 8, final user move). currentMoveIndex = 9 = length.
      // No opponent response since the line ends on a user move.
      final result = engine.submitMove('O-O') as CorrectMove;
      expect(result.isLineComplete, true);
      expect(result.opponentResponse, isNull);
    });

    test('advances currentMoveIndex correctly', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      expect(engine.currentCardState!.currentMoveIndex, 6); // intro end
      engine.submitMove('Ba4'); // user move + opponent auto-play
      expect(engine.currentCardState!.currentMoveIndex, 8);
    });

    test('returns CorrectMove without opponentResponse when next is user turn', () {
      // Black line: user is black. After intro (ends at index 7, last user move),
      // user plays Nf6 (index 7). After Nf6, line is complete (8 plies).
      final engine = buildEngine(blackLine8Ply, blackLine8Ply);
      engine.startCard();

      // introEndIndex = 7. User plays Nf6 (index 7).
      final result = engine.submitMove('Nf6') as CorrectMove;
      expect(result.isLineComplete, true);
      // No opponent response because line is complete.
      expect(result.opponentResponse, isNull);
    });

    test('correct move on user turn without opponent follow-up returns no opponentResponse', () {
      // Build a 12-ply black line (even length -> black).
      // 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5
      final blackLine12 = buildLine([
        'e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6',
        'Ba4', 'Nf6', 'O-O', 'Be7', 'Re1', 'b5',
      ]);
      final engine = buildEngine(blackLine12, blackLine12);
      engine.startCard();

      // Black line, 12 plies. User is black.
      // Black user moves at 1, 3, 5, 7, 9, 11.
      // Cap at 3 user moves: indices 1 (e5), 3 (Nc6), 5 (a6).
      // After cap, find next user move: index 7 (Nf6). Also auto-play index 6
      // (Ba4). introEndIndex = 7.
      expect(engine.currentCardState!.introEndIndex, 7);

      // User plays Nf6 (index 7, black). Next is O-O (index 8, white = opponent).
      final result = engine.submitMove('Nf6') as CorrectMove;
      expect(result.isLineComplete, false);
      expect(result.opponentResponse!.san, 'O-O');

      // User plays Be7 (index 9, black). Next is Re1 (index 10, white = opponent).
      final result2 = engine.submitMove('Be7') as CorrectMove;
      expect(result2.isLineComplete, false);
      expect(result2.opponentResponse!.san, 'Re1');

      // User plays b5 (index 11, black). Line is complete.
      final result3 = engine.submitMove('b5') as CorrectMove;
      expect(result3.isLineComplete, true);
      expect(result3.opponentResponse, isNull);
    });
  });

  group('submitMove -- wrong move', () {
    test('returns WrongMove with expected SAN', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      // Expected move at index 6 is Ba4. Play something wrong.
      final result = engine.submitMove('Bc4');

      expect(result, isA<WrongMove>());
      expect((result as WrongMove).expectedSan, 'Ba4');
    });

    test('increments mistakeCount', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      expect(engine.currentCardState!.mistakeCount, 0);
      engine.submitMove('Bc4'); // wrong
      expect(engine.currentCardState!.mistakeCount, 1);
      engine.submitMove('Bc4'); // wrong again
      expect(engine.currentCardState!.mistakeCount, 2);
    });

    test('does not advance currentMoveIndex', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      final indexBefore = engine.currentCardState!.currentMoveIndex;
      engine.submitMove('Bc4'); // wrong
      expect(engine.currentCardState!.currentMoveIndex, indexBefore);
    });
  });

  group('submitMove -- sibling line correction', () {
    test('returns SiblingLineCorrection when move exists in a sibling line', () {
      // 9-ply white line with branch at index 4 (3. Bb5 vs 3. Bc4).
      // Parent Nc6 (id=4) has two children, creating a branch point.
      final mainLine = whiteLine9;

      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      final posAfterBc4 = pos.play(pos.parseSan('Bc4')!);

      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: 4, // Nc6's id
        fen: posAfterBc4.fen,
        san: 'Bc4',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, branchMove];
      final engine = buildEngine(allMoves, mainLine);
      engine.startCard();

      // introEndIndex = 4 (branch point). Expected move is Bb5.
      // User plays Bc4, which is a sibling.
      final result = engine.submitMove('Bc4');

      expect(result, isA<SiblingLineCorrection>());
      expect((result as SiblingLineCorrection).expectedSan, 'Bb5');
    });

    test('does NOT increment mistakeCount', () {
      final mainLine = whiteLine9;
      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      final posAfterBc4 = pos.play(pos.parseSan('Bc4')!);

      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: 4,
        fen: posAfterBc4.fen,
        san: 'Bc4',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, branchMove];
      final engine = buildEngine(allMoves, mainLine);
      engine.startCard();

      expect(engine.currentCardState!.mistakeCount, 0);
      engine.submitMove('Bc4'); // sibling line correction
      expect(engine.currentCardState!.mistakeCount, 0);
    });

    test('does not advance currentMoveIndex', () {
      final mainLine = whiteLine9;
      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      final posAfterBc4 = pos.play(pos.parseSan('Bc4')!);

      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: 4,
        fen: posAfterBc4.fen,
        san: 'Bc4',
        sortOrder: 1,
      );

      final allMoves = [...mainLine, branchMove];
      final engine = buildEngine(allMoves, mainLine);
      engine.startCard();

      final indexBefore = engine.currentCardState!.introEndIndex;
      engine.submitMove('Bc4'); // sibling
      expect(engine.currentCardState!.currentMoveIndex, indexBefore);
    });
  });

  group('Card completion scoring', () {
    test('0 mistakes -> quality 5', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      // Play all remaining moves correctly (intro ends at 6).
      engine.submitMove('Ba4'); // correct + opponent Nf6 auto
      engine.submitMove('O-O'); // correct, line complete

      final result = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result, isNotNull);
      expect(result!.mistakeCount, 0);
      expect(result.quality, 5);
    });

    test('1 mistake -> quality 4', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      engine.submitMove('Bc4'); // wrong
      engine.submitMove('Ba4'); // correct + opponent Nf6 auto
      engine.submitMove('O-O'); // correct, line complete

      final result = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result!.mistakeCount, 1);
      expect(result.quality, 4);
    });

    test('2 mistakes -> quality 2', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      engine.submitMove('Bc4'); // wrong (1)
      engine.submitMove('Bc4'); // wrong (2)
      engine.submitMove('Ba4'); // correct + opponent Nf6 auto
      engine.submitMove('O-O'); // correct, line complete

      final result = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result!.mistakeCount, 2);
      expect(result.quality, 2);
    });

    test('3+ mistakes -> quality 1', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      engine.submitMove('Bc4'); // wrong (1)
      engine.submitMove('Bc4'); // wrong (2)
      engine.submitMove('Bc4'); // wrong (3)
      engine.submitMove('Ba4'); // correct + opponent Nf6 auto
      engine.submitMove('O-O'); // correct, line complete

      final result = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result!.mistakeCount, 3);
      expect(result.quality, 1);
    });

    test('returns CardResult with correct SM-2 fields', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();

      engine.submitMove('Ba4');
      engine.submitMove('O-O');

      final result = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result, isNotNull);
      expect(result!.updatedCard, isA<ReviewCardsCompanion>());
      // Quality 5 -> pass -> repetitions advance, interval set
      expect(result.updatedCard.repetitions.value, 1);
      expect(result.updatedCard.intervalDays.value, 1); // first review
    });

    test('extra practice mode: returns null', () {
      final engine = buildEngine(whiteLine9, whiteLine9, isExtraPractice: true);
      engine.startCard();

      engine.submitMove('Ba4');
      engine.submitMove('O-O');

      final result = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result, isNull);
    });
  });

  group('Skip/defer', () {
    test('skipCard() advances to next card without scoring', () {
      // Build 2-card session with two white lines sharing the same opening.
      // Line 1 (main): 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O (9 plies)
      // Line 2 (branch): 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 b5 5. Bb3 (9 plies)
      // They share moves up to Ba4 (ids 1-7), then diverge.
      final mainLine = whiteLine9; // ids 1-9
      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      final posAfterB5 = pos.play(pos.parseSan('b5')!);
      final posAfterBb3 =
          posAfterB5.play(posAfterB5.parseSan('Bb3')!);

      final b5Move = RepertoireMove(
        id: 50,
        repertoireId: 1,
        parentMoveId: 7, // Ba4
        fen: posAfterB5.fen,
        san: 'b5',
        sortOrder: 1,
      );
      final bb3Move = RepertoireMove(
        id: 51,
        repertoireId: 1,
        parentMoveId: 50, // b5
        fen: posAfterBb3.fen,
        san: 'Bb3',
        sortOrder: 0,
      );

      // Line 2 for drilling: shared prefix (ids 1-7) + b5 (50) + Bb3 (51).
      final line2 = [...mainLine.sublist(0, 7), b5Move, bb3Move];
      final allMoves = [...mainLine, b5Move, bb3Move];

      final card1 = buildReviewCard(mainLine, cardId: 1);
      final card2 = buildReviewCard(line2, cardId: 2);
      final cache = RepertoireTreeCache.build(allMoves);
      final engine = DrillEngine(cards: [card1, card2], treeCache: cache);

      engine.startCard();
      expect(engine.currentIndex, 0);

      engine.skipCard();
      expect(engine.currentIndex, 1);
      expect(engine.isSessionComplete, false);
    });

    test('session is complete after skipping last card', () {
      final engine = buildEngine(whiteLine9, whiteLine9);
      engine.startCard();
      engine.skipCard();

      expect(engine.isSessionComplete, true);
    });
  });

  group('Session progress', () {
    test('currentIndex, totalCards, isSessionComplete reflect correct state', () {
      // Two white lines sharing the same opening, diverging after Ba4.
      // Line 1: 9 plies (ids 1-9), intro at 6. Play Ba4, auto Nf6, play O-O.
      // Line 2: 9 plies (ids 1-7 + 50-51), intro at 6. Play Ba4, auto b5, play Bb3.
      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      final posAfterB5 = pos.play(pos.parseSan('b5')!);
      final posAfterBb3 = posAfterB5.play(posAfterB5.parseSan('Bb3')!);

      final b5Move = RepertoireMove(
        id: 50,
        repertoireId: 1,
        parentMoveId: 7, // Ba4
        fen: posAfterB5.fen,
        san: 'b5',
        sortOrder: 1,
      );
      final bb3Move = RepertoireMove(
        id: 51,
        repertoireId: 1,
        parentMoveId: 50,
        fen: posAfterBb3.fen,
        san: 'Bb3',
        sortOrder: 0,
      );

      final line2 = [...whiteLine9.sublist(0, 7), b5Move, bb3Move];
      final allMoves = [...whiteLine9, b5Move, bb3Move];
      final card1 = buildReviewCard(whiteLine9, cardId: 1);
      final card2 = buildReviewCard(line2, cardId: 2);
      final cache = RepertoireTreeCache.build(allMoves);
      final engine = DrillEngine(cards: [card1, card2], treeCache: cache);

      expect(engine.currentIndex, 0);
      expect(engine.totalCards, 2);
      expect(engine.isSessionComplete, false);

      // Start and complete first card (9-ply white line, intro at 6)
      engine.startCard();
      engine.submitMove('Ba4'); // index 6, opponent Nf6 auto at 7
      engine.submitMove('O-O'); // index 8, line complete
      engine.completeCard(today: DateTime(2026, 3, 1));

      expect(engine.currentIndex, 1);
      expect(engine.isSessionComplete, false);

      // Start and complete second card (9-ply white line, intro at 6)
      engine.startCard();
      engine.submitMove('Ba4'); // index 6, opponent b5 auto at 7
      engine.submitMove('Bb3'); // index 8, line complete
      engine.completeCard(today: DateTime(2026, 3, 1));

      expect(engine.currentIndex, 2);
      expect(engine.isSessionComplete, true);
    });

    test('multiple cards processed in sequence', () {
      // Two white lines diverging after Ba4.
      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      final posAfterB5 = pos.play(pos.parseSan('b5')!);
      final posAfterBb3 = posAfterB5.play(posAfterB5.parseSan('Bb3')!);

      final b5Move = RepertoireMove(
        id: 50,
        repertoireId: 1,
        parentMoveId: 7,
        fen: posAfterB5.fen,
        san: 'b5',
        sortOrder: 1,
      );
      final bb3Move = RepertoireMove(
        id: 51,
        repertoireId: 1,
        parentMoveId: 50,
        fen: posAfterBb3.fen,
        san: 'Bb3',
        sortOrder: 0,
      );

      final line2 = [...whiteLine9.sublist(0, 7), b5Move, bb3Move];
      final allMoves = [...whiteLine9, b5Move, bb3Move];
      final card1 = buildReviewCard(whiteLine9, cardId: 1);
      final card2 = buildReviewCard(line2, cardId: 2);
      final cache = RepertoireTreeCache.build(allMoves);
      final engine = DrillEngine(cards: [card1, card2], treeCache: cache);

      // First card
      engine.startCard();
      expect(engine.session.currentCard.id, 1);
      engine.submitMove('Ba4');
      engine.submitMove('O-O');
      final result1 = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result1!.quality, 5);

      // Second card
      engine.startCard();
      expect(engine.session.currentCard.id, 2);
      engine.submitMove('Ba4');
      engine.submitMove('Bb3');
      final result2 = engine.completeCard(today: DateTime(2026, 3, 1));
      expect(result2!.quality, 5);

      expect(engine.isSessionComplete, true);
    });
  });

  group('getLineLabelName', () {
    test('line with no labels returns empty string', () {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final engine = buildEngine(line, line);
      engine.startCard();

      expect(engine.getLineLabelName(), '');
    });

    test('line with a single label returns that label', () {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3],
        line[4],
      ];
      final engine = buildEngine(labeledLine, labeledLine);
      engine.startCard();

      expect(engine.getLineLabelName(), 'Sicilian');
    });

    test('line with multiple labels returns aggregate of root-to-deepest', () {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3].copyWith(label: const Value('Najdorf')),
        line[4],
      ];
      final engine = buildEngine(labeledLine, labeledLine);
      engine.startCard();

      expect(engine.getLineLabelName(), 'Sicilian \u2014 Najdorf');
    });

    test('uses deepest label, not leaf', () {
      final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      // Label only on the intermediate move (index 1), not on the leaf (index 4)
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Open Game')),
        line[2],
        line[3],
        line[4],
      ];
      final engine = buildEngine(labeledLine, labeledLine);
      engine.startCard();

      // Aggregate display name is computed for the labeled move's position,
      // not the leaf. Since only move at index 1 has a label, result is just
      // that label.
      expect(engine.getLineLabelName(), 'Open Game');
    });
  });

  group('RepertoireTreeCache -- getDistinctLabels', () {
    test('returns empty list when no moves have labels', () {
      final moves = buildLine(['e4', 'e5', 'Nf3']);
      final cache = RepertoireTreeCache.build(moves);
      expect(cache.getDistinctLabels(), isEmpty);
    });

    test('returns single label when one move has a label', () {
      final moves = buildLine(['e4', 'e5', 'Nf3']);
      final labeled = [
        RepertoireMove(
          id: moves[0].id,
          repertoireId: 1,
          parentMoveId: null,
          fen: moves[0].fen,
          san: moves[0].san,
          sortOrder: 0,
          label: 'Sicilian',
        ),
        moves[1],
        moves[2],
      ];
      final cache = RepertoireTreeCache.build(labeled);
      expect(cache.getDistinctLabels(), ['Sicilian']);
    });

    test('returns distinct labels sorted alphabetically', () {
      final moves = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
      final labeled = [
        RepertoireMove(
          id: moves[0].id,
          repertoireId: 1,
          parentMoveId: null,
          fen: moves[0].fen,
          san: moves[0].san,
          sortOrder: 0,
          label: 'Sicilian',
        ),
        moves[1],
        RepertoireMove(
          id: moves[2].id,
          repertoireId: 1,
          parentMoveId: moves[2].parentMoveId,
          fen: moves[2].fen,
          san: moves[2].san,
          sortOrder: 0,
          label: 'Italian',
        ),
        RepertoireMove(
          id: moves[3].id,
          repertoireId: 1,
          parentMoveId: moves[3].parentMoveId,
          fen: moves[3].fen,
          san: moves[3].san,
          sortOrder: 0,
          label: 'Sicilian',
        ),
      ];
      final cache = RepertoireTreeCache.build(labeled);
      expect(cache.getDistinctLabels(), ['Italian', 'Sicilian']);
    });

    test('ignores null labels and returns only non-null values', () {
      final moves = buildLine(['e4', 'e5', 'Nf3']);
      final labeled = [
        moves[0], // no label
        RepertoireMove(
          id: moves[1].id,
          repertoireId: 1,
          parentMoveId: moves[1].parentMoveId,
          fen: moves[1].fen,
          san: moves[1].san,
          sortOrder: 0,
          label: 'French',
        ),
        moves[2], // no label
      ];
      final cache = RepertoireTreeCache.build(labeled);
      expect(cache.getDistinctLabels(), ['French']);
    });

    test('returns labels from different branches of the tree', () {
      // Main line: 1. e4 e5 2. Nf3
      final mainLine = buildLine(['e4', 'e5', 'Nf3']);
      // Branch: 1. e4 d5 (branching at root's child)
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      pos = pos.play(pos.parseSan('d5')!);
      final branchMove = RepertoireMove(
        id: 100,
        repertoireId: 1,
        parentMoveId: mainLine[0].id,
        fen: pos.fen,
        san: 'd5',
        sortOrder: 1,
        label: 'Scandinavian',
      );

      final labeled = [
        mainLine[0],
        RepertoireMove(
          id: mainLine[1].id,
          repertoireId: 1,
          parentMoveId: mainLine[1].parentMoveId,
          fen: mainLine[1].fen,
          san: mainLine[1].san,
          sortOrder: 0,
          label: 'Open Game',
        ),
        mainLine[2],
        branchMove,
      ];
      final cache = RepertoireTreeCache.build(labeled);
      expect(cache.getDistinctLabels(), ['Open Game', 'Scandinavian']);
    });
  });

  group('reshuffleQueue', () {
    test('resets index and preserves card set', () {
      // Build a 2-card engine with two white lines sharing the same opening.
      Position pos = Chess.initial;
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4']) {
        pos = pos.play(pos.parseSan(san)!);
      }
      final posAfterB5 = pos.play(pos.parseSan('b5')!);
      final posAfterBb3 = posAfterB5.play(posAfterB5.parseSan('Bb3')!);

      final b5Move = RepertoireMove(
        id: 50,
        repertoireId: 1,
        parentMoveId: 7, // Ba4
        fen: posAfterB5.fen,
        san: 'b5',
        sortOrder: 1,
      );
      final bb3Move = RepertoireMove(
        id: 51,
        repertoireId: 1,
        parentMoveId: 50,
        fen: posAfterBb3.fen,
        san: 'Bb3',
        sortOrder: 0,
      );

      final line2 = [...whiteLine9.sublist(0, 7), b5Move, bb3Move];
      final allMoves = [...whiteLine9, b5Move, bb3Move];
      final card1 = buildReviewCard(whiteLine9, cardId: 1);
      final card2 = buildReviewCard(line2, cardId: 2);
      final cache = RepertoireTreeCache.build(allMoves);
      final engine = DrillEngine(
        cards: [card1, card2],
        treeCache: cache,
        isExtraPractice: true,
      );

      // Advance through both cards
      engine.startCard();
      engine.submitMove('Ba4');
      engine.submitMove('O-O');
      engine.completeCard();

      engine.startCard();
      engine.submitMove('Ba4');
      engine.submitMove('Bb3');
      engine.completeCard();

      expect(engine.isSessionComplete, true);

      // Capture card IDs before reshuffle
      final cardIdsBefore =
          engine.session.cardQueue.map((c) => c.id).toSet();

      // Reshuffle
      engine.reshuffleQueue();

      // Verify: totalCards unchanged, currentIndex == 0, isSessionComplete == false
      expect(engine.totalCards, 2);
      expect(engine.currentIndex, 0);
      expect(engine.isSessionComplete, false);

      // Verify: same card set preserved (order may differ)
      final cardIdsAfter =
          engine.session.cardQueue.map((c) => c.id).toSet();
      expect(cardIdsAfter, cardIdsBefore);
    });

    test('can be called after session is complete', () {
      final engine = buildEngine(whiteLine9, whiteLine9, isExtraPractice: true);
      engine.startCard();
      engine.submitMove('Ba4');
      engine.submitMove('O-O');
      engine.completeCard();

      expect(engine.isSessionComplete, true);

      // Call reshuffleQueue
      engine.reshuffleQueue();

      // Verify: isSessionComplete is false, can call startCard()
      expect(engine.isSessionComplete, false);
      expect(engine.totalCards, 1);
      engine.startCard();
      expect(engine.currentCardState, isNotNull);
    });
  });
}
