import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/controllers/add_line_controller.dart';
import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/widgets/chessboard_controller.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory [AppDatabase] for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a repertoire and moves into the database. Returns the repertoire ID.
///
/// [lines] is a list of SAN-string lines. Shared prefixes are deduped.
/// [labelsOnSan] maps a SAN string to a label.
/// [createCards] auto-creates review cards for leaf moves.
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

/// Plays a sequence of SAN moves from a given FEN position and returns FENs.
List<String> computeFens(List<String> sans, {String startFen = kInitialFEN}) {
  final fens = <String>[];
  Position position = Chess.fromSetup(Setup.parseFen(startFen));
  for (final san in sans) {
    final parsed = position.parseSan(san);
    position = position.play(parsed!);
    fens.add(position.fen);
  }
  return fens;
}

/// Helper to create a NormalMove from SAN + position FEN.
NormalMove sanToNormalMove(String fen, String san) {
  final position = Chess.fromSetup(Setup.parseFen(fen));
  final move = position.parseSan(san);
  return move as NormalMove;
}

/// Helper to look up the move ID for a given SAN in the DB.
Future<int?> getMoveIdBySan(AppDatabase db, int repId, String san) async {
  final allMoves = await LocalRepertoireRepository(db)
      .getMovesForRepertoire(repId);
  for (final m in allMoves) {
    if (m.san == san) return m.id;
  }
  return null;
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

  group('Initial state', () {
    test('after loadData with empty tree, pills list is empty', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      expect(controller.state.isLoading, false);
      expect(controller.state.pills, isEmpty);
      expect(controller.canTakeBack, false);
      expect(controller.hasNewMoves, false);
      expect(controller.state.repertoireName, 'Test Repertoire');
      expect(controller.state.currentFen, kInitialFEN);
      expect(controller.state.preMoveFen, kInitialFEN);

      controller.dispose();
    });

    test('after loadData with startingMoveId, existingPath pills populated',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      // Get the move ID for Nf3.
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId, startingMoveId: nf3Id);
      await controller.loadData();

      // Existing path: e4, e5, Nf3 => 3 pills, all saved.
      expect(controller.state.pills.length, 3);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[1].san, 'e5');
      expect(controller.state.pills[2].san, 'Nf3');
      for (final pill in controller.state.pills) {
        expect(pill.isSaved, true);
      }

      // preMoveFen should be the FEN after Nf3.
      final fens = computeFens(['e4', 'e5', 'Nf3']);
      expect(controller.state.preMoveFen, fens[2]);

      controller.dispose();
    });
  });

  group('Accept move flow', () {
    test('play 3 moves, verify pills list and preMoveFen updates', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        final result = controller.onBoardMove(normalMove, boardController);
        expect(result, isA<MoveAccepted>());
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 3);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[1].san, 'e5');
      expect(controller.state.pills[2].san, 'Nf3');

      // preMoveFen should match the resulting FEN after last move.
      final fens = computeFens(moves);
      expect(controller.state.preMoveFen, fens[2]);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Follow existing moves', () {
    test('seed tree with e4 e5 Nf3, play those moves, all pills saved',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 3);
      for (final pill in controller.state.pills) {
        expect(pill.isSaved, true);
      }
      expect(controller.hasNewMoves, false);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Diverge and buffer', () {
    test('seed tree with e4 e5, play e4 e5 d4, first 2 saved, last unsaved',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      final moves = ['e4', 'e5', 'd4'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 3);
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[1].isSaved, true);
      expect(controller.state.pills[2].isSaved, false);
      expect(controller.hasNewMoves, true);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Take-back', () {
    test('buffer 2 moves, take back 1, verify pills shrink by 1', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play 2 moves.
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 2);
      expect(controller.canTakeBack, true);

      // Take back.
      controller.onTakeBack(boardController);

      expect(controller.state.pills.length, 1);
      expect(controller.state.pills[0].san, 'e4');

      // preMoveFen should revert to FEN after e4.
      final fens = computeFens(['e4']);
      expect(controller.state.preMoveFen, fens[0]);

      controller.dispose();
      boardController.dispose();
    });

    test('take back first move on empty tree returns to initial position', () async {
      final repId = await seedRepertoire(db); // empty repertoire
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play one move (e4) -- buffered since tree is empty.
      final normalMove = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(normalMove);
      controller.onBoardMove(normalMove, boardController);

      expect(controller.state.pills.length, 1);
      expect(controller.canTakeBack, true);

      // Take back.
      controller.onTakeBack(boardController);

      expect(controller.state.pills, isEmpty);
      expect(controller.canTakeBack, false);
      expect(controller.state.currentFen, kInitialFEN);
      expect(controller.state.preMoveFen, kInitialFEN);
      // Board should be at initial position.
      expect(boardController.fen, kInitialFEN);

      controller.dispose();
      boardController.dispose();
    });

    test('take back multiple moves returns to previous positions with last-move highlight', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play 3 moves.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 3);

      // Take back Nf3 -- undo() path, should show e5 highlight.
      controller.onTakeBack(boardController);
      expect(controller.state.pills.length, 2);
      final fensAfterE5 = computeFens(['e4', 'e5']);
      expect(controller.state.currentFen, fensAfterE5[1]);
      expect(boardController.lastMove, isNotNull,
          reason: 'After undo(), lastMove should highlight the previous move (e5)');

      // Take back e5 -- undo() path, should show e4 highlight.
      controller.onTakeBack(boardController);
      expect(controller.state.pills.length, 1);
      final fensAfterE4 = computeFens(['e4']);
      expect(controller.state.currentFen, fensAfterE4[0]);
      expect(boardController.lastMove, isNotNull,
          reason: 'After undo(), lastMove should highlight the previous move (e4)');

      // Take back e4 -- undo() path, back to initial, lastMove null is OK.
      controller.onTakeBack(boardController);
      expect(controller.state.pills, isEmpty);
      expect(controller.state.currentFen, kInitialFEN);
      expect(boardController.fen, kInitialFEN);

      controller.dispose();
      boardController.dispose();
    });

    test('take-back works after pill navigation (setPosition fallback)', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play 3 moves.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Navigate to pill 0 (e4) -- this calls setPosition, clearing board history.
      controller.onPillTapped(0, boardController);
      expect(boardController.canUndo, false);

      // Take back should still work (falls back to setPosition).
      controller.onTakeBack(boardController);
      expect(controller.state.pills.length, 2);
      // Board FEN should match the engine's expected FEN.
      expect(boardController.fen, controller.state.currentFen);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Pill tap navigation', () {
    test('play 5 moves, tap pill at index 2, verify state', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      final moves = ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 5);

      // Tap pill at index 2 (Nf3).
      controller.onPillTapped(2, boardController);

      expect(controller.state.focusedPillIndex, 2);

      // preMoveFen should equal the FEN at pill index 2.
      final fens = computeFens(moves);
      expect(controller.state.preMoveFen, fens[2]);
      expect(controller.state.currentFen, fens[2]);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Flip board', () {
    test('toggles boardOrientation', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      expect(controller.state.boardOrientation, Side.white);
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.black);
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.white);

      controller.dispose();
    });
  });

  group('Aggregate display name', () {
    test('seed tree with labels, follow those moves, verify displayName',
        () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        labelsOnSan: {'e4': 'King Pawn'},
      );
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4 (which has the label).
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      expect(controller.state.aggregateDisplayName, 'King Pawn');

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Confirm persistence (extension)', () {
    test('extend a leaf, confirm, verify DB has new moves and new card',
        () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4'],
        ],
        createCards: true,
      );
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4 (leaf), then play e5 (new).
      final fens = computeFens(['e4', 'e5']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      expect(controller.hasNewMoves, true);

      // Line is 2-ply (even) so expected orientation is black. Flip to match.
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());
      final success = result as ConfirmSuccess;
      expect(success.isExtension, true);
      expect(success.insertedMoveIds.length, 1);
      expect(success.oldCard, isNotNull);

      // Verify DB state: new move exists.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves.length, 2); // e4 + e5

      // Verify new review card exists for the new leaf.
      final reviewRepo = LocalReviewRepository(db);
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, success.insertedMoveIds.last);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Confirm persistence (branching)', () {
    test('branch from non-leaf, confirm, verify both old and new cards exist',
        () async {
      final repId = await seedRepertoire(
        db,
        lines: [
          ['e4', 'e5'],
        ],
        createCards: true,
      );
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, then play d5 (branching from non-leaf).
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fens = computeFens(['e4', 'd5']);
      final d5Move = sanToNormalMove(fens[0], 'd5');
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      expect(controller.hasNewMoves, true);

      // Line is 2-ply (even) so expected orientation is black. Flip to match.
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());
      final success = result as ConfirmSuccess;
      expect(success.isExtension, false);

      // Verify DB: original e5 card + new d5 card.
      final reviewRepo = LocalReviewRepository(db);
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 2);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Parity validation', () {
    test('mismatch is detected correctly', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Flip board to black perspective.
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.black);

      // Play 3 moves (odd ply => white line, but board is black).
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmParityMismatch>());
      final mismatch = (result as ConfirmParityMismatch).mismatch;
      expect(mismatch.expectedOrientation, Side.white);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Branching guard - blocked', () {
    test(
        'focus a saved pill with unsaved pills after it, verify MoveBranchBlocked',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, e5, then buffer a new move d4.
      final moves = ['e4', 'e5', 'd4'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 3);
      expect(controller.state.pills[2].isSaved, false); // d4 is unsaved

      // Tap pill at index 0 (e4) to focus it.
      controller.onPillTapped(0, boardController);
      expect(controller.state.focusedPillIndex, 0);

      // Now try to play a different move from the e4 position (black to move).
      final fenAtE4 = controller.state.preMoveFen;
      final d5Move = sanToNormalMove(fenAtE4, 'd5');
      boardController.playMove(d5Move);
      final result = controller.onBoardMove(d5Move, boardController);

      expect(result, isA<MoveBranchBlocked>());
      // Pills should be unchanged.
      expect(controller.state.pills.length, 3);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Branching guard - allowed', () {
    test(
        'focus a saved pill with only saved pills after, play diverging move, verify MoveAccepted',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow all existing moves: e4, e5, Nf3.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.state.pills.length, 3);
      // All pills are saved.
      for (final pill in controller.state.pills) {
        expect(pill.isSaved, true);
      }

      // Tap pill at index 0 (e4) to focus it.
      controller.onPillTapped(0, boardController);
      expect(controller.state.focusedPillIndex, 0);

      // Play a diverging move: d5 (instead of continuing with e5).
      final fenAtE4 = controller.state.preMoveFen;
      final d5Move = sanToNormalMove(fenAtE4, 'd5');
      boardController.playMove(d5Move);
      final result = controller.onBoardMove(d5Move, boardController);

      expect(result, isA<MoveAccepted>());
      // A new engine should have been created. Pills should show
      // existingPath (e4) + buffered (d5).
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[1].san, 'd5');
      expect(controller.state.pills[1].isSaved, false);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Label update', () {
    test('focus a saved pill, call updateLabel, verify label persisted',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      expect(controller.state.pills.length, 1);
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[0].label, isNull);

      // Get the focused pill index (should be 0).
      expect(controller.state.focusedPillIndex, 0);

      // Update the label.
      await controller.updateLabel(0, 'Sicilian');

      // After updateLabel, loadData is called internally.
      // The controller state should be rebuilt.
      // Verify the label is persisted in the DB.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move2 = allMoves.firstWhere((m) => m.san == 'e4');
      expect(e4Move2.label, 'Sicilian');

      controller.dispose();
      boardController.dispose();
    });

    test('updateLabel preserves focusedPillIndex and currentFen', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow all 3 existing moves.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final fens = computeFens(moves);

      // Tap pill at index 1 (e5).
      controller.onPillTapped(1, boardController);
      expect(controller.state.focusedPillIndex, 1);
      expect(controller.state.currentFen, fens[1]);

      // Update label on pill 1.
      await controller.updateLabel(1, 'Sicilian');

      // Assert: navigation state preserved.
      expect(controller.state.focusedPillIndex, 1);
      expect(controller.state.currentFen, fens[1]);
      expect(controller.state.preMoveFen, fens[1]);
      expect(controller.state.pills.length, 3);
      for (final pill in controller.state.pills) {
        expect(pill.isSaved, true);
      }
      expect(controller.state.pills[1].label, 'Sicilian');

      controller.dispose();
      boardController.dispose();
    });

    test('updateLabel does not break subsequent branching', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow all 3 existing moves.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final fens = computeFens(moves);

      // Tap pill at index 1 (e5) to focus it.
      controller.onPillTapped(1, boardController);

      // Update label.
      await controller.updateLabel(1, 'Sicilian');

      // After updateLabel, no new moves and no take-back possible.
      expect(controller.hasNewMoves, false);
      expect(controller.canTakeBack, false);

      // Play a new move (d4) from the e5 position. Black played e5, so
      // it's white to move at fens[1]. d4 is legal.
      final d4Move = sanToNormalMove(fens[1], 'd4');
      boardController.setPosition(fens[1]);
      boardController.playMove(d4Move);
      final result = controller.onBoardMove(d4Move, boardController);

      expect(result, isA<MoveAccepted>());

      // Because focusedPillIndex (1) is not at the end (pills.length was 3),
      // onBoardMove triggers branch mode: creates a new engine from e5's
      // move ID, drops the tail (Nf3), and adds d4 as buffered.
      expect(controller.state.pills.length, 3);
      expect(controller.hasNewMoves, true);
      expect(controller.canTakeBack, true);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[1].san, 'e5');
      expect(controller.state.pills[1].isSaved, true);
      expect(controller.state.pills[2].san, 'd4');
      expect(controller.state.pills[2].isSaved, false);

      controller.dispose();
      boardController.dispose();
    });

    test('updateLabel preserves pills when starting from root', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4 and e5 (startingMoveId is null, so these are followed moves).
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final fens = computeFens(moves);

      // Tap pill 0 (e4).
      controller.onPillTapped(0, boardController);
      expect(controller.state.focusedPillIndex, 0);

      // Update label on pill 0.
      await controller.updateLabel(0, 'King Pawn');

      // Assert: pills preserved, label updated, focus preserved.
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.focusedPillIndex, 0);
      expect(controller.state.currentFen, fens[0]);

      controller.dispose();
      boardController.dispose();
    });

    test('updateLabel is a no-op when hasNewMoves is true', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4 (saved), then play e5 (buffered).
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fens = computeFens(['e4']);
      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      expect(controller.hasNewMoves, true);
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].label, isNull);

      // Attempt to update label while hasNewMoves is true.
      await controller.updateLabel(0, 'Test');

      // Assert: no-op -- label unchanged, state unchanged.
      expect(controller.state.pills[0].label, isNull);
      expect(controller.hasNewMoves, true);
      expect(controller.state.pills.length, 2);

      // Verify the label was NOT persisted to DB.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move2 = allMoves.firstWhere((m) => m.san == 'e4');
      expect(e4Move2.label, isNull);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('getFenAtPillIndex', () {
    test('returns correct FEN for existing, followed, and buffered pills',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, e5, then buffer Nf3.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final fens = computeFens(moves);

      expect(controller.getFenAtPillIndex(0), fens[0]); // e4 (followed)
      expect(controller.getFenAtPillIndex(1), fens[1]); // e5 (followed)
      expect(controller.getFenAtPillIndex(2), fens[2]); // Nf3 (buffered)

      controller.dispose();
      boardController.dispose();
    });
  });

  group('getMoveIdAtPillIndex', () {
    test('returns move ID for saved pills, null for unsaved', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, e5, then buffer Nf3.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      expect(controller.getMoveIdAtPillIndex(0), isNotNull); // e4
      expect(controller.getMoveIdAtPillIndex(1), isNotNull); // e5
      expect(controller.getMoveIdAtPillIndex(2), isNull); // Nf3 (buffered)

      controller.dispose();
      boardController.dispose();
    });
  });

  group('undoNewLine', () {
    test('removes inserted moves after new-line confirm', () async {
      // Seed an empty repertoire, play e4, e5 (2-ply, even), flip, confirm.
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5.
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Flip board for parity (2-ply = even = black expected).
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());
      final success = result as ConfirmSuccess;
      expect(success.isExtension, false);
      expect(success.insertedMoveIds.length, 2);

      // Capture generation before undo.
      final gen = controller.undoGeneration;

      // Verify DB state: 2 moves, 1 card.
      final repRepo = LocalRepertoireRepository(db);
      final reviewRepo = LocalReviewRepository(db);
      var allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves.length, 2);
      var cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);

      // Undo.
      await controller.undoNewLine(gen, success.insertedMoveIds);

      // Verify DB state: 0 moves, 0 cards.
      allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves, isEmpty);
      cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards, isEmpty);

      controller.dispose();
      boardController.dispose();
    });

    test('is a no-op when generation does not match', () async {
      // Seed empty repertoire, play e4, e5, flip, confirm first line.
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5 for the first line.
      var moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      controller.flipBoard();

      final result1 = await controller.confirmAndPersist();
      expect(result1, isA<ConfirmSuccess>());
      final success1 = result1 as ConfirmSuccess;
      final gen1 = controller.undoGeneration;

      // Confirm a second line (d4, d5) to increment generation.
      // Flip back to white first since confirmAndPersist calls loadData.
      controller.flipBoard();

      moves = ['d4', 'd5'];
      currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Flip for parity (even ply -> black).
      controller.flipBoard();

      final result2 = await controller.confirmAndPersist();
      expect(result2, isA<ConfirmSuccess>());

      // Now try to undo the first line with gen1 -- should be a no-op.
      await controller.undoNewLine(gen1, success1.insertedMoveIds);

      // Verify both lines still exist (4 moves, 2 cards).
      final repRepo = LocalRepertoireRepository(db);
      final reviewRepo = LocalReviewRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves.length, 4);
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 2);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('canBranchFromFocusedPill', () {
    test('returns false when no pill is focused', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      expect(controller.canBranchFromFocusedPill(), false);

      controller.dispose();
    });

    test('returns true when focused pill is saved and all after are saved',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow all existing moves.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Focus on pill 0 (e4).
      controller.onPillTapped(0, boardController);

      expect(controller.canBranchFromFocusedPill(), true);

      controller.dispose();
      boardController.dispose();
    });

    test('returns false when unsaved pills exist after focused pill',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ]);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, then buffer e5.
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;

      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Focus on pill 0 (e4, saved). Pill 1 (e5) is unsaved.
      controller.onPillTapped(0, boardController);

      expect(controller.canBranchFromFocusedPill(), false);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Confirm error handling', () {
    test('duplicate sibling SAN triggers ConfirmError with constraint message', () async {
      // Seed a tree with e4 -> e5.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4 (existing), then buffer a move d5 (new).
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fens = computeFens(['e4']);
      final d5Move = sanToNormalMove(fens[0], 'd5');
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      expect(controller.hasNewMoves, true);

      // Flip board to match parity (2-ply = even = black).
      controller.flipBoard();

      // Now inject a conflicting row: insert 'd5' under e4's move ID directly.
      // This simulates a race condition or cache staleness.
      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: fens[0], // doesn't matter for the constraint
          san: 'd5',
          sortOrder: 1,
        ).copyWith(parentMoveId: Value(e4Id)),
      );

      // Now confirm -- the engine thinks d5 is new, but DB has a duplicate.
      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmError>());
      final error = result as ConfirmError;
      expect(error.userMessage, contains('already exists'));

      controller.dispose();
      boardController.dispose();
    });

    test('state remains consistent after ConfirmError', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, buffer d5.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fens = computeFens(['e4']);
      final d5Move = sanToNormalMove(fens[0], 'd5');
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      controller.flipBoard();

      // Inject conflicting row.
      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: fens[0],
          san: 'd5',
          sortOrder: 1,
        ).copyWith(parentMoveId: Value(e4Id)),
      );

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmError>());

      // After error, loadData() was called. State should be consistent.
      expect(controller.state.isLoading, false);
      // hasNewMoves is false because loadData() rebuilt the engine from DB.
      expect(controller.hasNewMoves, false);

      controller.dispose();
      boardController.dispose();
    });

    test('saveBranch atomicity: no partial moves after constraint failure', () async {
      // Seed a tree with e4 -> e5. We'll branch from e4 with d5, Nf3 (2 new moves).
      // Inject a conflicting d5 so the first insert fails.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ], createCards: true);

      final repRepo = LocalRepertoireRepository(db);
      final movesBefore = await repRepo.getMovesForRepertoire(repId);
      final moveCountBefore = movesBefore.length; // e4 + e5 = 2

      final controller = AddLineController(
        repRepo, LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, buffer d5, then Nf6.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fens = computeFens(['e4', 'd5', 'Nf3']);
      final d5Move = sanToNormalMove(fens[0], 'd5');
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      final nf3Move = sanToNormalMove(fens[1], 'Nf3');
      boardController.playMove(nf3Move);
      controller.onBoardMove(nf3Move, boardController);

      // Flip board for parity (3-ply = odd = white).
      // Board is already white, so parity matches.

      // Inject conflicting d5 under e4.
      final e4Id = await getMoveIdBySan(db, repId, 'e4');
      await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: fens[0],
          san: 'd5',
          sortOrder: 1,
        ).copyWith(parentMoveId: Value(e4Id)),
      );

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmError>());

      // Verify atomicity: no partial moves from the branch should remain.
      // The only new row should be the conflicting d5 we injected manually.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      // moveCountBefore (2) + 1 injected conflict = 3. No Nf3 should exist.
      expect(movesAfter.length, moveCountBefore + 1);
      expect(movesAfter.any((m) => m.san == 'Nf3'), false,
          reason: 'Transaction rollback should prevent partial inserts');

      controller.dispose();
      boardController.dispose();
    });
  });
}
