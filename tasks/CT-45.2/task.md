---
id: CT-45.2
title: Chain collapsing for single-child sequences
epic: CT-45
depends: [CT-45.1]
specs:
  - features/repertoire-browser.md
files:
  - src/lib/widgets/move_tree_widget.dart
  - src/test/widgets/move_tree_widget_test.dart
---
# CT-45.2: Chain collapsing for single-child sequences

**Epic:** CT-45
**Depends on:** CT-45.1

## Description

Collapse single-child sequences in the move tree into one row. When a node has exactly one unlabeled child, absorb the child into the same row. Continue until a branch point (2+ children), leaf (0 children), or labeled node is reached. Display the full chain as compact notation (e.g., "1...c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4").

## Acceptance Criteria

- [ ] `VisibleNode` holds a `List<RepertoireMove> moves` instead of a single `move`
- [ ] `buildVisibleNodes()` collapses single-child unlabeled sequences into one `VisibleNode`
- [ ] Chains stop before labeled children (labeled nodes always get their own row)
- [ ] A new `buildChainNotation()` function produces compact multi-move notation
- [ ] Tapping a chain row selects the **last** (tail) move
- [ ] The expand chevron controls the **tail** node's children
- [ ] A chain row highlights when **any** move in the chain is the selected move
- [ ] Label icon edits the **first** move's label
- [ ] Existing tests updated; new chain-specific unit and widget tests added
- [ ] All tests pass

## Context

All changes are in `src/lib/widgets/move_tree_widget.dart`. No changes to the controller, tree cache, or data models.

### 1. Data model change: `VisibleNode` (lines 11-26)

Current:
```dart
class VisibleNode {
  final RepertoireMove move;
  final int depth;
  final bool hasChildren;
  final int plyCount;
}
```

New:
```dart
class VisibleNode {
  final List<RepertoireMove> moves; // 1+ moves in the chain
  final int depth;
  final bool hasChildren; // whether LAST move has children
  final int plyCount;     // ply of the FIRST move

  RepertoireMove get firstMove => moves.first;
  RepertoireMove get lastMove => moves.last;
}
```

### 2. Updated `buildVisibleNodes()` (lines 37-63)

Current algorithm emits one `VisibleNode` per move. New algorithm:

```
walk(nodes, depth):
  for each node in nodes:
    chain = [node]
    current = node
    while current has exactly 1 child:
      child = that single child
      if child has a label: break   // labeled nodes get their own row
      chain.append(child)
      current = child

    tailChildren = cache.getChildren(current.id)
    emit VisibleNode(
      moves: chain,
      depth: depth,
      hasChildren: tailChildren.isNotEmpty,
      plyCount: depth + 1,
    )

    if tailChildren.isNotEmpty AND expanded.contains(current.id):
      walk(tailChildren, depth + 1)
```

Key rules:
- Only unlabeled single-child nodes are absorbed into the chain.
- Expand/collapse keys on `current.id` (the tail move's ID).
- Children of the tail appear at `depth + 1`.

### 3. New `buildChainNotation()` function

Add near `buildVisibleNodes()`. For a single-move chain, delegate to `cache.getMoveNotation()`. For multi-move chains, build compact notation:

- White moves: `"N. san"` (number + dot + space + san)
- Black moves after a white move: just `"san"` (no number prefix)
- Black moves standalone (first in chain or after a gap): `"N...san"`

Use `plyCount` of the first move and increment for each subsequent move in the chain.

Reference: `RepertoireTreeCache.getMoveNotation()` at `src/lib/models/repertoire.dart` lines 161-167.

### 4. Tile display updates in `MoveTreeWidget.build()` (lines 106-138)

| Property | Current | New |
|----------|---------|-----|
| `isSelected` | `vn.move.id == selectedMoveId` | `vn.moves.any((m) => m.id == selectedMoveId)` |
| `isExpanded` | `expandedNodeIds.contains(vn.move.id)` | `expandedNodeIds.contains(vn.lastMove.id)` |
| `moveNotation` | `treeCache.getMoveNotation(vn.move.id, plyCount: vn.plyCount)` | `buildChainNotation(vn, treeCache)` |
| `onTap` | `onNodeSelected(vn.move.id)` | `onNodeSelected(vn.lastMove.id)` |
| `onToggleExpand` | `onNodeToggleExpand(vn.move.id)` | `onNodeToggleExpand(vn.lastMove.id)` |
| `onEditLabel` | `onEditLabel!(vn.move.id)` | `onEditLabel!(vn.firstMove.id)` |
| Label display | `node.move.label` | `node.firstMove.label` |
| `dueCount` | `dueCountByMoveId[vn.move.id]` | First move in chain with a due count |

### 5. Tests (`src/test/widgets/move_tree_widget_test.dart`)

**Unit tests for `buildVisibleNodes`:**
- Update existing: `VisibleNode.move` references become `VisibleNode.firstMove` / check `moves` list
- Add: single-child chain collapses into one `VisibleNode` with multiple moves
- Add: chain stops at branch point (2+ children)
- Add: chain stops before labeled child
- Add: entire linear tree produces one `VisibleNode`
- Add: mixed tree with branches and chains

**Widget tests:**
- Update: some previously separate row texts are now combined
- Add: collapsed chain shows combined notation
- Add: tapping chain selects last move
- Add: chevron on chain toggles last move's expansion

## Notes

- No changes to `repertoire_browser_controller.dart` — `_computeInitialExpandState` (lines 149-166) already expands all unlabeled interior nodes, which aligns with chain tail nodes being in the expanded set.
- No changes to `browser_content.dart` or `repertoire.dart`.
- `RepertoireTreeCache.getChildren()` (line ~129) and `getMoveNotation()` (line 161) are used but not modified.
