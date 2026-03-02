import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/screens/free_practice_setup_screen.dart';
import 'package:chess_trainer/screens/home_screen.dart';

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

class FakeRepertoireRepository implements RepertoireRepository {
  List<Repertoire> _repertoires;
  int _nextId;

  FakeRepertoireRepository({
    List<Repertoire>? repertoires,
  })  : _repertoires =
            repertoires ?? [const Repertoire(id: 1, name: 'Test')],
        _nextId = (repertoires ?? [const Repertoire(id: 1, name: 'Test')])
                .fold<int>(0, (max, r) => r.id > max ? r.id : max) +
            1;

  @override
  Future<List<Repertoire>> getAllRepertoires() async => _repertoires;

  @override
  Future<Repertoire> getRepertoire(int id) async =>
      _repertoires.firstWhere((r) => r.id == id);

  @override
  Future<int> saveRepertoire(RepertoiresCompanion repertoire) async {
    final id = _nextId++;
    _repertoires = [
      ..._repertoires,
      Repertoire(id: id, name: repertoire.name.value),
    ];
    return id;
  }

  @override
  Future<void> deleteRepertoire(int id) async {}

  @override
  Future<List<RepertoireMove>> getMovesForRepertoire(int repertoireId) async =>
      [];

  @override
  Future<RepertoireMove?> getMove(int id) async => null;

  @override
  Future<List<RepertoireMove>> getChildMoves(int parentMoveId) async => [];

  @override
  Future<int> saveMove(RepertoireMovesCompanion move) async => 1;

  @override
  Future<void> deleteMove(int id) async {}

  @override
  Future<List<RepertoireMove>> getRootMoves(int repertoireId) async => [];

  @override
  Future<List<RepertoireMove>> getLineForLeaf(int leafMoveId) async => [];

  @override
  Future<bool> isLeafMove(int moveId) async => true;

  @override
  Future<List<RepertoireMove>> getMovesAtPosition(
          int repertoireId, String fen) async =>
      [];

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
  List<ReviewCard> dueCards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({List<ReviewCard>? dueCards})
      : dueCards = dueCards ?? [];

  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) async => dueCards;

  @override
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
      {DateTime? asOf}) async {
    return dueCards.where((c) => c.repertoireId == repertoireId).toList();
  }

  @override
  Future<ReviewCard?> getCardForLeaf(int leafMoveId) async =>
      dueCards.where((c) => c.leafMoveId == leafMoveId).firstOrNull;

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
      dueCards.where((c) => c.repertoireId == repertoireId).toList();
}

/// A repertoire repository that blocks [getAllRepertoires] on a completer so
/// the loading state is observable in tests without leaving pending timers.
class _SlowRepertoireRepository extends FakeRepertoireRepository {
  final Completer<void> completer = Completer<void>();

  @override
  Future<List<Repertoire>> getAllRepertoires() async {
    await completer.future;
    return super.getAllRepertoires();
  }
}

// ---------------------------------------------------------------------------
// Widget builder helper
// ---------------------------------------------------------------------------

Widget buildTestApp({
  required FakeRepertoireRepository repertoireRepo,
  required FakeReviewRepository reviewRepo,
  AppDatabase? db,
}) {
  final testDb = db ?? AppDatabase(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
      reviewRepositoryProvider.overrideWithValue(reviewRepo),
    ],
    child: MaterialApp(
      home: HomeScreen(db: testDb),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HomeScreen - due count display', () {
    testWidgets('shows due count on initial load', (tester) async {
      final reviewCards = [
        ReviewCard(
          id: 1,
          repertoireId: 1,
          leafMoveId: 10,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 2,
          repertoireId: 1,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 3,
          repertoireId: 1,
          leafMoveId: 30,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];

      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: reviewCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('3 cards due'), findsOneWidget);
    });

    testWidgets('shows 0 cards due when no due cards', (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('0 cards due'), findsOneWidget);
    });

    testWidgets('disables Start Drill button when no cards due',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.widgetWithText(
        FilledButton,
        'Start Drill',
      ));
      expect(button.onPressed, isNull);
    });

    testWidgets('enables Start Drill button when cards are due',
        (tester) async {
      final reviewCards = [
        ReviewCard(
          id: 1,
          repertoireId: 1,
          leafMoveId: 10,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];

      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: reviewCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.widgetWithText(
        FilledButton,
        'Start Drill',
      ));
      expect(button.onPressed, isNotNull);
    });
  });

  group('HomeScreen - due count refresh', () {
    testWidgets('due count updates after controller refresh', (tester) async {
      final reviewCards = [
        ReviewCard(
          id: 1,
          repertoireId: 1,
          leafMoveId: 10,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 2,
          repertoireId: 1,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];

      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: reviewCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Verify initial count
      expect(find.text('2 cards due'), findsOneWidget);

      // Mutate the fake repo to simulate cards being reviewed
      reviewRepo.dueCards = [];

      // Trigger refresh via the controller
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await container.read(homeControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      // Verify updated count
      expect(find.text('0 cards due'), findsOneWidget);
    });

    testWidgets('due count increases after new cards become due',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Verify initial count
      expect(find.text('0 cards due'), findsOneWidget);

      // Add due cards to the fake repo
      reviewRepo.dueCards = [
        ReviewCard(
          id: 1,
          repertoireId: 1,
          leafMoveId: 10,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];

      // Trigger refresh
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await container.read(homeControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      // Verify updated count
      expect(find.text('1 cards due'), findsOneWidget);
    });
  });

  group('HomeScreen - loading and error states', () {
    testWidgets('shows loading indicator when data is pending', (tester) async {
      // Use a slow repo that doesn't resolve immediately
      final repertoireRepo = _SlowRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      // Pump a single frame — the async notifier should still be loading
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the completer so no pending futures remain after the test.
      repertoireRepo.completer.complete();
      await tester.pumpAndSettle();
    });
  });

  group('HomeScreen - repertoire button', () {
    testWidgets('shows Repertoire button', (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Repertoire'), findsOneWidget);
    });
  });

  group('HomeScreen -- Free Practice button', () {
    testWidgets('shows Free Practice button', (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Free Practice'), findsOneWidget);
    });

    testWidgets('Free Practice button is enabled when repertoire exists',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Free Practice'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Free Practice button is disabled when no repertoire exists',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(repertoires: []);
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Free Practice'));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping Free Practice navigates to setup screen',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Free Practice'));
      await tester.pumpAndSettle();

      expect(find.byType(FreePracticeSetupScreen), findsOneWidget);
    });
  });
}
