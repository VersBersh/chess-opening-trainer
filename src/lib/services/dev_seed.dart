import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart';

import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';

const _devSeedRepertoireName = 'Dev Openings';

/// Seeds the database with sample repertoire data for development and manual
/// testing. On a fresh database, creates the seed repertoire and review cards.
/// On subsequent launches, ensures at least some seed cards are due today so
/// drill mode is always available during development.
Future<void> seedDevData(
  RepertoireRepository repertoireRepo,
  ReviewRepository reviewRepo,
) async {
  final existing = await repertoireRepo.getAllRepertoires();
  if (existing.isEmpty) {
    await _createSeedRepertoire(repertoireRepo, reviewRepo);
  }
  await _ensureCardsDueToday(repertoireRepo, reviewRepo);
}

/// Creates the "Dev Openings" repertoire with a branching tree from 1. e4:
///
/// ```
/// e4
///   e5 -> Nf3 -> Nc6 -> Bb5  [Leaf 1: 5-ply, white line]
///                     -> Bc4  [Leaf 2: 5-ply, white line]
///   c5 -> Nf3 -> d6 -> d4 -> cxd4 -> Nxd4  [Leaf 3: 7-ply, white line]
///      -> Nc3 -> Nc6 -> g3               [Leaf 4: 4-ply, black line]
/// ```
///
/// All leaf nodes get review cards with nextReviewDate = today (all due).
Future<void> _createSeedRepertoire(
  RepertoireRepository repertoireRepo,
  ReviewRepository reviewRepo,
) async {
  // Create the repertoire
  final repertoireId = await repertoireRepo.saveRepertoire(
    RepertoiresCompanion.insert(name: _devSeedRepertoireName),
  );

  final today = DateTime.now();

  // ---- Helper to insert a move and return its ID --------------------------
  Future<int> insertMove({
    required int repId,
    required int? parentMoveId,
    required String san,
    required Position positionBefore,
    required int sortOrder,
  }) async {
    final parsed = positionBefore.parseSan(san);
    if (parsed == null) {
      throw ArgumentError('Illegal move "$san"');
    }
    final positionAfter = positionBefore.play(parsed);

    return repertoireRepo.saveMove(
      RepertoireMovesCompanion.insert(
        repertoireId: repId,
        parentMoveId: parentMoveId != null
            ? Value(parentMoveId)
            : const Value.absent(),
        fen: positionAfter.fen,
        san: san,
        sortOrder: sortOrder,
      ),
    );
  }

  // ---- Helper to create a review card for a leaf move ---------------------
  Future<void> insertReviewCard(int repId, int leafMoveId) async {
    await reviewRepo.saveReview(
      ReviewCardsCompanion.insert(
        repertoireId: repId,
        leafMoveId: leafMoveId,
        nextReviewDate: today,
      ),
    );
  }

  // ---- Shared root: 1. e4 -------------------------------------------------
  Position pos = Chess.initial;

  final e4Id = await insertMove(
    repId: repertoireId,
    parentMoveId: null,
    san: 'e4',
    positionBefore: pos,
    sortOrder: 0,
  );
  final posAfterE4 = pos.play(pos.parseSan('e4')!);

  // ---- Branch A: 1...e5 (Ruy Lopez / Italian) ----------------------------
  final e5Id = await insertMove(
    repId: repertoireId,
    parentMoveId: e4Id,
    san: 'e5',
    positionBefore: posAfterE4,
    sortOrder: 0,
  );
  pos = posAfterE4.play(posAfterE4.parseSan('e5')!);

  final nf3Id = await insertMove(
    repId: repertoireId,
    parentMoveId: e5Id,
    san: 'Nf3',
    positionBefore: pos,
    sortOrder: 0,
  );
  pos = pos.play(pos.parseSan('Nf3')!);

  final nc6Id = await insertMove(
    repId: repertoireId,
    parentMoveId: nf3Id,
    san: 'Nc6',
    positionBefore: pos,
    sortOrder: 0,
  );
  final posAfterNc6 = pos.play(pos.parseSan('Nc6')!);

  // ---- Leaf 1: 3. Bb5 (Ruy Lopez, 5-ply, odd = white line) ---------------
  final bb5Id = await insertMove(
    repId: repertoireId,
    parentMoveId: nc6Id,
    san: 'Bb5',
    positionBefore: posAfterNc6,
    sortOrder: 0,
  );
  await insertReviewCard(repertoireId, bb5Id);

  // ---- Leaf 2: 3. Bc4 (Italian Game, 5-ply, odd = white line) ------------
  final bc4Id = await insertMove(
    repId: repertoireId,
    parentMoveId: nc6Id,
    san: 'Bc4',
    positionBefore: posAfterNc6,
    sortOrder: 1,
  );
  await insertReviewCard(repertoireId, bc4Id);

  // ---- Branch B: 1...c5 (Sicilian) ---------------------------------------
  final c5Id = await insertMove(
    repId: repertoireId,
    parentMoveId: e4Id,
    san: 'c5',
    positionBefore: posAfterE4,
    sortOrder: 1,
  );
  final posAfterC5 = posAfterE4.play(posAfterE4.parseSan('c5')!);

  // ---- Branch B1: 2. Nf3 (Open Sicilian) ---------------------------------
  final nf3SicId = await insertMove(
    repId: repertoireId,
    parentMoveId: c5Id,
    san: 'Nf3',
    positionBefore: posAfterC5,
    sortOrder: 0,
  );
  pos = posAfterC5.play(posAfterC5.parseSan('Nf3')!);

  final d6Id = await insertMove(
    repId: repertoireId,
    parentMoveId: nf3SicId,
    san: 'd6',
    positionBefore: pos,
    sortOrder: 0,
  );
  pos = pos.play(pos.parseSan('d6')!);

  final d4Id = await insertMove(
    repId: repertoireId,
    parentMoveId: d6Id,
    san: 'd4',
    positionBefore: pos,
    sortOrder: 0,
  );
  pos = pos.play(pos.parseSan('d4')!);

  final cxd4Id = await insertMove(
    repId: repertoireId,
    parentMoveId: d4Id,
    san: 'cxd4',
    positionBefore: pos,
    sortOrder: 0,
  );
  pos = pos.play(pos.parseSan('cxd4')!);

  // ---- Leaf 3: 4. Nxd4 (Open Sicilian, 7-ply, odd = white line) ----------
  final nxd4Id = await insertMove(
    repId: repertoireId,
    parentMoveId: cxd4Id,
    san: 'Nxd4',
    positionBefore: pos,
    sortOrder: 0,
  );
  await insertReviewCard(repertoireId, nxd4Id);

  // ---- Branch B2: 2. Nc3 (Closed Sicilian) -------------------------------
  final nc3Id = await insertMove(
    repId: repertoireId,
    parentMoveId: c5Id,
    san: 'Nc3',
    positionBefore: posAfterC5,
    sortOrder: 1,
  );
  pos = posAfterC5.play(posAfterC5.parseSan('Nc3')!);

  final nc6SicId = await insertMove(
    repId: repertoireId,
    parentMoveId: nc3Id,
    san: 'Nc6',
    positionBefore: pos,
    sortOrder: 0,
  );
  pos = pos.play(pos.parseSan('Nc6')!);

  // ---- Leaf 4: 3. g3 (Closed Sicilian, 4-ply, even = black line) ---------
  final g3Id = await insertMove(
    repId: repertoireId,
    parentMoveId: nc6SicId,
    san: 'g3',
    positionBefore: pos,
    sortOrder: 0,
  );
  await insertReviewCard(repertoireId, g3Id);
}

/// Ensures at least some seed cards are due today so drill mode is always
/// available during development. Only touches cards in the "Dev Openings"
/// repertoire; other repertoires are left untouched.
Future<void> _ensureCardsDueToday(
  RepertoireRepository repertoireRepo,
  ReviewRepository reviewRepo,
) async {
  final repertoires = await repertoireRepo.getAllRepertoires();
  final seedRepertoire = repertoires
      .where((r) => r.name == _devSeedRepertoireName)
      .firstOrNull;
  if (seedRepertoire == null) return;

  final dueCards = await reviewRepo.getDueCardsForRepertoire(
    seedRepertoire.id,
  );
  if (dueCards.isNotEmpty) return;

  final allSeedCards = await reviewRepo.getAllCardsForRepertoire(
    seedRepertoire.id,
  );
  if (allSeedCards.isEmpty) return;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final cardsToMakeDue = allSeedCards.take(4).toList();
  for (final card in cardsToMakeDue) {
    await reviewRepo.saveReview(
      card.toCompanion(true).copyWith(
        id: Value(card.id),
        nextReviewDate: Value(today),
      ),
    );
  }
}
