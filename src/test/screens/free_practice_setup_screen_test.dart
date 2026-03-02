import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/screens/drill_screen.dart';
import 'package:chess_trainer/screens/free_practice_setup_screen.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

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
  Future<List<int>> extendLine(
          int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves) async =>
      [];

  @override
  Future<void> undoExtendLine(
          int oldLeafMoveId, List<int> insertedMoveIds, ReviewCard oldCard) async {}

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
  final List<ReviewCard> _allCards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({List<ReviewCard>? allCards})
      : _allCards = allCards ?? [];

  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) async => _allCards;

  @override
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
      {DateTime? asOf}) async {
    return _allCards.where((c) => c.repertoireId == repertoireId).toList();
  }

  @override
  Future<ReviewCard?> getCardForLeaf(int leafMoveId) async =>
      _allCards.where((c) => c.leafMoveId == leafMoveId).firstOrNull;

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
      _allCards.where((c) => c.repertoireId == repertoireId).toList();
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
      home: FreePracticeSetupScreen(repertoireId: repertoireId),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Line: 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O (9 plies)
  final whiteLine9 = buildLine(
      ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);

  // Add a label to the 5th move (Bb5, id=5) to create a labeled subtree
  RepertoireMove labeledBb5(List<RepertoireMove> moves) => RepertoireMove(
        id: moves[4].id,
        repertoireId: 1,
        parentMoveId: moves[4].parentMoveId,
        fen: moves[4].fen,
        san: moves[4].san,
        sortOrder: 0,
        label: 'Ruy Lopez',
      );

  group('FreePracticeSetupScreen -- basic rendering', () {
    testWidgets('shows autocomplete field and start button', (tester) async {
      final movesWithLabel = [
        ...whiteLine9.sublist(0, 4),
        labeledBb5(whiteLine9),
        ...whiteLine9.sublist(5),
      ];
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: movesWithLabel);
      final reviewRepo = FakeReviewRepository(allCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Autocomplete<String>), findsOneWidget);
      expect(find.text('Start Practice'), findsOneWidget);
    });

    testWidgets('shows total card count on initial load', (tester) async {
      final card1 = buildReviewCard(whiteLine9, cardId: 1);
      final card2 = ReviewCard(
        id: 2,
        repertoireId: 1,
        leafMoveId: 5,
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 0,
        nextReviewDate: DateTime(2026, 1, 1),
      );
      final card3 = ReviewCard(
        id: 3,
        repertoireId: 1,
        leafMoveId: 3,
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 0,
        nextReviewDate: DateTime(2026, 1, 1),
      );
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo =
          FakeReviewRepository(allCards: [card1, card2, card3]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('3 cards'), findsOneWidget);
    });
  });

  group('FreePracticeSetupScreen -- label filtering', () {
    testWidgets('autocomplete filters options by typed text', (tester) async {
      // Add two labeled moves: "Ruy Lopez" on Bb5, "Italian" on a different branch
      final branch2 = buildLine(['e4', 'e5', 'Bc4'], startId: 10);
      final movesWithLabels = [
        ...whiteLine9.sublist(0, 4),
        labeledBb5(whiteLine9),
        ...whiteLine9.sublist(5),
        branch2[0], // duplicate e4 -- same id conflict, use separate branch start
        branch2[1],
        RepertoireMove(
          id: branch2[2].id,
          repertoireId: 1,
          parentMoveId: branch2[2].parentMoveId,
          fen: branch2[2].fen,
          san: branch2[2].san,
          sortOrder: 0,
          label: 'Italian',
        ),
      ];
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: movesWithLabels);
      final reviewRepo = FakeReviewRepository(allCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Focus the autocomplete field to show all options
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Both labels should be visible
      expect(find.text('Italian'), findsOneWidget);
      expect(find.text('Ruy Lopez'), findsOneWidget);

      // Type "Ruy" to filter
      await tester.enterText(find.byType(TextField), 'Ruy');
      await tester.pumpAndSettle();

      // Only "Ruy Lopez" should remain as an option
      expect(find.text('Ruy Lopez'), findsOneWidget);
      expect(find.text('Italian'), findsNothing);
    });

    testWidgets('selecting a label updates card count', (tester) async {
      // Bb5 (id=5) is labeled "Ruy Lopez". O-O (id=9) is a descendant.
      // Card pointing to leaf O-O (id=9) is under the Ruy Lopez subtree.
      final movesWithLabel = [
        ...whiteLine9.sublist(0, 4),
        labeledBb5(whiteLine9),
        ...whiteLine9.sublist(5),
      ];
      final cardInSubtree = buildReviewCard(whiteLine9, cardId: 1);
      // Card pointing to a move NOT under Bb5 (e.g. Nc6 id=4)
      final cardOutsideSubtree = ReviewCard(
        id: 2,
        repertoireId: 1,
        leafMoveId: 4,
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 0,
        nextReviewDate: DateTime(2026, 1, 1),
      );
      final repertoireRepo = FakeRepertoireRepository(moves: movesWithLabel);
      final reviewRepo = FakeReviewRepository(
          allCards: [cardInSubtree, cardOutsideSubtree]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Initially shows total count
      expect(find.text('2 cards'), findsOneWidget);

      // Type in the autocomplete field to trigger options
      await tester.enterText(find.byType(TextField), 'Ruy');
      await tester.pumpAndSettle();

      // Select "Ruy Lopez" from the options
      expect(find.text('Ruy Lopez'), findsOneWidget);
      await tester.tap(find.text('Ruy Lopez'));
      await tester.pumpAndSettle();

      // Only the card under the Ruy Lopez subtree should be counted
      expect(find.text('1 cards'), findsOneWidget);
    });
  });

  group('FreePracticeSetupScreen -- navigation', () {
    testWidgets('Start Practice button navigates to DrillScreen',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(allCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Practice'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(DrillScreen), findsOneWidget);
    });

    testWidgets('disables Start Practice when no cards at all',
        (tester) async {
      // No cards at all
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(allCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('0 cards'), findsOneWidget);

      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start Practice'));
      expect(button.onPressed, isNull);
    });

    testWidgets('disables Start Practice when label filter yields 0 cards',
        (tester) async {
      // Bb5 (id=5) is labeled "Ruy Lopez", but the only card points to
      // Nc6 (id=4), which is NOT under the Ruy Lopez subtree.
      final movesWithLabel = [
        ...whiteLine9.sublist(0, 4),
        labeledBb5(whiteLine9),
        ...whiteLine9.sublist(5),
      ];
      final cardOutsideSubtree = ReviewCard(
        id: 1,
        repertoireId: 1,
        leafMoveId: 4,
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 0,
        nextReviewDate: DateTime(2026, 1, 1),
      );
      final repertoireRepo = FakeRepertoireRepository(moves: movesWithLabel);
      final reviewRepo =
          FakeReviewRepository(allCards: [cardOutsideSubtree]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Initially shows total count (1 card)
      expect(find.text('1 cards'), findsOneWidget);

      // Select Ruy Lopez label
      await tester.enterText(find.byType(TextField), 'Ruy');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ruy Lopez'));
      await tester.pumpAndSettle();

      // Filtered count should be 0 (no cards under Ruy Lopez subtree)
      expect(find.text('0 cards'), findsOneWidget);

      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start Practice'));
      expect(button.onPressed, isNull);
    });
  });

  group('FreePracticeSetupScreen -- Practice All', () {
    testWidgets('Practice All button shows total count and navigates',
        (tester) async {
      final card = buildReviewCard(whiteLine9);
      final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
      final reviewRepo = FakeReviewRepository(allCards: [card]);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Practice All (1 cards)'), findsOneWidget);

      await tester.tap(find.text('Practice All (1 cards)'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(DrillScreen), findsOneWidget);
    });
  });
}
