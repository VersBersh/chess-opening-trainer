import 'dart:async';

import 'package:chessground/chessground.dart' show PlayerSide;
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/screens/drill_screen.dart';
import 'package:chess_trainer/theme/spacing.dart';
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
    intervalDays: 0,
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
  Future<void> renameRepertoire(int id, String newName) async {}

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
  Future<List<int>> extendLine(
          int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves) async =>
      [];

  @override
  Future<List<int>> saveBranch(int? parentMoveId,
          List<RepertoireMovesCompanion> newMoves) async =>
      [];

  @override
  Future<void> undoExtendLine(
          int oldLeafMoveId, List<int> insertedMoveIds, ReviewCard oldCard) async {}

  @override
  Future<void> undoNewLine(List<int> insertedMoveIds) async {}

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
  final List<ReviewCard> _allCards;
  final Map<int, List<ReviewCard>> _subtreeCards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({
    List<ReviewCard>? dueCards,
    List<ReviewCard>? allCards,
    Map<int, List<ReviewCard>>? subtreeCards,
  })  : _dueCards = dueCards ?? [],
        _allCards = allCards ?? dueCards ?? [],
        _subtreeCards = subtreeCards ?? {};

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
      _subtreeCards[moveId] ?? [];

  @override
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId) async =>
      _allCards.where((c) => c.repertoireId == repertoireId).toList();

  @override
  Future<int> getCardCountForRepertoire(int repertoireId) async =>
      _allCards.where((c) => c.repertoireId == repertoireId).length;

  @override
  Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries(
          {DateTime? asOf}) async =>
      {};

  @override
  Future<Map<int, int>> getDueCountForSubtrees(List<int> moveIds,
          {DateTime? asOf}) async =>
      {};
}

// ---------------------------------------------------------------------------
// Widget builder helper
// ---------------------------------------------------------------------------

const _defaultConfig = DrillConfig(repertoireId: 1);

late SharedPreferences _testPrefs;


