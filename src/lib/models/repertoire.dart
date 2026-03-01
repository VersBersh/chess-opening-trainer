import '../repositories/local/database.dart';

/// Eagerly-loaded, indexed view of the full repertoire move tree.
/// Built from a single getMovesForRepertoire() call.
/// Provides O(depth) path reconstruction, O(1) lookups by ID and FEN.
class RepertoireTreeCache {
  final Map<int, RepertoireMove> movesById;
  final Map<int, List<RepertoireMove>> childrenByParentId;
  final Map<String, List<RepertoireMove>> movesByFen;
  final List<RepertoireMove> rootMoves;

  RepertoireTreeCache._({
    required this.movesById,
    required this.childrenByParentId,
    required this.movesByFen,
    required this.rootMoves,
  });

  factory RepertoireTreeCache.build(List<RepertoireMove> allMoves) {
    final movesById = <int, RepertoireMove>{};
    final childrenByParentId = <int, List<RepertoireMove>>{};
    final movesByFen = <String, List<RepertoireMove>>{};
    final rootMoves = <RepertoireMove>[];

    for (final move in allMoves) {
      movesById[move.id] = move;

      if (move.parentMoveId != null) {
        childrenByParentId.putIfAbsent(move.parentMoveId!, () => []).add(move);
      } else {
        rootMoves.add(move);
      }

      movesByFen.putIfAbsent(move.fen, () => []).add(move);
    }

    // Sort children by sort_order
    for (final children in childrenByParentId.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    rootMoves.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return RepertoireTreeCache._(
      movesById: movesById,
      childrenByParentId: childrenByParentId,
      movesByFen: movesByFen,
      rootMoves: rootMoves,
    );
  }

  /// Returns the ordered root-to-move path.
  List<RepertoireMove> getLine(int moveId) {
    final path = <RepertoireMove>[];
    int? current = moveId;
    while (current != null) {
      final move = movesById[current];
      if (move == null) break;
      path.add(move);
      current = move.parentMoveId;
    }
    return path.reversed.toList();
  }

  List<RepertoireMove> getMovesAtPosition(String fen) {
    return movesByFen[fen] ?? [];
  }

  List<RepertoireMove> getRootMoves() => rootMoves;

  bool isLeaf(int moveId) {
    return !(childrenByParentId.containsKey(moveId) &&
        childrenByParentId[moveId]!.isNotEmpty);
  }

  List<RepertoireMove> getChildren(int moveId) {
    return childrenByParentId[moveId] ?? [];
  }

  /// Returns the move and all its descendants.
  List<RepertoireMove> getSubtree(int moveId) {
    final result = <RepertoireMove>[];
    final move = movesById[moveId];
    if (move == null) return result;

    final stack = [move];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      result.add(current);
      final children = childrenByParentId[current.id];
      if (children != null) {
        stack.addAll(children.reversed);
      }
    }
    return result;
  }
}
