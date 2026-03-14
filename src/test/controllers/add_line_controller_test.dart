import 'dart:ui' show Color;

import 'package:chessground/chessground.dart' show Arrow;
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

    test('flipBoard does not modify the move buffer', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5, Nf3 (3 buffered moves, 3-ply).
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final engine = controller.state.engine!;
      expect(engine.bufferedMoves.length, 3);

      // Flip white -> black.
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.black);
      expect(engine.bufferedMoves.length, 3);
      expect(engine.bufferedMoves.map((m) => m.san).toList(), ['e4', 'e5', 'Nf3']);

      // Flip black -> white.
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.white);
      expect(engine.bufferedMoves.length, 3);
      expect(engine.bufferedMoves.map((m) => m.san).toList(), ['e4', 'e5', 'Nf3']);

      controller.dispose();
      boardController.dispose();
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

    test('confirmAndPersist after flip returns ConfirmParityMismatch for odd-ply line on black board', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4 (1-ply, odd = white line). Default orientation is white -> parity matches.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      // Flip to black -> now 1-ply line with black board = parity mismatch.
      controller.flipBoard();
      expect(controller.state.boardOrientation, Side.black);

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmParityMismatch>());
      expect((result as ConfirmParityMismatch).mismatch.expectedOrientation, Side.white);

      // Buffer unchanged, nothing written to DB.
      final engine = controller.state.engine!;
      expect(engine.bufferedMoves.length, 1);
      final allMoves = await LocalRepertoireRepository(db).getMovesForRepertoire(repId);
      expect(allMoves, isEmpty);

      controller.dispose();
      boardController.dispose();
    });

    test('buffer is unchanged after confirmAndPersist returns ConfirmParityMismatch', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5, Nf3 (3 buffered moves, 3-ply = odd = white line).
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Flip to black -> mismatch.
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmParityMismatch>());

      // Buffer must still contain all 3 moves with correct SANs.
      final engine = controller.state.engine!;
      expect(engine.bufferedMoves.map((m) => m.san).toList(), ['e4', 'e5', 'Nf3']);

      // Nothing written to DB.
      final allMoves = await LocalRepertoireRepository(db).getMovesForRepertoire(repId);
      expect(allMoves, isEmpty);

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

  group('Label update (deferred persistence)', () {
    test('updateLabel stores pending label in _pendingLabels map',
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

      // Update the label (now synchronous, deferred).
      controller.updateLabel(0, 'Sicilian');

      // Verify the label is in pendingLabels, NOT in the DB.
      expect(controller.pendingLabels[0], 'Sicilian');
      expect(controller.state.pills[0].label, 'Sicilian');

      // DB should still have the original null label.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Db = allMoves.firstWhere((m) => m.san == 'e4');
      expect(e4Db.label, isNull);

      controller.dispose();
      boardController.dispose();
    });

    test('updateLabel with original value removes entry from _pendingLabels',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ], labelsOnSan: {'e4': 'King Pawn'});
      final controller = AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      // Change label to something different.
      controller.updateLabel(0, 'Sicilian');
      expect(controller.pendingLabels[0], 'Sicilian');

      // Revert to original value.
      controller.updateLabel(0, 'King Pawn');
      expect(controller.pendingLabels.containsKey(0), false);

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

      // Update label on pill 1 (now synchronous).
      controller.updateLabel(1, 'Sicilian');

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

    test('updateLabel does not break subsequent branching and clears pending labels', () async {
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

      // Update label (synchronous, deferred).
      controller.updateLabel(1, 'Sicilian');
      expect(controller.pendingLabels[1], 'Sicilian');

      // After updateLabel, no new moves but take-back is possible (followed
      // moves are still visible).
      expect(controller.hasNewMoves, false);
      expect(controller.canTakeBack, true);

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
      // Pending labels should be cleared on branch.
      expect(controller.pendingLabels, isEmpty);
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

      // Update label on pill 0 (synchronous).
      controller.updateLabel(0, 'King Pawn');

      // Assert: pills preserved, label updated, focus preserved.
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.focusedPillIndex, 0);
      expect(controller.state.currentFen, fens[0]);

      controller.dispose();
      boardController.dispose();
    });

    test('updateLabel succeeds and preserves buffered moves when hasNewMoves is true', () async {
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

      // Focus pill 0 (the saved e4 pill) before editing.
      controller.onPillTapped(0, boardController);

      // Update label while hasNewMoves is true (now synchronous).
      controller.updateLabel(0, 'Test');

      // Assert: label is in pendingLabels, NOT yet in DB.
      expect(controller.pendingLabels[0], 'Test');
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Db = allMoves.firstWhere((m) => m.san == 'e4');
      expect(e4Db.label, isNull);

      // Assert: hasNewMoves remains true (buffered moves trivially preserved).
      expect(controller.hasNewMoves, true);

      // Assert: pills list still has 2 items.
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[0].label, 'Test');
      expect(controller.state.pills[1].isSaved, false);

      // Assert: focusedPillIndex and currentFen are preserved.
      expect(controller.state.focusedPillIndex, 0);
      expect(controller.state.currentFen, fens[0]);

      controller.dispose();
      boardController.dispose();
    });

    test('_buildPillsList overlays pending labels onto saved pill data only', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4 and e5 (both saved).
      final fens = computeFens(['e4', 'e5', 'Nf3']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      // Buffer Nf3 (unsaved).
      final nf3Move = sanToNormalMove(fens[1], 'Nf3');
      boardController.playMove(nf3Move);
      controller.onBoardMove(nf3Move, boardController);

      expect(controller.state.pills.length, 3);

      // Update label on pill 0 (saved).
      controller.updateLabel(0, 'King Pawn');

      // Pill 0 should show the pending label.
      expect(controller.state.pills[0].label, 'King Pawn');
      // Pill 1 should show original (null).
      expect(controller.state.pills[1].label, isNull);
      // Pill 2 (buffered) should show BufferedMove.label (null).
      expect(controller.state.pills[2].label, isNull);
      expect(controller.state.pills[2].isSaved, false);

      controller.dispose();
      boardController.dispose();
    });

    test('label editing preserves buffered moves across multiple pills', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4 and e5 (both saved).
      final fens = computeFens(['e4', 'e5', 'Nf3', 'Nc6']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      // Buffer Nf3 and Nc6 (unsaved).
      final nf3Move = sanToNormalMove(fens[1], 'Nf3');
      boardController.playMove(nf3Move);
      controller.onBoardMove(nf3Move, boardController);

      final nc6Move = sanToNormalMove(fens[2], 'Nc6');
      boardController.playMove(nc6Move);
      controller.onBoardMove(nc6Move, boardController);

      expect(controller.state.pills.length, 4);
      expect(controller.hasNewMoves, true);

      // Focus on pill 0 (e4, saved).
      controller.onPillTapped(0, boardController);
      expect(controller.canEditLabel, true);

      // Update label on pill 0 (synchronous).
      controller.updateLabel(0, 'King Pawn');

      // Assert: label is in pendingLabels.
      expect(controller.pendingLabels[0], 'King Pawn');

      // Assert: pills list has 4 items with correct saved/unsaved status.
      expect(controller.state.pills.length, 4);
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.pills[1].isSaved, true);
      expect(controller.state.pills[2].isSaved, false);
      expect(controller.state.pills[3].isSaved, false);

      // Assert: hasNewMoves is still true.
      expect(controller.hasNewMoves, true);

      // Assert: canEditLabel is true when focused on pill 0 (saved).
      expect(controller.canEditLabel, true);

      // Focus on pill 3 (Nc6, unsaved). Assert canEditLabel is true (unsaved
      // pills now support label editing).
      controller.onPillTapped(3, boardController);
      expect(controller.canEditLabel, true);

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

      // CT-54: After confirm, position persists at the e5 leaf (not root).
      // Navigate back to pill 0 (e4) and branch with d5 from there.
      // Post-confirm state: pills are [e4, e5], all saved, position at e5.
      final e5Fen = controller.state.currentFen;
      expect(e5Fen, isNot(kInitialFEN));

      // Navigate to pill 0 (e4 position -- black to move).
      controller.onPillTapped(0, boardController);
      final e4Fen = controller.state.currentFen;

      // Play d5 from e4 position (branching -- diverges from e5).
      final d5Move = sanToNormalMove(e4Fen, 'd5');
      boardController.setPosition(e4Fen);
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      // Flip for parity (2-ply = even = black expected, board was flipped
      // from first confirm -- flip back to white then to black).
      // After first confirm the board is black. We played a 2-ply line
      // (e4, d5) so expected is black. Board is already black -> matches.

      final result2 = await controller.confirmAndPersist();
      expect(result2, isA<ConfirmSuccess>());

      // Now try to undo the first line with gen1 -- should be a no-op.
      await controller.undoNewLine(gen1, success1.insertedMoveIds);

      // Verify both lines still exist (3 moves: e4, e5, d5; 2 cards).
      final repRepo = LocalRepertoireRepository(db);
      final reviewRepo = LocalReviewRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves.length, 3); // e4 shared, e5 from line 1, d5 from line 2
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

  group('hasLineLabel', () {
    test('returns false for a fresh repertoire with no moves', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      expect(controller.hasLineLabel, false);

      controller.dispose();
    });

    test('returns false when line path has no labels', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow existing moves e4, e5.
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Buffer a new move Bc4.
      final bc4Move = sanToNormalMove(currentFen, 'Bc4');
      boardController.playMove(bc4Move);
      controller.onBoardMove(bc4Move, boardController);

      expect(controller.hasNewMoves, true);
      expect(controller.hasLineLabel, false);

      controller.dispose();
      boardController.dispose();
    });

    test('returns true when extending a path that has a label', () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'e5'],
          ],
          labelsOnSan: {'e4': 'King Pawn'});
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow existing moves e4, e5.
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Buffer a new move Nf3.
      final nf3Move = sanToNormalMove(currentFen, 'Nf3');
      boardController.playMove(nf3Move);
      controller.onBoardMove(nf3Move, boardController);

      expect(controller.hasNewMoves, true);
      expect(controller.hasLineLabel, true);

      controller.dispose();
      boardController.dispose();
    });

    test('returns true when branching from a labeled starting node', () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'e5', 'Nf3'],
          ],
          labelsOnSan: {'e5': 'Sicilian'});

      // Find e5's move ID to use as startingMoveId.
      final e5Id = await getMoveIdBySan(db, repId, 'e5');

      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId,
          startingMoveId: e5Id);
      final boardController = ChessboardController();
      await controller.loadData();

      // Buffer a new move d4 (branching from e5).
      final currentFen = controller.state.currentFen;
      final d4Move = sanToNormalMove(currentFen, 'd4');
      boardController.setPosition(currentFen);
      boardController.playMove(d4Move);
      controller.onBoardMove(d4Move, boardController);

      expect(controller.hasNewMoves, true);
      expect(controller.hasLineLabel, true);

      controller.dispose();
      boardController.dispose();
    });

    test('returns true when pending label is set on a saved pill', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow existing moves e4, e5.
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Buffer a new move Nf3.
      final nf3Move = sanToNormalMove(currentFen, 'Nf3');
      boardController.playMove(nf3Move);
      controller.onBoardMove(nf3Move, boardController);

      expect(controller.hasNewMoves, true);
      expect(controller.hasLineLabel, false);

      // Set a pending label on saved pill 0.
      controller.updateLabel(0, 'King Pawn');
      expect(controller.hasLineLabel, true);

      // Revert the pending label.
      controller.updateLabel(0, null);
      expect(controller.hasLineLabel, false);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('unsaved pill label editing', () {
    test('canEditLabel returns true when focused on an unsaved pill', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Buffer e4 (unsaved pill).
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      // Focus on pill 0 (e4, unsaved).
      expect(controller.state.pills.length, 1);
      expect(controller.state.pills[0].isSaved, false);
      expect(controller.state.focusedPillIndex, 0);
      expect(controller.canEditLabel, true);

      controller.dispose();
      boardController.dispose();
    });

    test('updateBufferedLabel sets label on buffered move and rebuilds pills',
        () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Buffer e4 and e5.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fens = computeFens(['e4', 'e5']);
      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].label, isNull);

      // Set label on first buffered pill.
      controller.updateBufferedLabel(0, 'King Pawn');

      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.pills[0].isSaved, false);
      expect(controller.state.pills[1].label, isNull);

      controller.dispose();
      boardController.dispose();
    });

    test('buffered labels are preserved across take-back and re-entry',
        () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Buffer e4, e5, Nf3.
      final fens = computeFens(['e4', 'e5', 'Nf3']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      final nf3Move = sanToNormalMove(fens[1], 'Nf3');
      boardController.playMove(nf3Move);
      controller.onBoardMove(nf3Move, boardController);

      // Label the first two buffered moves.
      controller.updateBufferedLabel(0, 'King Pawn');
      controller.updateBufferedLabel(1, 'Open Game');

      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.pills[1].label, 'Open Game');
      expect(controller.state.pills[2].label, isNull);

      // Take back the last move (Nf3).
      controller.onTakeBack(boardController);

      // Labels on remaining pills should be preserved.
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.pills[1].label, 'Open Game');

      // Re-enter a new move — earlier labels should still persist.
      final nc3Move = sanToNormalMove(fens[1], 'Nc3');
      boardController.playMove(nc3Move);
      controller.onBoardMove(nc3Move, boardController);

      expect(controller.state.pills.length, 3);
      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.pills[1].label, 'Open Game');
      expect(controller.state.pills[2].label, isNull);

      controller.dispose();
      boardController.dispose();
    });

    test('buffered labels are preserved when updateLabel is called on a saved move',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, e5 (saved), then buffer Nf3.
      final fens = computeFens(['e4', 'e5', 'Nf3']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      final nf3Move = sanToNormalMove(fens[1], 'Nf3');
      boardController.playMove(nf3Move);
      controller.onBoardMove(nf3Move, boardController);

      // Label the buffered move Nf3.
      controller.updateBufferedLabel(2, 'Italian');

      expect(controller.state.pills[2].label, 'Italian');
      expect(controller.state.pills[2].isSaved, false);

      // Focus on pill 0 (e4, saved) and update its label (now synchronous).
      controller.onPillTapped(0, boardController);
      controller.updateLabel(0, 'King Pawn');

      // The buffered label on Nf3 should still be preserved (trivially,
      // since updateLabel no longer reloads the engine).
      expect(controller.state.pills.length, 3);
      expect(controller.state.pills[0].label, 'King Pawn');
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[2].label, 'Italian');
      expect(controller.state.pills[2].isSaved, false);

      controller.dispose();
      boardController.dispose();
    });

    test('buffered labels are persisted on confirm', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Buffer e4, e5.
      final fens = computeFens(['e4', 'e5']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      // Label first buffered move.
      controller.updateBufferedLabel(0, 'King Pawn');

      // Flip board for parity (2-ply = even = black expected).
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());

      // Verify the label was persisted to the DB.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Db = allMoves.firstWhere((m) => m.san == 'e4');
      expect(e4Db.label, 'King Pawn');

      controller.dispose();
      boardController.dispose();
    });
  });

  group('isExistingLine', () {
    test('is false at starting position with no pills', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      expect(controller.state.pills, isEmpty);
      expect(controller.isExistingLine, false);

      controller.dispose();
    });

    test('is true when following existing moves without new moves', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
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

      expect(controller.hasNewMoves, false);
      expect(controller.state.pills.isNotEmpty, true);
      expect(controller.isExistingLine, true);

      controller.dispose();
      boardController.dispose();
    });

    test('is false when new moves are buffered', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
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

      // Play an additional new move Nc6 (buffered).
      final nc6Move = sanToNormalMove(currentFen, 'Nc6');
      boardController.playMove(nc6Move);
      controller.onBoardMove(nc6Move, boardController);

      expect(controller.hasNewMoves, true);
      expect(controller.isExistingLine, false);

      controller.dispose();
      boardController.dispose();
    });

    test('is true when starting from a mid-tree position', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);

      // Find e4's move ID to use as startingMoveId.
      final e4Id = await getMoveIdBySan(db, repId, 'e4');

      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId,
          startingMoveId: e4Id);
      await controller.loadData();

      // After loadData with startingMoveId, pills should be non-empty
      // (existingPath contains moves from root to e4) and hasNewMoves
      // should be false.
      expect(controller.state.pills.isNotEmpty, true);
      expect(controller.hasNewMoves, false);
      expect(controller.isExistingLine, true);

      controller.dispose();
    });

    test('becomes false after playing a new move', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
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

      // Verify isExistingLine is true before playing a new move.
      expect(controller.isExistingLine, true);

      // Play a new move Nc6 (buffered).
      final nc6Move = sanToNormalMove(currentFen, 'Nc6');
      boardController.playMove(nc6Move);
      controller.onBoardMove(nc6Move, boardController);

      // isExistingLine should flip to false.
      expect(controller.isExistingLine, false);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Take-back through followed moves', () {
    test('take-back through followed moves shrinks pills and updates board',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4 and e5.
      final moves = ['e4', 'e5'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final fens = computeFens(moves);

      expect(controller.state.pills.length, 2);
      expect(controller.canTakeBack, true);

      // Take back e5 (followed).
      controller.onTakeBack(boardController);
      expect(controller.state.pills.length, 1);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.currentFen, fens[0]);
      expect(boardController.fen, fens[0]);

      // Take back e4 (followed).
      controller.onTakeBack(boardController);
      expect(controller.state.pills, isEmpty);
      expect(controller.state.currentFen, kInitialFEN);
      expect(boardController.fen, kInitialFEN);
      expect(controller.canTakeBack, false);

      controller.dispose();
      boardController.dispose();
    });

    test('take-back through followed moves then new move creates branch',
        () async {
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

      expect(controller.state.pills.length, 3);

      // Take back Nf3 (followed) and e5 (followed).
      controller.onTakeBack(boardController);
      controller.onTakeBack(boardController);
      expect(controller.state.pills.length, 1);
      expect(controller.state.pills[0].san, 'e4');

      final fensAfterE4 = computeFens(['e4']);

      // Play d5 (new move, not in tree as child of e4's child is e5).
      final d5Move = sanToNormalMove(fensAfterE4[0], 'd5');
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      // e4 is saved (followed), d5 is unsaved (buffered).
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[1].san, 'd5');
      expect(controller.state.pills[1].isSaved, false);
      expect(controller.hasNewMoves, true);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('getEffectiveLabelAtPillIndex', () {
    test('returns pending label when one exists', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      // Set pending label.
      controller.updateLabel(0, 'King Pawn');

      expect(controller.getEffectiveLabelAtPillIndex(0), 'King Pawn');

      controller.dispose();
      boardController.dispose();
    });

    test('returns DB label when no pending edit', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ], labelsOnSan: {'e4': 'King Pawn'});
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      // No pending edit -- should return DB label.
      expect(controller.getEffectiveLabelAtPillIndex(0), 'King Pawn');
      expect(controller.pendingLabels, isEmpty);

      controller.dispose();
      boardController.dispose();
    });

    test('returns BufferedMove.label for unsaved pills', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Buffer e4.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      // Label it via updateBufferedLabel.
      controller.updateBufferedLabel(0, 'Test');

      expect(controller.getEffectiveLabelAtPillIndex(0), 'Test');

      controller.dispose();
      boardController.dispose();
    });
  });

  group('Pending labels and confirm', () {
    test('confirmAndPersist persists pending labels alongside moves atomically',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ], createCards: true);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
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

      // Set a pending label on the saved e4 pill.
      controller.onPillTapped(0, boardController);
      controller.updateLabel(0, 'King Pawn');
      expect(controller.pendingLabels[0], 'King Pawn');

      // Flip board for parity (2-ply = even = black expected).
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());

      // Verify that the pending label was persisted to the DB.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Db = allMoves.firstWhere((m) => m.san == 'e4');
      expect(e4Db.label, 'King Pawn');

      // Verify new move was also persisted.
      expect(allMoves.any((m) => m.san == 'e5'), true);

      controller.dispose();
      boardController.dispose();
    });

    test('pending labels are cleared after successful confirm (via loadData)',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ], createCards: true);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4, buffer e5.
      final fens = computeFens(['e4', 'e5']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      // Set pending label.
      controller.onPillTapped(0, boardController);
      controller.updateLabel(0, 'Test');
      expect(controller.pendingLabels, isNotEmpty);

      // Flip and confirm.
      controller.flipBoard();
      await controller.confirmAndPersist();

      // After confirm + loadData, pendingLabels should be empty.
      expect(controller.pendingLabels, isEmpty);

      controller.dispose();
      boardController.dispose();
    });

    test('pending labels are discarded when screen is abandoned (controller disposed)',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow e4.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      // Set pending label.
      controller.updateLabel(0, 'Test');
      expect(controller.pendingLabels[0], 'Test');

      // Verify DB label is unchanged.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Db = allMoves.firstWhere((m) => m.san == 'e4');
      expect(e4Db.label, isNull);

      // Dispose simulates abandoning the screen.
      controller.dispose();
      boardController.dispose();

      // DB label is still null -- pending was never persisted.
      final allMoves2 = await repRepo.getMovesForRepertoire(repId);
      final e4Db2 = allMoves2.firstWhere((m) => m.san == 'e4');
      expect(e4Db2.label, isNull);
    });

    test('pending labels are cleared on branch (via onBoardMove branching path)',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
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

      final fens = computeFens(moves);

      // Set a pending label on pill 0.
      controller.updateLabel(0, 'King Pawn');
      expect(controller.pendingLabels, isNotEmpty);

      // Focus pill 1 and branch.
      controller.onPillTapped(1, boardController);
      final d4Move = sanToNormalMove(fens[1], 'd4');
      boardController.setPosition(fens[1]);
      boardController.playMove(d4Move);
      final result = controller.onBoardMove(d4Move, boardController);

      expect(result, isA<MoveAccepted>());
      // Pending labels should be cleared after branching.
      expect(controller.pendingLabels, isEmpty);

      controller.dispose();
      boardController.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // CT-54: Post-confirm pill and position persistence
  // ---------------------------------------------------------------------------

  group('CT-54: Pills persist after confirm', () {
    test('pills persist after confirm (root start), all marked saved', () async {
      // Seed empty repertoire, play e4/e5, flip to black, confirm.
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5.
      final fens = computeFens(['e4', 'e5']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      // Flip board for parity (2-ply = even = black expected).
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());

      // After confirm, pills should persist with 2 pills, both saved.
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[1].san, 'e5');
      expect(controller.state.pills[1].isSaved, true);

      // hasNewMoves should be false (all moves now saved).
      expect(controller.hasNewMoves, false);

      // isExistingLine should be true.
      expect(controller.isExistingLine, true);

      // currentFen should be the FEN after e5 (not kInitialFEN).
      expect(controller.state.currentFen, fens[1]);
      expect(controller.state.currentFen, isNot(kInitialFEN));

      controller.dispose();
      boardController.dispose();
    });

    test('pills persist after confirm (mid-tree start)', () async {
      // Seed repertoire with e4/e5/Nf3, create controller with
      // startingMoveId = Nf3, play Nc6, flip, confirm.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ]);
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId,
          startingMoveId: nf3Id);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play Nc6 (extends from Nf3).
      final nf3Fen = controller.state.currentFen;
      final nc6Move = sanToNormalMove(nf3Fen, 'Nc6');
      boardController.setPosition(nf3Fen);
      boardController.playMove(nc6Move);
      controller.onBoardMove(nc6Move, boardController);

      // Flip for parity (4-ply = even = black expected).
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());

      // After confirm, pills should show the full path: e4, e5, Nf3, Nc6.
      expect(controller.state.pills.length, 4);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[1].san, 'e5');
      expect(controller.state.pills[2].san, 'Nf3');
      expect(controller.state.pills[3].san, 'Nc6');
      for (final pill in controller.state.pills) {
        expect(pill.isSaved, true);
      }

      // currentFen should be the Nc6 FEN.
      final nc6Fens = computeFens(['e4', 'e5', 'Nf3', 'Nc6']);
      expect(controller.state.currentFen, nc6Fens[3]);

      controller.dispose();
      boardController.dispose();
    });

    test('board position preserved after confirm (preMoveFen matches leaf)', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5.
      final fens = computeFens(['e4', 'e5']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      controller.flipBoard();

      await controller.confirmAndPersist();

      // Both currentFen and preMoveFen should match the FEN after e5.
      expect(controller.state.currentFen, fens[1]);
      expect(controller.state.preMoveFen, fens[1]);

      controller.dispose();
      boardController.dispose();
    });

    test('branching after confirm', () async {
      // After confirming e4/e5, tap pill at index 0 (e4), play d5.
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5.
      final fens = computeFens(['e4', 'e5']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());

      // Post-confirm: pills [e4, e5] all saved, position at e5.
      // Navigate back to pill 0 (e4 position, black to move).
      controller.onPillTapped(0, boardController);
      final e4Fen = controller.state.currentFen;

      // Play d5 (diverging from e5).
      final d5Move = sanToNormalMove(e4Fen, 'd5');
      boardController.setPosition(e4Fen);
      boardController.playMove(d5Move);
      final moveResult = controller.onBoardMove(d5Move, boardController);

      expect(moveResult, isA<MoveAccepted>());
      // Pills should now show the branched line: e4 (saved), d5 (unsaved).
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[1].san, 'd5');
      expect(controller.state.pills[1].isSaved, false);
      expect(controller.hasNewMoves, true);

      controller.dispose();
      boardController.dispose();
    });

    test('confirm button disabled after confirm (hasNewMoves is false)', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4 (1-ply, odd = white, default orientation matches).
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      expect(controller.hasNewMoves, true);

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());

      // After confirm, hasNewMoves should be false.
      expect(controller.hasNewMoves, false);

      controller.dispose();
      boardController.dispose();
    });

    test('second confirm after branching', () async {
      // Confirm e4/e5, branch to e4/d5, confirm again.
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5.
      final fens = computeFens(['e4', 'e5']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      controller.flipBoard();

      final result1 = await controller.confirmAndPersist();
      expect(result1, isA<ConfirmSuccess>());

      // Branch: navigate to pill 0 (e4), play d5.
      controller.onPillTapped(0, boardController);
      final e4Fen = controller.state.currentFen;
      final d5Move = sanToNormalMove(e4Fen, 'd5');
      boardController.setPosition(e4Fen);
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      expect(controller.hasNewMoves, true);

      // Board is black (flipped earlier). 2-ply line (e4, d5) = even = black.
      // Parity matches.
      final result2 = await controller.confirmAndPersist();
      expect(result2, isA<ConfirmSuccess>());

      // After second confirm, pills should persist showing e4/d5, both saved.
      expect(controller.state.pills.length, 2);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[0].isSaved, true);
      expect(controller.state.pills[1].san, 'd5');
      expect(controller.state.pills[1].isSaved, true);
      expect(controller.hasNewMoves, false);

      // Verify DB has both lines: e4/e5 and e4/d5 (3 moves total).
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves.length, 3); // e4 shared, e5, d5

      controller.dispose();
      boardController.dispose();
    });

    test('undo after confirm resets to original starting position (root start)', () async {
      // Seed empty repertoire, play e4/e5, confirm, then undo.
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fens = computeFens(['e4', 'e5']);
      final e5Move = sanToNormalMove(fens[0], 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());
      final success = result as ConfirmSuccess;

      // Capture generation for undo.
      final gen = controller.undoGeneration;

      // Undo the new line.
      await controller.undoNewLine(gen, success.insertedMoveIds);

      // After undo: state resets to initial (empty pills, kInitialFEN).
      expect(controller.state.pills, isEmpty);
      expect(controller.state.currentFen, kInitialFEN);
      expect(controller.hasNewMoves, false);

      // DB should have no moves.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves, isEmpty);

      controller.dispose();
      boardController.dispose();
    });

    test('undo after confirm resets to original starting position (mid-tree start)', () async {
      // Seed repertoire with e4/e5/Nf3 (with cards), create controller with
      // startingMoveId = Nf3, play Nc6, confirm, then undo.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
      ], createCards: true);
      final nf3Id = await getMoveIdBySan(db, repId, 'Nf3');

      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId,
          startingMoveId: nf3Id);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play Nc6 (extends from Nf3).
      final nf3Fen = controller.state.currentFen;
      final nc6Move = sanToNormalMove(nf3Fen, 'Nc6');
      boardController.setPosition(nf3Fen);
      boardController.playMove(nc6Move);
      controller.onBoardMove(nc6Move, boardController);

      // Flip for parity (4-ply = even = black expected).
      controller.flipBoard();

      final result = await controller.confirmAndPersist();
      expect(result, isA<ConfirmSuccess>());
      final success = result as ConfirmSuccess;

      // Capture generation for undo.
      final gen = controller.undoGeneration;

      // Undo the extension.
      await controller.undoExtension(
        gen, success.oldLeafMoveId!, success.insertedMoveIds, success.oldCard!);

      // After undo, state resets to the original startingMoveId position
      // (Nf3), not to kInitialFEN.
      final nf3Fens = computeFens(['e4', 'e5', 'Nf3']);
      expect(controller.state.currentFen, nf3Fens[2]);
      expect(controller.state.currentFen, isNot(kInitialFEN));

      // Pills should show existing path: e4, e5, Nf3.
      expect(controller.state.pills.length, 3);
      expect(controller.state.pills[0].san, 'e4');
      expect(controller.state.pills[1].san, 'e5');
      expect(controller.state.pills[2].san, 'Nf3');
      for (final pill in controller.state.pills) {
        expect(pill.isSaved, true);
      }

      // Nc6 should have been removed from DB.
      final repRepo = LocalRepertoireRepository(db);
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      expect(allMoves.length, 3); // e4, e5, Nf3 remain
      expect(allMoves.any((m) => m.san == 'Nc6'), false);

      controller.dispose();
      boardController.dispose();
    });
  });

  // --------------------------------------------------------------------------
  // CT-56: Transposition detection
  // --------------------------------------------------------------------------

  group('Transposition detection', () {
    test('transpositionMatches populated after move reaching existing position',
        () async {
      // Seed two branches that transpose:
      // Branch A: e4 d5 d4
      // Branch B: d4 d5 e4
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd5', 'd4'],
        ['d4', 'd5', 'e4'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play branch A: e4, d5, d4.
      final moves = ['e4', 'd5', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // After d4, the position transposes with branch B's e4 endpoint.
      expect(controller.state.transpositionMatches, isNotEmpty);
      expect(controller.state.transpositionMatches.length, 1);

      controller.dispose();
      boardController.dispose();
    });

    test('transpositionMatches cleared after take-back to non-transposition position',
        () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd5', 'd4'],
        ['d4', 'd5', 'e4'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play branch A: e4, d5, d4.
      final moves = ['e4', 'd5', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Transposition detected at d4.
      expect(controller.state.transpositionMatches, isNotEmpty);

      // Take back d4 -> position after d5, no transposition expected.
      controller.onTakeBack(boardController);
      expect(controller.state.transpositionMatches, isEmpty);

      controller.dispose();
      boardController.dispose();
    });

    test('transpositionMatches updated on pill tap', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd5', 'd4'],
        ['d4', 'd5', 'e4'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play branch A: e4, d5, d4.
      final moves = ['e4', 'd5', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Transposition detected at pill index 2 (d4).
      expect(controller.state.transpositionMatches, isNotEmpty);

      // Tap pill 0 (e4) -- position after e4 should have no transposition.
      controller.onPillTapped(0, boardController);
      expect(controller.state.transpositionMatches, isEmpty);

      // Tap pill 2 (d4) -- transposition should reappear.
      controller.onPillTapped(2, boardController);
      expect(controller.state.transpositionMatches, isNotEmpty);

      controller.dispose();
      boardController.dispose();
    });

    test('transpositionMatches recomputed after updateLabel changes classification',
        () async {
      // Both branches share label "Alpha" on e4 initially.
      // Only e4 is labeled so editing it breaks the overlap entirely.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd5', 'd4'],
        ['d4', 'd5', 'e4'],
      ], labelsOnSan: {
        'e4': 'Alpha',
      });
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play branch A: e4, d5, d4.
      final moves = ['e4', 'd5', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // Transposition should be same-opening (shared label "Alpha").
      expect(controller.state.transpositionMatches, isNotEmpty);
      expect(controller.state.transpositionMatches[0].isSameOpening, true);

      // Edit label on pill 0 (e4) from "Alpha" to "Beta" via pending label.
      controller.onPillTapped(0, boardController);
      controller.updateLabel(0, 'Beta');

      // Navigate back to d4 to see updated transposition.
      controller.onPillTapped(2, boardController);

      // Now active path has label "Beta", match path has label "Alpha".
      // They don't overlap -> cross-opening.
      expect(controller.state.transpositionMatches, isNotEmpty);
      expect(controller.state.transpositionMatches[0].isSameOpening, false);

      controller.dispose();
      boardController.dispose();
    });

    test('transpositionMatches recomputed after updateBufferedLabel', () async {
      // Tree has only branch B: d4 d5 e4 (labeled "Queen Pawn" on d4).
      // User buffers branch A: e4 d5 d4 (no labels initially).
      final repId = await seedRepertoire(db, lines: [
        ['d4', 'd5', 'e4'],
      ], labelsOnSan: {
        'd4': 'Queen Pawn',
      });
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4 (doesn't match tree root d4 -> buffered), d5, d4.
      final fens = computeFens(['e4', 'd5', 'd4']);
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final d5Move = sanToNormalMove(fens[0], 'd5');
      boardController.playMove(d5Move);
      controller.onBoardMove(d5Move, boardController);

      final d4Move = sanToNormalMove(fens[1], 'd4');
      boardController.playMove(d4Move);
      controller.onBoardMove(d4Move, boardController);

      // Transposition found: same-opening (active path has no labels).
      expect(controller.state.transpositionMatches, isNotEmpty);
      expect(controller.state.transpositionMatches[0].isSameOpening, true);

      // Add a label to the first buffered move (e4) that differs from "Queen Pawn".
      // Pill 0 is the buffered e4.
      controller.updateBufferedLabel(0, 'King Pawn');

      // Now active path has "King Pawn", match path has "Queen Pawn" -> cross-opening.
      expect(controller.state.transpositionMatches, isNotEmpty);
      expect(controller.state.transpositionMatches[0].isSameOpening, false);

      controller.dispose();
      boardController.dispose();
    });

    test('transpositionMatches preserved after flipBoard', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd5', 'd4'],
        ['d4', 'd5', 'e4'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play branch A: e4, d5, d4.
      final moves = ['e4', 'd5', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      final matchesBefore = controller.state.transpositionMatches;
      expect(matchesBefore, isNotEmpty);

      // Flip the board.
      controller.flipBoard();

      // Transposition matches should be preserved (unchanged).
      expect(controller.state.transpositionMatches, isNotEmpty);
      expect(controller.state.transpositionMatches.length, matchesBefore.length);
      expect(
        controller.state.transpositionMatches[0].moveId,
        matchesBefore[0].moveId,
      );

      controller.dispose();
      boardController.dispose();
    });

    test('transpositionMatches empty at initial position', () async {
      // Even if two branches exist, the initial position should not trigger
      // transposition warnings.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
        ['d4', 'd5'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      // At initial position, no transpositions should be reported.
      expect(controller.state.transpositionMatches, isEmpty);

      controller.dispose();
    });

    test('transpositionMatches works for followed (existing) moves', () async {
      // Seed two branches that transpose.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd5', 'd4'],
        ['d4', 'd5', 'e4'],
      ]);
      final controller = AddLineController(
          LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow branch A (all moves are existing/saved).
      final moves = ['e4', 'd5', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final normalMove = sanToNormalMove(currentFen, san);
        boardController.playMove(normalMove);
        controller.onBoardMove(normalMove, boardController);
        currentFen = boardController.fen;
      }

      // All pills are saved (following existing moves).
      for (final pill in controller.state.pills) {
        expect(pill.isSaved, true);
      }

      // Transposition should still be detected.
      expect(controller.state.transpositionMatches, isNotEmpty);

      controller.dispose();
      boardController.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // CT-58: Hint arrows
  // -------------------------------------------------------------------------

  group('toggleHintArrows', () {
    test('defaults to off', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      expect(controller.state.showHintArrows, false);

      controller.dispose();
    });

    test('toggles showHintArrows on and off', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      controller.toggleHintArrows();
      expect(controller.state.showHintArrows, true);

      controller.toggleHintArrows();
      expect(controller.state.showHintArrows, false);

      controller.dispose();
    });

    test('toggle preserves other state fields', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play a move to populate state.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final fenBefore = controller.state.currentFen;
      final pillsBefore = controller.state.pills.length;
      final orientationBefore = controller.state.boardOrientation;

      controller.toggleHintArrows();

      expect(controller.state.currentFen, fenBefore);
      expect(controller.state.pills.length, pillsBefore);
      expect(controller.state.boardOrientation, orientationBefore);
      expect(controller.state.showHintArrows, true);

      controller.dispose();
      boardController.dispose();
    });
  });

  group('getHintArrows', () {
    test('returns empty when toggled off (default)', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
        ['d4', 'd5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      // Default is off -- should return empty even though root moves exist.
      final arrows = controller.getHintArrows();
      expect(arrows.isEmpty, true);

      controller.dispose();
    });

    test('returns empty when treeCache is null', () async {
      final repId = await seedRepertoire(db);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      // Do NOT call loadData(), so treeCache stays null.

      controller.toggleHintArrows();
      final arrows = controller.getHintArrows();
      expect(arrows.isEmpty, true);

      controller.dispose();
    });

    test('shows root move arrows at initial position', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
        ['d4', 'd5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      controller.toggleHintArrows();

      final arrows = controller.getHintArrows();
      expect(arrows.length, 2);
      expect(arrows.every((s) => s is Arrow), true);

      // Both arrows should be direct-child colour (darker grey) since
      // root moves are direct children of the initial position.
      for (final shape in arrows) {
        final arrow = shape as Arrow;
        expect(arrow.color, const Color(0x60000000));
      }

      controller.dispose();
    });

    test('shows direct-child arrows with darker color', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
        ['e4', 'c5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4 to navigate to the position with children e5 and c5.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      controller.toggleHintArrows();

      final arrows = controller.getHintArrows();
      expect(arrows.length, 2);
      expect(arrows.every((s) => s is Arrow), true);

      // Both are direct children of e4, so both should be darker grey.
      for (final shape in arrows) {
        final arrow = shape as Arrow;
        expect(arrow.color, const Color(0x60000000));
      }

      controller.dispose();
      boardController.dispose();
    });

    test('shows transposition arrows with lighter color', () async {
      // Seed two lines that reach the same position via different move orders,
      // each with at least one child at that position.
      // Line A: e4 d6 d4 Nf6  (position after d4 = "e4 d6 d4")
      // Line B: d4 d6 e4 e5   (position after e4 = "d4 d6 e4", same position)
      // When we navigate to d4 in line A, "Nf6" is a direct child. "e5" is
      // a child of the transposed node, so it should appear lighter.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd6', 'd4', 'Nf6'],
        ['d4', 'd6', 'e4', 'e5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow line A: play e4, d6, d4.
      final lineA = ['e4', 'd6', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in lineA) {
        final move = sanToNormalMove(currentFen, san);
        boardController.playMove(move);
        controller.onBoardMove(move, boardController);
        currentFen = boardController.fen;
      }

      controller.toggleHintArrows();

      final arrows = controller.getHintArrows();
      // Should have 2 arrows: Nf6 (direct) and e5 (transposition).
      expect(arrows.length, 2);

      final arrowList = arrows.toList().cast<Arrow>();

      // Nf6 is a direct child (g8->f6) -> darker grey.
      final nf6Arrow = arrowList.firstWhere(
          (a) => a.orig == Square.g8 && a.dest == Square.f6);
      expect(nf6Arrow.color, const Color(0x60000000),
          reason: 'Direct child Nf6 should use darker grey');

      // e5 is a transposition child (e7->e5) -> lighter grey.
      final e5Arrow = arrowList.firstWhere(
          (a) => a.orig == Square.e7 && a.dest == Square.e5);
      expect(e5Arrow.color, const Color(0x30000000),
          reason: 'Transposition child e5 should use lighter grey');

      controller.dispose();
      boardController.dispose();
    });

    test('deduplicates arrows: direct-child colour takes priority', () async {
      // When the same move exists as both a direct child and a transposition
      // child, only one arrow should appear, with the darker (direct-child)
      // colour taking priority.
      //
      // Seed two lines that transpose into the same position, both having
      // the same child SAN:
      // Line A: e4 d6 d4 Nf6
      // Line B: d4 d6 e4 Nf6  (same child SAN "Nf6" at same position)
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd6', 'd4', 'Nf6'],
        ['d4', 'd6', 'e4', 'Nf6'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Follow line A: play e4, d6, d4.
      final lineA = ['e4', 'd6', 'd4'];
      var currentFen = kInitialFEN;
      for (final san in lineA) {
        final move = sanToNormalMove(currentFen, san);
        boardController.playMove(move);
        controller.onBoardMove(move, boardController);
        currentFen = boardController.fen;
      }

      controller.toggleHintArrows();

      final arrows = controller.getHintArrows();
      // Nf6 from line A is a direct child, Nf6 from line B is a transposition.
      // They should be deduplicated to a single arrow.
      final arrowList = arrows.toList().cast<Arrow>();

      // Count arrows going to the Nf6 destination (g8->f6).
      final nf6Dest = Square.f6;
      final nf6Arrows = arrowList.where((a) => a.dest == nf6Dest).toList();
      expect(nf6Arrows.length, 1,
          reason: 'Duplicate Nf6 arrows should be deduplicated');

      // The surviving arrow should use the darker direct-child colour.
      expect(nf6Arrows.first.color, const Color(0x60000000));

      controller.dispose();
      boardController.dispose();
    });

    test('updates arrows on pill tap (position change)', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5', 'Nf3'],
        ['e4', 'c5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4, e5, Nf3 to build up pills.
      final moves = ['e4', 'e5', 'Nf3'];
      var currentFen = kInitialFEN;
      for (final san in moves) {
        final move = sanToNormalMove(currentFen, san);
        boardController.playMove(move);
        controller.onBoardMove(move, boardController);
        currentFen = boardController.fen;
      }

      controller.toggleHintArrows();

      // At Nf3 position (leaf), there are no children.
      final arrowsAtNf3 = controller.getHintArrows();
      expect(arrowsAtNf3.isEmpty, true);

      // Tap pill 0 (e4 position) -- has children e5 and c5.
      controller.onPillTapped(0, boardController);
      final arrowsAtE4 = controller.getHintArrows();
      expect(arrowsAtE4.length, 2);

      controller.dispose();
      boardController.dispose();
    });

    test('returns empty when no existing moves at position', () async {
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play e4 (follows existing), then play e5 (buffered, new).
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);

      final e4Fen = boardController.fen;
      final e5Move = sanToNormalMove(e4Fen, 'e5');
      boardController.playMove(e5Move);
      controller.onBoardMove(e5Move, boardController);

      controller.toggleHintArrows();

      // At e5 position, there are no existing children at all.
      final arrows = controller.getHintArrows();
      expect(arrows.isEmpty, true);

      controller.dispose();
      boardController.dispose();
    });

    test('arrow orig and dest match the move squares', () async {
      // Seed e4 as a root move so we can verify its arrow squares.
      final repId = await seedRepertoire(db, lines: [
        ['e4'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      await controller.loadData();

      controller.toggleHintArrows();

      final arrows = controller.getHintArrows();
      expect(arrows.length, 1);

      final arrow = arrows.first as Arrow;
      // e4 is a pawn push from e2 to e4.
      expect(arrow.orig, Square.e2);
      expect(arrow.dest, Square.e4);

      controller.dispose();
    });

    test('showHintArrows state survives other state transitions', () async {
      // Verify that toggling hint arrows on survives move play, take-back,
      // flip board, etc.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'e5'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      controller.toggleHintArrows();
      expect(controller.state.showHintArrows, true);

      // Play a move.
      final e4Move = sanToNormalMove(kInitialFEN, 'e4');
      boardController.playMove(e4Move);
      controller.onBoardMove(e4Move, boardController);
      expect(controller.state.showHintArrows, true);

      // Flip board.
      controller.flipBoard();
      expect(controller.state.showHintArrows, true);

      // Take back.
      controller.onTakeBack(boardController);
      expect(controller.state.showHintArrows, true);

      controller.dispose();
      boardController.dispose();
    });

    test('transposition arrows shown at buffered move position', () async {
      // When the user plays buffered (unsaved) moves reaching a position that
      // exists elsewhere in the tree, all arrows should appear as lighter
      // grey (transposition) since there are no direct children at an unsaved
      // node.
      //
      // Seed: e4 d6 d4 Nf6  (position after d4 has child Nf6)
      // User plays: d4 (new root, buffered), d6 (buffered), e4 (buffered)
      // Position after "d4 d6 e4" transposes to "e4 d6 d4".
      // getChildrenAtPosition returns Nf6, but since the current node is
      // unsaved, there are no direct children — all arrows are lighter.
      final repId = await seedRepertoire(db, lines: [
        ['e4', 'd6', 'd4', 'Nf6'],
      ]);
      final controller = AddLineController(
        LocalRepertoireRepository(db), LocalReviewRepository(db), repId);
      final boardController = ChessboardController();
      await controller.loadData();

      // Play d4, d6, e4 — all buffered (d4 is a new root move).
      final bufferedMoves = ['d4', 'd6', 'e4'];
      var currentFen = kInitialFEN;
      for (final san in bufferedMoves) {
        final move = sanToNormalMove(currentFen, san);
        boardController.playMove(move);
        controller.onBoardMove(move, boardController);
        currentFen = boardController.fen;
      }

      controller.toggleHintArrows();

      final arrows = controller.getHintArrows();
      // Should show Nf6 arrow from transposition lookup.
      expect(arrows.isNotEmpty, true,
          reason: 'Transposition arrows should appear at buffered position');

      final arrowList = arrows.toList().cast<Arrow>();
      // All arrows should be lighter grey (no direct children at unsaved node).
      for (final arrow in arrowList) {
        expect(arrow.color, const Color(0x30000000),
            reason: 'All arrows at buffered position should be lighter grey');
      }

      controller.dispose();
      boardController.dispose();
    });
  });
}
