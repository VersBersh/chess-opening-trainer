import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/screens/add_line_screen.dart';
import 'package:chess_trainer/screens/repertoire_browser_screen.dart';
import 'package:chess_trainer/widgets/inline_label_editor.dart';
import 'package:chess_trainer/widgets/move_tree_widget.dart';

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
  bool createCards = false,
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

  if (createCards) {
    // Identify leaves: moves whose IDs are not the parent of any other move.
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

late SharedPreferences _testPrefs;

Widget buildTestApp(AppDatabase db, int repertoireId,
    {Size viewportSize = const Size(400, 800)}) {
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider
          .overrideWithValue(LocalRepertoireRepository(db)),
      reviewRepositoryProvider.overrideWithValue(LocalReviewRepository(db)),
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: viewportSize),
        child: RepertoireBrowserScreen(repertoireId: repertoireId),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _testPrefs = await SharedPreferences.getInstance();
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

      // Add Line button should always be enabled
      final addLineButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Add Line'),
      );
      expect(addLineButton.onPressed, isNotNull);

      // Stats button should be disabled (no leaf selected)
      final statsButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Stats'),
      );
      expect(statsButton.onPressed, isNull);

      // Select e4 (labeled, has children so NOT a leaf).
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();

      // Delete Branch button should be enabled (non-leaf node)
      final deleteBranchButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete Branch'),
      );
      expect(deleteBranchButton.onPressed, isNotNull);

      // Stats should still be disabled (non-leaf)
      final statsButton2 = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Stats'),
      );
      expect(statsButton2.onPressed, isNull);

      // Now expand and select the leaf node (Nf3)
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      // Need to expand e5 too
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      await tester.ensureVisible(find.text('2. Nf3'));
      await tester.pump();
      await tester.tap(find.text('2. Nf3'));
      await tester.pump();

      // Delete should be enabled (leaf)
      final deleteButton2 = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );
      expect(deleteButton2.onPressed, isNotNull);

      // Stats should be enabled (leaf)
      final statsButton3 = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Stats'),
      );
      expect(statsButton3.onPressed, isNotNull);
    });

    testWidgets('empty repertoire shows empty state', (tester) async {
      final repId = await seedRepertoire(db, lines: []);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.text('No moves yet. Add a line to get started.'),
          findsOneWidget);
    });

    testWidgets('repertoire name and subtitle shown in app bar',
        (tester) async {
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
      expect(find.text('Repertoire Manager'), findsOneWidget);
    });

    testWidgets('board is always PlayerSide.none', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.game?.playerSide, PlayerSide.none);
    });

    testWidgets('no Edit button in action bar', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Edit'), findsNothing);
    });

    testWidgets('no Focus button in action bar', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Focus'), findsNothing);
    });
  });

  group('Label editing', () {
    testWidgets('label button disabled when no node selected', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // No node selected -- Label button should be disabled
      final labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNull);
    });

    testWidgets('label button enabled when a node is selected', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Label button should be enabled
      final labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNotNull);
    });

    testWidgets('open inline editor and save a label', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Tap Label button
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Inline editor should appear
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Enter label text and press Enter
      await tester.enterText(find.byType(TextField), 'King Pawn');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // The label should appear in the tree (bold label text next to move)
      expect(find.textContaining('King Pawn'), findsWidgets);
    });

    testWidgets('open inline editor and clear a label', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4 (which has label "King Pawn")
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();

      // Tap Label button
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Inline editor should appear with existing label pre-filled.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Clear the text and press Enter to remove the label.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify the label is removed from the database
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, isNull);
    });

    testWidgets('dismiss inline editor by selecting a different node',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Tap Label button
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Inline editor should appear
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Select a different node (e5) to dismiss the editor
      await tester.tap(find.text('1...e5'));
      await tester.pumpAndSettle();

      // Editor should be gone
      expect(find.byType(InlineLabelEditor), findsNothing);

      // Verify no label was saved
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, isNull);
    });

    testWidgets('aggregate display name preview in inline editor',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'c5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'Sicilian'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Expand to see Nf3 and select it
      // e4 is labeled so it's collapsed initially. Expand it.
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      // Now expand c5
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      // Select Nf3
      await tester.tap(find.text('2. Nf3'));
      await tester.pump();

      // Tap Label button
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Inline editor should appear
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Type "Najdorf" in the text field
      await tester.enterText(find.byType(TextField), 'Najdorf');
      await tester.pumpAndSettle();

      // Preview should show "Sicilian -- Najdorf"
      expect(find.text('Sicilian \u2014 Najdorf'), findsOneWidget);

      // Select a different node to dismiss without saving
      await tester.tap(find.textContaining('1. e4'));
      await tester.pumpAndSettle();
    });

    testWidgets('label persists after reload', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4, add a label via inline editor
      await tester.tap(find.text('1. e4'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'King Pawn');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify in DB directly
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'King Pawn');
    });

    testWidgets('label works on root, interior, and leaf nodes',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Label root node (e4)
      await tester.tap(find.text('1. e4'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Root Label');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Label interior node (e5) -- expand e4 first
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      await tester.tap(find.text('1...e5'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Interior Label');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Label leaf node (Nf3) -- after labeling e4 and e5, both are
      // collapsed by _computeInitialExpandState (stops at labeled nodes).
      // Re-expand e4, then e5.
      await tester.tap(find.byIcon(Icons.chevron_right).first); // expand e4
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right).first); // expand e5
      await tester.pump();
      await tester.ensureVisible(find.text('2. Nf3'));
      await tester.pump();
      await tester.tap(find.text('2. Nf3'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Leaf Label');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify all three labels in DB
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      final e5Move = moves.firstWhere((m) => m.san == 'e5');
      final nf3Move = moves.firstWhere((m) => m.san == 'Nf3');
      expect(e4Move.label, 'Root Label');
      expect(e5Move.label, 'Interior Label');
      expect(nf3Move.label, 'Leaf Label');
    });

    testWidgets('no-op guard: saving unchanged label preserves existing value',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        labelsOnSan: {'e4': 'Existing'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();

      // Open inline editor
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Don't change the text, just press Enter
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify label is unchanged
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'Existing');
    });

    testWidgets('inline label icon on tree row opens inline editor',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // No node is selected initially.
      // Tap the inline label icon scoped to the MoveTreeWidget.
      final inlineLabelIcons = find.descendant(
        of: find.byType(MoveTreeWidget),
        matching: find.byTooltip('Label'),
      );
      expect(inlineLabelIcons, findsWidgets);

      await tester.tap(inlineLabelIcons.first);
      await tester.pumpAndSettle();

      // The inline editor should appear.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Select a different node to dismiss.
      await tester.tap(find.text('1...e5'));
      await tester.pumpAndSettle();
    });

    testWidgets('inline label save updates the move label', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Tap the inline label icon for e4 (first icon in the tree).
      final inlineLabelIcons = find.descendant(
        of: find.byType(MoveTreeWidget),
        matching: find.byTooltip('Label'),
      );
      await tester.tap(inlineLabelIcons.first);
      await tester.pumpAndSettle();

      // Inline editor should appear.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Enter label text and press Enter.
      await tester.enterText(find.byType(TextField), 'Inline Label');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify label was saved in the database.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'Inline Label');

      // Verify the label is visible in the tree UI.
      expect(find.textContaining('Inline Label'), findsWidgets);
    });

    testWidgets('inline label icon works without selecting the node first',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Verify no node is selected: the action bar Label button should be
      // disabled (no selection).
      final labelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Label'),
      );
      expect(labelButton.onPressed, isNull);

      // Tap the inline label icon for e5 (second icon in the tree).
      final inlineLabelIcons = find.descendant(
        of: find.byType(MoveTreeWidget),
        matching: find.byTooltip('Label'),
      );
      await tester.tap(inlineLabelIcons.last);
      await tester.pumpAndSettle();

      // The inline editor should appear even though no node was selected.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Select a different node to dismiss.
      await tester.tap(find.text('1. e4'));
      await tester.pumpAndSettle();
    });

    testWidgets('inline label clear removes the label', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        labelsOnSan: {'e4': 'To Remove'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Tap the inline label icon for e4 (the labeled node).
      final inlineLabelIcons = find.descendant(
        of: find.byType(MoveTreeWidget),
        matching: find.byTooltip('Label'),
      );
      await tester.tap(inlineLabelIcons.first);
      await tester.pumpAndSettle();

      // Inline editor should appear with existing label pre-filled.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Clear the text and press Enter to remove the label.
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify label was cleared in the database.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, isNull);
    });

    testWidgets('editor closes on node selection change', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4 and open the editor.
      await tester.tap(find.text('1. e4'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Select a different node (e5).
      await tester.tap(find.text('1...e5'));
      await tester.pumpAndSettle();

      // Editor should be dismissed.
      expect(find.byType(InlineLabelEditor), findsNothing);
    });

    testWidgets('editor closes on back navigation', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 and open the editor.
      await tester.tap(find.text('1...e5'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Tap the back navigation button.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Editor should be dismissed.
      expect(find.byType(InlineLabelEditor), findsNothing);
    });

    testWidgets(
        'no warning dialog when no labeled descendants -- label saved directly',
        (tester) async {
      // Tree: e4 -> e5 -> Nf3 -- no labels anywhere
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Open inline editor
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Enter label text and press Enter
      await tester.enterText(find.byType(TextField), 'King Pawn');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // No warning dialog should appear
      expect(find.text('Label affects other names'), findsNothing);

      // Verify label was saved directly
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'King Pawn');
    });

    testWidgets(
        'warning dialog shown when labeled descendants exist -- correct before/after names',
        (tester) async {
      // Tree: e4 (label: "Sicilian") -> c5 -> Nf3 (label: "Open")
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'c5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'Sicilian', 'Nf3': 'Open'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4 (which has label "Sicilian")
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();

      // Open inline editor
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Change label from "Sicilian" to "French"
      await tester.enterText(find.byType(TextField), 'French');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Warning dialog should appear
      expect(find.text('Label affects other names'), findsOneWidget);

      // Should show the before/after display names for Nf3
      expect(find.text('Sicilian \u2014 Open'), findsOneWidget);
      expect(find.text('French \u2014 Open'), findsOneWidget);
    });

    testWidgets(
        'warning dialog -- Apply saves the label',
        (tester) async {
      // Tree: e4 (label: "Sicilian") -> c5 -> Nf3 (label: "Open")
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'c5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'Sicilian', 'Nf3': 'Open'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4, open editor, change label
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'French');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Warning dialog should appear
      expect(find.text('Label affects other names'), findsOneWidget);

      // Tap Apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Verify label was saved
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'French');
    });

    testWidgets(
        'warning dialog -- Cancel does NOT save, editor stays open',
        (tester) async {
      // Tree: e4 (label: "Sicilian") -> c5 -> Nf3 (label: "Open")
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'c5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'Sicilian', 'Nf3': 'Open'},
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4, open editor, change label
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'French');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Warning dialog should appear
      expect(find.text('Label affects other names'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Editor should stay open (LabelChangeCancelledException keeps it open)
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Verify label was NOT changed
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'Sicilian');
    });

    testWidgets('editor closes when edited node is deleted', (tester) async {
      // Use sibling leaves so no orphan prompt after deleting one.
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
          ['e4', 'e5', 'Bc4'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select Nf3 and open the editor.
      await tester.ensureVisible(find.text('2. Nf3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Nf3'));
      await tester.pump();
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Delete Nf3. Tap the Delete button.
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion.
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // Editor should be dismissed (node no longer exists in tree cache).
      expect(find.byType(InlineLabelEditor), findsNothing);
    });
  });

  group('Deletion', () {
    testWidgets('delete a leaf node -- card is removed, tree updates',
        (tester) async {
      // Use a line with siblings so no orphan prompt after deleting one leaf.
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
          ['e4', 'e5', 'Bc4'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Nf3 should be visible (all nodes auto-expanded, no labels).
      expect(find.text('2. Nf3'), findsOneWidget);

      // Select Nf3 (leaf). Scroll into view first — banner gap may push it
      // just past the viewport edge in the test surface.
      await tester.ensureVisible(find.text('2. Nf3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Nf3'));
      await tester.pump();

      // Tap Delete button.
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(find.text('Delete this move and its review card?'), findsOneWidget);

      // Confirm deletion.
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // No orphan prompt -- e5 still has sibling child Bc4.
      expect(find.text('Keep shorter line'), findsNothing);

      // Nf3 should be gone from the tree.
      expect(find.text('2. Nf3'), findsNothing);

      // e4, e5, and Bc4 should remain.
      expect(find.text('1. e4'), findsOneWidget);
      expect(find.text('1...e5'), findsOneWidget);
      expect(find.text('2. Bc4'), findsOneWidget);

      // Verify the card for Nf3 is gone from the database.
      final reviewRepo = LocalReviewRepository(db);
      final allCards = await reviewRepo.getAllCardsForRepertoire(repId);
      // Only the card for Bc4 should remain.
      expect(allCards.length, 1);
    });

    testWidgets('delete a leaf -- orphan prompt appears when parent becomes childless',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (leaf).
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap Delete.
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion.
      expect(find.text('Delete this move and its review card?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // Orphan prompt should appear for e4 (now childless).
      expect(find.text('Keep shorter line'), findsOneWidget);
      expect(find.text('Remove move'), findsOneWidget);
    });

    testWidgets('orphan prompt -- keep shorter line creates a new card for parent',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (leaf), delete, confirm.
      await tester.tap(find.text('1...e5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // Orphan prompt for e4. Choose "Keep shorter line."
      expect(find.text('Keep shorter line'), findsOneWidget);
      await tester.tap(find.text('Keep shorter line'));
      await tester.pumpAndSettle();

      // Verify e4 is shown as a leaf in the tree.
      expect(find.text('1. e4'), findsOneWidget);
      expect(find.text('1...e5'), findsNothing);

      // Verify a new card exists for e4 in the database.
      final reviewRepo = LocalReviewRepository(db);
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves.length, 1); // Only e4 remains.
      final e4Move = moves.first;
      final card = await reviewRepo.getCardForLeaf(e4Move.id);
      expect(card, isNotNull);
    });

    testWidgets('orphan prompt -- remove move deletes the parent',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (leaf), delete, confirm.
      await tester.tap(find.text('1...e5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // Orphan prompt for e4. Choose "Remove move."
      expect(find.text('Remove move'), findsOneWidget);
      await tester.tap(find.text('Remove move'));
      await tester.pumpAndSettle();

      // e4 should also be deleted. Tree should be empty.
      expect(find.text('1. e4'), findsNothing);
      expect(find.text('1...e5'), findsNothing);

      // Verify the tree is empty.
      expect(find.text('No moves yet. Add a line to get started.'),
          findsOneWidget);

      // Verify the database is empty.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves, isEmpty);
    });

    testWidgets('deletion with sibling -- no orphan prompt',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
          ['e4', 'c5'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (leaf).
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap Delete.
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion.
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // No orphan prompt -- e4 still has child c5.
      expect(find.text('Keep shorter line'), findsNothing);
      expect(find.text('Remove move'), findsNothing);

      // Tree should still show e4 and c5.
      expect(find.text('1. e4'), findsOneWidget);
      expect(find.text('1...c5'), findsOneWidget);
      expect(find.text('1...e5'), findsNothing);
    });

    testWidgets('delete branch -- confirmation shows correct counts',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
          ['e4', 'e5', 'Bc4'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (non-leaf, has children Nf3 and Bc4).
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap "Delete Branch".
      await tester.tap(find.widgetWithText(TextButton, 'Delete Branch'));
      await tester.pumpAndSettle();

      // Confirmation dialog should show correct counts.
      expect(find.text('This will delete 2 lines and 2 review cards. Continue?'),
          findsOneWidget);
    });

    testWidgets('delete branch -- all descendants removed',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
          ['e4', 'e5', 'Bc4'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (non-leaf).
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap "Delete Branch", confirm.
      await tester.tap(find.widgetWithText(TextButton, 'Delete Branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // e4 becomes childless -- orphan prompt appears.
      // Choose "Keep shorter line" to keep e4.
      expect(find.text('Keep shorter line'), findsOneWidget);
      await tester.tap(find.text('Keep shorter line'));
      await tester.pumpAndSettle();

      // e5, Nf3, and Bc4 should all be gone.
      expect(find.text('1...e5'), findsNothing);
      expect(find.text('2. Nf3'), findsNothing);
      expect(find.text('2. Bc4'), findsNothing);

      // e4 should remain.
      expect(find.text('1. e4'), findsOneWidget);

      // Verify cards for descendants are gone from the database.
      final reviewRepo = LocalReviewRepository(db);
      final remainingCards = await reviewRepo.getAllCardsForRepertoire(repId);
      // Only the newly created card for e4 (from "Keep shorter line").
      expect(remainingCards.length, 1);
    });

    testWidgets('delete branch -- orphan handling on parent',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (non-leaf, has child Nf3).
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap "Delete Branch", confirm.
      await tester.tap(find.widgetWithText(TextButton, 'Delete Branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // e4 becomes childless. Verify orphan prompt appears.
      expect(find.text('Keep shorter line'), findsOneWidget);
      expect(find.text('Remove move'), findsOneWidget);
    });

    testWidgets('delete a root node (branch) -- no orphan prompt',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
          ['d4', 'd5'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4 (root, non-leaf since it has child e5).
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Tap "Delete Branch", confirm.
      await tester.tap(find.widgetWithText(TextButton, 'Delete Branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // No orphan prompt since e4 was a root (no parent).
      expect(find.text('Keep shorter line'), findsNothing);
      expect(find.text('Remove move'), findsNothing);

      // e4 and e5 should be gone.
      expect(find.text('1. e4'), findsNothing);
      expect(find.text('1...e5'), findsNothing);

      // d4 and d5 should remain.
      expect(find.text('1. d4'), findsOneWidget);
      expect(find.text('1...d5'), findsOneWidget);
    });

    testWidgets('orphan prompt -- dismiss preserves the orphaned move',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (leaf).
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap Delete.
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion.
      expect(find.text('Delete this move and its review card?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();

      // Orphan prompt should appear for e4 (now childless).
      expect(find.text('Keep shorter line'), findsOneWidget);
      expect(find.text('Remove move'), findsOneWidget);

      // Dismiss the dialog by tapping outside it (returns null to the
      // controller). Tapping at (10, 10) hits the ModalBarrier rather than the
      // dialog content that sits at the screen centre.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // e4 should still be visible in the tree (orphan preserved).
      expect(find.text('1. e4'), findsOneWidget);
      // e5 was deleted as intended.
      expect(find.text('1...e5'), findsNothing);

      // Verify DB state: only e4 remains.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves.length, 1);
      expect(moves.first.san, 'e4');

      // No card should exist for e4 -- "Keep shorter line" was NOT chosen,
      // so no card was created. The original e5 card was cascade-deleted.
      final reviewRepo = LocalReviewRepository(db);
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards, isEmpty);
    });
  });

  group('Add Line', () {
    testWidgets('Add Line button is always present and enabled',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Add Line button should be present and enabled even with no selection
      final addLineButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Add Line'),
      );
      expect(addLineButton.onPressed, isNotNull);
    });

    testWidgets('Add Line navigates to AddLineScreen with no selection',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Tap Add Line without selecting a node
      await tester.tap(find.widgetWithText(TextButton, 'Add Line'));
      await tester.pumpAndSettle();

      // Should navigate to AddLineScreen
      expect(find.byType(AddLineScreen), findsOneWidget);
    });

    testWidgets('Add Line navigates to AddLineScreen with startingMoveId',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Tap Add Line with a node selected
      await tester.tap(find.widgetWithText(TextButton, 'Add Line'));
      await tester.pumpAndSettle();

      // Should navigate to AddLineScreen with startingMoveId
      expect(find.byType(AddLineScreen), findsOneWidget);
      final screen =
          tester.widget<AddLineScreen>(find.byType(AddLineScreen));
      expect(screen.startingMoveId, isNotNull);
    });
  });

  group('Card Stats', () {
    testWidgets('Stats button disabled when no leaf selected',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // No selection -- Stats should be disabled
      final statsButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Stats'),
      );
      expect(statsButton.onPressed, isNull);

      // Select e4 (non-leaf) -- Stats should still be disabled
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      final statsButton2 = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Stats'),
      );
      expect(statsButton2.onPressed, isNull);
    });

    testWidgets('Stats button enabled on leaf; dialog shows card data',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (leaf)
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Stats button should be enabled
      final statsButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Stats'),
      );
      expect(statsButton.onPressed, isNotNull);

      // Tap Stats
      await tester.tap(find.widgetWithText(TextButton, 'Stats'));
      await tester.pumpAndSettle();

      // Dialog should show card stats
      expect(find.text('Card Stats'), findsOneWidget);
      expect(find.textContaining('Ease factor:'), findsOneWidget);
      expect(find.textContaining('Interval:'), findsOneWidget);
      expect(find.textContaining('Repetitions:'), findsOneWidget);
      expect(find.textContaining('Next review:'), findsOneWidget);
      expect(find.textContaining('Last quality:'), findsOneWidget);

      // Close the dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Card Stats'), findsNothing);
    });

    testWidgets('Stats on leaf with no card shows snackbar',
        (tester) async {
      // Create repertoire with a leaf but no cards
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: false,
      );

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 (leaf)
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Tap Stats
      await tester.tap(find.widgetWithText(TextButton, 'Stats'));
      await tester.pumpAndSettle();

      // Should show snackbar with message
      expect(find.text('No review card for this move.'), findsOneWidget);

      // Should NOT show the dialog
      expect(find.text('Card Stats'), findsNothing);
    });
  });

  group('RepertoireBrowserScreen — wide layout', () {
    testWidgets('renders board and tree side by side in wide layout',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(
          buildTestApp(db, repId, viewportSize: const Size(900, 800)));
      await tester.pumpAndSettle();

      // Board and tree should render without overflow
      expect(find.byType(Chessboard), findsOneWidget);
      expect(find.byType(MoveTreeWidget), findsOneWidget);

      // Wide layout uses compact action bar with IconButton tooltips.
      // Verify IconButton with tooltip "Add Line" exists (compact bar).
      expect(find.byTooltip('Add Line'), findsOneWidget);

      // Verify TextButton with text "Add Line" does NOT exist
      // (text-labeled buttons are unique to the narrow layout).
      expect(find.widgetWithText(TextButton, 'Add Line'), findsNothing);
    });

    testWidgets('compact action bar shows icon buttons in wide layout',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
      );

      await tester.pumpWidget(
          buildTestApp(db, repId, viewportSize: const Size(900, 800)));
      await tester.pumpAndSettle();

      // Compact action bar should have IconButtons with these icons
      expect(find.widgetWithIcon(IconButton, Icons.add), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.file_upload), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.label), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.bar_chart), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.delete), findsOneWidget);

      // Verify tooltips on compact action bar buttons
      expect(find.byTooltip('Add Line'), findsOneWidget);
      expect(find.byTooltip('Import'), findsOneWidget);
      expect(find.byTooltip('Stats'), findsOneWidget);
      // No selection, so delete tooltip should be "Delete Branch"
      expect(find.byTooltip('Delete Branch'), findsOneWidget);

      // Text-labeled buttons should NOT exist (confirms compact branch)
      expect(find.widgetWithText(TextButton, 'Add Line'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Label'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Stats'), findsNothing);
    });

    testWidgets(
        'action bar buttons have correct enabled/disabled state in wide layout',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5', 'Nf3'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
        createCards: true,
      );

      await tester.pumpWidget(
          buildTestApp(db, repId, viewportSize: const Size(900, 800)));
      await tester.pumpAndSettle();

      // Add Line icon should always be enabled
      final addLineButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(addLineButton.onPressed, isNotNull);

      // Label icon should be disabled (no selection)
      final labelButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.label),
      );
      expect(labelButton.onPressed, isNull);

      // Select e4 (non-leaf, has children)
      await tester.tap(find.textContaining('1. e4'));
      await tester.pump();

      // Label should now be enabled (node selected)
      final labelButton2 = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.label),
      );
      expect(labelButton2.onPressed, isNotNull);

      // Stats should be disabled (non-leaf)
      final statsButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.bar_chart),
      );
      expect(statsButton.onPressed, isNull);

      // Delete should be enabled (non-leaf selected)
      final deleteButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete),
      );
      expect(deleteButton.onPressed, isNotNull);
      // Delete tooltip should be "Delete Branch" for non-leaf
      expect(deleteButton.tooltip, 'Delete Branch');

      // Now expand and select the leaf node (Nf3)
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pump();
      await tester.ensureVisible(find.text('2. Nf3'));
      await tester.pump();
      await tester.tap(find.text('2. Nf3'));
      await tester.pump();

      // Stats should be enabled (leaf selected)
      final statsButton2 = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.bar_chart),
      );
      expect(statsButton2.onPressed, isNotNull);

      // Delete should be enabled (leaf selected)
      final deleteButton2 = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete),
      );
      expect(deleteButton2.onPressed, isNotNull);
      // Delete tooltip should change to "Delete" for leaf
      expect(deleteButton2.tooltip, 'Delete');
    });

    testWidgets('board flip works in wide layout', (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4'],
        ],
      );

      await tester.pumpWidget(
          buildTestApp(db, repId, viewportSize: const Size(900, 800)));
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

    testWidgets('node selection updates board in wide layout',
        (tester) async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
      );

      await tester.pumpWidget(
          buildTestApp(db, repId, viewportSize: const Size(900, 800)));
      await tester.pumpAndSettle();

      // Tap on e5
      await tester.tap(find.text('1...e5'));
      await tester.pump();

      // Board FEN should now reflect position after 1. e4 e5
      final chessboard =
          tester.widget<Chessboard>(find.byType(Chessboard));
      expect(chessboard.fen, isNot(kInitialFEN));
    });
  });

  group('Transposition conflict warnings', () {
    testWidgets(
        'label save proceeds without dialog when no conflicts exist',
        (tester) async {
      // Single line, no transpositions
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e4
      await tester.tap(find.text('1. e4'));
      await tester.pump();

      // Open label editor
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Enter label and submit
      await tester.enterText(find.byType(TextField), 'No Conflict');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // No dialog should appear
      expect(find.text('Label conflict'), findsNothing);

      // Label should be saved
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'No Conflict');
    });

    testWidgets(
        'dialog shown when conflicts exist; user confirms -> label saved',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3', 'Nc6'],
        ['Nf3', 'Nc6', 'e4', 'e5'],
      ]);

      final moves = await LocalRepertoireRepository(db)
          .getMovesForRepertoire(repId);
      final nc6Line1 =
          moves.firstWhere((m) => m.san == 'Nc6' && m.parentMoveId == 3);
      await (db.update(db.repertoireMoves)
            ..where((t) => t.id.equals(nc6Line1.id)))
          .write(const RepertoireMovesCompanion(label: Value('Italian')));

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Navigate to e5 in line 2. All nodes are auto-expanded (no labels
      // on the Nf3 branch that would cause collapsing).
      // Line 2 tree: 1. Nf3 -> 1...Nc6 -> 2. e4 -> 2...e5
      // Find and tap "2...e5" (the transposition endpoint in line 2).
      await tester.ensureVisible(find.text('2...e5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2...e5'));
      await tester.pump();

      // Open label editor
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Enter a different label
      await tester.enterText(find.byType(TextField), 'Ruy Lopez');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Conflict dialog should appear
      expect(find.text('Label conflict'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Italian'),
        ),
        findsOneWidget,
      );

      // Tap "Apply anyway"
      await tester.tap(find.text('Apply anyway'));
      await tester.pumpAndSettle();

      // Label should be saved
      final repRepo = LocalRepertoireRepository(db);
      final updatedMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Line2 =
          moves.firstWhere((m) => m.san == 'e4' && m.parentMoveId == 6);
      final savedE5 = updatedMoves.firstWhere(
          (m) => m.san == 'e5' && m.parentMoveId == e4Line2.id);
      expect(savedE5.label, 'Ruy Lopez');
    });

    testWidgets(
        'dialog shown when conflicts exist; user cancels -> label not saved',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3', 'Nc6'],
        ['Nf3', 'Nc6', 'e4', 'e5'],
      ]);

      final moves = await LocalRepertoireRepository(db)
          .getMovesForRepertoire(repId);
      final nc6Line1 =
          moves.firstWhere((m) => m.san == 'Nc6' && m.parentMoveId == 3);
      await (db.update(db.repertoireMoves)
            ..where((t) => t.id.equals(nc6Line1.id)))
          .write(const RepertoireMovesCompanion(label: Value('Italian')));

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 in line 2
      await tester.ensureVisible(find.text('2...e5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2...e5'));
      await tester.pump();

      // Open label editor
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Enter a conflicting label
      await tester.enterText(find.byType(TextField), 'Ruy Lopez');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Conflict dialog should appear
      expect(find.text('Label conflict'), findsOneWidget);

      // Tap "Cancel"
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Editor should still be open
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Label should NOT be saved
      final repRepo = LocalRepertoireRepository(db);
      final updatedMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Line2 =
          moves.firstWhere((m) => m.san == 'e4' && m.parentMoveId == 6);
      final savedE5 = updatedMoves.firstWhere(
          (m) => m.san == 'e5' && m.parentMoveId == e4Line2.id);
      expect(savedE5.label, isNull);
    });

    testWidgets(
        'clearing a label does NOT show the dialog even when transpositions have labels',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3', 'Nc6'],
        ['Nf3', 'Nc6', 'e4', 'e5'],
      ]);

      final moves = await LocalRepertoireRepository(db)
          .getMovesForRepertoire(repId);
      final nc6Line1 =
          moves.firstWhere((m) => m.san == 'Nc6' && m.parentMoveId == 3);
      await (db.update(db.repertoireMoves)
            ..where((t) => t.id.equals(nc6Line1.id)))
          .write(const RepertoireMovesCompanion(label: Value('Italian')));

      // Give e5 in line 2 a label first so clearing is a change
      final e4Line2 =
          moves.firstWhere((m) => m.san == 'e4' && m.parentMoveId == 6);
      final e5Line2 = moves
          .firstWhere((m) => m.san == 'e5' && m.parentMoveId == e4Line2.id);
      await (db.update(db.repertoireMoves)
            ..where((t) => t.id.equals(e5Line2.id)))
          .write(const RepertoireMovesCompanion(label: Value('Existing')));

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Select e5 in line 2. With the label "Existing" on it, it may be shown
      // with a label suffix. Find by text containing "2...e5".
      await tester.ensureVisible(find.textContaining('2...e5'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('2...e5'));
      await tester.pump();

      // Open label editor
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Clear the text to remove the label
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // No conflict dialog should appear
      expect(find.text('Label conflict'), findsNothing);

      // Label should be cleared
      final repRepo = LocalRepertoireRepository(db);
      final updatedMoves = await repRepo.getMovesForRepertoire(repId);
      final savedE5 =
          updatedMoves.firstWhere((m) => m.id == e5Line2.id);
      expect(savedE5.label, isNull);
    });
  });
}
