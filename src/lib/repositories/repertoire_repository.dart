import '../repositories/local/database.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// A pending label change for an already-saved move, to be persisted
/// atomically alongside new moves during confirm.
class PendingLabelUpdate {
  final int moveId;
  final String? label;
  const PendingLabelUpdate({required this.moveId, required this.label});
}

abstract class RepertoireRepository {
  /// Returns all repertoires ordered by creation order (ascending ID).
  Future<List<Repertoire>> getAllRepertoires();
  Future<Repertoire> getRepertoire(int id);
  Future<int> saveRepertoire(RepertoiresCompanion repertoire);
  Future<void> deleteRepertoire(int id);
  Future<void> renameRepertoire(int id, String newName);

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
  Future<List<int>> extendLine(
      int oldLeafMoveId, List<RepertoireMovesCompanion> newMoves);
  Future<List<int>> saveBranch(
    int? parentMoveId,
    List<RepertoireMovesCompanion> newMoves,
  );
  Future<void> undoExtendLine(
      int oldLeafMoveId, List<int> insertedMoveIds, ReviewCard oldCard);
  Future<void> undoNewLine(List<int> insertedMoveIds);

  /// Extends a line AND applies pending label updates in one transaction.
  Future<List<int>> extendLineWithLabelUpdates(
    int oldLeafMoveId,
    List<RepertoireMovesCompanion> newMoves,
    List<PendingLabelUpdate> labelUpdates,
  );

  /// Saves a branch AND applies pending label updates in one transaction.
  Future<List<int>> saveBranchWithLabelUpdates(
    int? parentMoveId,
    List<RepertoireMovesCompanion> newMoves,
    List<PendingLabelUpdate> labelUpdates,
  );
  Future<int> countLeavesInSubtree(int moveId);
  Future<List<RepertoireMove>> getOrphanedLeaves(int repertoireId);
  Future<void> pruneOrphans(int repertoireId);

  /// Atomic reroute operation:
  /// 1. Insert [newMoves] as a chain starting from [anchorMoveId] (or as root
  ///    moves if null), creating the new path to the convergence point.
  /// 2. Re-parent all children of [oldConvergenceId] under the last inserted
  ///    move (the new convergence node).
  /// 3. Prune the orphaned old path: walk up from [oldConvergenceId] toward
  ///    the root, deleting each childless node that has no review card, stopping
  ///    at the first node that still has children or a review card.
  /// 4. Apply any pending label updates.
  /// Returns the list of inserted move IDs.
  Future<List<int>> rerouteLine({
    required int? anchorMoveId,
    required List<RepertoireMovesCompanion> newMoves,
    required int oldConvergenceId,
    required List<PendingLabelUpdate> labelUpdates,
  });
}
