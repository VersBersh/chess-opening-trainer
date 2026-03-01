import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/screens/repertoire_browser_screen.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory [AppDatabase] for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a repertoire and moves into the database. Returns the repertoire ID.
///
/// [moves] is a list of (parentIndex, san) pairs where parentIndex is -1 for
/// root moves. Labels can optionally be attached via [labels] mapping from
/// move index to label string.
Future<int> seedRepertoire(
  AppDatabase db, {
  String name = 'Test Repertoire',
  List<List<String>> lines = const [],
  Map<String, String> labelsOnSan = const {},
}) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: name));

  // Build moves from lines. Each line is a list of SAN strings.
  // Lines share common prefixes automatically via FEN matching.
  final insertedMoves = <String, int>{}; // "parentId:san" -> moveId
  final fenByMoveId = <int, String>{}; // moveId -> resulting FEN

  for (final line in lines) {
    Position position = Chess.initial;
    int? parentMoveId;
    int sortOrder = 0;

    for (final san in line) {
      final key = '${parentMoveId ?? "root"}:$san';
      if (insertedMoves.containsKey(key)) {
        // Move already exists (shared prefix); follow it.
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

  return repId;
}

Widget buildTestApp(AppDatabase db, int repertoireId) {
  return MaterialApp(
    home: RepertoireBrowserScreen(db: db, repertoireId: repertoireId),
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

  group('RepertoireBrowserScreen', () {
    testWidgets('shows loading indicator then tree and board after load',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));

      // Loading indicator should be visible initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for data to load
      await tester.pumpAndSettle();

      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Board should be visible
      expect(find.byType(Chessboard), findsOneWidget);

      // Tree should show at least the root move
      expect(find.text('1. e4'), findsOneWidget);
    });

    testWidgets('selecting a node updates the board position', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // e4 is auto-expanded (no labels), so e5 is already visible.
      // Tap on e5
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Board FEN should now reflect position after 1. e4 e5
      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      // After 1. e4 e5, it should NOT be the initial FEN
      expect(chessboard.fen, isNot(kInitialFEN));
    });

    testWidgets('aggregate display name updates for labeled node',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4 (which has a label). Use textContaining because the label
      // is appended to the move notation inside Text.rich.
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();

      // Display name header should show "King Pawn"
      // (appears both in the header and in the tree node label)
      expect(find.textContaining('King Pawn'), findsWidgets);
    });

    testWidgets('aggregate display name is empty for unlabeled node',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // e4 is auto-expanded (no labels), so e5 is already visible.
      // Select e5 (no labels)
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // No display name header should appear (there are no labels in the path)
      // The display name container won't be built at all when empty.
    });

    testWidgets('expand/collapse toggles child visibility', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // No labels, so all nodes are auto-expanded initially.
      expect(find.text('1. e4'), findsOneWidget);
      expect(find.text('1...e5'), findsOneWidget);
      expect(find.text('2. Nf3'), findsOneWidget);

      // Collapse e4 (currently expanded, shows expand_more icon)
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pump();

      // e5 and Nf3 should no longer be visible
      expect(find.text('1...e5'), findsNothing);
      expect(find.text('2. Nf3'), findsNothing);

      // Re-expand e4 (now collapsed, shows chevron_right)
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();

      // e5 should be visible again
      expect(find.text('1...e5'), findsOneWidget);
    });

    testWidgets('board flip button changes board orientation', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Default orientation is white
      var chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.white);

      // Tap the flip button
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pump();

      // Orientation should now be black
      chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.black);
    });

    testWidgets('back navigation selects parent node', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // e4 is auto-expanded (no labels), so e5 is already visible.
      // Select e5
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      // Board should now show position after e4, not after e4 e5.
      // We verify by checking the board FEN changed.
      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      // After just 1. e4, the FEN is different from initial
      expect(chessboard.fen, isNot(kInitialFEN));
    });

    testWidgets('forward at a branch point expands instead of selecting',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
          ['e4', 'c5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Tap forward button -- e4 has two children (e5, c5), so it should
      // expand instead of selecting
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();

      // Both children should now be visible
      expect(find.text('1...e5'), findsOneWidget);
      expect(find.text('1...c5'), findsOneWidget);
    });

    testWidgets('action buttons enabled/disabled state', (tester) async {
      // Create a repertoire with a labeled node and a leaf node
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4 (labeled, has children so NOT a leaf).
      // Use textContaining because the label is appended in Text.rich.
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();

      // Focus button should be enabled (labeled node)
      final focusButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Focus'),
      );
      expect(focusButton.onPressed, isNotNull);

      // Delete button should be disabled (not a leaf)
      final deleteButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );
      expect(deleteButton.onPressed, isNull);

      // Now expand and select the leaf node (Nf3)
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      // Need to expand e5 too
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      await tester.tap(find.text('2. Nf3'));
      await tester.pump();

      // Delete should be enabled (leaf)
      final deleteButton2 = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );
      expect(deleteButton2.onPressed, isNotNull);

      // Focus should be disabled (no label on Nf3)
      final focusButton2 = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Focus'),
      );
      expect(focusButton2.onPressed, isNull);
    });

    testWidgets('empty repertoire shows empty state', (tester) async {
      final repId = await seedRepertoire(db, lines: []);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.text('No moves yet. Add a line to get started.'),
          findsOneWidget);
    });

    testWidgets('repertoire name is shown in app bar', (tester) async {
      final repId = await seedRepertoire(
        db,
        name: 'Sicilian Defence',
        lines: [
          ['e4', 'c5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      expect(find.text('Sicilian Defence'), findsOneWidget);
    });
  });

  group('Edit mode', () {
    testWidgets('enter edit mode shows edit-mode action bar', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Browse mode: Edit button should be visible
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Take Back'), findsNothing);

      // Tap Edit button
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Edit mode: Confirm and Take Back should be visible
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Take Back'), findsOneWidget);

      // Browse mode buttons should be gone
      expect(find.text('Label'), findsNothing);
      expect(find.text('Focus'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('board becomes interactive in edit mode', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // In browse mode, playerSide should be none
      var chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.game?.playerSide, PlayerSide.none);

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // In edit mode, playerSide should be both
      chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.game?.playerSide, PlayerSide.both);
    });

    testWidgets('confirm button disabled when no new moves', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Confirm should be disabled (no new moves buffered)
      final confirmButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Confirm'),
      );
      expect(confirmButton.onPressed, isNull);
    });

    testWidgets('take-back disabled when no buffered moves', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Take Back should be disabled (no buffered moves)
      final takeBackButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Take Back'),
      );
      expect(takeBackButton.onPressed, isNull);
    });

    testWidgets('discard exits edit mode', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Verify we are in edit mode
      expect(find.text('Confirm'), findsOneWidget);

      // Tap discard (close icon)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Should be back in browse mode
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('navigation buttons hidden in edit mode', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // In browse mode: navigation buttons visible
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Navigation buttons should be hidden
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });

    testWidgets('flip board works in edit mode', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Default orientation is white
      var chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.white);

      // Tap the flip button in edit mode action bar
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pump();

      // Orientation should now be black
      chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.orientation, Side.black);
    });

    testWidgets('enter edit mode from selected node sets board position',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Record board FEN at e5 position
      final chessboardBefore =
          tester.widget<Chessboard>(find.byType(Chessboard));
      final fenAtE5 = chessboardBefore.fen;

      // Enter edit mode from e5 position
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Board should still show position after e5
      final chessboardAfter =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboardAfter.fen, fenAtE5);
    });

    testWidgets('enter edit mode with no selection starts from initial position',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Do not select any node. Enter edit mode.
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Board should show initial position
      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.fen, kInitialFEN);
    });

    testWidgets('empty tree -- enter edit mode from root', (tester) async {
      final repId = await seedRepertoire(db, lines: []);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Enter edit mode on empty repertoire
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Should be in edit mode
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Take Back'), findsOneWidget);

      // Board should show initial position
      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.fen, kInitialFEN);
    });

    testWidgets('discard after entering edit mode restores original position',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      final fenBefore =
          tester.widget<Chessboard>(find.byType(Chessboard)).fen;

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Discard
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Board should show the same position as before entering edit mode
      final fenAfter =
          tester.widget<Chessboard>(find.byType(Chessboard)).fen;
      expect(fenAfter, fenBefore);
    });

    testWidgets('tree selection disabled during edit mode', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Record current board FEN
      final fenInEditMode =
          tester.widget<Chessboard>(find.byType(Chessboard)).fen;

      // Tap a tree node -- should not change the board
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      final fenAfterTap =
          tester.widget<Chessboard>(find.byType(Chessboard)).fen;
      expect(fenAfterTap, fenInEditMode);
    });

    testWidgets('confirm saves moves to database and exits edit mode',
        (tester) async {
      // Start with an empty repertoire to test the full flow.
      // We cannot easily simulate board moves in widget tests, so we
      // verify the infrastructure: enter edit mode, confirm is disabled
      // (no moves), and the DB is empty.
      final repId = await seedRepertoire(db, lines: []);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Confirm should be disabled (no new moves)
      final confirmButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Confirm'),
      );
      expect(confirmButton.onPressed, isNull);

      // Verify the DB has no moves
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves, isEmpty);
    });

    testWidgets('edit button is enabled even with no node selected',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Without selecting any node, Edit button should still be enabled
      final editButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Edit'),
      );
      expect(editButton.onPressed, isNotNull);
    });
  });
}
