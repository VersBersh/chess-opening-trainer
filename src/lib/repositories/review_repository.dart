import '../repositories/local/database.dart';

abstract class ReviewRepository {
  Future<List<ReviewCard>> getDueCards({DateTime? asOf});
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
      {DateTime? asOf});
  Future<ReviewCard?> getCardForLeaf(int leafMoveId);
  Future<void> saveReview(ReviewCardsCompanion card);
  Future<void> deleteCard(int id);
  Future<List<ReviewCard>> getCardsForSubtree(int moveId,
      {bool dueOnly = false, DateTime? asOf});
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId);
  Future<int> getCardCountForRepertoire(int repertoireId);

  /// Returns (repertoireId -> (dueCount, totalCount)) for all repertoires
  /// that have at least one review card, computed in a single query.
  Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries(
      {DateTime? asOf});

  /// Returns (moveId -> dueCount) for each move ID in [moveIds] that has at
  /// least one due card in its subtree. Move IDs with zero due cards are
  /// omitted from the result.
  Future<Map<int, int>> getDueCountForSubtrees(List<int> moveIds,
      {DateTime? asOf});
}
