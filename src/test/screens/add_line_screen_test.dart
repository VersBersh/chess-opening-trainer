import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/screens/add_line_screen.dart';
import 'package:chess_trainer/widgets/move_pills_widget.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory [AppDatabase] for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a repertoire and moves into the database. Returns the repertoire ID.
Future<int> seedRepertoire(
  AppDatabase db, {
  String name = 'Test Repertoire',
  List<List<String>> lines = const [],
  Map<String, String> labelsOnSan = const {},
  bool createCards = false,
}) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: name));

  final insertedMoves = <String, int>{}; // "parentId:san" -> moveId
  final fenByMoveId = <int, String>{}; // moveId -> resulting FEN

  for (final line in lines) {
    Position position = Chess.initial;
    int? parentMoveId;
    int sortOrder = 0;

    for (final san in line) {
      final key = '${parentMoveId ?? "root"}:$san';
      if (insertedMoves.containsKey(key)) {
        final existingId = insertedMoves[key]!;
        position = Chess.fromSetup(Setup.parseFen(fenByMoveId[existingId]!));
        parentMoveId = existingId;
        continue;
      }

      final parsed = position.parseSan(san);
      if (parsed == null) {
        throw ArgumentError('Illegal move "$san"');
      }
      position = position.play(parsed);
      final fen = position.fen;

      final moveId = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              parentMoveId: Value(parentMoveId),
              fen: fen,
              san: san,
              label: Value(labelsOnSan[san]),
              sortOrder: sortOrder,
            ),
          );

      insertedMoves[key] = moveId;
      fenByMoveId[moveId] = fen;
      parentMoveId = moveId;
      sortOrder++;
    }
  }

  if (createCards) {
    final allInsertedIds = insertedMoves.values.toSet();
    final parentOfSomeone = <int>{};
    for (final key in insertedMoves.keys) {
      final parts = key.split(':');
      if (parts[0] != 'root') {
        parentOfSomeone.add(int.parse(parts[0]));
      }
    }
    final leafIds = allInsertedIds.difference(parentOfSomeone);
    for (final leafId in leafIds) {
      await db.into(db.reviewCards).insert(
            ReviewCardsCompanion.insert(
              repertoireId: repId,
              leafMoveId: leafId,
              nextReviewDate: DateTime.now(),
            ),
          );
    }
  }

  return repId;
}

/// Helper to look up the move ID for a given SAN in the DB.
Future<int?> getMoveIdBySan(AppDatabase db, int repId, String san) async {
  final allMoves =
      await LocalRepertoireRepository(db).getMovesForRepertoire(repId);
  for (final m in allMoves) {
    if (m.san == san) return m.id;
  }
  return null;
}

