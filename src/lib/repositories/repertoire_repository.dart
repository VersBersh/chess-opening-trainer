import '../repositories/local/database.dart';

abstract class RepertoireRepository {
  Future<List<Repertoire>> getAllRepertoires();
  Future<Repertoire> getRepertoire(int id);
  Future<int> saveRepertoire(RepertoiresCompanion repertoire);
  Future<void> deleteRepertoire(int id);

  Future<List<RepertoireMove>> getMovesForRepertoire(int repertoireId);
  Future<RepertoireMove?> getMove(int id);
  Future<List<RepertoireMove>> getChildMoves(int parentMoveId);
  Future<int> saveMove(RepertoireMovesCompanion move);
  Future<void> deleteMove(int id);

  /// Updates just the label field on an existing move. Pass null to remove the label.
  Future<void> updateMoveLabel(int moveId, String? label);

  Future<List<RepertoireMove>> getRootMoves(int repertoireId);
  Future<List<RepertoireMove>> getLineForLeaf(int leafMoveId);
  Future<bool> isLeafMove(int moveId);
  Future<List<RepertoireMove>> getMovesAtPosition(
      int repertoireId, String fen);
  Future<void> extendLine(
      int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves);
  Future<int> countLeavesInSubtree(int moveId);
  Future<List<RepertoireMove>> getOrphanedLeaves(int repertoireId);
  Future<void> pruneOrphans(int repertoireId);
}
