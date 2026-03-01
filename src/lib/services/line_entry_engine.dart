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
  const BufferedMove({required this.san, required this.fen});
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
/// handles take-back within the buffer, validates parity, and produces the
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

  /// Whether take-back is possible (only buffered moves can be removed).
  bool canTakeBack() => _bufferedMoves.isNotEmpty;

  /// Removes the last buffered move and returns the FEN to revert to.
  ///
  /// Returns `null` if the buffer is already empty.
  TakeBackResult? takeBack() {
    if (_bufferedMoves.isEmpty) return null;

    _bufferedMoves.removeLast();

    // If buffer is now empty, reset divergence so the user can re-follow
    // existing branches from the current position.
    if (_bufferedMoves.isEmpty) {
      _hasDiverged = false;
    }

    if (_bufferedMoves.isNotEmpty) {
      return TakeBackResult(fen: _bufferedMoves.last.fen);
    }

    // Buffer is now empty. If we followed existing moves, revert to last
    // followed move's FEN.
    if (_followedMoves.isNotEmpty) {
      return TakeBackResult(fen: _followedMoves.last.fen);
    }

    // No followed moves either. If there is an existing path (started from
    // a specific node), revert to that node's FEN.
    if (_existingPath.isNotEmpty) {
      return TakeBackResult(fen: _existingPath.last.fen);
    }

    // Starting from root with no followed moves -- revert to initial position.
    return const TakeBackResult(fen: kInitialFEN);
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

  /// Returns the aggregate display name for the current position in the tree.
  ///
  /// Only reflects labels on existing moves (buffered moves have no labels).
  String getCurrentDisplayName() {
    final lastExisting = _lastExistingMoveId;
    if (lastExisting == null) return '';
    return _treeCache.getAggregateDisplayName(lastExisting);
  }
}
