import 'package:dartchess/dartchess.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// A move that has been entered by the user but not yet persisted to the DB.
class BufferedMove {
  final String san;
  final String fen;
  final String? label;
  const BufferedMove({required this.san, required this.fen, this.label});

  BufferedMove copyWith({String? san, String? fen, String? Function()? label}) {
    return BufferedMove(
      san: san ?? this.san,
      fen: fen ?? this.fen,
      label: label != null ? label() : this.label,
    );
  }
}

/// Result of [LineEntryEngine.acceptMove].
sealed class MoveAcceptResult {
  const MoveAcceptResult();
}

/// The played move matched an existing child in the tree -- followed it.
class FollowedExistingMove extends MoveAcceptResult {
  final RepertoireMove move;
  const FollowedExistingMove(this.move);
}

/// The played move is new (not in the tree) -- buffered for later persist.
class NewMoveBuffered extends MoveAcceptResult {
  final BufferedMove bufferedMove;
  const NewMoveBuffered(this.bufferedMove);
}

/// Result of [LineEntryEngine.takeBack].
class TakeBackResult {
  /// The FEN to revert the board to.
  final String fen;
  const TakeBackResult({required this.fen});
}

/// Result of [LineEntryEngine.validateParity].
sealed class ParityValidationResult {
  const ParityValidationResult();
}

class ParityMatch extends ParityValidationResult {
  const ParityMatch();
}

class ParityMismatch extends ParityValidationResult {
  /// The expected board orientation based on the line's ply count.
  final Side expectedOrientation;
  const ParityMismatch({required this.expectedOrientation});
}

/// Data returned by [LineEntryEngine.getConfirmData] for persistence.
class ConfirmData {
  final int? parentMoveId;
  final List<BufferedMove> newMoves;
  final bool isExtension;
  final int repertoireId;
  final int sortOrder;

  const ConfirmData({
    required this.parentMoveId,
    required this.newMoves,
    required this.isExtension,
    required this.repertoireId,
    required this.sortOrder,
  });
}

// ---------------------------------------------------------------------------
// LineEntryEngine
// ---------------------------------------------------------------------------

/// Pure business-logic service that manages line entry state.
///
/// Tracks which moves follow existing tree branches vs. new buffered moves,
/// handles take-back across all visible moves, validates parity, and produces the
/// data needed to persist a new line.
///
/// Has no database access, no Flutter dependencies, and no UI awareness.
class LineEntryEngine {
  final RepertoireTreeCache _treeCache;
  final int _repertoireId;

  /// Moves from root to the starting node (already in DB).
  final List<RepertoireMove> _existingPath;

  /// Existing tree moves the user followed after the starting position.
  final List<RepertoireMove> _followedMoves = [];

  /// New moves not yet in the DB.
  final List<BufferedMove> _bufferedMoves = [];

  /// The ID of the last existing move in the followed path.
  int? _lastExistingMoveId;

  /// Whether the user has played a move not in the tree.
  bool _hasDiverged = false;

  // ---- Read-only accessors --------------------------------------------------

  List<RepertoireMove> get existingPath => List.unmodifiable(_existingPath);
  List<RepertoireMove> get followedMoves => List.unmodifiable(_followedMoves);
  List<BufferedMove> get bufferedMoves => List.unmodifiable(_bufferedMoves);
  int? get lastExistingMoveId => _lastExistingMoveId;
  bool get hasDiverged => _hasDiverged;

  LineEntryEngine({
    required RepertoireTreeCache treeCache,
    required int repertoireId,
    int? startingMoveId,
  })  : _treeCache = treeCache,
        _repertoireId = repertoireId,
        _existingPath = startingMoveId != null
            ? treeCache.getLine(startingMoveId)
            : [],
        _lastExistingMoveId = startingMoveId;

  // ---- Public methods -----------------------------------------------------

  /// Accepts a move played on the board.
  ///
  /// If the user has not diverged from the tree, checks whether the move
  /// matches an existing child. If so, follows that branch. Otherwise,
  /// buffers the move as new.
  MoveAcceptResult acceptMove(String san, String resultingFen) {
    if (!_hasDiverged) {
      final children = _lastExistingMoveId != null
          ? _treeCache.getChildren(_lastExistingMoveId!)
          : _treeCache.getRootMoves();

      final match = children.where((m) => m.san == san).toList();
      if (match.isNotEmpty) {
        final existingMove = match.first;
        _followedMoves.add(existingMove);
        _lastExistingMoveId = existingMove.id;
        return FollowedExistingMove(existingMove);
      }

      // No match -- diverge.
      _hasDiverged = true;
    }

    final buffered = BufferedMove(san: san, fen: resultingFen);
    _bufferedMoves.add(buffered);
    return NewMoveBuffered(buffered);
  }

  /// Whether take-back is possible.
  ///
  /// Returns `true` when any visible pill can be removed — buffered moves,
  /// followed moves, or existing-path moves.
  bool canTakeBack() =>
      _bufferedMoves.isNotEmpty ||
      _followedMoves.isNotEmpty ||
      _existingPath.isNotEmpty;

