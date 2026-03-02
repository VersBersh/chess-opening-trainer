import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/screens/drill_screen.dart';
import 'package:chess_trainer/models/repertoire.dart';
import 'package:chess_trainer/models/review_card.dart';
import 'package:chess_trainer/services/drill_engine.dart';

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
  String? label,
  int? labelAtIndex,
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
      label: (labelAtIndex != null && i == labelAtIndex) ? label : null,
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

/// A FakeReviewRepository that supports subtree queries by using the tree
/// structure to determine which cards are descendants of a given move.
class FakeReviewRepository implements ReviewRepository {
  final List<ReviewCard> _allCards;
  final List<RepertoireMove> _allMoves;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({
    required List<ReviewCard> allCards,
    required List<RepertoireMove> allMoves,
  })  : _allCards = allCards,
        _allMoves = allMoves;

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
      {bool dueOnly = false, DateTime? asOf}) async {
    // Build a set of all move IDs in the subtree rooted at moveId
    final subtreeIds = <int>{};
    final stack = [moveId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      subtreeIds.add(current);
      for (final m in _allMoves) {
        if (m.parentMoveId == current && !subtreeIds.contains(m.id)) {
          stack.add(m.id);
        }
      }
    }

    // Return cards whose leafMoveId is in the subtree
    return _allCards
        .where((c) => subtreeIds.contains(c.leafMoveId))
        .toList();
  }

  @override
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId) async =>
      _allCards.where((c) => c.repertoireId == repertoireId).toList();
}

// ---------------------------------------------------------------------------
// Widget builder helper
// ---------------------------------------------------------------------------

const _freePracticeConfig = DrillConfig(
  repertoireId: 1,
  isExtraPractice: true,
);

const _regularDrillConfig = DrillConfig(repertoireId: 1);

late SharedPreferences _testPrefs;

