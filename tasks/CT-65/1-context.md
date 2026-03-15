# CT-65: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_tree_widget.dart` | Contains `VisibleNode` model, `buildVisibleNodes()`, `buildChainNotation()`, `MoveTreeWidget`, and `_MoveTreeNodeTile` -- the indentation formula at line 234-236 is the target of this change. |
| `src/test/widgets/move_tree_widget_test.dart` | Comprehensive unit tests for `buildVisibleNodes`/`buildChainNotation` and widget tests for `MoveTreeWidget`. New indentation cap tests will be added here. |
| `src/lib/models/repertoire.dart` | Defines `RepertoireTreeCache` (in-memory tree index) which provides `getChildren()`, `getRootMoves()`, etc. used by `buildVisibleNodes()`. Not modified in this task but essential context. |
| `features/repertoire-browser.md` | Feature spec for the repertoire browser. Describes compact rows (~28-32dp height), chain collapsing, expand/collapse, and tree visualization requirements. |
| `design/ui-guidelines.md` | Cross-cutting UI conventions. Relevant for spacing and layout constraints (e.g. minimal horizontal padding on mobile). |

## Architecture

### Move tree rendering subsystem

The move tree is rendered as a flat `ListView` of `_MoveTreeNodeTile` widgets. The pipeline works as follows:

1. **Data source:** `RepertoireTreeCache` holds the full repertoire move tree in memory, indexed by parent ID. It provides O(1) child lookups via `getChildren(moveId)`.

2. **Flattening:** `buildVisibleNodes(cache, expandedIds)` walks the tree depth-first, respecting expand/collapse state. It greedily collapses single-child unlabeled chains into one `VisibleNode`. Each `VisibleNode` carries a `depth` (int, 0-based) and a list of `moves`.

3. **Rendering:** `MoveTreeWidget.build()` calls `buildVisibleNodes()` and feeds the result to a `ListView.builder`. Each item becomes a `_MoveTreeNodeTile`.

4. **Indentation:** Inside `_MoveTreeNodeTile.build()`, the left padding is `8.0 + node.depth * 20.0`. This grows linearly with depth and has no upper bound. On a 360dp screen, the available content width at depth 6 is roughly `360 - 8 - 120 - 8 = 224dp`, and by depth 8 it drops to `184dp`, making text unreadable or pushing it off-screen.

### Key constraints

- The `VisibleNode.depth` field is an int set during tree walking; it reflects the tree's branching depth (not the ply count). Only branch points increment depth -- chain-collapsed linear sequences stay at the same depth.
- Rows are compact (minHeight 28dp) and contain a 28dp chevron area, an `Expanded` text area, an optional 28dp label icon, and an optional due-count badge.
- The indentation change must be purely visual (padding calculation). The `depth` field itself must remain accurate for tree semantics.
- Existing shallow trees (depth 0-4) must look identical after the change.
