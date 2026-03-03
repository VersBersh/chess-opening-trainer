import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';
import 'package:chess_trainer/services/line_entry_engine.dart';
import 'package:chess_trainer/services/line_persistence_service.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a repertoire and moves into the database. Returns the repertoire ID.
Future<int> seedRepertoire(
  AppDatabase db, {
  String name = 'Test Repertoire',
  List<List<String>> lines = const [],
  bool createCards = false,
}) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: name));

  final insertedMoves = <String, int>{};
  final fenByMoveId = <int, String>{};

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

/// Plays a sequence of SAN moves and returns FENs.
List<String> computeFens(List<String> sans) {
  final fens = <String>[];
  Position position = Chess.initial;
  for (final san in sans) {
    final parsed = position.parseSan(san);
    position = position.play(parsed!);
    fens.add(position.fen);
  }
  return fens;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late LocalRepertoireRepository repRepo;
  late LocalReviewRepository reviewRepo;
  late LinePersistenceService service;

  setUp(() {
    db = createTestDatabase();
    repRepo = LocalRepertoireRepository(db);
    reviewRepo = LocalReviewRepository(db);
    service = LinePersistenceService(
      repertoireRepo: repRepo,
      reviewRepo: reviewRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Extension persistence', () {
    test('extends a leaf: deletes old card, inserts moves, creates new card',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      // Build tree cache for ConfirmData construction.
      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [BufferedMove(san: 'e5', fen: fens[1])],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, true);
      expect(result.oldLeafMoveId, e4Move.id);
      expect(result.oldCard, isNotNull);
      expect(result.insertedMoveIds.length, 1);

      // Verify DB: 2 moves, 1 card on new leaf.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 2);

      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, result.insertedMoveIds.last);
    });

    test('extends with multiple moves: correct parent chain', () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5', 'Nf3']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [
          BufferedMove(san: 'e5', fen: fens[1]),
          BufferedMove(san: 'Nf3', fen: fens[2]),
        ],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, true);
      expect(result.insertedMoveIds.length, 2);

      // Verify DB: 3 moves, parent chain e4 -> e5 -> Nf3.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 3);

      final e5Move = movesAfter.firstWhere((m) => m.san == 'e5');
      final nf3Move = movesAfter.firstWhere((m) => m.san == 'Nf3');
      expect(e5Move.parentMoveId, e4Move.id);
      expect(nf3Move.parentMoveId, e5Move.id);

      // Card should be on Nf3 (the new leaf).
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, nf3Move.id);
    });
  });

  group('Extension persistence with labels', () {
    test('persistNewMoves writes buffered labels into RepertoireMovesCompanion inserts for extensions',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.first;

      final fens = computeFens(['e4', 'e5', 'Nf3']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [
          BufferedMove(san: 'e5', fen: fens[1], label: 'Open Game'),
          BufferedMove(san: 'Nf3', fen: fens[2]),
        ],
        isExtension: true,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);
      expect(result.insertedMoveIds.length, 2);

      // Verify the label was persisted on the e5 move.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      final e5Move = movesAfter.firstWhere((m) => m.san == 'e5');
      final nf3Move = movesAfter.firstWhere((m) => m.san == 'Nf3');
      expect(e5Move.label, 'Open Game');
      expect(nf3Move.label, isNull);
    });
  });

  group('Branch persistence', () {
    test('branches from non-leaf: inserts moves and card, preserves existing',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'e5'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.firstWhere((m) => m.san == 'e4');

      final fens = computeFens(['e4', 'd5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [BufferedMove(san: 'd5', fen: fens[1])],
        isExtension: false,
        repertoireId: repId,
        sortOrder: 1,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, false);
      expect(result.insertedMoveIds.length, 1);
      expect(result.oldCard, isNull);

      // Verify DB: 3 moves (e4, e5, d5), 2 cards.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 3);

      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 2);
    });

    test('branches from root: inserts moves starting from null parent',
        () async {
      final repId = await seedRepertoire(db);

      final fens = computeFens(['e4', 'e5']);

      final confirmData = ConfirmData(
        parentMoveId: null,
        newMoves: [
          BufferedMove(san: 'e4', fen: fens[0]),
          BufferedMove(san: 'e5', fen: fens[1]),
        ],
        isExtension: false,
        repertoireId: repId,
        sortOrder: 0,
      );

      final result = await service.persistNewMoves(confirmData);

      expect(result.isExtension, false);
      expect(result.insertedMoveIds.length, 2);

      // Verify DB: 2 moves, parent chain root -> e4 -> e5.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 2);

      final e4Move = movesAfter.firstWhere((m) => m.san == 'e4');
      final e5Move = movesAfter.firstWhere((m) => m.san == 'e5');
      expect(e4Move.parentMoveId, isNull);
      expect(e5Move.parentMoveId, e4Move.id);

      // 1 card on the leaf.
      final cards = await reviewRepo.getAllCardsForRepertoire(repId);
      expect(cards.length, 1);
      expect(cards.first.leafMoveId, e5Move.id);
    });
  });

  group('Branch persistence with labels', () {
    test('persistNewMoves writes buffered labels into RepertoireMovesCompanion inserts for branches',
        () async {
      final repId = await seedRepertoire(db,
          lines: [
            ['e4', 'e5'],
          ],
          createCards: true);

      final allMoves = await repRepo.getMovesForRepertoire(repId);
      final e4Move = allMoves.firstWhere((m) => m.san == 'e4');

      final fens = computeFens(['e4', 'd5']);

      final confirmData = ConfirmData(
        parentMoveId: e4Move.id,
        newMoves: [
          BufferedMove(san: 'd5', fen: fens[1], label: 'Scandinavian'),
        ],
        isExtension: false,
        repertoireId: repId,
        sortOrder: 1,
      );

      final result = await service.persistNewMoves(confirmData);
      expect(result.insertedMoveIds.length, 1);

      // Verify the label was persisted on the d5 move.
      final movesAfter = await repRepo.getMovesForRepertoire(repId);
      final d5Move = movesAfter.firstWhere((m) => m.san == 'd5');
      expect(d5Move.label, 'Scandinavian');
    });
  });
}
