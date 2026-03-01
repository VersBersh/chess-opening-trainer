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
