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
}
