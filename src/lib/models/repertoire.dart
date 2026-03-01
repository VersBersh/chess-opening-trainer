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

  /// Walks the root-to-node path and concatenates all labels with " — "
  /// separator. Returns an empty string if no labels exist along the path.
  String getAggregateDisplayName(int moveId) {
    final line = getLine(moveId);
    final labels = line.where((m) => m.label != null).map((m) => m.label!);
    return labels.join(' \u2014 ');
  }

  /// Computes what the aggregate display name would be if [moveId]'s label
  /// were changed to [newLabel]. If [newLabel] is null or empty, the move's
  /// label contribution is excluded.
  String previewAggregateDisplayName(int moveId, String? newLabel) {
    final line = getLine(moveId);
    final labels = <String>[];
    for (final m in line) {
      if (m.id == moveId) {
        if (newLabel != null && newLabel.isNotEmpty) labels.add(newLabel);
      } else if (m.label != null) {
        labels.add(m.label!);
      }
    }
    return labels.join(' \u2014 ');
  }

  /// Returns move notation string like "1. e4" or "1...c5".
  ///
  /// [plyCount] is the 1-based position in the line (i.e. depth + 1 from
  /// root). When not provided, falls back to computing via [getLine].
  String getMoveNotation(int moveId, {int? plyCount}) {
    final index = plyCount ?? getLine(moveId).length; // 1-based ply count
    final moveNumber = (index + 1) ~/ 2;
    final isBlack = index.isEven;
    if (isBlack) return '$moveNumber...${movesById[moveId]!.san}';
    return '$moveNumber. ${movesById[moveId]!.san}';
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
