import 'package:flutter/material.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';

// ---------------------------------------------------------------------------
// Visible node model
// ---------------------------------------------------------------------------

/// A flattened representation of a tree node for rendering in a list.
///
/// A single `VisibleNode` may represent a chain of consecutive single-child
/// unlabeled moves collapsed into one row. [moves] always has at least one
/// element.
class VisibleNode {
  final List<RepertoireMove> moves;
  final int depth;
  final bool hasChildren;

  /// 1-based ply count of the **first** move. Root moves have plyCount 1.
  /// For children of a chain, plyCount accounts for absorbed moves in the
  /// parent chain (not simply depth + 1).
  final int plyCount;

  const VisibleNode({
    required this.moves,
    required this.depth,
    required this.hasChildren,
    required this.plyCount,
  }) : assert(moves.length > 0);

  RepertoireMove get firstMove => moves.first;
  RepertoireMove get lastMove => moves.last;
}

// ---------------------------------------------------------------------------
// Visible node construction (top-level for testability -- review issue #9)
// ---------------------------------------------------------------------------

/// Builds a flat list of visible nodes by walking the tree depth-first,
/// only descending into expanded nodes.
///
/// Extracted as a top-level function so it can be unit-tested without widget
/// infrastructure.
List<VisibleNode> buildVisibleNodes(
  RepertoireTreeCache cache,
  Set<int> expanded,
) {
  final result = <VisibleNode>[];

  void walk(List<RepertoireMove> nodes, int depth, int plyBase) {
    for (final node in nodes) {
      // Greedily absorb single-child unlabeled successors into a chain.
      final chain = <RepertoireMove>[node];
      var current = node;
      var tailChildren = cache.getChildren(current.id);

      while (tailChildren.length == 1) {
        final child = tailChildren[0];
        if (child.label != null) break; // labeled nodes always get own row
        chain.add(child);
        current = child;
        tailChildren = cache.getChildren(current.id);
      }

      result.add(VisibleNode(
        moves: chain,
        depth: depth,
        hasChildren: tailChildren.isNotEmpty,
        plyCount: plyBase,
      ));
      if (tailChildren.isNotEmpty && expanded.contains(current.id)) {
        walk(tailChildren, depth + 1, plyBase + chain.length);
      }
    }
  }

  walk(cache.getRootMoves(), 0, 1);
  return result;
}

// ---------------------------------------------------------------------------
// Chain notation
// ---------------------------------------------------------------------------

/// Builds compact multi-move notation for a [VisibleNode].
///
/// For single-move nodes, delegates to [cache.getMoveNotation]. For chains,
/// inlines the same notation rules: white moves get `"N. san"`, black moves
/// after a white move in the same chain get just `"san"`, and black moves at
/// the start of a chain (or after another black move) get `"N...san"`.
String buildChainNotation(VisibleNode node, RepertoireTreeCache cache) {
  if (node.moves.length == 1) {
    return cache.getMoveNotation(node.firstMove.id, plyCount: node.plyCount);
  }

  final buffer = StringBuffer();
  for (var i = 0; i < node.moves.length; i++) {
    final ply = node.plyCount + i;
    final moveNumber = (ply + 1) ~/ 2;
    final isBlack = ply.isEven;
    final san = node.moves[i].san;

    if (i > 0) buffer.write(' ');

    if (isBlack) {
      final prevPly = node.plyCount + i - 1;
      final prevIsBlack = prevPly.isEven;
      if (i == 0 || prevIsBlack) {
        buffer.write('$moveNumber...$san');
      } else {
        buffer.write(san);
      }
    } else {
      buffer.write('$moveNumber. $san');
    }
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// MoveTreeWidget
// ---------------------------------------------------------------------------

/// A stateless widget that renders the move tree as a scrollable list of nodes.
///
/// Does not own state -- receives everything from the parent screen.
class MoveTreeWidget extends StatelessWidget {
  const MoveTreeWidget({
    super.key,
    required this.treeCache,
    required this.expandedNodeIds,
    this.selectedMoveId,
    this.dueCountByMoveId = const {},
    required this.onNodeSelected,
    required this.onNodeToggleExpand,
    this.onEditLabel,
  });

  /// The tree data.
  final RepertoireTreeCache treeCache;

  /// Which nodes are expanded.
  final Set<int> expandedNodeIds;

  /// The currently selected node.
  final int? selectedMoveId;

  /// Due-card counts for badge display.
  final Map<int, int> dueCountByMoveId;

  /// Callback when a node is tapped.
  final void Function(int moveId) onNodeSelected;

  /// Callback when expand/collapse indicator is tapped.
  final void Function(int moveId) onNodeToggleExpand;

  /// Callback when the inline label icon is tapped on a node.
  final void Function(int moveId)? onEditLabel;

  @override
  Widget build(BuildContext context) {
    final visibleNodes = buildVisibleNodes(treeCache, expandedNodeIds);

    if (visibleNodes.isEmpty) {
      return const Center(
        child: Text('No moves yet. Add a line to get started.'),
      );
    }

    return ListView.builder(
      itemCount: visibleNodes.length,
      itemBuilder: (context, index) {
        final vn = visibleNodes[index];
        return _MoveTreeNodeTile(
          node: vn,
          isSelected: vn.moves.any((m) => m.id == selectedMoveId),
          dueCount: vn.moves
              .map((m) => dueCountByMoveId[m.id] ?? 0)
              .firstWhere((c) => c > 0, orElse: () => 0),
          isExpanded: expandedNodeIds.contains(vn.lastMove.id),
          moveNotation: buildChainNotation(vn, treeCache),
          onTap: () => onNodeSelected(vn.lastMove.id),
          onToggleExpand: vn.hasChildren
              ? () => onNodeToggleExpand(vn.lastMove.id)
              : null,
          onEditLabel: onEditLabel != null
              ? () => onEditLabel!(vn.firstMove.id)
              : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Node tile
// ---------------------------------------------------------------------------

class _MoveTreeNodeTile extends StatelessWidget {
  const _MoveTreeNodeTile({
    required this.node,
    required this.isSelected,
    required this.dueCount,
    required this.isExpanded,
    required this.moveNotation,
    required this.onTap,
    this.onToggleExpand,
    this.onEditLabel,
  });

  final VisibleNode node;
  final bool isSelected;
  final int dueCount;
  final bool isExpanded;
  final String moveNotation;
  final VoidCallback onTap;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onEditLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasLabel = node.firstMove.label != null;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: 8.0 + node.depth * 20.0,
            right: 8.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 28,
            ),
            child: Row(
              children: [
              // Expand/collapse chevron
              if (node.hasChildren)
                GestureDetector(
                  onTap: onToggleExpand,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Icon(
                        isExpanded
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 28),

              // Move notation
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: moveNotation,
                        style: TextStyle(
                          fontWeight: hasLabel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (hasLabel) ...[
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: node.firstMove.label!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Inline label icon
              if (onEditLabel != null)
                GestureDetector(
                  onTap: onEditLabel,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Tooltip(
                        message: 'Label',
                        child: Icon(
                          Icons.label_outline,
                          size: 14,
                          color: hasLabel
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),

              // Due count badge
              if (dueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$dueCount due',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
