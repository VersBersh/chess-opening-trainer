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
import 'package:chess_trainer/widgets/repertoire_card.dart';

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
  Future<List<int>> extendLineWithLabelUpdates(
          int oldLeafMoveId,
          List<RepertoireMovesCompanion> newMoves,
          List<PendingLabelUpdate> labelUpdates) async =>
      [];

  @override
  Future<List<int>> saveBranch(int? parentMoveId,
          List<RepertoireMovesCompanion> newMoves) async =>
      [];

  @override
  Future<List<int>> saveBranchWithLabelUpdates(
          int? parentMoveId,
          List<RepertoireMovesCompanion> newMoves,
          List<PendingLabelUpdate> labelUpdates) async =>
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

  @override
  Future<List<int>> rerouteLine({
    required int? anchorMoveId,
    required List<RepertoireMovesCompanion> newMoves,
    required int oldConvergenceId,
    required List<PendingLabelUpdate> labelUpdates,
  }) =>
      throw UnimplementedError();
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

  group('HomeScreen - repertoire card layout', () {
    testWidgets('shows Start Drill, Free Practice, and Add Line buttons in card',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Start Drill'), findsOneWidget);
      expect(find.text('Free Practice'), findsOneWidget);
      expect(find.text('Add Line'), findsOneWidget);
    });

    testWidgets('shows RepertoireCard and FloatingActionButton',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('tapping repertoire name navigates to RepertoireBrowserScreen',
        (tester) async {
      // Seed the in-memory DB so RepertoireBrowserScreen can initialise.
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Test'),
          );

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

    testWidgets('Add Line navigates to AddLineScreen', (tester) async {
      // Seed the in-memory DB so AddLineScreen can initialise.
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Test'),
          );

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

      await tester.tap(find.text('Add Line'));
      await tester.pumpAndSettle();

      expect(find.byType(AddLineScreen), findsOneWidget);

      await db.close();
    });
  });

  group('HomeScreen - due count display', () {
    testWidgets('shows due count badge on initial load', (tester) async {
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

      expect(find.text('3 due'), findsOneWidget);
    });

    testWidgets('no due badge when no due cards', (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('due count uses per-repertoire count (summary.dueCount)',
        (tester) async {
      // Set up two repertoires: rep 1 has 1 due card, rep 2 has 2 due cards.
      final repertoireRepo = FakeRepertoireRepository(repertoires: const [
        Repertoire(id: 1, name: 'First'),
        Repertoire(id: 2, name: 'Second'),
      ]);
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
        ReviewCard(
          id: 2,
          repertoireId: 2,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 3,
          repertoireId: 2,
          leafMoveId: 30,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];
      final reviewRepo = FakeReviewRepository(dueCards: dueCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Each card shows its own due count
      expect(find.text('1 due'), findsOneWidget);
      expect(find.text('2 due'), findsOneWidget);
    });
  });

  group('HomeScreen - Start Drill button', () {
    testWidgets('Start Drill shows snackbar when no cards due',
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

      // Should not navigate to DrillScreen
      expect(find.byType(DrillScreen), findsNothing);
    });

    testWidgets('Start Drill navigates to DrillScreen when due cards exist',
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
    testWidgets('due count badge updates after controller refresh', (tester) async {
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

      // Verify initial badge
      expect(find.text('2 due'), findsOneWidget);

      // Mutate the fake repo to simulate cards being reviewed
      reviewRepo.dueCards = [];

      // Trigger refresh via the controller
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await container.read(homeControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      // Badge should disappear when no due cards
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('due count badge appears after new cards become due',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository();
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // No badge initially
      expect(find.byType(Badge), findsNothing);

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

      // Badge should now appear
      expect(find.text('1 due'), findsOneWidget);
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

  group('HomeScreen - Free Practice button', () {
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

    testWidgets('tapping Free Practice navigates to DrillScreen',
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

  group('HomeScreen - empty state', () {
    testWidgets(
        'shows Create your first repertoire button when no repertoires exist',
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
      // No action buttons in empty state
      expect(find.text('Start Drill'), findsNothing);
      expect(find.text('Free Practice'), findsNothing);
      expect(find.text('Add Line'), findsNothing);
      expect(find.text('Manage Repertoire'), findsNothing);
    });

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

  // =========================================================================
  // Step 7: Rename repertoire dialog tests
  // =========================================================================

  group('HomeScreen - rename repertoire dialog', () {
    testWidgets('rename dialog opens from context menu with current name pre-filled',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open the popup menu on the card
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap "Rename" menu item
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Verify rename dialog is shown
      expect(find.text('Rename repertoire'), findsOneWidget);

      // Verify the text field is pre-filled with the current name
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Alpha');
    });

    testWidgets('rename validates empty name — Rename button disabled',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu and tap Rename
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Clear the text field
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Verify "Rename" button is disabled
      final renameButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Rename'),
      );
      expect(renameButton.onPressed, isNull);
    });

    testWidgets('rename confirms and updates list with new name',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu and tap Rename
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Enter new name and confirm
      await tester.enterText(find.byType(TextField), 'Bravo');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Rename'));
      await tester.pumpAndSettle();

      // Verify the list now shows the new name
      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('rename cancel does not modify the name', (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu and tap Rename
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Enter a different name but cancel
      await tester.enterText(find.byType(TextField), 'Changed');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Verify original name is still displayed
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Changed'), findsNothing);
    });

    testWidgets('rename shows duplicate warning when name matches existing repertoire',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
        ],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu on the first card (Alpha) and tap Rename
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Enter a name that matches the other repertoire
      await tester.enterText(find.byType(TextField), 'Beta');
      await tester.pumpAndSettle();

      // Verify duplicate warning appears
      expect(
        find.text('A repertoire with this name already exists'),
        findsOneWidget,
      );

      // Verify "Rename" button remains enabled (soft warning)
      final renameButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Rename'),
      );
      expect(renameButton.onPressed, isNotNull);
    });

    testWidgets('rename duplicate warning is case-insensitive',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
        ],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu on the first card (Alpha) and tap Rename
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Enter lowercase version of the other repertoire's name
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pumpAndSettle();

      // Verify duplicate warning appears even with different case
      expect(
        find.text('A repertoire with this name already exists'),
        findsOneWidget,
      );
    });

    testWidgets('rename duplicate warning excludes current name',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
        ],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu on the first card (Alpha) and tap Rename
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Re-enter the same name (Alpha) — should not trigger duplicate warning
      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pumpAndSettle();

      // Verify NO duplicate warning is shown (current name is excluded)
      expect(
        find.text('A repertoire with this name already exists'),
        findsNothing,
      );
    });
  });

  // =========================================================================
  // Step 8: Delete repertoire dialog tests
  // =========================================================================

  group('HomeScreen - delete repertoire dialog', () {
    testWidgets('delete dialog opens from context menu with name in warning',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open the popup menu and tap Delete
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify delete confirmation dialog appears
      expect(find.text('Delete repertoire'), findsOneWidget);
      expect(
        find.text(
            'Delete "Alpha" and all its lines and review cards? This cannot be undone.'),
        findsOneWidget,
      );
    });

    testWidgets('delete confirms and removes repertoire — transitions to empty state',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu and tap Delete
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Should transition to empty state (no repertoires left)
      expect(find.text('Create your first repertoire'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('delete cancel does not remove repertoire', (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu and tap Delete
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Cancel deletion
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Repertoire should still be displayed
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('delete targets correct repertoire in multi-card list',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
        ],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu on the second card (Beta)
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify the delete dialog references Beta
      expect(
        find.text(
            'Delete "Beta" and all its lines and review cards? This cannot be undone.'),
        findsOneWidget,
      );

      // Confirm deletion
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Alpha should remain, Beta should be gone
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });
  });

  // =========================================================================
  // Step 9: Create additional repertoire (FAB) tests
  // =========================================================================

  group('HomeScreen - create additional repertoire', () {
    testWidgets('FAB appears when repertoires exist', (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Verify FAB is present with the correct tooltip
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip('Create repertoire'), findsOneWidget);
    });

    testWidgets('create dialog opens from FAB and creates second repertoire',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Tap the FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify create dialog opens
      expect(find.text('Create repertoire'), findsOneWidget);

      // Enter a name and create
      await tester.enterText(find.byType(TextField), 'Beta');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Create'));
      await tester.pumpAndSettle();

      // Verify two cards are now shown (stays on home screen, does not navigate)
      expect(find.byType(RepertoireCard), findsNWidgets(2));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('create dialog shows duplicate name warning',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [Repertoire(id: 1, name: 'Alpha')],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Tap the FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter a name that already exists
      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pumpAndSettle();

      // Verify duplicate warning appears
      expect(
        find.text('A repertoire with this name already exists'),
        findsOneWidget,
      );

      // Verify "Create" button remains enabled (soft warning)
      final createButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Create'),
      );
      expect(createButton.onPressed, isNotNull);
    });
  });

  // =========================================================================
  // Step 10: Multi-repertoire card rendering and interaction tests
  // =========================================================================

  group('HomeScreen - multi-repertoire list', () {
    testWidgets('renders correct number of RepertoireCard widgets',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
          Repertoire(id: 3, name: 'Gamma'),
        ],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RepertoireCard), findsNWidgets(3));
    });

    testWidgets('each card shows its own name and due count',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
        ],
      );
      // Alpha has 1 due card, Beta has 2 due cards
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
        ReviewCard(
          id: 2,
          repertoireId: 2,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
        ReviewCard(
          id: 3,
          repertoireId: 2,
          leafMoveId: 30,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];
      final reviewRepo = FakeReviewRepository(dueCards: dueCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Both repertoire names should be visible
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      // Due count badges: Alpha has 1 due, Beta has 2 due
      expect(find.text('1 due'), findsOneWidget);
      expect(find.text('2 due'), findsOneWidget);
    });

    testWidgets('rename targets correct repertoire when renaming non-first card',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
        ],
      );
      final reviewRepo = FakeReviewRepository(dueCards: []);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Open popup menu on the second card (Beta)
      await tester.tap(find.byType(PopupMenuButton<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Verify the dialog has Beta pre-filled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Beta');

      // Rename Beta to Gamma
      await tester.enterText(find.byType(TextField), 'Gamma');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Rename'));
      await tester.pumpAndSettle();

      // Alpha should be unchanged, Beta should now be Gamma
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('tapping name on non-first card navigates to RepertoireBrowserScreen with correct ID',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      // Seed two repertoires into the real DB
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Alpha'),
          );
      await db.into(db.repertoires).insert(
            RepertoiresCompanion.insert(name: 'Beta'),
          );

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

      // Tap the name on the second card (Beta)
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      // Should navigate to RepertoireBrowserScreen with Beta's ID (2)
      expect(find.byType(RepertoireBrowserScreen), findsOneWidget);
      final browserScreen = tester.widget<RepertoireBrowserScreen>(
        find.byType(RepertoireBrowserScreen),
      );
      expect(browserScreen.repertoireId, 2);

      await db.close();
    });

    testWidgets('Start Drill on non-first card uses correct repertoire ID',
        (tester) async {
      final repertoireRepo = FakeRepertoireRepository(
        repertoires: const [
          Repertoire(id: 1, name: 'Alpha'),
          Repertoire(id: 2, name: 'Beta'),
        ],
      );
      // Only Beta (id=2) has due cards
      final dueCards = [
        ReviewCard(
          id: 1,
          repertoireId: 2,
          leafMoveId: 20,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 1, 1),
        ),
      ];
      final reviewRepo = FakeReviewRepository(dueCards: dueCards);

      await tester.pumpWidget(buildTestApp(
        repertoireRepo: repertoireRepo,
        reviewRepo: reviewRepo,
      ));
      await tester.pumpAndSettle();

      // Tap "Start Drill" on the second card (Beta)
      // There should be two "Start Drill" buttons — one per card
      final startDrillButtons = find.widgetWithText(FilledButton, 'Start Drill');
      expect(startDrillButtons, findsNWidgets(2));

      // Tap the second Start Drill button (for Beta)
      await tester.tap(startDrillButtons.at(1));
      await tester.pumpAndSettle();

      // Should navigate to DrillScreen with Beta's repertoire ID (2)
      expect(find.byType(DrillScreen), findsOneWidget);
      final drillScreen = tester.widget<DrillScreen>(
        find.byType(DrillScreen),
      );
      expect(drillScreen.config.repertoireId, 2);
    });
  });
}