Widget buildTestApp({
  required FakeRepertoireRepository repertoireRepo,
  required FakeReviewRepository reviewRepo,
  DrillConfig config = _freePracticeConfig,
}) {
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
      reviewRepositoryProvider.overrideWithValue(reviewRepo),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
    child: MaterialApp(
      home: DrillScreen(config: config),
    ),
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

  // Build a tree with two labeled branches:
  //
  // Root: 1. e4
  //   Branch A (labeled "Sicilian" at e5, id=2):
  //     1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O  (ids 1-9)
  //   Branch B (labeled "French" at e6, id=100):
  //     1. e4 e6 2. d4 d5 3. Nc3 Nf6 4. Bg5 Be7 5. e5  (ids 1, 100-108)
  //
  // e4 is shared (id=1). Branch A continues with e5 (id=2), Branch B with e6 (id=100).

  final branchA = buildLine(
    ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O'],
    label: 'Sicilian',
    labelAtIndex: 1, // label on e5 (id=2)
  );

  // Branch B shares e4 (id=1), then diverges
  Position posAfterE4 = Chess.initial;
  posAfterE4 = posAfterE4.play(posAfterE4.parseSan('e4')!);

  Position posAfterE6 = posAfterE4.play(posAfterE4.parseSan('e6')!);
  final e6Move = RepertoireMove(
    id: 100,
    repertoireId: 1,
    parentMoveId: 1, // e4
    fen: posAfterE6.fen,
    san: 'e6',
    sortOrder: 1,
    label: 'French',
  );

  // Continue the French line: 2. d4 d5 3. Nc3 Nf6 4. Bg5 Be7 5. e5
  Position pos = posAfterE6;
  final frenchContinuation = <RepertoireMove>[];
  final frenchSans = ['d4', 'd5', 'Nc3', 'Nf6', 'Bg5', 'Be7', 'e5'];
  int? parentId = 100;
  for (var i = 0; i < frenchSans.length; i++) {
    final san = frenchSans[i];
    pos = pos.play(pos.parseSan(san)!);
    final id = 101 + i;
    frenchContinuation.add(RepertoireMove(
      id: id,
      repertoireId: 1,
      parentMoveId: parentId,
      fen: pos.fen,
      san: san,
      sortOrder: 0,
    ));
    parentId = id;
  }

  final branchBMoves = [e6Move, ...frenchContinuation];
  final branchBLine = [branchA[0], ...branchBMoves]; // e4 + French line

  // All moves in the tree
  final allMoves = [...branchA, ...branchBMoves];

  // Cards
  final cardA = buildReviewCard(branchA, cardId: 1);
  final cardB = buildReviewCard(branchBLine, cardId: 2);
  final allCards = [cardA, cardB];

  group('DrillEngine.replaceQueue', () {
    test('resets queue and index correctly', () {
      final cache = RepertoireTreeCache.build(allMoves);
      final engine = DrillEngine(
        cards: [cardA],
        treeCache: cache,
        isExtraPractice: true,
      );

      expect(engine.totalCards, 1);
      expect(engine.currentIndex, 0);

      // Start a card to advance state
      engine.startCard();
      expect(engine.currentCardState, isNotNull);
      expect(engine.userColor, Side.white);

      // Replace queue with both cards
      engine.replaceQueue([cardA, cardB]);

      expect(engine.totalCards, 2);
      expect(engine.currentIndex, 0);
      expect(engine.currentCardState, isNull);
      expect(engine.isSessionComplete, false);
    });

    test('replacing with empty queue makes session complete', () {
      final cache = RepertoireTreeCache.build(allMoves);
      final engine = DrillEngine(
        cards: [cardA],
        treeCache: cache,
        isExtraPractice: true,
      );

      engine.replaceQueue([]);

      expect(engine.totalCards, 0);
      expect(engine.isSessionComplete, true);
    });
  });

  group('DrillSession.resetQueue', () {
    test('clears and replaces queue in-place', () {
      final session = DrillSession(
        cardQueue: [cardA],
        isExtraPractice: true,
      );

      final originalQueue = session.cardQueue;

      session.resetQueue([cardA, cardB]);

      // Same list instance (in-place mutation)
      expect(identical(session.cardQueue, originalQueue), true);
      expect(session.cardQueue.length, 2);
      expect(session.currentCardIndex, 0);
    });

    test('resets currentCardIndex to 0', () {
      final session = DrillSession(
        cardQueue: [cardA, cardB],
        isExtraPractice: true,
      );

      session.currentCardIndex = 1;
      session.resetQueue([cardA]);

      expect(session.currentCardIndex, 0);
    });
  });

  group('Drill screen — filter box visibility', () {
    testWidgets('filter box is visible in free practice mode',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: allMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
          find.byKey(const ValueKey('drill-filter-box')), findsOneWidget);
    });

    testWidgets('filter box is not visible in regular drill mode',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: allMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _regularDrillConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byKey(const ValueKey('drill-filter-box')), findsNothing);
    });
  });

  group('Drill screen — filter interaction', () {
    testWidgets('selecting a label filters cards to matching subtree',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: allMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Get the notifier and apply filter
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_freePracticeConfig).notifier);

      // Apply filter for "Sicilian" — should scope to branch A only
      unawaited(notifier.applyFilter({'Sicilian'}));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify the filter is applied
      expect(notifier.selectedLabels, {'Sicilian'});

      // The state should be a card start or user turn (not empty)
      final state =
          container.read(drillControllerProvider(_freePracticeConfig));
      final stateVal = state.value!;
      expect(
        stateVal is DrillCardStart || stateVal is DrillUserTurn,
        true,
        reason: 'Expected DrillCardStart or DrillUserTurn, got $stateVal',
      );
    });

    testWidgets('clearing all labels returns to full card set',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: allMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_freePracticeConfig).notifier);

      // Apply filter, then clear it
      unawaited(notifier.applyFilter({'Sicilian'}));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      unawaited(notifier.applyFilter({}));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(notifier.selectedLabels, isEmpty);

      // State should be active (not empty results)
      final state =
          container.read(drillControllerProvider(_freePracticeConfig));
      final stateVal = state.value!;
      expect(
        stateVal is DrillCardStart || stateVal is DrillUserTurn,
        true,
      );
    });

    testWidgets(
        'filter with non-existent label shows DrillFilterNoResults',
        (tester) async {
      // Build a tree with labels but select a label that has no cards
      // We'll use a move with a label but no cards under it (non-leaf with
      // no cards in subtree). Easier: just select a label that doesn't exist.
      // Actually, applyFilter finds moves matching the label — if no moves
      // match, moveIdsForLabel is empty, so no subtree queries run, and
      // filteredCards is empty.
      //
      // But we can't select a non-existent label through the UI since
      // autocomplete limits to available labels. Instead, test via notifier
      // with a label that exists but whose subtree has no cards.
      //
      // Simpler approach: create a tree where one label has no cards.
      final noCardMoves = [
        ...allMoves,
        RepertoireMove(
          id: 200,
          repertoireId: 1,
          parentMoveId: 1,
          fen: 'dummy-fen',
          san: 'd5',
          sortOrder: 2,
          label: 'Scandinavian',
        ),
      ];

      final repertoireRepo = FakeRepertoireRepository(moves: noCardMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: noCardMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_freePracticeConfig).notifier);

      // Select "Scandinavian" — has a labeled move but no cards in its subtree
      unawaited(notifier.applyFilter({'Scandinavian'}));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final state =
          container.read(drillControllerProvider(_freePracticeConfig));
      expect(state.value, isA<DrillFilterNoResults>());

      // Filter box should still be visible
      expect(
          find.byKey(const ValueKey('drill-filter-box')), findsOneWidget);

      // "No cards match this filter" text should be visible
      expect(find.text('No cards match this filter'), findsOneWidget);
    });

    testWidgets(
        'changing filter from empty-result state to valid label starts new queue',
        (tester) async {
      final noCardMoves = [
        ...allMoves,
        RepertoireMove(
          id: 200,
          repertoireId: 1,
          parentMoveId: 1,
          fen: 'dummy-fen',
          san: 'd5',
          sortOrder: 2,
          label: 'Scandinavian',
        ),
      ];

      final repertoireRepo = FakeRepertoireRepository(moves: noCardMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: noCardMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_freePracticeConfig).notifier);

      // First go to empty results
      unawaited(notifier.applyFilter({'Scandinavian'}));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final emptyState =
          container.read(drillControllerProvider(_freePracticeConfig));
      expect(emptyState.value, isA<DrillFilterNoResults>());

      // Now select a valid label
      unawaited(notifier.applyFilter({'Sicilian'}));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final activeState =
          container.read(drillControllerProvider(_freePracticeConfig));
      final stateVal = activeState.value!;
      expect(
        stateVal is DrillCardStart || stateVal is DrillUserTurn,
        true,
        reason:
            'Expected active card state after filtering, got $stateVal',
      );
    });

    testWidgets('selecting multiple labels unions subtrees',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: allMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_freePracticeConfig).notifier);

      // Select both labels
      unawaited(notifier.applyFilter({'Sicilian', 'French'}));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(notifier.selectedLabels, {'Sicilian', 'French'});

      // State should be active
      final state =
          container.read(drillControllerProvider(_freePracticeConfig));
      final stateVal = state.value!;
      expect(
        stateVal is DrillCardStart || stateVal is DrillUserTurn,
        true,
      );
    });

    testWidgets('availableLabels is populated from tree cache',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: allMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillControllerProvider(_freePracticeConfig).notifier);

      // Should have the two labels from the tree, sorted alphabetically
      expect(notifier.availableLabels, ['French', 'Sicilian']);
    });

    testWidgets('filter autocomplete text field is present',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(moves: allMoves);
      final reviewRepo = FakeReviewRepository(
        allCards: allCards,
        allMoves: allMoves,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        config: _freePracticeConfig,
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should find the text field with the hint text
      expect(find.widgetWithText(TextField, 'Filter by label...'),
          findsOneWidget);
    });
  });
}
