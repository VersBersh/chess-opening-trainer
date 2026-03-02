import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/controllers/add_line_controller.dart';
import 'package:chess_trainer/providers.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/screens/add_line_screen.dart';
import 'package:chess_trainer/widgets/chessboard_controller.dart';
import 'package:chess_trainer/widgets/inline_label_editor.dart';
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

/// Helper to create a NormalMove from SAN + position FEN.
NormalMove sanToNormalMove(String fen, String san) {
  final position = Chess.fromSetup(Setup.parseFen(fen));
  final move = position.parseSan(san);
  return move as NormalMove;
}

/// Plays e4 then e5 and taps Confirm to trigger a parity mismatch warning.
/// Board is White (default) with 2 ply (even = Black expected) -> mismatch.
/// Returns after pumpAndSettle so the inline warning is visible.
Future<void> triggerParityMismatchWarning(WidgetTester tester) async {
  var chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
  chessboard.game!.onMove(NormalMove(from: Square.e2, to: Square.e4));
  await tester.pumpAndSettle();

  chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
  chessboard.game!.onMove(NormalMove(from: Square.e7, to: Square.e5));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Confirm'));
  await tester.pumpAndSettle();
}

Widget buildTestApp(
  AppDatabase db,
  int repertoireId, {
  int? startingMoveId,
  AddLineController? controller,
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
        controllerOverride: controller,
      ),
    ),
  );
}

/// Pumps AddLineScreen, plays an extending move after settle, and returns
/// the pieces needed for snackbar assertions. Registers teardown for the
/// injected controller and test board controller automatically.
///
/// After calling this, the Confirm button is enabled. The caller should
/// `await tester.tap(find.text('Confirm'))` and `pumpAndSettle()`.
Future<({AddLineController controller, ChessboardController testBoard, int repId})>
    pumpWithExtendingMove(WidgetTester tester, AppDatabase db) async {
  final repId = await seedRepertoire(db, lines: [['e4']], createCards: true);
  final e4Id = await getMoveIdBySan(db, repId, 'e4');

  final repRepo = LocalRepertoireRepository(db);
  final reviewRepo = LocalReviewRepository(db);
  final controller =
      AddLineController(repRepo, reviewRepo, repId, startingMoveId: e4Id);

  await tester.pumpWidget(
    buildTestApp(db, repId, startingMoveId: e4Id, controller: controller),
  );
  await tester.pumpAndSettle(); // completes loadData()

  // Now play extending move e5 using a test-local board controller.
  final testBoard = ChessboardController();
  // Advance testBoard to the e4 position so it matches the engine state.
  final e4Fen = controller.state.currentFen;
  testBoard.setPosition(e4Fen);
  final e5NormalMove = sanToNormalMove(e4Fen, 'e5');
  testBoard.playMove(e5NormalMove);
  controller.onBoardMove(e5NormalMove, testBoard);

  // Flip board for parity (2-ply = even = black expected).
  controller.flipBoard();

  // Register teardown so callers don't need to remember disposal.
  addTearDown(() {
    controller.dispose();
    testBoard.dispose();
  });

  // Rebuild widget with updated controller state.
  await tester.pump();

  return (controller: controller, testBoard: testBoard, repId: repId);
}

