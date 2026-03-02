import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';

// ---------------------------------------------------------------------------
// Orphan handling
// ---------------------------------------------------------------------------

/// User's choice when a parent move becomes childless after deletion.
enum OrphanChoice { keepShorterLine, removeMove }

// ---------------------------------------------------------------------------
// Data types for two-step dialog pattern
// ---------------------------------------------------------------------------

/// Data needed by the screen to show a branch-delete confirmation dialog.
class BranchDeleteInfo {
  final int lineCount;
  final int cardCount;
  const BranchDeleteInfo({required this.lineCount, required this.cardCount});
}

// ---------------------------------------------------------------------------
// Deletion service
// ---------------------------------------------------------------------------

/// Pure Dart service that handles delete-leaf, delete-branch, and orphan
/// handling logic for the repertoire move tree.
///
/// Depends on repository abstractions (no Flutter imports). Follows the same
/// constructor-injection pattern as [PgnImporter].
class DeletionService {
  final RepertoireRepository _repertoireRepo;
  final ReviewRepository _reviewRepo;

  DeletionService({
    required RepertoireRepository repertoireRepo,
    required ReviewRepository reviewRepo,
  })  : _repertoireRepo = repertoireRepo,
        _reviewRepo = reviewRepo;

  /// Deletes a move (and all descendants via CASCADE) and returns the parent ID.
  Future<int?> deleteMoveAndGetParent(int moveId) async {
    final move = await _repertoireRepo.getMove(moveId);
    if (move == null) return null;
    final parentId = move.parentMoveId;
    await _repertoireRepo.deleteMove(moveId);
    return parentId;
  }

  /// Returns info needed for the branch-delete confirmation dialog.
  Future<BranchDeleteInfo> getBranchDeleteInfo(int moveId) async {
    final lineCount = await _repertoireRepo.countLeavesInSubtree(moveId);
    final cards = await _reviewRepo.getCardsForSubtree(moveId);
    return BranchDeleteInfo(lineCount: lineCount, cardCount: cards.length);
  }

  /// Handles orphaned moves after a deletion.
  ///
  /// [promptUser] is a callback that shows the orphan dialog for a given
  /// move ID and returns the user's choice. This keeps the service free
  /// of Flutter/UI imports.
  Future<void> handleOrphans(
    int? parentMoveId,
    Future<OrphanChoice?> Function(int moveId) promptUser,
  ) async {
    int? currentId = parentMoveId;

    while (currentId != null) {
      final children = await _repertoireRepo.getChildMoves(currentId);
      if (children.isNotEmpty) break; // not an orphan

      final choice = await promptUser(currentId);

      if (choice == null) {
        break; // Dialog dismissed -- abort orphan handling
      } else if (choice == OrphanChoice.keepShorterLine) {
        final move = await _repertoireRepo.getMove(currentId);
        if (move == null) break;
        await _reviewRepo.saveReview(ReviewCardsCompanion.insert(
          repertoireId: move.repertoireId,
          leafMoveId: currentId,
          nextReviewDate: DateTime.now(),
        ));
        break;
      } else {
        // Remove move -- delete and check its parent
        final move = await _repertoireRepo.getMove(currentId);
        final nextParent = move?.parentMoveId;
        await _repertoireRepo.deleteMove(currentId);
        currentId = nextParent;
      }
    }
  }

  /// Returns the move data needed to show an orphan prompt dialog.
  Future<RepertoireMove?> getMoveForOrphanPrompt(int moveId) async {
    return _repertoireRepo.getMove(moveId);
  }
}
