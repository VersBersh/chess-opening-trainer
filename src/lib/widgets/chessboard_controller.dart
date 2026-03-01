import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that owns the chess [Position] state and exposes
/// derived properties consumed by [ChessboardWidget].
///
/// Follows Flutter's controller pattern (like [TextEditingController]).
/// Parent widgets (DrillController, LineEntryController) own and manage the
/// controller instance.
class ChessboardController extends ChangeNotifier {
  ChessboardController() : _position = Chess.initial;

  Position _position;
  NormalMove? _lastMove;
  IMap<Square, ISet<Square>>? _validMovesCache;
  final List<_HistoryEntry> _history = [];

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The current chess position.
  Position get position => _position;

  /// Full FEN string of the current position.
  String get fen => _position.fen;

  /// Which side is to move.
  Side get sideToMove => _position.turn;

  /// Whether the side to move is in check.
  bool get isCheck => _position.isCheck;

  /// Legal moves from the current position, keyed by origin square.
  IMap<Square, ISet<Square>> get validMoves =>
      _validMovesCache ??= makeLegalMoves(_position);

  /// The last move played, or `null` if no move has been made.
  NormalMove? get lastMove => _lastMove;

  /// Whether there is at least one move in the history that can be undone.
  bool get canUndo => _history.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Mutators
  // ---------------------------------------------------------------------------

  /// Replaces the current position by parsing the given [fen] string.
  ///
  /// Resets [lastMove] to `null` and clears move history ([canUndo] becomes
  /// `false`). Notifies listeners.
  ///
  /// Throws [FenException] or [PositionSetupException] if [fen] is invalid.
  void setPosition(String fen) {
    final newPosition = Chess.fromSetup(Setup.parseFen(fen));
    _history.clear();
    _position = newPosition;
    _lastMove = null;
    _validMovesCache = null;
    notifyListeners();
  }

  /// Validates and plays [move] on the current position.
  ///
  /// Returns `true` if the move was legal and was played. Returns `false`
  /// without modifying state if the move is illegal.
  bool playMove(NormalMove move) {
    if (!_position.isLegal(move)) return false;
    _history.add(_HistoryEntry(position: _position, lastMove: _lastMove));
    _position = _position.play(move);
    _lastMove = move;
    _validMovesCache = null;
    notifyListeners();
    return true;
  }

  /// Convenience method to reset the position to the standard initial position.
  ///
  /// Clears move history ([canUndo] becomes `false`).
  void resetToInitial() {
    _history.clear();
    _position = Chess.initial;
    _lastMove = null;
    _validMovesCache = null;
    notifyListeners();
  }

  /// Reverts to the position before the most recent [playMove] call.
  ///
  /// Returns `true` if a move was undone. Returns `false` (no-op) if there
  /// is no history to undo.
  bool undo() {
    if (_history.isEmpty) return false;
    final entry = _history.removeLast();
    _position = entry.position;
    _lastMove = entry.lastMove;
    _validMovesCache = null;
    notifyListeners();
    return true;
  }

  /// Returns `true` when [move] is a pawn reaching the back rank without a
  /// promotion role already set (i.e. the user needs to choose).
  bool isPromotionRequired(NormalMove move) {
    if (move.promotion != null) return false;
    final role = _position.board.roleAt(move.from);
    if (role != Role.pawn) return false;
    return (move.to.rank == Rank.first && _position.turn == Side.black) ||
        (move.to.rank == Rank.eighth && _position.turn == Side.white);
  }
}

class _HistoryEntry {
  final Position position;
  final NormalMove? lastMove;
  const _HistoryEntry({required this.position, this.lastMove});
}
