import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/screens/drill_screen.dart';
import 'package:chess_trainer/widgets/chessboard_widget.dart';

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
    intervalDays: 1,
    repetitions: 0,
    nextReviewDate: DateTime(2026, 1, 1),
  );
}

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

class FakeRepertoireRepository implements RepertoireRepository {
  final List<RepertoireMove> _moves;
  final List<Repertoire> _repertoires;

  FakeRepertoireRepository({
    List<RepertoireMove>? moves,
    List<Repertoire>? repertoires,
  })  : _moves = moves ?? [],
        _repertoires = repertoires ?? [const Repertoire(id: 1, name: 'Test')];

  @override
  Future<List<RepertoireMove>> getMovesForRepertoire(int repertoireId) async {
    return _moves.where((m) => m.repertoireId == repertoireId).toList();
  }

  @override
  Future<List<Repertoire>> getAllRepertoires() async => _repertoires;

  @override
  Future<Repertoire> getRepertoire(int id) async =>
      _repertoires.firstWhere((r) => r.id == id);

  @override
  Future<int> saveRepertoire(RepertoiresCompanion repertoire) async => 1;

  @override
  Future<void> deleteRepertoire(int id) async {}

  @override
  Future<RepertoireMove?> getMove(int id) async =>
      _moves.where((m) => m.id == id).firstOrNull;

  @override
  Future<List<RepertoireMove>> getChildMoves(int parentMoveId) async =>
      _moves.where((m) => m.parentMoveId == parentMoveId).toList();

  @override
  Future<int> saveMove(RepertoireMovesCompanion move) async => 1;

  @override
  Future<void> deleteMove(int id) async {}

  @override
  Future<List<RepertoireMove>> getRootMoves(int repertoireId) async =>
      _moves
          .where(
              (m) => m.repertoireId == repertoireId && m.parentMoveId == null)
          .toList();

  @override
  Future<List<RepertoireMove>> getLineForLeaf(int leafMoveId) async => [];

  @override
  Future<bool> isLeafMove(int moveId) async => true;

  @override
  Future<List<RepertoireMove>> getMovesAtPosition(
          int repertoireId, String fen) async =>
      _moves
          .where((m) => m.repertoireId == repertoireId && m.fen == fen)
          .toList();

  @override
  Future<void> extendLine(
          int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves) async {}

  @override
  Future<int> countLeavesInSubtree(int moveId) async => 0;

  @override
  Future<List<RepertoireMove>> getOrphanedLeaves(int repertoireId) async => [];

  @override
  Future<void> pruneOrphans(int repertoireId) async {}

  @override
  Future<void> updateMoveLabel(int moveId, String? label) async {}
}

class FakeReviewRepository implements ReviewRepository {
  final List<ReviewCard> _dueCards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({List<ReviewCard>? dueCards})
      : _dueCards = dueCards ?? [];

  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) async => _dueCards;

  @override
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
      {DateTime? asOf}) async {
    return _dueCards.where((c) => c.repertoireId == repertoireId).toList();
  }

  @override
  Future<ReviewCard?> getCardForLeaf(int leafMoveId) async =>
      _dueCards.where((c) => c.leafMoveId == leafMoveId).firstOrNull;

  @override
  Future<void> saveReview(ReviewCardsCompanion card) async {
    savedReviews.add(card);
  }

  @override
  Future<void> deleteCard(int id) async {}

  @override
  Future<List<ReviewCard>> getCardsForSubtree(int moveId,
          {bool dueOnly = false, DateTime? asOf}) async =>
      [];

  @override
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId) async =>
      _dueCards.where((c) => c.repertoireId == repertoireId).toList();
}

// ---------------------------------------------------------------------------
// Widget builder helper
// ---------------------------------------------------------------------------

