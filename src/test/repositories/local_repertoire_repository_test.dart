import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory [AppDatabase] for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

/// Seeds a repertoire and a single move into the database.
/// Returns the move ID.
Future<({int repId, int moveId})> seedSingleMove(
  AppDatabase db, {
  String? label,
}) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: 'Test'));

  final moveId = await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          san: 'e4',
          label: Value(label),
          sortOrder: 0,
        ),
      );

  return (repId: repId, moveId: moveId);
}

/// Seeds a simple linear repertoire and creates a review card for the leaf.
///
/// Returns `(repertoireId, leafMoveId, reviewCard)`.
Future<(int, int, ReviewCard)> seedLineWithCard(
  AppDatabase db,
  List<String> sans,
) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: 'Test'));

  Position position = Chess.initial;
  int? parentId;
  late int lastMoveId;

  for (var i = 0; i < sans.length; i++) {
    final san = sans[i];
    final parsed = position.parseSan(san);
    if (parsed == null) throw ArgumentError('Illegal move "$san"');
    position = position.play(parsed);

    lastMoveId = await db.into(db.repertoireMoves).insert(
          RepertoireMovesCompanion.insert(
            repertoireId: repId,
            parentMoveId: Value(parentId),
            fen: position.fen,
            san: san,
            sortOrder: 0,
          ),
        );
    parentId = lastMoveId;
  }

  // Create a review card for the leaf with non-default SR values.
  final cardId = await db.into(db.reviewCards).insert(
        ReviewCardsCompanion.insert(
          repertoireId: repId,
          leafMoveId: lastMoveId,
          nextReviewDate: DateTime(2026, 6, 15),
        ).copyWith(
          easeFactor: const Value(2.8),
          intervalDays: const Value(7),
          repetitions: const Value(3),
        ),
      );

  final card = await (db.select(db.reviewCards)
        ..where((c) => c.id.equals(cardId)))
      .getSingle();

  return (repId, lastMoveId, card);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late LocalRepertoireRepository repo;
  late LocalReviewRepository reviewRepo;

  setUp(() {
    db = createTestDatabase();
    repo = LocalRepertoireRepository(db);
    reviewRepo = LocalReviewRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('renameRepertoire', () {
    test('renames an existing repertoire', () async {
      final repId = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'Original'));

      await repo.renameRepertoire(repId, 'Renamed');

      final repertoire = await repo.getRepertoire(repId);
      expect(repertoire.name, 'Renamed');
    });

    test('rename persists after re-fetching', () async {
      final repId = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'Before'));

      await repo.renameRepertoire(repId, 'After');

      final all = await repo.getAllRepertoires();
      final renamed = all.firstWhere((r) => r.id == repId);
      expect(renamed.name, 'After');
    });

    test('only renames the targeted repertoire', () async {
      final id1 = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'First'));
      final id2 = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'Second'));

      await repo.renameRepertoire(id1, 'First Renamed');

      final r1 = await repo.getRepertoire(id1);
      final r2 = await repo.getRepertoire(id2);
      expect(r1.name, 'First Renamed');
      expect(r2.name, 'Second');
    });
  });

  group('updateMoveLabel', () {
    test('sets a label on an unlabeled move', () async {
      final seed = await seedSingleMove(db);

      await repo.updateMoveLabel(seed.moveId, 'Sicilian');

      final move = await repo.getMove(seed.moveId);
      expect(move, isNotNull);
      expect(move!.label, 'Sicilian');
    });

    test('changes an existing label', () async {
      final seed = await seedSingleMove(db, label: 'Sicilian');

      await repo.updateMoveLabel(seed.moveId, 'Sicilian Defense');

      final move = await repo.getMove(seed.moveId);
      expect(move, isNotNull);
      expect(move!.label, 'Sicilian Defense');
    });

    test('removes a label by setting to null', () async {
      final seed = await seedSingleMove(db, label: 'Sicilian');

      await repo.updateMoveLabel(seed.moveId, null);

      final move = await repo.getMove(seed.moveId);
      expect(move, isNotNull);
      expect(move!.label, isNull);
    });

    test('only changes the label field, leaving other fields unchanged',
        () async {
      final seed = await seedSingleMove(db);
      final originalMove = await repo.getMove(seed.moveId);

      await repo.updateMoveLabel(seed.moveId, 'Test Label');

      final updatedMove = await repo.getMove(seed.moveId);
      expect(updatedMove, isNotNull);
      expect(updatedMove!.label, 'Test Label');
      // All other fields should remain unchanged.
      expect(updatedMove.fen, originalMove!.fen);
      expect(updatedMove.san, originalMove.san);
      expect(updatedMove.parentMoveId, originalMove.parentMoveId);
      expect(updatedMove.sortOrder, originalMove.sortOrder);
      expect(updatedMove.repertoireId, originalMove.repertoireId);
      expect(updatedMove.comment, originalMove.comment);
    });
  });

  group('undoExtendLine', () {
    test('deletes extension moves and restores old card with SR values',
        () async {
      // Seed: 1. e4 e5 (leaf = e5, card on e5)
      final (repId, oldLeafId, oldCard) =
          await seedLineWithCard(db, ['e4', 'e5']);

      // Extend: add Nf3, Nc6
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      pos = pos.play(pos.parseSan('e5')!);
      final posAfterNf3 = pos.play(pos.parseSan('Nf3')!);
      final posAfterNc6 = posAfterNf3.play(posAfterNf3.parseSan('Nc6')!);

      final insertedIds = await repo.extendLine(oldLeafId, [
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: posAfterNf3.fen,
          san: 'Nf3',
          sortOrder: 0,
        ),
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: posAfterNc6.fen,
          san: 'Nc6',
          sortOrder: 0,
        ),
      ]);

      expect(insertedIds.length, 2);

      // Verify extension was applied: old card gone, new card exists.
      final cardBeforeUndo = await reviewRepo.getCardForLeaf(oldLeafId);
      expect(cardBeforeUndo, isNull);
      final newCard = await reviewRepo.getCardForLeaf(insertedIds.last);
      expect(newCard, isNotNull);

      // Undo the extension.
      await repo.undoExtendLine(oldLeafId, insertedIds, oldCard);

      // Extension moves should be gone.
      for (final id in insertedIds) {
        final move = await repo.getMove(id);
        expect(move, isNull, reason: 'Inserted move $id should be deleted');
      }

      // Old leaf move should still exist.
      final oldLeaf = await repo.getMove(oldLeafId);
      expect(oldLeaf, isNotNull);

      // Old card should be restored with original SR values.
      final restoredCard = await reviewRepo.getCardForLeaf(oldLeafId);
      expect(restoredCard, isNotNull);
      expect(restoredCard!.easeFactor, oldCard.easeFactor);
      expect(restoredCard.intervalDays, oldCard.intervalDays);
      expect(restoredCard.repetitions, oldCard.repetitions);
      expect(restoredCard.nextReviewDate, oldCard.nextReviewDate);
      expect(restoredCard.repertoireId, oldCard.repertoireId);
    });

    test('old leaf move still exists after undo', () async {
      final (repId, oldLeafId, oldCard) =
          await seedLineWithCard(db, ['e4', 'e5']);

      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      pos = pos.play(pos.parseSan('e5')!);
      final posAfterNf3 = pos.play(pos.parseSan('Nf3')!);

      final insertedIds = await repo.extendLine(oldLeafId, [
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: posAfterNf3.fen,
          san: 'Nf3',
          sortOrder: 0,
        ),
      ]);

      await repo.undoExtendLine(oldLeafId, insertedIds, oldCard);

      // The original line should still be intact.
      final allMoves = await repo.getMovesForRepertoire(repId);
      expect(allMoves.length, 2); // e4, e5
      expect(allMoves.any((m) => m.san == 'e4'), isTrue);
      expect(allMoves.any((m) => m.san == 'e5'), isTrue);
    });

    test('empty insertedMoveIds is a no-op', () async {
      final (repId, oldLeafId, oldCard) =
          await seedLineWithCard(db, ['e4', 'e5']);

      // Call undoExtendLine with empty list -- should not crash or change data.
      await repo.undoExtendLine(oldLeafId, [], oldCard);

      // Everything should be unchanged.
      final allMoves = await repo.getMovesForRepertoire(repId);
      expect(allMoves.length, 2);
      final card = await reviewRepo.getCardForLeaf(oldLeafId);
      expect(card, isNotNull);
    });

    test('throws StateError when oldCard.leafMoveId != oldLeafMoveId',
        () async {
      final (_, oldLeafId, oldCard) =
          await seedLineWithCard(db, ['e4', 'e5']);

      // Pass a mismatched oldLeafMoveId (e.g. 9999).
      expect(
        () => repo.undoExtendLine(9999, [100], oldCard),
        throwsA(isA<StateError>()),
      );
    });

  });

  group('undoNewLine', () {
    test('deletes inserted moves and card', () async {
      // Seed: 1. e4 (leaf = e4, card on e4)
      final (repId, e4Id, _) = await seedLineWithCard(db, ['e4']);

      // Manually insert a branch: d4, d5 as root moves (new line from root).
      Position pos = Chess.initial;
      final posAfterD4 = pos.play(pos.parseSan('d4')!);
      final posAfterD5 = posAfterD4.play(posAfterD4.parseSan('d5')!);

      final d4Id = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              fen: posAfterD4.fen,
              san: 'd4',
              sortOrder: 1,
            ),
          );
      final d5Id = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              parentMoveId: Value(d4Id),
              fen: posAfterD5.fen,
              san: 'd5',
              sortOrder: 0,
            ),
          );

      // Create a card for the d5 leaf.
      await db.into(db.reviewCards).insert(
            ReviewCardsCompanion.insert(
              repertoireId: repId,
              leafMoveId: d5Id,
              nextReviewDate: DateTime(2026, 6, 15),
            ),
          );

      // Verify both moves and card exist before undo.
      var allMoves = await repo.getMovesForRepertoire(repId);
      expect(allMoves.length, 3); // e4, d4, d5
      var d5Card = await reviewRepo.getCardForLeaf(d5Id);
      expect(d5Card, isNotNull);

      // Undo the new line.
      await repo.undoNewLine([d4Id, d5Id]);

      // d4 and d5 should be gone (CASCADE).
      allMoves = await repo.getMovesForRepertoire(repId);
      expect(allMoves.length, 1);
      expect(allMoves.first.san, 'e4');

      // Card for d5 should be gone (CASCADE).
      d5Card = await reviewRepo.getCardForLeaf(d5Id);
      expect(d5Card, isNull);

      // Original e4 card should still exist.
      final e4Card = await reviewRepo.getCardForLeaf(e4Id);
      expect(e4Card, isNotNull);
    });

    test('with empty list is a no-op', () async {
      final (repId, e4Id, _) = await seedLineWithCard(db, ['e4']);

      // Call undoNewLine with empty list -- should not crash or change data.
      await repo.undoNewLine([]);

      final allMoves = await repo.getMovesForRepertoire(repId);
      expect(allMoves.length, 1);
      final card = await reviewRepo.getCardForLeaf(e4Id);
      expect(card, isNotNull);
    });

    test('does not affect sibling branches', () async {
      // Seed: 1. e4 e5 (leaf = e5, card on e5)
      final (repId, _, _) = await seedLineWithCard(db, ['e4', 'e5']);

      // Get the e4 move ID.
      final allMoves = await repo.getMovesForRepertoire(repId);
      final e4Move = allMoves.firstWhere((m) => m.san == 'e4');
      final e5Move = allMoves.firstWhere((m) => m.san == 'e5');

      // Add a sibling branch: e4 -> d5
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      final posAfterD5 = pos.play(pos.parseSan('d5')!);

      final d5Id = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              parentMoveId: Value(e4Move.id),
              fen: posAfterD5.fen,
              san: 'd5',
              sortOrder: 1,
            ),
          );

      // Create a card for d5.
      await db.into(db.reviewCards).insert(
            ReviewCardsCompanion.insert(
              repertoireId: repId,
              leafMoveId: d5Id,
              nextReviewDate: DateTime(2026, 6, 15),
            ),
          );

      // Undo only the d5 branch.
      await repo.undoNewLine([d5Id]);

      // d5 should be gone.
      final movesAfter = await repo.getMovesForRepertoire(repId);
      expect(movesAfter.length, 2); // e4, e5
      expect(movesAfter.any((m) => m.san == 'e4'), isTrue);
      expect(movesAfter.any((m) => m.san == 'e5'), isTrue);
      expect(movesAfter.any((m) => m.san == 'd5'), isFalse);

      // e5 card should still exist.
      final e5Card = await reviewRepo.getCardForLeaf(e5Move.id);
      expect(e5Card, isNotNull);

      // d5 card should be gone.
      final d5Card = await reviewRepo.getCardForLeaf(d5Id);
      expect(d5Card, isNull);
    });
  });

  group('undoExtendLine (continued)', () {
    test('sequential extend then undo restores correct intermediate state',
        () async {
      // Seed: 1. e4 e5 (leaf = e5, card on e5)
      final (repId, oldLeafId, oldCard) =
          await seedLineWithCard(db, ['e4', 'e5']);

      // First extension: add Nf3
      Position pos = Chess.initial;
      pos = pos.play(pos.parseSan('e4')!);
      pos = pos.play(pos.parseSan('e5')!);
      final posAfterNf3 = pos.play(pos.parseSan('Nf3')!);

      final ext1Ids = await repo.extendLine(oldLeafId, [
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: posAfterNf3.fen,
          san: 'Nf3',
          sortOrder: 0,
        ),
      ]);

      // Capture intermediate card for Nf3 (created by extendLine).
      final nf3Card = await reviewRepo.getCardForLeaf(ext1Ids.last);
      expect(nf3Card, isNotNull);

      // Second extension: add Nc6 after Nf3
      final posAfterNc6 = posAfterNf3.play(posAfterNf3.parseSan('Nc6')!);

      final ext2Ids = await repo.extendLine(ext1Ids.last, [
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: posAfterNc6.fen,
          san: 'Nc6',
          sortOrder: 0,
        ),
      ]);

      // Undo only the second extension.
      await repo.undoExtendLine(ext1Ids.last, ext2Ids, nf3Card!);

      // Nc6 should be gone, but Nf3 should still exist.
      final movesAfterUndo = await repo.getMovesForRepertoire(repId);
      expect(movesAfterUndo.any((m) => m.san == 'e4'), isTrue);
      expect(movesAfterUndo.any((m) => m.san == 'e5'), isTrue);
      expect(movesAfterUndo.any((m) => m.san == 'Nf3'), isTrue);
      expect(movesAfterUndo.any((m) => m.san == 'Nc6'), isFalse);

      // Nf3 should have its card restored.
      final restoredNf3Card =
          await reviewRepo.getCardForLeaf(ext1Ids.last);
      expect(restoredNf3Card, isNotNull);
    });
  });
}
