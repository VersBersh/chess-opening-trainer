import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/screens/add_line_screen.dart';
import 'package:chess_trainer/screens/drill_screen.dart';
import 'package:chess_trainer/screens/free_practice_setup_screen.dart';
import 'package:chess_trainer/screens/home_screen.dart';
import 'package:chess_trainer/screens/repertoire_browser_screen.dart';

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
  List<ReviewCard> allCards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({
    List<ReviewCard>? dueCards,
    List<ReviewCard>? allCards,
  })  : dueCards = dueCards ?? [],
        allCards = allCards ?? dueCards ?? [];

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
      allCards.where((c) => c.repertoireId == repertoireId).toList();
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

late SharedPreferences _testPrefs;

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
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _testPrefs = await SharedPreferences.getInstance();
  });

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

    testWidgets(
        'Start Drill shows snackbar when no cards due',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Start Drill is still tappable (onPressed is not null)
      final button = tester.widget<FilledButton>(find.widgetWithText(
        FilledButton,
        'Start Drill',
      ));
      expect(button.onPressed, isNotNull);

      // Tapping shows a snackbar instead of navigating
      await tester.tap(find.widgetWithText(FilledButton, 'Start Drill'));
      await tester.pump();

      expect(
        find.text('No cards due for review. Come back later!'),
        findsOneWidget,
      );
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

    testWidgets(
        'Free Practice is enabled when repertoire has cards',
        (tester) async {
      final allCards = [
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
      final reviewRepo =
          FakeReviewRepository(dueCards: [], allCards: allCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Free Practice'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
        'Free Practice is disabled when repertoire has no cards',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo =
          FakeReviewRepository(dueCards: [], allCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Free Practice'));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'empty state shows Create your first repertoire button '
        'when no repertoires exist',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(repertoires: []);
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(
          find.text('Create your first repertoire'), findsOneWidget);
      // No Free Practice button in empty state
      expect(find.text('Free Practice'), findsNothing);
    });

    testWidgets('tapping Free Practice navigates to setup screen',
        (tester) async {
      final allCards = [
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
      final reviewRepo =
          FakeReviewRepository(dueCards: [], allCards: allCards);

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

  group('HomeScreen -- per-repertoire card layout', () {
    testWidgets('each repertoire card shows Start Drill, Free Practice, '
        'and Add Line buttons', (tester) async {
      final repertoireRepo = FakeRepertoireRepository(repertoires: const [
        Repertoire(id: 1, name: 'White Openings'),
        Repertoire(id: 2, name: 'Black Openings'),
      ]);
      final allCards = [
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
          repertoireId: 2,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];
      final reviewRepo = FakeReviewRepository(
        dueCards: allCards,
        allCards: allCards,
      );

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Two repertoire names
      expect(find.text('White Openings'), findsOneWidget);
      expect(find.text('Black Openings'), findsOneWidget);

      // Two of each button (one per card)
      expect(find.text('Start Drill'), findsNWidgets(2));
      expect(find.text('Free Practice'), findsNWidgets(2));
      expect(find.text('Add Line'), findsNWidgets(2));
    });

    testWidgets('Start Drill shows snackbar when dueCount == 0',
        (tester) async {
      final allCards = [
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
      final reviewRepo =
          FakeReviewRepository(dueCards: [], allCards: allCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start Drill'));
      await tester.pump();

      expect(
        find.text('No cards due for review. Come back later!'),
        findsOneWidget,
      );
    });

    testWidgets('Start Drill navigates to DrillScreen when dueCount > 0',
        (tester) async {
      final dueCards = [
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
      final reviewRepo = FakeReviewRepository(dueCards: dueCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start Drill'));
      await tester.pumpAndSettle();

      expect(find.byType(DrillScreen), findsOneWidget);
    });

    testWidgets(
        'Free Practice is enabled when repertoire has cards but none due',
        (tester) async {
      final allCards = [
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
      final reviewRepo =
          FakeReviewRepository(dueCards: [], allCards: allCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Free Practice'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Free Practice is disabled when repertoire has no cards',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo =
          FakeReviewRepository(dueCards: [], allCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Free Practice'));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping Add Line navigates to AddLineScreen',
        (tester) async {
      // Seed the in-memory DB with a matching repertoire so
      // AddLineController.loadData() can find it.
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Test'),
          );

      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        db: db,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Line'));
      await tester.pumpAndSettle();

      expect(find.byType(AddLineScreen), findsOneWidget);

      await db.close();
    });

    testWidgets('tapping repertoire name navigates to RepertoireBrowserScreen',
        (tester) async {
      // Seed the in-memory DB so RepertoireBrowserScreen can initialise.
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Test'),
          );

      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
        db: db,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();

      expect(find.byType(RepertoireBrowserScreen), findsOneWidget);

      await db.close();
    });

    testWidgets(
        'empty state shows Create your first repertoire button '
        'and no repertoire cards', (tester) async {
      final repertoireRepo = FakeRepertoireRepository(repertoires: []);
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(
          find.text('Create your first repertoire'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('Start Drill'), findsNothing);
      expect(find.text('Free Practice'), findsNothing);
      expect(find.text('Add Line'), findsNothing);
    });
  });
}
