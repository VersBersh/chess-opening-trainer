import 'package:drift/drift.dart';

import '../repertoire_repository.dart';
import 'database.dart';

class LocalRepertoireRepository implements RepertoireRepository {
  final AppDatabase _db;

  LocalRepertoireRepository(this._db);

  @override
  Future<List<Repertoire>> getAllRepertoires() {
    return _db.select(_db.repertoires).get();
  }

  @override
  Future<Repertoire> getRepertoire(int id) {
    return (_db.select(_db.repertoires)..where((r) => r.id.equals(id)))
        .getSingle();
  }

  @override
  Future<int> saveRepertoire(RepertoiresCompanion repertoire) {
    return _db.into(_db.repertoires).insert(repertoire);
  }

  @override
  Future<void> deleteRepertoire(int id) async {
    await (_db.delete(_db.repertoires)..where((r) => r.id.equals(id))).go();
  }

  @override
  Future<List<RepertoireMove>> getMovesForRepertoire(int repertoireId) {
    return (_db.select(_db.repertoireMoves)
          ..where((m) => m.repertoireId.equals(repertoireId)))
        .get();
  }

  @override
  Future<RepertoireMove?> getMove(int id) {
    return (_db.select(_db.repertoireMoves)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<RepertoireMove>> getChildMoves(int parentMoveId) {
    return (_db.select(_db.repertoireMoves)
          ..where((m) => m.parentMoveId.equals(parentMoveId))
          ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
        .get();
  }

  @override
  Future<int> saveMove(RepertoireMovesCompanion move) {
    return _db.into(_db.repertoireMoves).insert(move);
  }

  @override
  Future<void> updateMoveLabel(int moveId, String? label) async {
    await (_db.update(_db.repertoireMoves)
          ..where((m) => m.id.equals(moveId)))
        .write(RepertoireMovesCompanion(label: Value(label)));
  }

  @override
  Future<void> deleteMove(int id) async {
    await (_db.delete(_db.repertoireMoves)..where((m) => m.id.equals(id)))
        .go();
  }

  @override
  Future<List<RepertoireMove>> getRootMoves(int repertoireId) {
    return (_db.select(_db.repertoireMoves)
          ..where((m) =>
              m.repertoireId.equals(repertoireId) &
              m.parentMoveId.isNull())
          ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
        .get();
  }

  @override
  Future<List<RepertoireMove>> getLineForLeaf(int leafMoveId) async {
    final results = await _db.customSelect(
      '''
      WITH RECURSIVE line(id, repertoire_id, parent_move_id, fen, san, label, comment, sort_order, depth) AS (
        SELECT id, repertoire_id, parent_move_id, fen, san, label, comment, sort_order, 0
        FROM repertoire_moves WHERE id = ?
        UNION ALL
        SELECT m.id, m.repertoire_id, m.parent_move_id, m.fen, m.san, m.label, m.comment, m.sort_order, line.depth + 1
        FROM repertoire_moves m JOIN line ON m.id = line.parent_move_id
      )
      SELECT id, repertoire_id, parent_move_id, fen, san, label, comment, sort_order
      FROM line ORDER BY depth DESC
      ''',
      variables: [Variable.withInt(leafMoveId)],
      readsFrom: {_db.repertoireMoves},
    ).get();

    return results.map((row) {
      return RepertoireMove(
        id: row.read<int>('id'),
        repertoireId: row.read<int>('repertoire_id'),
        parentMoveId: row.readNullable<int>('parent_move_id'),
        fen: row.read<String>('fen'),
        san: row.read<String>('san'),
        label: row.readNullable<String>('label'),
        comment: row.readNullable<String>('comment'),
        sortOrder: row.read<int>('sort_order'),
      );
    }).toList();
  }

  @override
  Future<bool> isLeafMove(int moveId) async {
    final result = await _db.customSelect(
      'SELECT NOT EXISTS(SELECT 1 FROM repertoire_moves WHERE parent_move_id = ?) AS is_leaf',
      variables: [Variable.withInt(moveId)],
      readsFrom: {_db.repertoireMoves},
    ).getSingle();
    return result.read<bool>('is_leaf');
  }

  @override
  Future<List<RepertoireMove>> getMovesAtPosition(
      int repertoireId, String fen) {
    return (_db.select(_db.repertoireMoves)
          ..where((m) =>
              m.repertoireId.equals(repertoireId) & m.fen.equals(fen)))
        .get();
  }

  @override
  Future<List<int>> extendLine(
      int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves) {
    return _db.transaction(() async {
      // Delete the old leaf's review card
      await (_db.delete(_db.reviewCards)
            ..where((c) => c.leafMoveId.equals(oldLeafMoveId)))
          .go();

      // Insert new moves, chaining parent IDs
      final insertedIds = <int>[];
      int parentId = oldLeafMoveId;
      for (final move in newMoves) {
        final insertedId = await _db.into(_db.repertoireMoves).insert(
              move.copyWith(parentMoveId: Value(parentId)),
            );
        insertedIds.add(insertedId);
        parentId = insertedId;
      }

      // Create a new review card for the new leaf
      if (insertedIds.isNotEmpty) {
        final newLeaf = await getMove(insertedIds.last);
        if (newLeaf != null) {
          await _db.into(_db.reviewCards).insert(
                ReviewCardsCompanion.insert(
                  repertoireId: newLeaf.repertoireId,
                  leafMoveId: newLeaf.id,
                  nextReviewDate: DateTime.now(),
                ),
              );
        }
      }

      return insertedIds;
    });
  }

  @override
  Future<void> undoExtendLine(
      int oldLeafMoveId, List<int> insertedMoveIds, ReviewCard oldCard) {
    return _db.transaction(() async {
      // Guard: no-op if nothing was inserted.
      if (insertedMoveIds.isEmpty) return;

      // Assert consistency: the old card must point to the old leaf.
      if (oldCard.leafMoveId != oldLeafMoveId) {
        throw StateError(
          'undoExtendLine contract violation: '
          'oldCard.leafMoveId (${oldCard.leafMoveId}) != '
          'oldLeafMoveId ($oldLeafMoveId)',
        );
      }

      // Delete the first inserted move; CASCADE removes all descendants
      // and the new review card.
      await (_db.delete(_db.repertoireMoves)
            ..where((m) => m.id.equals(insertedMoveIds.first)))
          .go();

      // Re-insert the old review card with a fresh auto-increment ID.
      final companion = oldCard.toCompanion(false).copyWith(
            id: const Value.absent(),
            leafMoveId: Value(oldLeafMoveId),
          );
      await _db.into(_db.reviewCards).insert(companion);
    });
  }

  @override
  Future<int> countLeavesInSubtree(int moveId) async {
    final result = await _db.customSelect(
      '''
      WITH RECURSIVE subtree(id) AS (
        SELECT id FROM repertoire_moves WHERE id = ?
        UNION ALL
        SELECT m.id FROM repertoire_moves m JOIN subtree ON m.parent_move_id = subtree.id
      )
      SELECT COUNT(*) AS cnt FROM subtree s
      WHERE NOT EXISTS(SELECT 1 FROM repertoire_moves WHERE parent_move_id = s.id)
      ''',
      variables: [Variable.withInt(moveId)],
      readsFrom: {_db.repertoireMoves},
    ).getSingle();
    return result.read<int>('cnt');
  }

  @override
  Future<List<RepertoireMove>> getOrphanedLeaves(int repertoireId) async {
    final results = await _db.customSelect(
      '''
      SELECT m.* FROM repertoire_moves m
      WHERE m.repertoire_id = ?
        AND NOT EXISTS(SELECT 1 FROM repertoire_moves c WHERE c.parent_move_id = m.id)
        AND NOT EXISTS(SELECT 1 FROM review_cards r WHERE r.leaf_move_id = m.id)
      ''',
      variables: [Variable.withInt(repertoireId)],
      readsFrom: {_db.repertoireMoves, _db.reviewCards},
    ).get();

    return results.map((row) {
      return RepertoireMove(
        id: row.read<int>('id'),
        repertoireId: row.read<int>('repertoire_id'),
        parentMoveId: row.readNullable<int>('parent_move_id'),
        fen: row.read<String>('fen'),
        san: row.read<String>('san'),
        label: row.readNullable<String>('label'),
        comment: row.readNullable<String>('comment'),
        sortOrder: row.read<int>('sort_order'),
      );
    }).toList();
  }

  @override
  Future<void> pruneOrphans(int repertoireId) async {
    while (true) {
      final orphans = await getOrphanedLeaves(repertoireId);
      if (orphans.isEmpty) break;
      for (final orphan in orphans) {
        await deleteMove(orphan.id);
      }
    }
  }
}
