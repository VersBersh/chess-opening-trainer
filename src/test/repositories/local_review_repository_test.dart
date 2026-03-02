import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_trainer/repositories/local/database.dart';
import 'package:chess_trainer/repositories/local/local_review_repository.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates an in-memory [AppDatabase] for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
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

  // Create a review card for the leaf.
  await db.into(db.reviewCards).insert(
        ReviewCardsCompanion.insert(
          repertoireId: repId,
          leafMoveId: lastMoveId,
          nextReviewDate: DateTime(2026, 6, 15),
        ),
      );

  final card = await (db.select(db.reviewCards)
        ..where((c) => c.leafMoveId.equals(lastMoveId)))
      .getSingle();

  return (repId, lastMoveId, card);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late LocalReviewRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = LocalReviewRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getCardCountForRepertoire', () {
    test('returns 0 for empty repertoire', () async {
      final repId = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'Empty'));

      final count = await repo.getCardCountForRepertoire(repId);
      expect(count, 0);
    });

    test('returns correct count after seeding cards', () async {
      final (repId, _, _) = await seedLineWithCard(db, ['e4', 'e5']);

      final count = await repo.getCardCountForRepertoire(repId);
      expect(count, 1);
    });

    test('counts only cards for the specified repertoire', () async {
      // Seed two separate repertoires, each with one card.
      final (repId1, _, _) = await seedLineWithCard(db, ['e4', 'e5']);
      final (repId2, _, _) = await seedLineWithCard(db, ['d4', 'd5']);

      final count1 = await repo.getCardCountForRepertoire(repId1);
      final count2 = await repo.getCardCountForRepertoire(repId2);

      expect(count1, 1);
      expect(count2, 1);
    });
  });
}
