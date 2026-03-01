import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_repertoire_repository.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late LocalRepertoireRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = LocalRepertoireRepository(db);
  });

  tearDown(() async {
    await db.close();
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
}
