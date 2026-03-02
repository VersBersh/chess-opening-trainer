import 'package:drift/drift.dart';

import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';
import 'line_entry_engine.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Result of persisting new moves via [LinePersistenceService].
class PersistResult {
  final bool isExtension;
  final int? oldLeafMoveId;
  final List<int> insertedMoveIds;
  final ReviewCard? oldCard;

  const PersistResult({
    required this.isExtension,
    this.oldLeafMoveId,
    this.insertedMoveIds = const [],
    this.oldCard,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Handles persistence of new moves from line entry.
///
/// Accepts [ConfirmData] from [LineEntryEngine] and writes moves and cards
/// to the database via repository abstractions. Returns a [PersistResult]
/// summarizing what was persisted.
class LinePersistenceService {
  final RepertoireRepository _repertoireRepo;
  final ReviewRepository _reviewRepo;

  LinePersistenceService({
    required RepertoireRepository repertoireRepo,
    required ReviewRepository reviewRepo,
  })  : _repertoireRepo = repertoireRepo,
        _reviewRepo = reviewRepo;

  /// Persists the new moves described by [confirmData].
  ///
  /// Delegates to the extension path (atomic [extendLine]) or the branch path
  /// (sequential [saveMove] + card creation) based on [ConfirmData.isExtension].
  ///
  /// Throws [ArgumentError] if [confirmData] has invalid preconditions
  /// (e.g. extension without a parentMoveId, or empty newMoves).
  Future<PersistResult> persistNewMoves(ConfirmData confirmData) async {
    if (confirmData.newMoves.isEmpty) {
      throw ArgumentError('confirmData.newMoves must not be empty');
    }
    if (confirmData.isExtension) {
      return _persistExtension(confirmData);
    } else {
      return _persistBranch(confirmData);
    }
  }

  Future<PersistResult> _persistExtension(ConfirmData confirmData) async {
    final oldLeafMoveId = confirmData.parentMoveId;
    if (oldLeafMoveId == null) {
      throw ArgumentError(
          'parentMoveId must not be null for extension persistence');
    }
    final oldCard = await _reviewRepo.getCardForLeaf(oldLeafMoveId);

    final companions = <RepertoireMovesCompanion>[];
    for (var i = 0; i < confirmData.newMoves.length; i++) {
      final buffered = confirmData.newMoves[i];
      companions.add(RepertoireMovesCompanion.insert(
        repertoireId: confirmData.repertoireId,
        fen: buffered.fen,
        san: buffered.san,
        sortOrder: i == 0 ? confirmData.sortOrder : 0,
      ));
    }
    final insertedMoveIds =
        await _repertoireRepo.extendLine(oldLeafMoveId, companions);

    return PersistResult(
      isExtension: true,
      oldLeafMoveId: oldLeafMoveId,
      insertedMoveIds: insertedMoveIds,
      oldCard: oldCard,
    );
  }

  Future<PersistResult> _persistBranch(ConfirmData confirmData) async {
    int? parentId = confirmData.parentMoveId;
    final insertedIds = <int>[];

    for (var i = 0; i < confirmData.newMoves.length; i++) {
      final buffered = confirmData.newMoves[i];
      final companion = RepertoireMovesCompanion.insert(
        repertoireId: confirmData.repertoireId,
        fen: buffered.fen,
        san: buffered.san,
        sortOrder: i == 0 ? confirmData.sortOrder : 0,
      );
      final withParent = parentId != null
          ? companion.copyWith(parentMoveId: Value(parentId))
          : companion;
      parentId = await _repertoireRepo.saveMove(withParent);
      insertedIds.add(parentId);
    }

    // Create card for the new leaf.
    await _reviewRepo.saveReview(ReviewCardsCompanion.insert(
      repertoireId: confirmData.repertoireId,
      leafMoveId: parentId!,
      nextReviewDate: DateTime.now(),
    ));

    return PersistResult(
      isExtension: false,
      insertedMoveIds: insertedIds,
    );
  }
}