Widget buildTestApp({
  required FakeRepertoireRepository repertoireRepo,
  required FakeReviewRepository reviewRepo,
  DrillConfig config = _defaultConfig,
  Size? viewportSize,
  DateTime Function()? clock,
}) {
  Widget home = DrillScreen(config: config);
  if (viewportSize != null) {
    home = MediaQuery(
      data: MediaQueryData(size: viewportSize),
      child: home,
    );
  }
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
      reviewRepositoryProvider.overrideWithValue(reviewRepo),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
    child: MaterialApp(home: home),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _testPrefs = await SharedPreferences.getInstance();
  });

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
          container.read(drillControllerProvider(_defaultConfig).notifier);

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
      final state = container.read(drillControllerProvider(_defaultConfig));
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
          container.read(drillControllerProvider(_defaultConfig).notifier);

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
      final state = container.read(drillControllerProvider(_defaultConfig));
      expect(state.value, isA<DrillMistakeFeedback>());

      final feedback = state.value! as DrillMistakeFeedback;
      expect(feedback.isSiblingCorrection, false);
      expect(feedback.wrongMoveDestination, isNotNull);

      // The widget should have shapes (arrow)
      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      expect(boardWidget.shapes, isNotNull);
      expect(boardWidget.shapes!.isNotEmpty, true);
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
          container.read(drillControllerProvider(_defaultConfig).notifier);

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
          container.read(drillControllerProvider(_defaultConfig).notifier);

      // With the branch, intro ends at index 4 (the branch point).
      // Expected move is Bb5. Play the sibling Bc4.
      final prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final siblingMove = prePos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(siblingMove);
      unawaited(notifier.processUserMove(siblingMove));
      await tester.pump();

      final state = container.read(drillControllerProvider(_defaultConfig));
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
    });
  });

  group('DrillScreen — mistake revert', () {
    testWidgets('reverts incorrect move immediately', (tester) async {
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
          container.read(drillControllerProvider(_defaultConfig).notifier);

      // Store the FEN before the mistake
      final fenBeforeMistake = notifier.boardController.fen;

      final pos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final wrongMove = pos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(wrongMove);
      unawaited(notifier.processUserMove(wrongMove));
      await tester.pump();

      // Board should already be reverted to pre-mistake FEN
      expect(notifier.boardController.fen, fenBeforeMistake);

      // State should be DrillMistakeFeedback (not DrillUserTurn)
      final state = container.read(drillControllerProvider(_defaultConfig));
      expect(state.value, isA<DrillMistakeFeedback>());
    });

    testWidgets('board is interactive during mistake feedback and accepts retry',
        (tester) async {
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
          container.read(drillControllerProvider(_defaultConfig).notifier);

      // Play a wrong move: Bc4 instead of expected Ba4
      final pos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final wrongMove = pos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(wrongMove);
      unawaited(notifier.processUserMove(wrongMove));
      await tester.pump();

      // Verify state is DrillMistakeFeedback
      var state = container.read(drillControllerProvider(_defaultConfig));
      expect(state.value, isA<DrillMistakeFeedback>());

      // Verify the ChessboardWidget has playerSide set to the user's color
      // (not PlayerSide.none), confirming the board is interactive
      final boardWidget =
          tester.widget<ChessboardWidget>(find.byType(ChessboardWidget));
      expect(boardWidget.playerSide, PlayerSide.white);

      // Without any additional delay, play the correct move (Ba4)
      final retryPos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final correctMove = retryPos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(correctMove);
      unawaited(notifier.processUserMove(correctMove));
      // Pump for the 300ms opponent auto-play delay
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // State should advance past mistake feedback (DrillUserTurn for next
      // user move, since the line is not complete yet after Ba4 + Nf6)
      state = container.read(drillControllerProvider(_defaultConfig));
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
          container.read(drillControllerProvider(_defaultConfig).notifier);

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
      final state = container.read(drillControllerProvider(_defaultConfig));
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
          container.read(drillControllerProvider(_defaultConfig).notifier);

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
          container.read(drillControllerProvider(_defaultConfig).notifier);

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
          container.read(drillControllerProvider(_defaultConfig).notifier);

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

      // Should show next review text (0 mistakes = quality 5, interval 1 day)
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

  group('DrillScreen — line label display', () {
    testWidgets('shows label below board when line has labels',
        (tester) async {
      final line = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3],
        line[4],
        line[5],
        line[6],
        line[7],
        line[8],
      ];
      final card = buildReviewCard(labeledLine);
      final repertoireRepo = FakeRepertoireRepository(moves: labeledLine);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Sicilian'), findsOneWidget);
    });

    testWidgets('label area reserves space but shows no text when line has no labels',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The text-keyed widget is absent (key only set when label is non-empty)
      expect(find.byKey(const ValueKey('drill-line-label')), findsNothing);

      // But the label area container always reserves space
      final areaFinder = find.byKey(const ValueKey('drill-line-label-area'));
      expect(areaFinder, findsOneWidget);
      final areaBox = tester.getRect(areaFinder);
      expect(areaBox.height, kLineLabelHeight);
    });

    testWidgets(
        'label persists through user turn and mistake feedback states',
        (tester) async {
      final line = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3],
        line[4],
        line[5],
        line[6],
        line[7],
        line[8],
      ];
      final card = buildReviewCard(labeledLine);
      final repertoireRepo = FakeRepertoireRepository(moves: labeledLine);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After intro, should be in DrillUserTurn -- label still visible
      expect(find.text('Sicilian'), findsOneWidget);

      // Play a wrong move to trigger DrillMistakeFeedback
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_defaultConfig).notifier);

      final pos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      final wrongMove = pos.parseSan('Bc4')! as NormalMove;
      notifier.boardController.playMove(wrongMove);
      unawaited(notifier.processUserMove(wrongMove));
      await tester.pump();

      // In DrillMistakeFeedback state -- label still visible
      expect(find.text('Sicilian'), findsOneWidget);
    });

    testWidgets('aggregate label format (multiple labels)', (tester) async {
      final line = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3].copyWith(label: const Value('Najdorf')),
        line[4],
        line[5],
        line[6],
        line[7],
        line[8],
      ];
      final card = buildReviewCard(labeledLine);
      final repertoireRepo = FakeRepertoireRepository(moves: labeledLine);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Sicilian \u2014 Najdorf'), findsOneWidget);
    });

    testWidgets('label updates when advancing to next card', (tester) async {
      // Card 1: line with label "Sicilian" (ids 1-9)
      final line1 = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine1 = [
        line1[0],
        line1[1].copyWith(label: const Value('Sicilian')),
        line1[2],
        line1[3],
        line1[4],
        line1[5],
        line1[6],
        line1[7],
        line1[8],
      ];

      // Card 2: branch diverging after Ba4 (id 7) with label "French"
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
        label: 'French',
      );
      final bb3Move = RepertoireMove(
        id: 51,
        repertoireId: 1,
        parentMoveId: 50,
        fen: posAfterBb3.fen,
        san: 'Bb3',
        sortOrder: 0,
      );

      final line2 = [...labeledLine1.sublist(0, 7), b5Move, bb3Move];
      final allMoves = [...labeledLine1, b5Move, bb3Move];

      final card1 = buildReviewCard(labeledLine1, cardId: 1);
      final card2 = buildReviewCard(line2, cardId: 2);

      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(dueCards: [card1, card2]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Card 1 should show "Sicilian"
      expect(find.text('Sicilian'), findsOneWidget);

      // Complete card 1 by playing correct moves
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_defaultConfig).notifier);

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
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Card 2 should show "Sicilian — French" (aggregate from root to deepest label)
      expect(find.text('Sicilian \u2014 French'), findsOneWidget);
      // Card 1's label alone should no longer be on screen
      expect(find.text('Sicilian'), findsNothing);
    });
  });

  group('DrillScreen -- free practice', () {
    testWidgets('free practice does not save reviews', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Complete the card by playing correct moves
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

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

      // No reviews should have been saved
      expect(reviewRepo.savedReviews, isEmpty);
    });

    testWidgets('free practice session summary shows "Practice Complete"',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

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

      // Should show DrillPassComplete with "Pass Complete" heading
      expect(find.text('Pass Complete'), findsOneWidget);
      expect(find.text('Keep Going'), findsOneWidget);

      // Tap "Finish" to reach the session summary
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show "Practice Complete" instead of "Session Complete"
      expect(find.text('Practice Complete'), findsNWidgets(2));
      expect(find.text('Session Complete'), findsNothing);
    });

    testWidgets('free practice session summary shows SR-exempt subtitle',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

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

      // Tap "Finish" to reach the session summary
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('no SR updates'), findsOneWidget);
    });

    testWidgets('free practice session summary hides next review date',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

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

      // Tap "Finish" to reach the session summary
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Next review:'), findsNothing);
    });

    testWidgets('free practice without preloadedCards loads all cards',
        (tester) async {
      final allCard = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        isExtraPractice: true,
        // No preloadedCards — controller must fetch them itself
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      // dueCards is empty, allCards has a card — proves getAllCardsForRepertoire is called
      final reviewRepo =
          FakeReviewRepository(dueCards: [], allCards: [allCard]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should have loaded the card and be showing a drill state, not session-complete
      expect(find.textContaining('Free Practice'), findsOneWidget);
      // Verify we did NOT get the empty-session outcome
      expect(find.text('Practice Complete'), findsNothing);
    });

    testWidgets('free practice shows "Free Practice" in AppBar title',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // AppBar should say "Free Practice — 1/1"
      expect(find.text('Free Practice \u2014 1/1'), findsOneWidget);
    });

    testWidgets('"Keep Going" button appears after all cards reviewed in free practice',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

      // Complete the card
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

      // "Keep Going" button should be visible
      expect(find.text('Keep Going'), findsOneWidget);
      expect(find.text('Pass Complete'), findsOneWidget);
      // We should NOT be on the session summary screen
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('tapping "Keep Going" starts a new pass',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

      // Complete the card
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

      // Should be on the pass complete screen
      expect(find.text('Keep Going'), findsOneWidget);

      // Tap "Keep Going"
      await tester.tap(find.text('Keep Going'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should be back on a card (DrillCardStart or DrillUserTurn)
      final state =
          container.read(drillControllerProvider(freePracticeConfig));
      final stateVal = state.value!;
      expect(
        stateVal is DrillCardStart || stateVal is DrillUserTurn,
        true,
        reason: 'Expected active card state after Keep Going, got $stateVal',
      );

      // Progress indicator should show 1/1 (reset for new pass)
      expect(find.text('Free Practice \u2014 1/1'), findsOneWidget);
    });

    testWidgets('"Finish" button shows session summary',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

      // Complete the card
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

      // Tap "Finish" to reach the session summary
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show the session summary with "Practice Complete"
      expect(find.text('Practice Complete'), findsNWidgets(2));
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('1 cards reviewed'), findsOneWidget);
    });

    testWidgets('regular drill mode does NOT show "Keep Going"',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        // Uses _defaultConfig which has isExtraPractice: false
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_defaultConfig).notifier);

      // Complete the card
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

      // Should show DrillSessionComplete directly (no "Keep Going")
      expect(find.text('Session Complete'), findsNWidgets(2));
      expect(find.text('Keep Going'), findsNothing);
      expect(find.text('Pass Complete'), findsNothing);
    });

    testWidgets('multiple passes work',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

      // --- Pass 1 ---
      var prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      var ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      var oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Pass Complete'), findsOneWidget);

      // Tap "Keep Going"
      await tester.tap(find.text('Keep Going'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // --- Pass 2 ---
      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should see "Pass Complete" again
      expect(find.text('Pass Complete'), findsOneWidget);
      expect(find.text('Keep Going'), findsOneWidget);
    });

    testWidgets('cumulative stats in summary after multiple passes',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

      // --- Pass 1 ---
      var prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      var ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      var oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap "Keep Going"
      await tester.tap(find.text('Keep Going'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // --- Pass 2 ---
      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      ba4Move = prePos.parseSan('Ba4')! as NormalMove;
      notifier.boardController.playMove(ba4Move);
      unawaited(notifier.processUserMove(ba4Move));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      prePos =
          Chess.fromSetup(Setup.parseFen(notifier.boardController.fen));
      oOMove = prePos.parseSan('O-O')! as NormalMove;
      notifier.boardController.playMove(oOMove);
      unawaited(notifier.processUserMove(oOMove));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap "Finish" to see cumulative summary
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show "Practice Complete" and cumulative stats
      expect(find.text('Practice Complete'), findsNWidgets(2));
      // 2 cards reviewed across both passes (1 card completed per pass x 2 passes)
      expect(find.text('2 cards reviewed'), findsOneWidget);
    });
  });

  group('DrillScreen -- line label in free practice', () {
    testWidgets('shows line label below board in Free Practice mode',
        (tester) async {
      // Build a labeled line: label 'Sicilian' on the second move (e5)
      final line = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3],
        line[4],
        line[5],
        line[6],
        line[7],
        line[8],
      ];
      final card = buildReviewCard(labeledLine);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: labeledLine);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Sicilian'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('drill-line-label')), findsOneWidget);
    });

    testWidgets('label area reserves space but shows no text in Free Practice when unlabeled',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The text-keyed widget is absent (key only set when label is non-empty)
      expect(find.byKey(const ValueKey('drill-line-label')), findsNothing);

      // But the label area container always reserves space
      final areaFinder = find.byKey(const ValueKey('drill-line-label-area'));
      expect(areaFinder, findsOneWidget);
      final areaBox = tester.getRect(areaFinder);
      expect(areaBox.height, kLineLabelHeight);
    });

    testWidgets('line label updates after Keep Going in Free Practice',
        (tester) async {
      // Build a labeled line for a single-card free practice session
      final line = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3],
        line[4],
        line[5],
        line[6],
        line[7],
        line[8],
      ];
      final card = buildReviewCard(labeledLine);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: labeledLine);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify label is shown initially
      expect(find.text('Sicilian'), findsOneWidget);

      // Complete the card
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

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

      // Should be at DrillPassComplete
      expect(find.text('Pass Complete'), findsOneWidget);

      // Tap "Keep Going" to start a new pass
      await tester.tap(find.text('Keep Going'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After reshuffling and starting the same card again, label should
      // still be present (same card, same label)
      expect(find.text('Sicilian'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('drill-line-label')), findsOneWidget);
    });

    testWidgets('line label updates after filter change in Free Practice',
        (tester) async {
      // Build two lines with different labels, branching after Ba4 (id 7).
      //
      // Line 1: 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O
      //   Label 'Sicilian' on e5 (id 2)
      //
      // Line 2: 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 b5 5. Bb3
      //   Label 'French' on b5 (id 50)
      final line1 = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine1 = [
        line1[0],
        line1[1].copyWith(label: const Value('Sicilian')),
        line1[2],
        line1[3],
        line1[4],
        line1[5],
        line1[6],
        line1[7],
        line1[8],
      ];

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
        label: 'French',
      );
      final bb3Move = RepertoireMove(
        id: 51,
        repertoireId: 1,
        parentMoveId: 50,
        fen: posAfterBb3.fen,
        san: 'Bb3',
        sortOrder: 0,
      );

      final line2 = [...labeledLine1.sublist(0, 7), b5Move, bb3Move];
      final allMoves = [...labeledLine1, b5Move, bb3Move];

      final card1 = buildReviewCard(labeledLine1, cardId: 1);
      final card2 = buildReviewCard(line2, cardId: 2);

      // Start with both cards loaded
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card1, card2],
        isExtraPractice: true,
      );

      // Configure getCardsForSubtree: move 2 (e5, label 'Sicilian') subtree
      // contains card1; move 50 (b5, label 'French') subtree contains card2.
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        dueCards: [card1, card2],
        subtreeCards: {
          2: [card1],
          50: [card2],
        },
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(freePracticeConfig).notifier);

      // Apply filter to show only 'French' labeled cards
      await notifier.applyFilter({'French'});
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After filtering to 'French', the label should show the aggregate
      // name for line2's deepest label. Line2 has 'Sicilian' on e5 and
      // 'French' on b5, so the aggregate is 'Sicilian — French'.
      expect(find.text('Sicilian \u2014 French'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('drill-line-label')), findsOneWidget);
    });
  });

  group('DrillScreen — narrow layout', () {
    testWidgets('renders board and status in column layout at narrow width',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        viewportSize: const Size(400, 800),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Board and status text should render without error
      expect(find.byType(ChessboardWidget), findsOneWidget);
      expect(find.text('Your turn'), findsOneWidget);

      // Narrow layout uses Column, not a Row containing both board and status.
      // Verify no LayoutBuilder is used (wide path wraps in LayoutBuilder).
      // The scaffold body should not contain a LayoutBuilder in narrow mode
      // (LayoutBuilder is only used in the wide path).
      final boardWidget = find.byType(ChessboardWidget);
      final boardElement = tester.element(boardWidget);
      final ancestor = boardElement.findAncestorWidgetOfExactType<LayoutBuilder>();
      expect(ancestor, isNull,
          reason: 'Narrow layout should not wrap board in LayoutBuilder');
    });

    testWidgets('line label appears below board in narrow layout',
        (tester) async {
      final line = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3],
        line[4],
        line[5],
        line[6],
        line[7],
        line[8],
      ];
      final card = buildReviewCard(labeledLine);
      final repertoireRepo = FakeRepertoireRepository(moves: labeledLine);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        viewportSize: const Size(400, 800),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byKey(const ValueKey('drill-line-label')), findsOneWidget);
      expect(find.text('Sicilian'), findsOneWidget);

      final boardBox = tester.getRect(find.byType(ChessboardWidget));
      final labelBox = tester.getRect(find.byKey(const ValueKey('drill-line-label')));
      expect(labelBox.top, greaterThanOrEqualTo(boardBox.bottom),
          reason: 'Line label should appear below the board');
    });

    testWidgets('skip button works in narrow layout', (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        viewportSize: const Size(400, 800),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the skip button
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should show session complete
      expect(find.text('Session Complete'), findsNWidgets(2));
      expect(find.text('0 cards reviewed'), findsOneWidget);
      expect(find.text('1 cards skipped'), findsOneWidget);
    });

    testWidgets('filter box renders in narrow layout (free practice)',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
        viewportSize: const Size(400, 800),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
          find.byKey(const ValueKey('drill-filter-box')), findsOneWidget);
    });
  });

  group('DrillScreen — wide layout', () {
    testWidgets('renders board and status side by side in wide layout',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        viewportSize: const Size(900, 600),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Board and status text should render without error
      expect(find.byType(ChessboardWidget), findsOneWidget);
      expect(find.text('Your turn'), findsOneWidget);

      // Wide layout uses LayoutBuilder wrapping a Row.
      // Verify the board is inside a LayoutBuilder (wide path).
      final boardWidget = find.byType(ChessboardWidget);
      final boardElement = tester.element(boardWidget);
      final ancestor =
          boardElement.findAncestorWidgetOfExactType<LayoutBuilder>();
      expect(ancestor, isNotNull,
          reason: 'Wide layout should wrap board in LayoutBuilder');
    });

    testWidgets('line label appears below board in wide layout',
        (tester) async {
      final line = buildLine(
          ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
      final labeledLine = [
        line[0],
        line[1].copyWith(label: const Value('Sicilian')),
        line[2],
        line[3],
        line[4],
        line[5],
        line[6],
        line[7],
        line[8],
      ];
      final card = buildReviewCard(labeledLine);
      final repertoireRepo = FakeRepertoireRepository(moves: labeledLine);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        viewportSize: const Size(900, 600),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byKey(const ValueKey('drill-line-label')), findsOneWidget);
      expect(find.text('Sicilian'), findsOneWidget);

      final boardBox = tester.getRect(find.byType(ChessboardWidget));
      final labelBox = tester.getRect(find.byKey(const ValueKey('drill-line-label')));
      expect(labelBox.top, greaterThanOrEqualTo(boardBox.bottom),
          reason: 'Line label should appear below the board in wide layout');
    });

    testWidgets('filter box renders in wide side panel (free practice)',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final freePracticeConfig = DrillConfig(
        repertoireId: 1,
        preloadedCards: [card],
        isExtraPractice: true,
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: freePracticeConfig,
        viewportSize: const Size(900, 600),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
          find.byKey(const ValueKey('drill-filter-box')), findsOneWidget);
    });
  });

  group('DrillScreen — deterministic clock', () {
    testWidgets('summary shows correct elapsed time with injected clock',
        (tester) async {
      var now = DateTime(2026, 3, 1, 10, 0, 0);
      DateTime advancingClock() => now;

      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(dueCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        clock: advancingClock,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Advance the clock by 2 minutes 30 seconds
      now = DateTime(2026, 3, 1, 10, 2, 30);

      // Complete the card
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_defaultConfig).notifier);

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

      // Verify the summary shows "2m 30s"
      expect(find.text('2m 30s'), findsOneWidget);
    });
  });
}
