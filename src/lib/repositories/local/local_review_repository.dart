import 'package:drift/drift.dart';

import '../review_repository.dart';
import 'database.dart';

class LocalReviewRepository implements ReviewRepository {
  final AppDatabase _db;

  LocalReviewRepository(this._db);

  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) {
    final cutoff = asOf ?? DateTime.now();
    return (_db.select(_db.reviewCards)
          ..where((c) => c.nextReviewDate.isSmallerOrEqualValue(cutoff)))
        .get();
  }

  @override
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
      {DateTime? asOf}) {
    final cutoff = asOf ?? DateTime.now();
    return (_db.select(_db.reviewCards)
          ..where((c) =>
              c.repertoireId.equals(repertoireId) &
              c.nextReviewDate.isSmallerOrEqualValue(cutoff)))
        .get();
  }

  @override
  Future<ReviewCard?> getCardForLeaf(int leafMoveId) {
    return (_db.select(_db.reviewCards)
          ..where((c) => c.leafMoveId.equals(leafMoveId)))
        .getSingleOrNull();
  }

  @override
  Future<void> saveReview(ReviewCardsCompanion card) async {
    if (card.id.present) {
      await (_db.update(_db.reviewCards)
            ..where((c) => c.id.equals(card.id.value)))
          .write(card);
    } else {
      await _db.into(_db.reviewCards).insert(card);
    }
  }

  @override
  Future<void> deleteCard(int id) async {
    await (_db.delete(_db.reviewCards)..where((c) => c.id.equals(id))).go();
  }

  @override
  Future<List<ReviewCard>> getCardsForSubtree(int moveId,
      {bool dueOnly = false, DateTime? asOf}) async {
    final cutoff = asOf ?? DateTime.now();
    final dueFilter = dueOnly ? 'AND rc.next_review_date <= ?' : '';

    final results = await _db.customSelect(
      '''
      WITH RECURSIVE subtree(id) AS (
        SELECT id FROM repertoire_moves WHERE id = ?
        UNION ALL
        SELECT m.id FROM repertoire_moves m JOIN subtree ON m.parent_move_id = subtree.id
      )
      SELECT rc.* FROM review_cards rc
      JOIN subtree s ON rc.leaf_move_id = s.id
      $dueFilter
      ''',
      variables: [
        Variable.withInt(moveId),
        if (dueOnly) Variable<DateTime>(cutoff),
      ],
      readsFrom: {_db.repertoireMoves, _db.reviewCards},
    ).get();

    return results.map((row) {
      return ReviewCard(
        id: row.read<int>('id'),
        repertoireId: row.read<int>('repertoire_id'),
        leafMoveId: row.read<int>('leaf_move_id'),
        easeFactor: row.read<double>('ease_factor'),
        intervalDays: row.read<int>('interval_days'),
        repetitions: row.read<int>('repetitions'),
        nextReviewDate: row.read<DateTime>('next_review_date'),
        lastQuality: row.readNullable<int>('last_quality'),
        lastExtraPracticeDate:
            row.readNullable<DateTime>('last_extra_practice_date'),
      );
    }).toList();
  }

  @override
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId) {
    return (_db.select(_db.reviewCards)
          ..where((c) => c.repertoireId.equals(repertoireId)))
        .get();
  }

  @override
  Future<int> getCardCountForRepertoire(int repertoireId) async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) AS cnt FROM review_cards WHERE repertoire_id = ?',
      variables: [Variable.withInt(repertoireId)],
      readsFrom: {_db.reviewCards},
    ).getSingle();
    return result.read<int>('cnt');
  }

  @override
  Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries(
      {DateTime? asOf}) async {
    final cutoff = asOf ?? DateTime.now();

    final results = await _db.customSelect(
      '''
      SELECT
        repertoire_id,
        COUNT(*) AS total_count,
        COUNT(CASE WHEN next_review_date <= ? THEN 1 END) AS due_count
      FROM review_cards
      GROUP BY repertoire_id
      ''',
      variables: [Variable<DateTime>(cutoff)],
      readsFrom: {_db.reviewCards},
    ).get();

    final map = <int, ({int dueCount, int totalCount})>{};
    for (final row in results) {
      final repertoireId = row.read<int>('repertoire_id');
      map[repertoireId] = (
        dueCount: row.read<int>('due_count'),
        totalCount: row.read<int>('total_count'),
      );
    }
    return map;
  }

  /// SQLite bind-variable limit minus one (reserved for the cutoff datetime).
  static const _maxIdsPerChunk = 900;

  @override
  Future<Map<int, int>> getDueCountForSubtrees(List<int> moveIds,
      {DateTime? asOf}) async {
    if (moveIds.isEmpty) return {};

    final cutoff = asOf ?? DateTime.now();
    final map = <int, int>{};

    // Chunk to stay within SQLite's 999-variable limit.
    for (var i = 0; i < moveIds.length; i += _maxIdsPerChunk) {
      final chunk = moveIds.sublist(
        i,
        i + _maxIdsPerChunk < moveIds.length
            ? i + _maxIdsPerChunk
            : moveIds.length,
      );
      final placeholders = List.filled(chunk.length, '?').join(', ');

      final results = await _db.customSelect(
        '''
        WITH RECURSIVE subtrees(root_id, node_id) AS (
          SELECT id, id FROM repertoire_moves WHERE id IN ($placeholders)
          UNION ALL
          SELECT s.root_id, m.id
          FROM repertoire_moves m
          JOIN subtrees s ON m.parent_move_id = s.node_id
        )
        SELECT s.root_id, COUNT(*) AS due_count
        FROM subtrees s
        JOIN review_cards rc ON rc.leaf_move_id = s.node_id
        WHERE rc.next_review_date <= ?
        GROUP BY s.root_id
        ''',
        variables: [
          ...chunk.map(Variable.withInt),
          Variable<DateTime>(cutoff),
        ],
        readsFrom: {_db.repertoireMoves, _db.reviewCards},
      ).get();

      for (final row in results) {
        final rootId = row.read<int>('root_id');
        map[rootId] = (map[rootId] ?? 0) + row.read<int>('due_count');
      }
    }
    return map;
  }
}