Widget buildTestApp({
  required FakeRepertoireRepository repertoireRepo,
  required FakeReviewRepository reviewRepo,
  int repertoireId = 1,
}) {
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
      reviewRepositoryProvider.overrideWithValue(reviewRepo),
    ],
    child: MaterialApp(
      home: DrillScreen(repertoireId: repertoireId),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // A reusable white line (9 plies, odd = white):
  // 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O
  final whiteLine9 = buildLine(
      ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);

  // A black line (8 plies, even = black):
  // 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6
  final blackLine8 = buildLine(
      ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6']);

  group('DrillScreen — board orientation', () {
    testWidgets('white line orients board with white at bottom',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      // Let async build complete and intro moves play
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      expect(boardWidget.orientation, Side.white);
    });

    testWidgets('black line orients board with black at bottom',
        (tester) async {
      final card = buildReviewCard(blackLine8);
      final repertoireRepo = FakeRepertoireRepository(moves: blackLine8);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      expect(boardWidget.orientation, Side.black);
    });
  });

  group('DrillScreen — intro auto-play', () {
    testWidgets('auto-plays intro moves and advances board position',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      // Pump through intro move delays (6 intro moves x 300ms each)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After intro, the board should be past the initial position.
      // The intro for the 9-ply white line is 6 moves: e4 e5 Nf3 Nc6 Bb5 a6
      // The board should show the position after 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6
      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      // Board should not be at initial FEN
      expect(boardWidget.controller.fen, isNot(kInitialFEN));
    });
  });

  group('DrillScreen — user moves', () {
    testWidgets('processes correct user move via controller', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // At this point the user should be in DrillUserTurn state.
      // The expected move at index 6 is Ba4.
      // Access the notifier directly to test processUserMove.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      // Get the position before the user's move to compute the correct
      // NormalMove for Ba4
      final pos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final ba4Move = pos.parseSan('Ba4')! as NormalMove;

      // Play the user's move on the board (simulating what ChessboardWidget does).
      // Don't await processUserMove — it contains Future.delayed calls that
      // only resolve when the test clock is pumped.
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      // Pump past the 300ms opponent-response delay
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // After correct move Ba4 + opponent auto-play Nf6, state should still
      // be DrillUserTurn (one more user move remaining: O-O)
      final state = container.read(drillControllerProvider(1));
      expect(state.value, isA<DrillUserTurn>());
    });
  });

  group('DrillScreen — mistake feedback', () {
    testWidgets('shows arrow on wrong move', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      // Play a wrong move: Bc4 instead of Ba4
      final pos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      // For the wrong move, we need a legal but incorrect move.
      // At the position after intro (after a6), white can play many moves.
      // The expected move is Ba4, so let's play a different bishop move.
      final wrongMove = pos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(wrongMove);
      // Don't await — Future.delayed inside only resolves via pump
      unawaited(notifier.processUserMove(wrongMove));
      await tester.pump();

      // State should be DrillMistakeFeedback
      final state = container.read(drillControllerProvider(1));
      expect(state.value, isA<DrillMistakeFeedback>());

      final feedback = state.value! as DrillMistakeFeedback;
      expect(feedback.isSiblingCorrection, false);
      expect(feedback.wrongMoveDestination, isNotNull);

      // The widget should have shapes (arrow)
      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      expect(boardWidget.shapes, isNotNull);
      expect(boardWidget.shapes!.isNotEmpty, true);

      // Drain the pending 1500ms revert timer to avoid test framework error
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();
    });

    testWidgets('shows X annotation on genuine wrong move', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      final pos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final wrongMove = pos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(wrongMove);
      unawaited(notifier.processUserMove(wrongMove));
      await tester.pump();

      // Widget should have annotations (X icon)
      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      expect(boardWidget.annotations, isNotNull);
      expect(boardWidget.annotations!.isNotEmpty, true);

      // Drain the pending 1500ms revert timer
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();
    });

    testWidgets('arrow only on sibling correction (no X annotation)',
        (tester) async {
      // Create a branching tree: 1. e4 e5 2. Nf3 Nc6 3. Bb5 vs 3. Bc4
      // This creates a branch at index 4 (user's 3rd move)
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
      final card = buildReviewCard(mainLine);
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      // With the branch, intro ends at index 4 (the branch point).
      // Expected move is Bb5. Play the sibling Bc4.
      final prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final siblingMove = prePos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(siblingMove);
      unawaited(notifier.processUserMove(siblingMove));
      await tester.pump();

      final state = container.read(drillControllerProvider(1));
      expect(state.value, isA<DrillMistakeFeedback>());

      final feedback = state.value! as DrillMistakeFeedback;
      expect(feedback.isSiblingCorrection, true);

      // Widget should have shapes (arrow) but no annotations (no X)
      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      expect(boardWidget.shapes, isNotNull);
      expect(boardWidget.shapes!.isNotEmpty, true);
      // annotations should be null for sibling corrections
      expect(boardWidget.annotations, isNull);

      // Drain the pending 1500ms revert timer
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();
    });
  });

  group('DrillScreen — mistake revert', () {
    testWidgets('reverts incorrect move after pause', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      // Store the FEN before the mistake
      final fenBeforeMistake = notifier.boardController.fen;

      final pos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final wrongMove = pos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(wrongMove);
      unawaited(notifier.processUserMove(wrongMove));

      // Board should not be at pre-mistake position yet
      await tester.pump();

      // Pump past the 1500ms revert delay
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();

      // Board should be back to pre-mistake FEN
      expect(notifier.boardController.fen, fenBeforeMistake);

      // State should be back to DrillUserTurn
      final state = container.read(drillControllerProvider(1));
      expect(state.value, isA<DrillUserTurn>());
    });
  });

  group('DrillScreen — card advancement', () {
    testWidgets('advances to next card after line completion', (tester) async {
      // Create two lines sharing moves, with branch at Nf6 vs b5 after Ba4
      final mainLine = whiteLine9; // ids 1-9

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

      final line2 = [...mainLine.sublist(0, 7), b5Move, bb3Move];
      final allMoves = [...mainLine, b5Move, bb3Move];
      final card1 = buildReviewCard(mainLine, cardId: 1);
      final card2 = buildReviewCard(line2, cardId: 2);

      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(dueCards: [card1, card2]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      // Complete first card: play Ba4, pump past opponent delay, then O-O
      var prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      // Pump past the 300ms opponent-response delay
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      // Pump past line completion + next card intro
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // A review should have been saved
      expect(reviewRepo.savedReviews.length, 1);

      // State should show the second card (CardStart or UserTurn)
      final state = container.read(drillControllerProvider(1));
      final stateVal = state.value!;
      final isCard2 = stateVal is DrillCardStart &&
              stateVal.currentCardNumber == 2 ||
          stateVal is DrillUserTurn && stateVal.currentCardNumber == 2;
      expect(isCard2, true);
    });
  });

  group('DrillScreen — progress indicator', () {
    testWidgets('shows "Card N of M" text', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Card 1 of 1'), findsOneWidget);
    });
  });

  group('DrillScreen — empty card queue', () {
    testWidgets('shows session complete when no cards are due',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Session Complete'), findsNWidgets(2));
      expect(find.text('0 cards reviewed'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  group('DrillScreen — skip', () {
    testWidgets('skip button advances to session complete on single card',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the skip button
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show session complete with 0 completed, 1 skipped
      expect(find.text('Session Complete'), findsNWidgets(2));
      expect(find.text('0 cards reviewed'), findsOneWidget);
      expect(find.text('1 cards skipped'), findsOneWidget);
    });
  });

  group('DrillScreen — session summary', () {
    testWidgets('shows mistake breakdown after completing a card',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Complete the card by playing the correct moves: Ba4, then O-O
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      var prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show session complete with breakdown rows
      expect(find.text('Session Complete'), findsNWidgets(2));
      expect(find.text('1 cards reviewed'), findsOneWidget);
      expect(find.text('Perfect'), findsOneWidget);
      expect(find.text('Hesitation'), findsOneWidget);
      expect(find.text('Struggled'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);

      // Verify exact counts: 0-mistake card = quality 5 = Perfect
      // The breakdown rows render count as standalone Text widgets
      expect(find.text('1'), findsOneWidget); // Perfect count
      expect(find.text('0'), findsNWidgets(3)); // Hesitation, Struggled, Failed
    });

    testWidgets('shows session duration text', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Complete the card
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      var prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Duration will be near-zero in tests; verify the text widget exists
      // by matching the "s" suffix pattern (e.g. "0s", "1s", "0m 0s")
      expect(find.textContaining(RegExp(r'\d+s')), findsOneWidget);
    });

    testWidgets('shows next due date preview after completing a card',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Complete the card
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(1).notifier);

      var prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show next review text (0 mistakes = quality 5, interval 1 day = "Tomorrow")
      expect(find.textContaining('Next review:'), findsOneWidget);
    });

    testWidgets('hides breakdown when all cards skipped', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Skip the card instead of completing it
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show session complete but NOT show breakdown labels
      expect(find.text('Session Complete'), findsNWidgets(2));
      expect(find.text('0 cards reviewed'), findsOneWidget);
      expect(find.text('Perfect'), findsNothing);
      expect(find.text('Hesitation'), findsNothing);
      expect(find.text('Struggled'), findsNothing);
      expect(find.text('Failed'), findsNothing);
      // No next review date since no cards were completed
      expect(find.textContaining('Next review:'), findsNothing);
    });
  });
}
