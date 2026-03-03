import 'package:dartchess/dartchess.dart';

/// Resolves a Standard Algebraic Notation string (e.g. "e4", "Nf3", "a8=Q")
/// to a [NormalMove] that is legal in the given [position].
///
/// Returns `null` if the SAN is invalid or does not correspond to a legal
/// [NormalMove] in the position (e.g. it represents a drop move in
/// Crazyhouse).
NormalMove? sanToMove(Position position, String san) {
  final move = position.parseSan(san);
  return move is NormalMove ? move : null;
}

/// Returns the canonical form of [move] within [position].
///
/// For castling moves expressed as king-to-king-destination (e.g. e1→g1),
/// this returns the king-to-rook form that dartchess uses internally
/// (e.g. e1→h1). For all other moves, the move is returned unchanged.
NormalMove normalizeMoveForPosition(Position position, NormalMove move) {
  final normalized = position.normalizeMove(move);
  return normalized is NormalMove ? normalized : move;
}