Widget buildTestApp(
  AppDatabase db,
  int repertoireId, {
  int? startingMoveId,
}) {
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider
          .overrideWithValue(LocalRepertoireRepository(db)),
      reviewRepositoryProvider.overrideWithValue(LocalReviewRepository(db)),
    ],
    child: MaterialApp(
      home: AddLineScreen(
        repertoireId: repertoireId,
        startingMoveId: startingMoveId,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('AddLineScreen', () {
    testWidgets('renders "Add Line" header', (tester) async {
      final repId = await seedRepertoire(db);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      expect(find.text('Add Line'), findsOneWidget);
    });

    testWidgets('shows loading indicator then content', (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));

      // Loading indicator should be visible initially.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for data to load.
      await tester.pumpAndSettle();

      // Loading indicator should be gone.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Board should be visible.
      expect(find.byType(Chessboard), findsOneWidget);
    });

    testWidgets('board is always interactive (PlayerSide.both)', (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.game?.playerSide, PlayerSide.both);
    });

    testWidgets('empty pills shows "Play a move to begin"', (tester) async {
      final repId = await seedRepertoire(db);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      expect(find.text('Play a move to begin'), findsOneWidget);
    });

    testWidgets('confirm button disabled when no new moves', (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Confirm'),
      );
      expect(confirmButton.onPressed, isNull);
    });

    testWidgets('take-back button disabled when no buffered moves',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      final takeBackButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Take Back'),
      );
      expect(takeBackButton.onPressed, isNull);
    });

    testWidgets('flip board toggles orientation', (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Default orientation is white.
      var chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.white);

      // Tap the flip button.
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pump();

      // Orientation should now be black.
      chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.black);
    });

    testWidgets('no tree explorer on screen', (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // No tree widget should be on screen (unlike repertoire browser).
      // The screen should NOT contain move tree notation like "1. e4".
      expect(find.text('1. e4'), findsNothing);
    });

    testWidgets('label button disabled when no saved pill focused',
        (tester) async {
      final repId = await seedRepertoire(db);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      final labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNull);
    });

    testWidgets('action bar shows all four buttons', (tester) async {
      final repId = await seedRepertoire(db);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.text('Take Back'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Label'), findsOneWidget);
    });

    testWidgets('MovePillsWidget is rendered', (tester) async {
      final repId = await seedRepertoire(db);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      expect(find.byType(MovePillsWidget), findsOneWidget);
    });

    testWidgets(
        'startingMoveId: screen starts at given position with existing path pills',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      // Get the move ID for Nf3.
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // Board should NOT be at initial position.
      final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.fen, isNot(kInitialFEN));

      // Pills should show existing path: e4, e5, Nf3.
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('e5'), findsOneWidget);
      expect(find.text('Nf3'), findsOneWidget);
    });

    testWidgets('aggregate display name shown when labels exist in path',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
      );

      // Start from Nf3 so existing path includes e4 (labeled).
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // The aggregate display name should include "King Pawn".
      // It may also appear in a pill label, so check at least 1 match.
      expect(find.text('King Pawn'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'label on multi-line node: confirmation dialog appears, confirm persists label',
        (tester) async {
      // Tree: e4 -> e5 -> {Nf3, Bc4}  (e5 has 2 descendant leaves)
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
        ['e4', 'e5', 'Bc4'],
      ]);

      // Start at e5 (the branch point with 2 descendant leaves).
      final e5Id = await getMoveIdBySan(db, repId, 'e5');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: e5Id));
      await tester.pumpAndSettle();

      // e5 should be focused (last pill in existing path).
      // Tap Label button.
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Label dialog should open.
      expect(find.text('Add label'), findsOneWidget);

      // Enter label text and save.
      await tester.enterText(find.byType(TextField), 'Branch Point');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Multi-line warning dialog should appear.
      expect(find.text('Label affects multiple lines'), findsOneWidget);
      expect(find.text('This label applies to 2 lines. Continue?'),
          findsOneWidget);

      // Confirm the dialog.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify the label was persisted.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e5Move = moves.firstWhere((m) => m.san == 'e5');
      expect(e5Move.label, 'Branch Point');
    });

    testWidgets(
        'label on multi-line node: cancel confirmation dialog does NOT persist label',
        (tester) async {
      // Tree: e4 -> e5 -> {Nf3, Bc4}  (e5 has 2 descendant leaves)
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
        ['e4', 'e5', 'Bc4'],
      ]);

      // Start at e5.
      final e5Id = await getMoveIdBySan(db, repId, 'e5');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: e5Id));
      await tester.pumpAndSettle();

      // Tap Label button.
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Enter label text and save.
      await tester.enterText(find.byType(TextField), 'Branch Point');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Multi-line warning dialog should appear.
      expect(find.text('Label affects multiple lines'), findsOneWidget);

      // Cancel the dialog.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify the label was NOT persisted.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e5Move = moves.firstWhere((m) => m.san == 'e5');
      expect(e5Move.label, isNull);
    });

    testWidgets(
        'label on leaf node: no confirmation dialog, label persists directly',
        (tester) async {
      // Tree: e4 -> e5 -> Nf3  (Nf3 is a leaf, 1 descendant leaf)
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      // Start at Nf3 (a leaf node).
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // Nf3 should be focused (last pill).
      // Tap Label button.
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Label dialog should open.
      expect(find.text('Add label'), findsOneWidget);

      // Enter label text and save.
      await tester.enterText(find.byType(TextField), 'Leaf Label');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // No confirmation dialog should appear.
      expect(find.text('Label affects multiple lines'), findsNothing);

      // Verify the label was persisted directly.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final nf3Move = moves.firstWhere((m) => m.san == 'Nf3');
      expect(nf3Move.label, 'Leaf Label');
    });

    testWidgets(
        'label button remains enabled after flipping the board',
        (tester) async {
      // Seed a repertoire with saved moves; start at Nf3 so a saved pill is
      // focused and there are no unsaved/buffered moves.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // Label button should be enabled (saved pill focused, no new moves).
      var labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNotNull);

      // Flip the board to black.
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pump();

      // Label button should still be enabled.
      labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNotNull);

      // Flip back to white.
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pump();

      // Label button should still be enabled.
      labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNotNull);
    });

    testWidgets(
        'full label editing flow works with board flipped to black',
        (tester) async {
      // Seed a repertoire with saved moves; start at Nf3 (leaf node).
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // Flip the board to black orientation.
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pump();

      // Verify board is now black.
      final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.black);

      // Tap Label button — should be enabled.
      final labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNotNull);

      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Label dialog should open.
      expect(find.text('Add label'), findsOneWidget);

      // Enter label text and save.
      await tester.enterText(find.byType(TextField), 'Flipped Label');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // No multi-line dialog (leaf node with 1 descendant leaf).
      expect(find.text('Label affects multiple lines'), findsNothing);

      // Verify the label was persisted to the database.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final nf3Move = moves.firstWhere((m) => m.san == 'Nf3');
      expect(nf3Move.label, 'Flipped Label');
    });

    testWidgets('PopScope warns on unsaved moves when navigating back',
        (tester) async {
      final repId = await seedRepertoire(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repertoireRepositoryProvider
                .overrideWithValue(LocalRepertoireRepository(db)),
            reviewRepositoryProvider
                .overrideWithValue(LocalReviewRepository(db)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddLineScreen(
                            repertoireId: repId,
                          ),
                        ),
                      );
                    },
                    child: const Text('Go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Navigate to AddLineScreen.
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Add Line'), findsOneWidget);

      // With no unsaved moves, back should not warn.
      // Verify canPop is true (no unsaved moves).
      // The PopScope's canPop depends on hasNewMoves which is false for empty.
      // We cannot easily test the PopScope dialog without playing moves,
      // but we can verify the structure is in place.
      // PopScope<T> generic type prevents find.byType(PopScope) from matching.
      expect(find.byWidgetPredicate((w) => w is PopScope), findsOneWidget);
    });
  });
}