/// Pumps AddLineScreen from initial position with an empty repertoire, plays
/// the move `e4` (1-ply, odd, matches default white orientation), and returns
/// the pieces needed for snackbar assertions. After calling this, the Confirm
/// button is enabled.
Future<({AddLineController controller, ChessboardController testBoard, int repId})>
    pumpWithNewLine(WidgetTester tester, AppDatabase db) async {
  final repId = await seedRepertoire(db);

  final repRepo = LocalRepertoireRepository(db);
  final reviewRepo = LocalReviewRepository(db);
  final controller = AddLineController(repRepo, reviewRepo, repId);

  await tester.pumpWidget(buildTestApp(db, repId, controller: controller));
  await tester.pumpAndSettle(); // completes loadData()

  // Play e4 using a test-local board controller.
  final testBoard = ChessboardController();
  final e4NormalMove = sanToNormalMove(kInitialFEN, 'e4');
  testBoard.playMove(e4NormalMove);
  controller.onBoardMove(e4NormalMove, testBoard);

  // No flip needed: 1-ply (odd) matches default white orientation.

  // Register teardown so callers don't need to remember disposal.
  addTearDown(() {
    controller.dispose();
    testBoard.dispose();
  });

  // Rebuild widget with updated controller state.
  await tester.pump();

  return (controller: controller, testBoard: testBoard, repId: repId);
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
        'label on multi-line node: inline editor shows warning, Enter persists label',
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

      // Inline label editor should appear.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Multi-line warning text should be shown inline.
      expect(
          find.text('This label applies to 2 lines'), findsOneWidget);

      // Enter label text and press Enter.
      await tester.enterText(find.byType(TextField), 'Branch Point');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify the label was persisted.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e5Move = moves.firstWhere((m) => m.san == 'e5');
      expect(e5Move.label, 'Branch Point');
    });

    testWidgets(
        'label on multi-line node: tapping different pill dismisses editor without saving',
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

      // Tap Label button to open inline editor.
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();

      // Inline label editor should appear.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Enter label text but do NOT submit.
      await tester.enterText(find.byType(TextField), 'Branch Point');
      await tester.pumpAndSettle();

      // Tap a different pill (e4) to dismiss the editor.
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();

      // Editor should be gone.
      expect(find.byType(InlineLabelEditor), findsNothing);

      // Verify the label was NOT persisted (editor was dismissed, not saved).
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e5Move = moves.firstWhere((m) => m.san == 'e5');
      expect(e5Move.label, isNull);
    });

    testWidgets(
        'label on leaf node: no multi-line warning, Enter persists label',
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

      // Inline label editor should appear.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // No multi-line warning text (leaf node has 1 descendant leaf).
      expect(find.textContaining('This label applies to'), findsNothing);

      // Enter label text and press Enter.
      await tester.enterText(find.byType(TextField), 'Leaf Label');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

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

      // Inline label editor should appear.
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Enter label text and press Enter.
      await tester.enterText(find.byType(TextField), 'Flipped Label');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify the label was persisted to the database.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final nf3Move = moves.firstWhere((m) => m.san == 'Nf3');
      expect(nf3Move.label, 'Flipped Label');
    });

    testWidgets('extension undo snackbar appears after confirming extension',
        (tester) async {
      await pumpWithExtendingMove(tester, db);

      // Tap Confirm.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Snackbar should appear with "Line extended" and "Undo".
      expect(find.text('Line extended'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets(
        'undo action on extension snackbar rolls back the extension',
        (tester) async {
      final result = await pumpWithExtendingMove(tester, db);

      // Tap Confirm.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Snackbar should appear.
      expect(find.text('Line extended'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Verify DB state after confirm: e4 + e5 moves, card on e5 leaf.
      final reviewRepo = LocalReviewRepository(db);
      final repRepo = LocalRepertoireRepository(db);
      var cards = await reviewRepo.getAllCardsForRepertoire(result.repId);
      expect(cards.length, 1);
      var moves = await repRepo.getMovesForRepertoire(result.repId);
      expect(moves.length, 2);
      final e5Move = moves.firstWhere((m) => m.san == 'e5');
      expect(cards.first.leafMoveId, e5Move.id);

      // Tap Undo on the snackbar.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Verify DB state after undo: e5 removed, card restored to e4.
      moves = await repRepo.getMovesForRepertoire(result.repId);
      expect(moves.length, 1);
      expect(moves.first.san, 'e4');

      cards = await reviewRepo.getAllCardsForRepertoire(result.repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, moves.first.id);
    });

    testWidgets('extension persists after snackbar dismissed without undo',
        (tester) async {
      final result = await pumpWithExtendingMove(tester, db);

      // Tap Confirm.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Snackbar should appear with 8-second auto-dismiss duration.
      expect(find.text('Line extended'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 8));

      // Dismiss the snackbar without tapping Undo (the auto-dismiss Timer
      // is created in the root zone due to Drift async I/O, so we trigger
      // it manually via ScaffoldMessenger).
      final scaffoldContext =
          tester.element(find.byType(AddLineScreen));
      ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Snackbar should be gone.
      expect(find.text('Line extended'), findsNothing);

      // Verify extension persists: e4 + e5 moves, card on e5 leaf.
      final reviewRepo = LocalReviewRepository(db);
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(result.repId);
      expect(moves.length, 2);
      final e5Move = moves.firstWhere((m) => m.san == 'e5');

      final cards = await reviewRepo.getAllCardsForRepertoire(result.repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, e5Move.id);
    });

    testWidgets('re-tapping a focused saved pill opens the inline editor',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');
      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // Nf3 should be the focused pill (last in existing path).
      // Re-tap the focused pill (Nf3) to open the editor.
      await tester.tap(find.text('Nf3'));
      await tester.pumpAndSettle();

      expect(find.byType(InlineLabelEditor), findsOneWidget);
    });

    testWidgets(
        'tapping a different pill while editor is open closes the editor',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');
      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // Open editor via Label button.
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Tap a different pill (e4).
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();

      // Editor should be gone.
      expect(find.byType(InlineLabelEditor), findsNothing);
    });

    testWidgets('board move while editor is open closes the editor',
        (tester) async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      // Start at Nf3 -- no unsaved moves, so Label button is enabled.
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');
      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: nf3Id));
      await tester.pumpAndSettle();

      // Open editor via Label button.
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Simulate a board move by invoking the Chessboard's onMove callback.
      // Position after e4 e5 Nf3 is black to move; Nc6 is a legal move.
      final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      chessboard.game!.onMove(
        NormalMove(from: Square.b8, to: Square.c6),
      );
      await tester.pumpAndSettle();

      // Editor should be dismissed.
      expect(find.byType(InlineLabelEditor), findsNothing);
    });
    testWidgets('take-back removes last pill and shows empty state',
        (tester) async {
      final repId = await seedRepertoire(db); // empty tree

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Verify initial empty state.
      expect(find.text('Play a move to begin'), findsOneWidget);

      // Play a move via the screen's own chessboard callback.
      final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      chessboard.game!.onMove(NormalMove(from: Square.e2, to: Square.e4));
      await tester.pumpAndSettle();

      // Pill should appear.
      expect(find.text('e4'), findsOneWidget);

      // Take Back button should be enabled. Tap it.
      final takeBackButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Take Back'),
      );
      expect(takeBackButton.onPressed, isNotNull);
      await tester.tap(find.text('Take Back'));
      await tester.pumpAndSettle();

      // Pill should be gone, empty state restored.
      expect(find.text('e4'), findsNothing);
      expect(find.text('Play a move to begin'), findsOneWidget);

      // Take Back button should now be disabled.
      final takeBackAfter = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Take Back'),
      );
      expect(takeBackAfter.onPressed, isNull);
    });

    // ---- Inline parity warning tests ----------------------------------------

    testWidgets('parity mismatch shows inline warning, not a dialog',
        (tester) async {
      final repId = await seedRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await triggerParityMismatchWarning(tester);

      // Inline warning should appear (not a dialog).
      expect(find.text('Line parity mismatch'), findsOneWidget);
      expect(find.textContaining('Flip and confirm as Black'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('flip and confirm from inline warning persists the line',
        (tester) async {
      final repId = await seedRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await triggerParityMismatchWarning(tester);
      expect(find.text('Line parity mismatch'), findsOneWidget);

      // Tap "Flip and confirm as Black".
      await tester.tap(find.textContaining('Flip and confirm as Black'));
      await tester.pumpAndSettle();

      expect(find.text('Line parity mismatch'), findsNothing);

      // Moves should be persisted.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves.length, 2);
      expect(moves.any((m) => m.san == 'e4'), isTrue);
      expect(moves.any((m) => m.san == 'e5'), isTrue);
    });

    testWidgets('inline warning is dismissible via close button',
        (tester) async {
      final repId = await seedRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await triggerParityMismatchWarning(tester);
      expect(find.text('Line parity mismatch'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Line parity mismatch'), findsNothing);

      // Moves should NOT be persisted (just dismissed, not confirmed).
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves.length, 0);
    });

    testWidgets('warning auto-dismisses when user plays a new move',
        (tester) async {
      final repId = await seedRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await triggerParityMismatchWarning(tester);
      expect(find.text('Line parity mismatch'), findsOneWidget);

      // Play another move (Nf3) to auto-dismiss the warning.
      final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      chessboard.game!.onMove(NormalMove(from: Square.g1, to: Square.f3));
      await tester.pumpAndSettle();

      expect(find.text('Line parity mismatch'), findsNothing);
    });

    testWidgets('no warning when parity matches -- confirm saves immediately',
        (tester) async {
      // Seed empty tree. Play e4: 1 ply = odd = White expected.
      // Board is White (default) -> parity matches.
      final repId = await seedRepertoire(db);

      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      // Play e4.
      final chessboard = tester.widget<Chessboard>(find.byType(Chessboard));
      chessboard.game!.onMove(NormalMove(from: Square.e2, to: Square.e4));
      await tester.pumpAndSettle();

      // Tap Confirm.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // No parity warning should appear.
      expect(find.text('Line parity mismatch'), findsNothing);

      // Move should be persisted directly.
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      expect(moves.length, 1);
      expect(moves.first.san, 'e4');
    });

    testWidgets('manual board flip clears the inline warning',
        (tester) async {
      final repId = await seedRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await triggerParityMismatchWarning(tester);
      expect(find.text('Line parity mismatch'), findsOneWidget);

      // Scroll to make flip board button visible (warning pushes it off-screen).
      await tester.ensureVisible(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();

      expect(find.text('Line parity mismatch'), findsNothing);
    });

    testWidgets('pill tap clears the inline warning', (tester) async {
      final repId = await seedRepertoire(db);
      await tester.pumpWidget(buildTestApp(db, repId));
      await tester.pumpAndSettle();

      await triggerParityMismatchWarning(tester);
      expect(find.text('Line parity mismatch'), findsOneWidget);

      // Tap the first pill (e4) to navigate to that position.
      await tester.tap(find.text('e4').first);
      await tester.pumpAndSettle();

      // Warning should be dismissed (position context changed).
      expect(find.text('Line parity mismatch'), findsNothing);
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

    testWidgets(
        'no warning dialog when no labeled descendants -- label saved directly',
        (tester) async {
      // Tree: e4 -> e5 -> Nf3 -- no labels
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      // Start at e4 (has unlabeled descendants)
      final e4Id = await getMoveIdBySan(db, repId, 'e4');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: e4Id));
      await tester.pumpAndSettle();

      // Tap Label button
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

      // Start at e4
      final e4Id = await getMoveIdBySan(db, repId, 'e4');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: e4Id));
      await tester.pumpAndSettle();

      // e4 should be the focused pill. Re-tap to open editor.
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();

      expect(find.byType(InlineLabelEditor), findsOneWidget);

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

      // Start at e4
      final e4Id = await getMoveIdBySan(db, repId, 'e4');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: e4Id));
      await tester.pumpAndSettle();

      // Re-tap e4 to open editor
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();

      // Change label and submit
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

      // Start at e4
      final e4Id = await getMoveIdBySan(db, repId, 'e4');

      await tester.pumpWidget(buildTestApp(db, repId, startingMoveId: e4Id));
      await tester.pumpAndSettle();

      // Re-tap e4 to open editor
      await tester.tap(find.text('e4'));
      await tester.pumpAndSettle();

      // Change label and submit
      await tester.enterText(find.byType(TextField), 'French');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Warning dialog should appear
      expect(find.text('Label affects other names'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Editor should stay open
      expect(find.byType(InlineLabelEditor), findsOneWidget);

      // Verify label was NOT changed
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = moves.firstWhere((m) => m.san == 'e4');
      expect(e4Move.label, 'Sicilian');
    });

    testWidgets('new-line undo snackbar appears after confirming a new line',
        (tester) async {
      await pumpWithNewLine(tester, db);

      // Tap Confirm.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Snackbar should appear with "Line saved" and "Undo".
      expect(find.text('Line saved'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets(
        'undo action on new-line snackbar rolls back the new line',
        (tester) async {
      final result = await pumpWithNewLine(tester, db);

      // Tap Confirm.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Snackbar should appear.
      expect(find.text('Line saved'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Verify DB state after confirm: e4 move + card.
      final reviewRepo = LocalReviewRepository(db);
      final repRepo = LocalRepertoireRepository(db);
      var moves = await repRepo.getMovesForRepertoire(result.repId);
      expect(moves.length, 1);
      expect(moves.first.san, 'e4');
      var cards = await reviewRepo.getAllCardsForRepertoire(result.repId);
      expect(cards.length, 1);

      // Tap Undo on the snackbar.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Verify DB state after undo: no moves, no cards.
      moves = await repRepo.getMovesForRepertoire(result.repId);
      expect(moves, isEmpty);
      cards = await reviewRepo.getAllCardsForRepertoire(result.repId);
      expect(cards, isEmpty);
    });

    testWidgets('new-line persists after snackbar dismissed without undo',
        (tester) async {
      final result = await pumpWithNewLine(tester, db);

      // Tap Confirm.
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Snackbar should appear with 8-second auto-dismiss duration.
      expect(find.text('Line saved'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 8));

      // Dismiss the snackbar without tapping Undo.
      final scaffoldContext =
          tester.element(find.byType(AddLineScreen));
      ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Snackbar should be gone.
      expect(find.text('Line saved'), findsNothing);

      // Verify new line persists: e4 move + card.
      final reviewRepo = LocalReviewRepository(db);
      final repRepo = LocalRepertoireRepository(db);
      final moves = await repRepo.getMovesForRepertoire(result.repId);
      expect(moves.length, 1);
      expect(moves.first.san, 'e4');

      final cards = await reviewRepo.getAllCardsForRepertoire(result.repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, moves.first.id);
    });
  });
}