  /// Removes the last visible pill and returns the FEN to revert to.
  ///
  /// Pops from the three internal lists in reverse order:
  /// 1. **Buffer** — removes the last buffered move; resets `_hasDiverged`
  ///    when the buffer becomes empty.
  /// 2. **Followed moves** — when the buffer is empty, removes the last
  ///    followed move and updates `_lastExistingMoveId`.
  /// 3. **Existing path** — when both are empty, removes the last existing-
  ///    path move and updates `_lastExistingMoveId`.
  ///
  /// Returns `null` only when all three lists are empty (nothing to undo).
  TakeBackResult? takeBack() {
    // Phase 1: pop from buffer.
    if (_bufferedMoves.isNotEmpty) {
      _bufferedMoves.removeLast();

      // If buffer is now empty, reset divergence so the user can re-follow
      // existing branches from the current position.
      if (_bufferedMoves.isEmpty) {
        _hasDiverged = false;
      }

      if (_bufferedMoves.isNotEmpty) {
        return TakeBackResult(fen: _bufferedMoves.last.fen);
      }

      // Buffer is now empty — fall through to determine the revert FEN from
      // followed or existing-path moves.
      if (_followedMoves.isNotEmpty) {
        return TakeBackResult(fen: _followedMoves.last.fen);
      }
      if (_existingPath.isNotEmpty) {
        return TakeBackResult(fen: _existingPath.last.fen);
      }
      return const TakeBackResult(fen: kInitialFEN);
    }

    // Phase 2: pop from followed moves.
    if (_followedMoves.isNotEmpty) {
      _followedMoves.removeLast();

      // Update _lastExistingMoveId to the new tail of the followed chain,
      // or fall back to the existing path tip, or null.
      if (_followedMoves.isNotEmpty) {
        _lastExistingMoveId = _followedMoves.last.id;
        return TakeBackResult(fen: _followedMoves.last.fen);
      }
      if (_existingPath.isNotEmpty) {
        _lastExistingMoveId = _existingPath.last.id;
        return TakeBackResult(fen: _existingPath.last.fen);
      }
      _lastExistingMoveId = null;
      return const TakeBackResult(fen: kInitialFEN);
    }

    // Phase 3: pop from existing path.
    if (_existingPath.isNotEmpty) {
      _existingPath.removeLast();

      if (_existingPath.isNotEmpty) {
        _lastExistingMoveId = _existingPath.last.id;
        return TakeBackResult(fen: _existingPath.last.fen);
      }
      _lastExistingMoveId = null;
      return const TakeBackResult(fen: kInitialFEN);
    }

    // All three lists are empty — nothing to undo.
    return null;
  }

  /// Total ply count of the line so far.
  int get totalPly =>
      _existingPath.length + _followedMoves.length + _bufferedMoves.length;

  /// Validates whether the total ply matches the board orientation.
  ///
  /// Odd ply = white line, even ply = black line.
  ParityValidationResult validateParity(Side boardOrientation) {
    final isOddPly = totalPly.isOdd;
    final expectedOrientation = isOddPly ? Side.white : Side.black;

    if (boardOrientation == expectedOrientation) {
      return const ParityMatch();
    }
    return ParityMismatch(expectedOrientation: expectedOrientation);
  }

  /// Whether there are new (buffered) moves to persist.
  bool get hasNewMoves => _bufferedMoves.isNotEmpty;

  /// Returns the data needed to persist the new moves.
  ConfirmData getConfirmData() {
    final parentId = _lastExistingMoveId;

    // Compute isExtension: true only when parentMoveId is non-null AND
    // the parent is a leaf in the tree cache.
    final isExtension =
        parentId != null && _treeCache.isLeaf(parentId);

    // Compute sort order for the first buffered move.
    final int sortOrder;
    if (parentId != null) {
      sortOrder = _treeCache.getChildren(parentId).length;
    } else {
      sortOrder = _treeCache.getRootMoves().length;
    }

    return ConfirmData(
      parentMoveId: parentId,
      newMoves: List.unmodifiable(_bufferedMoves),
      isExtension: isExtension,
      repertoireId: _repertoireId,
      sortOrder: sortOrder,
    );
  }

  /// Sets the label on a buffered move at the given index.
  void setBufferedLabel(int index, String? label) {
    if (index >= 0 && index < _bufferedMoves.length) {
      _bufferedMoves[index] = _bufferedMoves[index].copyWith(label: () => label);
    }
  }

  /// Reapplies labels to buffered moves after a replay.
  ///
  /// Used to restore labels that would otherwise be lost when buffered moves
  /// are replayed onto a fresh engine (e.g. after [updateLabel] rebuilds the
  /// cache).
  void reapplyBufferedLabels(List<String?> labels) {
    for (var i = 0; i < labels.length && i < _bufferedMoves.length; i++) {
      _bufferedMoves[i] = _bufferedMoves[i].copyWith(label: () => labels[i]);
    }
  }

  /// Returns the aggregate display name for the current position in the tree.
  ///
  /// Only reflects labels on existing/followed moves; buffered labels are not
  /// included in the aggregate display name (they are not in the tree cache).
  String getCurrentDisplayName() {
    final lastExisting = _lastExistingMoveId;
    if (lastExisting == null) return '';
    return _treeCache.getAggregateDisplayName(lastExisting);
  }
}
