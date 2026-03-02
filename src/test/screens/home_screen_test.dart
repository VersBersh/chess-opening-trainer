import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/repositories/repertoire_repository.dart';
import 'package:chess_trainer/repositories/review_repository.dart';
import 'package:chess_trainer/screens/add_line_screen.dart';
import 'package:chess_trainer/screens/drill_screen.dart';
import 'package:chess_trainer/controllers/home_controller.dart';
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
  Future<void> deleteRepertoire(int id) async {
    _repertoires = _repertoires.where((r) => r.id != id).toList();
  }

  @override
  Future<void> renameRepertoire(int id, String newName) async {
    _repertoires = _repertoires.map((r) {
      if (r.id == id) return Repertoire(id: r.id, name: newName);
      return r;
    }).toList();
  }

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

  @override
  Future<int> getCardCountForRepertoire(int repertoireId) async =>
      allCards.where((c) => c.repertoireId == repertoireId).length;

  @override
  Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries(
      {DateTime? asOf}) async {
    // Merge allCards and dueCards so that tests setting only dueCards still work.
    final seen = <int>{};
    final merged = <ReviewCard>[];
    for (final card in [...allCards, ...dueCards]) {
      if (seen.add(card.id)) merged.add(card);
    }
    final map = <int, ({int dueCount, int totalCount})>{};
    for (final card in merged) {
      final rid = card.repertoireId;
      final prev = map[rid] ?? (dueCount: 0, totalCount: 0);
      final isDue = dueCards.contains(card);
      map[rid] = (
        dueCount: prev.dueCount + (isDue ? 1 : 0),
        totalCount: prev.totalCount + 1,
      );
    }
    return map;
  }

  @override
  Future<Map<int, int>> getDueCountForSubtrees(List<int> moveIds,
          {DateTime? asOf}) async =>
      {};
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
}) {
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
      reviewRepositoryProvider.overrideWithValue(reviewRepo),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
    child: const MaterialApp(
      home: HomeScreen(),
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
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 2,
          repertoireId: 1,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 3,
          repertoireId: 1,
          leafMoveId: 30,
          easeFactor: 2.5,
          intervalDays: 0,
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
          intervalDays: 0,
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
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 2,
          repertoireId: 1,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 0,
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
          intervalDays: 0,
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
          intervalDays: 0,
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

    testWidgets('tapping Free Practice navigates to drill screen',
        (tester) async {
      final allCards = [
        ReviewCard(
          id: 1,
          repertoireId: 1,
          leafMoveId: 10,
          easeFactor: 2.5,
          intervalDays: 0,
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

      expect(find.byType(DrillScreen), findsOneWidget);
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
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 2,
          repertoireId: 2,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 0,
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
          intervalDays: 0,
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
          intervalDays: 0,
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
          intervalDays: 0,
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
      // AddLineController.loadData() can find it via the repository providers.
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Test'),
          );

      // Use real DB-backed repos so both HomeController and child screens
      // (which now read from providers) can load data.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repertoireRepositoryProvider
                .overrideWithValue(LocalRepertoireRepository(db)),
            reviewRepositoryProvider
                .overrideWithValue(LocalReviewRepository(db)),
            sharedPreferencesProvider.overrideWithValue(_testPrefs),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
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

      // Use real DB-backed repos so both HomeController and child screens
      // (which now read from providers) can load data.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repertoireRepositoryProvider
                .overrideWithValue(LocalRepertoireRepository(db)),
            reviewRepositoryProvider
                .overrideWithValue(LocalReviewRepository(db)),
            sharedPreferencesProvider.overrideWithValue(_testPrefs),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
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

  group('HomeScreen -- repertoire CRUD', () {
    group('Empty-state create flow', () {
      testWidgets('Create dialog opens from empty state button',
          (tester) async {
        final repertoireRepo = FakeRepertoireRepository(repertoires: []);
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create your first repertoire'));
        await tester.pumpAndSettle();

        expect(find.text('Create repertoire'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Create'), findsOneWidget);
      });

      testWidgets('Create dialog validates empty name', (tester) async {
        final repertoireRepo = FakeRepertoireRepository(repertoires: []);
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create your first repertoire'));
        await tester.pumpAndSettle();

        // "Create" button should be disabled when text field is empty
        final createButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Create'),
        );
        expect(createButton.onPressed, isNull);
      });

      testWidgets('Empty-state create navigates to browser', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              repertoireRepositoryProvider
                  .overrideWithValue(LocalRepertoireRepository(db)),
              reviewRepositoryProvider
                  .overrideWithValue(LocalReviewRepository(db)),
              sharedPreferencesProvider.overrideWithValue(_testPrefs),
            ],
            child: const MaterialApp(
              home: HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should be in empty state
        await tester.tap(find.text('Create your first repertoire'));
        await tester.pumpAndSettle();

        // Enter a name and tap Create
        await tester.enterText(find.byType(TextField), 'My Repertoire');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Create'));
        await tester.pumpAndSettle();

        // Should navigate to RepertoireBrowserScreen
        expect(find.byType(RepertoireBrowserScreen), findsOneWidget);

        await db.close();
      });

      testWidgets('Cancel on empty-state Create dialog does not create',
          (tester) async {
        final repertoireRepo = FakeRepertoireRepository(repertoires: []);
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create your first repertoire'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        // Should still be in empty state
        expect(find.text('Create your first repertoire'), findsOneWidget);
      });
    });

    group('FAB create flow', () {
      testWidgets('Create dialog from FAB', (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        // Tap the FAB
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Create repertoire'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('FAB create adds repertoire to list', (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        // Tap FAB, enter name, confirm
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'New Rep');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Create'));
        await tester.pumpAndSettle();

        // New repertoire should appear in the list (no navigation away)
        expect(find.text('New Rep'), findsOneWidget);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(RepertoireBrowserScreen), findsNothing);
      });

      testWidgets('Cancel on FAB Create dialog does not create',
          (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        // Only the original repertoire should exist
        expect(find.text('Test'), findsOneWidget);
        expect(find.text('New Rep'), findsNothing);
      });
    });

    group('Context menu and Rename', () {
      testWidgets('Context menu shows Rename and Delete', (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        // Tap the PopupMenuButton (more_vert icon)
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('Rename dialog pre-fills current name', (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();

        expect(find.text('Rename repertoire'), findsOneWidget);
        // Text field should be pre-filled with "Test"
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, 'Test');
      });

      testWidgets('Rename updates the repertoire name', (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();

        // Clear and enter new name
        await tester.enterText(find.byType(TextField), 'Renamed Rep');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Rename'));
        await tester.pumpAndSettle();

        // Updated name should appear
        expect(find.text('Renamed Rep'), findsOneWidget);
        expect(find.text('Test'), findsNothing);
      });
    });

    group('Delete', () {
      testWidgets('Delete confirmation dialog shows correct message',
          (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete repertoire'), findsOneWidget);
        expect(
          find.textContaining('Delete Test?'),
          findsOneWidget,
        );
        expect(
          find.textContaining('This cannot be undone.'),
          findsOneWidget,
        );
      });

      testWidgets('Delete removes the repertoire', (tester) async {
        final repertoireRepo = FakeRepertoireRepository(repertoires: const [
          Repertoire(id: 1, name: 'Keep'),
          Repertoire(id: 2, name: 'Remove'),
        ]);
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        // Find the PopupMenuButton for the second card ("Remove")
        final popupButtons =
            find.byType(PopupMenuButton<String>);
        await tester.tap(popupButtons.last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Remove'), findsNothing);
        expect(find.text('Keep'), findsOneWidget);
      });

      testWidgets('Delete last repertoire shows empty state', (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Create your first repertoire'), findsOneWidget);
      });

      testWidgets('Cancel on Delete dialog does not delete', (tester) async {
        final repertoireRepo = FakeRepertoireRepository();
        final reviewRepo = FakeReviewRepository(dueCards: []);

        await tester.pumpWidget(buildTestApp(
          repertoireRepo: repertoireRepo,
          reviewRepo: reviewRepo,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        // Repertoire should still exist
        expect(find.text('Test'), findsOneWidget);
      });
    });
  });
}
