import 'package:drift/drift.dart' show Value;

import '../repositories/local/database.dart';
import '../repositories/repertoire_repository.dart';
import '../repositories/review_repository.dart';
import 'line_entry_engine.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Result of a reroute operation.
class PersistenceRerouteResult {
  final List<int> insertedMoveIds;
  final int newConvergenceId;
  const PersistenceRerouteResult({
    required this.insertedMoveIds,
    required this.newConvergenceId,
  });
}

/// Result of persisting new moves via [LinePersistenceService].
class PersistResult {
  final bool isExtension;
  final int? oldLeafMoveId;
  final List<int> insertedMoveIds;
  final ReviewCard? oldCard;

  /// The move ID of the new leaf node created by this persist operation.
  /// Used by the controller to reload the engine at the correct position
  /// after confirm (for persistent-pill behavior).
  final int newLeafMoveId;

  const PersistResult({
    required this.isExtension,
    required this.newLeafMoveId,
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
  /// When [pendingLabelUpdates] is non-empty, label changes are applied
  /// atomically in the same transaction as the move inserts.
  ///
  /// Throws [ArgumentError] if [confirmData] has invalid preconditions
  /// (e.g. extension without a parentMoveId, or empty newMoves).
  Future<PersistResult> persistNewMoves(
    ConfirmData confirmData, {
    List<PendingLabelUpdate> pendingLabelUpdates = const [],
  }) async {
    if (confirmData.newMoves.isEmpty) {
      throw ArgumentError('confirmData.newMoves must not be empty');
    }
    if (confirmData.isExtension) {
      return _persistExtension(confirmData, pendingLabelUpdates: pendingLabelUpdates);
    } else {
      return _persistBranch(confirmData, pendingLabelUpdates: pendingLabelUpdates);
    }
  }

  Future<PersistResult> _persistExtension(
    ConfirmData confirmData, {
    List<PendingLabelUpdate> pendingLabelUpdates = const [],
  }) async {
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
        label: buffered.label != null
            ? Value(buffered.label)
            : const Value.absent(),
        sortOrder: i == 0 ? confirmData.sortOrder : 0,
      ));
    }

    final List<int> insertedMoveIds;
    if (pendingLabelUpdates.isNotEmpty) {
      insertedMoveIds = await _repertoireRepo.extendLineWithLabelUpdates(
        oldLeafMoveId, companions, pendingLabelUpdates);
    } else {
      insertedMoveIds =
          await _repertoireRepo.extendLine(oldLeafMoveId, companions);
    }

    return PersistResult(
      isExtension: true,
      newLeafMoveId: insertedMoveIds.last,
      oldLeafMoveId: oldLeafMoveId,
      insertedMoveIds: insertedMoveIds,
      oldCard: oldCard,
    );
  }

  Future<PersistResult> _persistBranch(
    ConfirmData confirmData, {
    List<PendingLabelUpdate> pendingLabelUpdates = const [],
  }) async {
    final companions = <RepertoireMovesCompanion>[];
    for (var i = 0; i < confirmData.newMoves.length; i++) {
      final buffered = confirmData.newMoves[i];
      companions.add(RepertoireMovesCompanion.insert(
        repertoireId: confirmData.repertoireId,
        fen: buffered.fen,
        san: buffered.san,
        label: buffered.label != null
            ? Value(buffered.label)
            : const Value.absent(),
        sortOrder: i == 0 ? confirmData.sortOrder : 0,
      ));
    }

    // Atomic: inserts all moves + review card in a single transaction.
    final List<int> insertedIds;
    if (pendingLabelUpdates.isNotEmpty) {
      insertedIds = await _repertoireRepo.saveBranchWithLabelUpdates(
        confirmData.parentMoveId, companions, pendingLabelUpdates);
    } else {
      insertedIds = await _repertoireRepo.saveBranch(
        confirmData.parentMoveId, companions);
    }

    return PersistResult(
      isExtension: false,
      newLeafMoveId: insertedIds.last,
      insertedMoveIds: insertedIds,
    );
  }

  /// Reroutes an existing line's continuation to go through a new path.
  ///
  /// Converts [movesToPersist] to companions, delegates to
  /// [RepertoireRepository.rerouteLine], and returns a [PersistenceRerouteResult].
  Future<PersistenceRerouteResult> reroute({
    required int? anchorMoveId,
    required List<BufferedMove> movesToPersist,
    required int oldConvergenceId,
    required int repertoireId,
    required int sortOrder,
    required List<PendingLabelUpdate> labelUpdates,
  }) async {
    final companions = <RepertoireMovesCompanion>[];
    for (var i = 0; i < movesToPersist.length; i++) {
      final buffered = movesToPersist[i];
      companions.add(RepertoireMovesCompanion.insert(
        repertoireId: repertoireId,
        fen: buffered.fen,
        san: buffered.san,
        label: buffered.label != null
            ? Value(buffered.label)
            : const Value.absent(),
        sortOrder: i == 0 ? sortOrder : 0,
      ));
    }

    final insertedIds = await _repertoireRepo.rerouteLine(
      anchorMoveId: anchorMoveId,
      newMoves: companions,
      oldConvergenceId: oldConvergenceId,
      labelUpdates: labelUpdates,
    );

    final newConvergenceId =
        insertedIds.isNotEmpty ? insertedIds.last : anchorMoveId!;

    return PersistenceRerouteResult(
      insertedMoveIds: insertedIds,
      newConvergenceId: newConvergenceId,
    );
  }
}
