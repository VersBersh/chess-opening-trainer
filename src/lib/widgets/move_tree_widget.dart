import 'package:flutter/material.dart';

import '../models/repertoire.dart';
import '../repositories/local/database.dart';

// ---------------------------------------------------------------------------
// Visible node model
// ---------------------------------------------------------------------------

/// A flattened representation of a tree node for rendering in a list.
class VisibleNode {
  final RepertoireMove move;
  final int depth;
  final bool hasChildren;

  /// 1-based ply count, equal to tree depth + 1. Root moves are depth 0,
  /// ply 1.
  final int plyCount;

  const VisibleNode({
    required this.move,
    required this.depth,
    required this.hasChildren,
    required this.plyCount,
  });
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

  void walk(List<RepertoireMove> nodes, int depth) {
    for (final node in nodes) {
      // Review issue #3: call getChildren once per node instead of twice.
      final children = cache.getChildren(node.id);
      final hasChildren = children.isNotEmpty;
      final plyCount = depth + 1;
      result.add(VisibleNode(
        move: node,
        depth: depth,
        hasChildren: hasChildren,
        plyCount: plyCount,
      ));
      if (hasChildren && expanded.contains(node.id)) {
        walk(children, depth + 1);
      }
    }
  }

  walk(cache.getRootMoves(), 0);
  return result;
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
          isSelected: vn.move.id == selectedMoveId,
          dueCount: dueCountByMoveId[vn.move.id] ?? 0,
          isExpanded: expandedNodeIds.contains(vn.move.id),
          moveNotation: treeCache.getMoveNotation(
            vn.move.id,
            plyCount: vn.plyCount,
          ),
          onTap: () => onNodeSelected(vn.move.id),
          onToggleExpand: vn.hasChildren
              ? () => onNodeToggleExpand(vn.move.id)
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
  });

  final VisibleNode node;
  final bool isSelected;
  final int dueCount;
  final bool isExpanded;
  final String moveNotation;
  final VoidCallback onTap;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasLabel = node.move.label != null;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0 + node.depth * 24.0,
            right: 8.0,
            top: 4.0,
            bottom: 4.0,
          ),
          child: Row(
            children: [
              // Expand/collapse chevron
              if (node.hasChildren)
                GestureDetector(
                  onTap: onToggleExpand,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Icon(
                      isExpanded
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(width: 24),

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
                          text: node.move.label!,
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
    );
  }
}
