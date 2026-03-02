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
/// [nextReviewDate] defaults to `DateTime(2026, 6, 15)` when omitted.
///
/// Returns `(repertoireId, leafMoveId, reviewCard)`.
Future<(int, int, ReviewCard)> seedLineWithCard(
  AppDatabase db,
  List<String> sans, {
  DateTime? nextReviewDate,
}) async {
  final reviewDate = nextReviewDate ?? DateTime(2026, 6, 15);

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
          nextReviewDate: reviewDate,
        ),
      );

  final card = await (db.select(db.reviewCards)
        ..where((c) => c.leafMoveId.equals(lastMoveId)))
      .getSingle();

  return (repId, lastMoveId, card);
}

/// Result record for [seedBranchingTree].
typedef BranchingTreeSeed = ({
  int repId,
  int e4Id,
  int e5Id,
  int nf3Id,
  int bc4Id,
  int c5Id,
});

/// Seeds a repertoire with a branching move tree and three review cards.
///
/// Tree structure:
/// ```
/// e4 (root)
/// +-- e5 (branch A parent)
/// |   +-- Nf3 (leaf A1 -- past due: DateTime(2026, 1, 10))
/// |   +-- Bc4 (leaf A2 -- due today: DateTime(2026, 3, 2))
/// +-- c5 (leaf B -- future due: DateTime(2026, 6, 15))
/// ```
Future<BranchingTreeSeed> seedBranchingTree(AppDatabase db) async {
  final repId = await db
      .into(db.repertoires)
      .insert(RepertoiresCompanion.insert(name: 'Branching'));

  // --- Compute valid FEN positions using dartchess ---
  final initial = Chess.initial;

  // e4 from the starting position.
  final posAfterE4 = initial.play(initial.parseSan('e4')!);

  // e5 as response to e4.
  final posAfterE5 = posAfterE4.play(posAfterE4.parseSan('e5')!);

  // Nf3 after e4 e5 (leaf A1).
  final posAfterNf3 = posAfterE5.play(posAfterE5.parseSan('Nf3')!);

  // Bc4 after e4 e5 (leaf A2 -- sibling of Nf3 under e5).
  final posAfterBc4 = posAfterE5.play(posAfterE5.parseSan('Bc4')!);

  // c5 as response to e4 (leaf B -- sibling of e5 under e4).
  final posAfterC5 = posAfterE4.play(posAfterE4.parseSan('c5')!);

  // --- Insert moves ---
  final e4Id = await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          fen: posAfterE4.fen,
          san: 'e4',
          sortOrder: 0,
        ),
      );

  final e5Id = await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          parentMoveId: Value(e4Id),
          fen: posAfterE5.fen,
          san: 'e5',
          sortOrder: 0,
        ),
      );

  final nf3Id = await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          parentMoveId: Value(e5Id),
          fen: posAfterNf3.fen,
          san: 'Nf3',
          sortOrder: 0,
        ),
      );

  final bc4Id = await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          parentMoveId: Value(e5Id),
          fen: posAfterBc4.fen,
          san: 'Bc4',
          sortOrder: 1,
        ),
      );

  final c5Id = await db.into(db.repertoireMoves).insert(
        RepertoireMovesCompanion.insert(
          repertoireId: repId,
          parentMoveId: Value(e4Id),
          fen: posAfterC5.fen,
          san: 'c5',
          sortOrder: 1,
        ),
      );

  // --- Create review cards for the three leaves ---
  // Nf3: past due.
  await db.into(db.reviewCards).insert(
        ReviewCardsCompanion.insert(
          repertoireId: repId,
          leafMoveId: nf3Id,
          nextReviewDate: DateTime(2026, 1, 10),
        ),
      );

  // Bc4: due today (boundary).
  await db.into(db.reviewCards).insert(
        ReviewCardsCompanion.insert(
          repertoireId: repId,
          leafMoveId: bc4Id,
          nextReviewDate: DateTime(2026, 3, 2),
        ),
      );

  // c5: future due.
  await db.into(db.reviewCards).insert(
        ReviewCardsCompanion.insert(
          repertoireId: repId,
          leafMoveId: c5Id,
          nextReviewDate: DateTime(2026, 6, 15),
        ),
      );

  return (
    repId: repId,
    e4Id: e4Id,
    e5Id: e5Id,
    nf3Id: nf3Id,
    bc4Id: bc4Id,
    c5Id: c5Id,
  );
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

  // -------------------------------------------------------------------------
  // getCardCountForRepertoire
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // getDueCards
  // -------------------------------------------------------------------------

  group('getDueCards', () {
    test('returns empty list when no cards exist', () async {
      final cards = await repo.getDueCards(asOf: DateTime(2026, 3, 2));
      expect(cards, isEmpty);
    });

    test('returns cards with nextReviewDate <= asOf', () async {
      await seedLineWithCard(
        db,
        ['e4', 'e5'],
        nextReviewDate: DateTime(2026, 1, 10),
      );

      final cards = await repo.getDueCards(asOf: DateTime(2026, 3, 2));
      expect(cards, hasLength(1));
    });

    test('includes cards due exactly on asOf', () async {
      await seedLineWithCard(
        db,
        ['e4', 'e5'],
        nextReviewDate: DateTime(2026, 3, 2),
      );

      final cards = await repo.getDueCards(asOf: DateTime(2026, 3, 2));
      expect(cards, hasLength(1));
    });

    test('excludes cards with nextReviewDate after asOf', () async {
      await seedLineWithCard(
        db,
        ['e4', 'e5'],
        nextReviewDate: DateTime(2026, 6, 15),
      );

      final cards = await repo.getDueCards(asOf: DateTime(2026, 3, 2));
      expect(cards, isEmpty);
    });

    test('returns due cards across multiple repertoires', () async {
      // Both cards are past due.
      await seedLineWithCard(
        db,
        ['e4', 'e5'],
        nextReviewDate: DateTime(2026, 1, 10),
      );
      await seedLineWithCard(
        db,
        ['d4', 'd5'],
        nextReviewDate: DateTime(2026, 2, 1),
      );

      final cards = await repo.getDueCards(asOf: DateTime(2026, 3, 2));
      expect(cards, hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  // getDueCardsForRepertoire
  // -------------------------------------------------------------------------

  group('getDueCardsForRepertoire', () {
    test('returns only cards for the specified repertoire', () async {
      final (repId1, _, _) = await seedLineWithCard(
        db,
        ['e4', 'e5'],
        nextReviewDate: DateTime(2026, 1, 10),
      );
      await seedLineWithCard(
        db,
        ['d4', 'd5'],
        nextReviewDate: DateTime(2026, 1, 10),
      );

      final cards = await repo.getDueCardsForRepertoire(
        repId1,
        asOf: DateTime(2026, 3, 2),
      );
      expect(cards, hasLength(1));
      expect(cards.first.repertoireId, repId1);
    });

    test('filters by date cutoff', () async {
      final seed = await seedBranchingTree(db);

      // asOf = 2026-03-02: Nf3 (Jan 10) and Bc4 (Mar 2) are due; c5 (Jun 15) is not.
      final cards = await repo.getDueCardsForRepertoire(
        seed.repId,
        asOf: DateTime(2026, 3, 2),
      );
      expect(cards, hasLength(2));
    });

    test('includes cards due exactly on asOf', () async {
      final (repId, _, _) = await seedLineWithCard(
        db,
        ['e4', 'e5'],
        nextReviewDate: DateTime(2026, 3, 2),
      );

      final cards = await repo.getDueCardsForRepertoire(
        repId,
        asOf: DateTime(2026, 3, 2),
      );
      expect(cards, hasLength(1));
    });

    test('returns empty for repertoire with only future-due cards', () async {
      final (repId, _, _) = await seedLineWithCard(
        db,
        ['e4', 'e5'],
        nextReviewDate: DateTime(2026, 6, 15),
      );

      final cards = await repo.getDueCardsForRepertoire(
        repId,
        asOf: DateTime(2026, 3, 2),
      );
      expect(cards, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // getCardsForSubtree — dueOnly: false
  // -------------------------------------------------------------------------

  group('getCardsForSubtree (dueOnly: false)', () {
    test('returns all leaf cards under root move', () async {
      final seed = await seedBranchingTree(db);

      final cards = await repo.getCardsForSubtree(seed.e4Id);
      expect(cards, hasLength(3));
    });

    test('returns only cards in the targeted sub-branch', () async {
      final seed = await seedBranchingTree(db);

      // e5 subtree contains Nf3 and Bc4 but not c5.
      final cards = await repo.getCardsForSubtree(seed.e5Id);
      expect(cards, hasLength(2));

      final leafIds = cards.map((c) => c.leafMoveId).toSet();
      expect(leafIds, contains(seed.nf3Id));
      expect(leafIds, contains(seed.bc4Id));
    });

    test('returns single card when called on a leaf move', () async {
      final seed = await seedBranchingTree(db);

      final cards = await repo.getCardsForSubtree(seed.nf3Id);
      expect(cards, hasLength(1));
      expect(cards.first.leafMoveId, seed.nf3Id);
    });

    test('returns empty for a move with no leaf cards', () async {
      // Create a repertoire with a single root move but no review card.
      final repId = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'No Cards'));

      final initial = Chess.initial;
      final posAfterE4 = initial.play(initial.parseSan('e4')!);

      final moveId = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              fen: posAfterE4.fen,
              san: 'e4',
              sortOrder: 0,
            ),
          );

      final cards = await repo.getCardsForSubtree(moveId);
      expect(cards, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // getCardsForSubtree — dueOnly: true
  // -------------------------------------------------------------------------

  group('getCardsForSubtree (dueOnly: true)', () {
    test('excludes cards with nextReviewDate after asOf', () async {
      final seed = await seedBranchingTree(db);

      // asOf = 2026-03-02: c5 (Jun 15) should be excluded from full tree.
      final cards = await repo.getCardsForSubtree(
        seed.e4Id,
        dueOnly: true,
        asOf: DateTime(2026, 3, 2),
      );
      expect(cards, hasLength(2));

      final leafIds = cards.map((c) => c.leafMoveId).toSet();
      expect(leafIds, contains(seed.nf3Id));
      expect(leafIds, contains(seed.bc4Id));
    });

    test('includes cards due exactly on asOf', () async {
      final seed = await seedBranchingTree(db);

      // asOf = 2026-03-02: Bc4 is due exactly on this date.
      final cards = await repo.getCardsForSubtree(
        seed.e5Id,
        dueOnly: true,
        asOf: DateTime(2026, 3, 2),
      );
      expect(cards, hasLength(2));

      final leafIds = cards.map((c) => c.leafMoveId).toSet();
      expect(leafIds, contains(seed.nf3Id));
      expect(leafIds, contains(seed.bc4Id));
    });

    test('returns empty when all cards are in the future', () async {
      final seed = await seedBranchingTree(db);

      // asOf before any card is due.
      final cards = await repo.getCardsForSubtree(
        seed.e4Id,
        dueOnly: true,
        asOf: DateTime(2025, 1, 1),
      );
      expect(cards, isEmpty);
    });

    test('returns all cards when all are past due', () async {
      final seed = await seedBranchingTree(db);

      // asOf well after all cards are due.
      final cards = await repo.getCardsForSubtree(
        seed.e4Id,
        dueOnly: true,
        asOf: DateTime(2027, 1, 1),
      );
      expect(cards, hasLength(3));
    });

    test('combines subtree scoping with date filtering', () async {
      final seed = await seedBranchingTree(db);

      // e5 subtree has Nf3 (Jan 10) and Bc4 (Mar 2).
      // asOf = 2026-01-15: only Nf3 (Jan 10) is due.
      final cards = await repo.getCardsForSubtree(
        seed.e5Id,
        dueOnly: true,
        asOf: DateTime(2026, 1, 15),
      );
      expect(cards, hasLength(1));
      expect(cards.first.leafMoveId, seed.nf3Id);
    });
  });

  // -------------------------------------------------------------------------
  // getCardForLeaf
  // -------------------------------------------------------------------------

  group('getCardForLeaf', () {
    test('returns the card for an existing leaf', () async {
      final (_, leafId, _) = await seedLineWithCard(db, ['e4', 'e5']);

      final card = await repo.getCardForLeaf(leafId);
      expect(card, isNotNull);
      expect(card!.leafMoveId, leafId);
    });

    test('returns null for a leaf with no card', () async {
      // Insert a move but no review card.
      final repId = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'No Card'));

      final initial = Chess.initial;
      final posAfterE4 = initial.play(initial.parseSan('e4')!);

      final moveId = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              fen: posAfterE4.fen,
              san: 'e4',
              sortOrder: 0,
            ),
          );

      final card = await repo.getCardForLeaf(moveId);
      expect(card, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // saveReview
  // -------------------------------------------------------------------------

  group('saveReview', () {
    test('updates all SR fields on an existing card', () async {
      final (_, leafId, originalCard) =
          await seedLineWithCard(db, ['e4', 'e5']);

      await repo.saveReview(ReviewCardsCompanion(
        id: Value(originalCard.id),
        easeFactor: const Value(3.0),
        intervalDays: const Value(14),
        repetitions: const Value(5),
        nextReviewDate: Value(DateTime(2026, 4, 1)),
      ));

      final updated = await repo.getCardForLeaf(leafId);
      expect(updated, isNotNull);
      expect(updated!.easeFactor, 3.0);
      expect(updated.intervalDays, 14);
      expect(updated.repetitions, 5);
      expect(updated.nextReviewDate, DateTime(2026, 4, 1));
    });

    test('inserts a new card when id is absent', () async {
      // Create a repertoire with a move but no card.
      final repId = await db
          .into(db.repertoires)
          .insert(RepertoiresCompanion.insert(name: 'Insert Test'));

      final initial = Chess.initial;
      final posAfterE4 = initial.play(initial.parseSan('e4')!);

      final moveId = await db.into(db.repertoireMoves).insert(
            RepertoireMovesCompanion.insert(
              repertoireId: repId,
              fen: posAfterE4.fen,
              san: 'e4',
              sortOrder: 0,
            ),
          );

      await repo.saveReview(ReviewCardsCompanion.insert(
        repertoireId: repId,
        leafMoveId: moveId,
        nextReviewDate: DateTime(2026, 5, 1),
      ));

      final card = await repo.getCardForLeaf(moveId);
      expect(card, isNotNull);
      expect(card!.leafMoveId, moveId);
      expect(card.nextReviewDate, DateTime(2026, 5, 1));
    });

    test('is a no-op when id is present but no matching row exists', () async {
      final seedDate = DateTime(2026, 7, 1);
      final (_, leafId, _) = await seedLineWithCard(db, ['e4', 'e5'],
          nextReviewDate: seedDate);

      // Use a non-existent ID.
      await repo.saveReview(ReviewCardsCompanion(
        id: const Value(999999),
        easeFactor: const Value(3.0),
        intervalDays: const Value(14),
        repetitions: const Value(5),
        nextReviewDate: Value(DateTime(2026, 4, 1)),
      ));

      // Original card should be unchanged.
      final card = await repo.getCardForLeaf(leafId);
      expect(card, isNotNull);
      expect(card!.nextReviewDate, seedDate);
    });
  });

  // -------------------------------------------------------------------------
  // deleteCard
  // -------------------------------------------------------------------------

  group('deleteCard', () {
    test('removes the card', () async {
      final (_, leafId, originalCard) =
          await seedLineWithCard(db, ['e4', 'e5']);

      await repo.deleteCard(originalCard.id);

      final card = await repo.getCardForLeaf(leafId);
      expect(card, isNull);
    });

    test('does not affect other cards', () async {
      final (_, leafId1, card1) = await seedLineWithCard(db, ['e4', 'e5']);
      final (_, leafId2, _) = await seedLineWithCard(db, ['d4', 'd5']);

      await repo.deleteCard(card1.id);

      final deletedCard = await repo.getCardForLeaf(leafId1);
      expect(deletedCard, isNull);

      final survivingCard = await repo.getCardForLeaf(leafId2);
      expect(survivingCard, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // getAllCardsForRepertoire
  // -------------------------------------------------------------------------

  group('getAllCardsForRepertoire', () {
    test('returns all cards regardless of due date', () async {
      final seed = await seedBranchingTree(db);

      final cards = await repo.getAllCardsForRepertoire(seed.repId);
      // All 3 cards: Nf3 (past), Bc4 (today), c5 (future).
      expect(cards, hasLength(3));
    });

    test('returns only cards for the specified repertoire', () async {
      final seed = await seedBranchingTree(db);
      await seedLineWithCard(db, ['d4', 'd5']);

      final cards = await repo.getAllCardsForRepertoire(seed.repId);
      expect(cards, hasLength(3));
      for (final card in cards) {
        expect(card.repertoireId, seed.repId);
      }
    });
  });
}
