import '../repositories/local/database.dart';

/// A single entry describing how a descendant's display name changes when an
/// ancestor's label is modified.
class LabelImpactEntry {
  final int moveId;
  final String before;
  final String after;

  const LabelImpactEntry({
    required this.moveId,
    required this.before,
    required this.after,
  });
}

/// Eagerly-loaded, indexed view of the full repertoire move tree.
/// Built from a single getMovesForRepertoire() call.
/// Provides O(depth) path reconstruction, O(1) lookups by ID and FEN.
class RepertoireTreeCache {
  final Map<int, RepertoireMove> movesById;
  final Map<int, List<RepertoireMove>> childrenByParentId;
  final Map<String, List<RepertoireMove>> movesByFen;
  final Map<String, List<RepertoireMove>> movesByPositionKey;
  final List<RepertoireMove> rootMoves;

  RepertoireTreeCache._({
    required this.movesById,
    required this.childrenByParentId,
    required this.movesByFen,
    required this.movesByPositionKey,
    required this.rootMoves,
  });

  /// Strips the halfmove clock and fullmove number from a FEN string,
  /// returning the first four fields (board, turn, castling, en-passant).
  ///
  /// This produces a position key that is identical for transposition-
  /// equivalent positions regardless of the move order used to reach them.
  static String normalizePositionKey(String fen) {
    int spaceCount = 0;
    for (int i = 0; i < fen.length; i++) {
      if (fen[i] == ' ') {
        spaceCount++;
        if (spaceCount == 4) return fen.substring(0, i);
      }
    }
    return fen; // Defensive: return as-is if fewer than 4 spaces
  }

  factory RepertoireTreeCache.build(List<RepertoireMove> allMoves) {
    final movesById = <int, RepertoireMove>{};
    final childrenByParentId = <int, List<RepertoireMove>>{};
    final movesByFen = <String, List<RepertoireMove>>{};
    final movesByPositionKey = <String, List<RepertoireMove>>{};
    final rootMoves = <RepertoireMove>[];

    for (final move in allMoves) {
      movesById[move.id] = move;

      if (move.parentMoveId != null) {
        childrenByParentId.putIfAbsent(move.parentMoveId!, () => []).add(move);
      } else {
        rootMoves.add(move);
      }

      movesByFen.putIfAbsent(move.fen, () => []).add(move);

      final positionKey = normalizePositionKey(move.fen);
      movesByPositionKey.putIfAbsent(positionKey, () => []).add(move);
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
      movesByPositionKey: movesByPositionKey,
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

  /// Returns all child moves of all nodes whose normalized FEN matches the
  /// given [positionKey]. Used for transposition detection: finds repertoire
  /// moves available at a position regardless of the move order used to reach
  /// it.
  List<RepertoireMove> getChildrenAtPosition(String positionKey) {
    final nodesAtPosition = movesByPositionKey[positionKey];
    if (nodesAtPosition == null) return [];
    final result = <RepertoireMove>[];
    for (final node in nodesAtPosition) {
      final children = childrenByParentId[node.id];
      if (children != null) {
        result.addAll(children);
      }
    }
    return result;
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

  /// Returns all distinct non-null labels across the tree, sorted alphabetically.
  List<String> getDistinctLabels() {
    final labels = <String>{};
    for (final move in movesById.values) {
      if (move.label != null) {
        labels.add(move.label!);
      }
    }
    final sorted = labels.toList()..sort();
    return sorted;
  }

  /// Counts the number of leaf nodes in the subtree rooted at [moveId].
  /// A leaf is a node with no children. Returns 0 if [moveId] is not found.
  int countDescendantLeaves(int moveId) {
    final subtree = getSubtree(moveId);
    return subtree.where((m) => isLeaf(m.id)).length;
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

  /// Returns a list of [LabelImpactEntry] describing how each labeled
  /// descendant's display name would change if [moveId]'s label were set to
  /// [newLabel]. Only descendants whose display name actually changes are
  /// included.
  List<LabelImpactEntry> getDescendantLabelImpact(
    int moveId,
    String? newLabel,
  ) {
    final subtree = getSubtree(moveId);
    final result = <LabelImpactEntry>[];

    for (final descendant in subtree) {
      // Skip the node itself — only report descendants.
      if (descendant.id == moveId) continue;
      // Skip descendants without their own label.
      if (descendant.label == null) continue;

      final before = getAggregateDisplayName(descendant.id);
      final after = _previewDescendantDisplayName(
        descendant.id,
        moveId,
        newLabel,
      );

      if (before != after) {
        result.add(LabelImpactEntry(
          moveId: descendant.id,
          before: before,
          after: after,
        ));
      }
    }

    return result;
  }

  /// Computes what the aggregate display name of [descendantMoveId] would be
  /// if [changedMoveId]'s label were set to [newLabel].
  String _previewDescendantDisplayName(
    int descendantMoveId,
    int changedMoveId,
    String? newLabel,
  ) {
    final line = getLine(descendantMoveId);
    final labels = <String>[];
    for (final m in line) {
      if (m.id == changedMoveId) {
        if (newLabel != null && newLabel.isNotEmpty) labels.add(newLabel);
      } else if (m.label != null) {
        labels.add(m.label!);
      }
    }
    return labels.join(' \u2014 ');
  }
}
