# CT-2.1 Plan

## Goal

Build a read-only repertoire browser screen with an expandable move tree, board preview synced to the selected node, aggregate display name header, and stub entry points for edit mode, labeling, deletion, and focus mode.

## Steps

### 1. Add `getAggregateDisplayName` helper to `RepertoireTreeCache`

**File:** `src/lib/models/repertoire.dart`

Add a method to `RepertoireTreeCache`:

```dart
String getAggregateDisplayName(int moveId) {
  final line = getLine(moveId);
  final labels = line.where((m) => m.label != null).map((m) => m.label!);
  return labels.join(' \u2014 ');
}
```

This walks root-to-node and concatenates all labels with " -- " separator. Returns an empty string if no labels exist along the path.

Also add a convenience method to compute the move number string for a node:

```dart
String getMoveNotation(int moveId) {
  final line = getLine(moveId);
  final index = line.length; // 1-based ply count
  final moveNumber = (index + 1) ~/ 2;
  final isBlack = index.isEven;
  if (isBlack) return '$moveNumber...${movesById[moveId]!.san}';
  return '$moveNumber. ${movesById[moveId]!.san}';
}
```

**Depends on:** Nothing (existing file).

### 2. Create `RepertoireBrowserState` model class

**File:** `src/lib/screens/repertoire_browser_screen.dart` (inline, or in a separate state file if complexity warrants)

Define the state that the browser screen manages:

```dart
class RepertoireBrowserState {
  final RepertoireTreeCache treeCache;
  final Set<int> expandedNodeIds;      // IDs of expanded nodes
  final int? selectedMoveId;           // currently selected node
  final Side boardOrientation;         // default Side.white
  final Map<int, int> dueCountByMoveId; // subtree due counts for labeled nodes
  final bool isLoading;
}
```

This is a plain data class. The screen widget (a `StatefulWidget`) owns and mutates this state. (When Riverpod is adopted per the state-management spec, this becomes the state of an `AsyncNotifier`. For now, follow the existing `HomeScreen` pattern of `StatefulWidget` + `setState`.)

**Depends on:** Nothing.

### 3. Create `MoveTreeWidget`

**File:** `src/lib/widgets/move_tree_widget.dart`

A `StatelessWidget` that renders the move tree as a scrollable list of nodes. It does not own state -- it receives everything from the parent screen.

**Constructor parameters:**
- `RepertoireTreeCache treeCache` -- the tree data
- `Set<int> expandedNodeIds` -- which nodes are expanded
- `int? selectedMoveId` -- the currently selected node
- `Map<int, int> dueCountByMoveId` -- due-card counts for badge display
- `void Function(int moveId) onNodeSelected` -- callback when a node is tapped
- `void Function(int moveId) onNodeToggleExpand` -- callback when expand/collapse indicator is tapped

**Rendering approach:**

Build a flat list of visible nodes by walking the tree depth-first, only descending into expanded nodes. Each visible node is a `MoveTreeNodeTile` (a private widget or inline builder within `MoveTreeWidget`).

For each visible node:
- Indent by depth level (padding proportional to depth).
- Show move number + SAN (e.g., "1. e4", "1...c5"). Compute from ply position in tree via `treeCache.getLine(moveId).length`.
- If the node has a non-null `label`, display it prominently (bold, distinct background or icon).
- If the node has children, show an expand/collapse chevron icon. Tapping the chevron calls `onNodeToggleExpand`.
- If `dueCountByMoveId` has an entry for this node and it is > 0, show a badge (e.g., "12 due").
- If the node is selected (`selectedMoveId == node.id`), highlight with a distinct background color.
- Tapping the node (not the chevron) calls `onNodeSelected`.

**Flat list construction helper** (private method):

```dart
List<_VisibleNode> _buildVisibleNodes(RepertoireTreeCache cache, Set<int> expanded) {
  final result = <_VisibleNode>[];
  void walk(List<RepertoireMove> nodes, int depth) {
    for (final node in nodes) {
      final hasChildren = cache.getChildren(node.id).isNotEmpty;
      result.add(_VisibleNode(move: node, depth: depth, hasChildren: hasChildren));
      if (hasChildren && expanded.contains(node.id)) {
        walk(cache.getChildren(node.id), depth + 1);
      }
    }
  }
  walk(cache.getRootMoves(), 0);
  return result;
}
```

Use `ListView.builder` with the flat list for efficient rendering of large trees.

**Depends on:** Step 1 (for display name / move notation helpers).

### 4. Create `RepertoireBrowserScreen`

**File:** `src/lib/screens/repertoire_browser_screen.dart`

A `StatefulWidget` that is the main browser screen. Receives `AppDatabase` and `int repertoireId` as constructor parameters (following the existing `HomeScreen` pattern).

**Layout (portrait, stacked):**
- `AppBar` with the repertoire name as title.
- Below the app bar, a `Column` containing:
  1. **Aggregate display name header / breadcrumb** -- shows the aggregate display name for the selected node (or empty if no node selected / no labels). Uses `treeCache.getAggregateDisplayName(selectedMoveId)`.
  2. **ChessboardWidget** -- read-only board preview. Uses `PlayerSide.none` to prevent interaction. Wrapped in an `AspectRatio(aspectRatio: 1)` or constrained box to keep the board square and not too large. A flip button below or overlaid allows toggling `boardOrientation`.
  3. **Action bar** -- a row of buttons for actions on the selected node. For CT-2.1, these are stubs:
     - "Edit" button (disabled, placeholder for CT-2.2)
     - "Label" button (disabled, placeholder for CT-2.3)
     - "Focus" button (enabled only when selected node has a label, placeholder for CT-4)
     - "Delete" button (enabled only when selected node is a leaf, placeholder for CT-2.4)
  4. **MoveTreeWidget** -- in an `Expanded` widget to fill remaining vertical space.

**State management in `initState`:**
1. Load the repertoire name via `RepertoireRepository.getRepertoire(repertoireId)`.
2. Load all moves via `RepertoireRepository.getMovesForRepertoire(repertoireId)`.
3. Build `RepertoireTreeCache.build(moves)`.
4. Compute initial expand state: expand nodes down to the first level of labeled nodes. Walk the tree breadth-first from roots; expand each node until a labeled node is found on that branch, then stop expanding that branch.
5. Load due-card counts: for each labeled node in the tree, call `ReviewRepository.getCardsForSubtree(nodeId, dueOnly: true)` and store `{nodeId: cards.length}`. (Optimization: could compute this from a single `getAllCardsForRepertoire` call + tree walk, but per-node queries are simpler for v1.)
6. Set `isLoading = false` and trigger `setState`.

**Node selection handler (`_onNodeSelected`):**
- Set `selectedMoveId` to the tapped node's ID.
- Update the `ChessboardController` via `controller.setPosition(node.fen)`.
- Trigger `setState`.

**Expand/collapse handler (`_onNodeToggleExpand`):**
- Toggle the node's ID in the `expandedNodeIds` set.
- Trigger `setState`.

**Board flip handler:**
- Toggle `boardOrientation` between `Side.white` and `Side.black`.
- Trigger `setState`.

**Forward / Back navigation:**
- "Back" button: if the selected node has a parent, select the parent.
- "Forward" button: if the selected node has exactly one child, select that child. If multiple children, expand the node (but don't auto-select).
- These buttons sit adjacent to the board (below or as overlay controls).

**Depends on:** Steps 1, 2, 3.

### 5. Wire navigation from `HomeScreen` to `RepertoireBrowserScreen`

**File:** `src/lib/screens/home_screen.dart`

Update the "Repertoire" button's `onPressed` to navigate to the browser screen. For now, this requires a repertoire to exist. Options:
- If repertoires exist, navigate to the first (or show a selection list).
- If no repertoires exist, show a prompt or create a default one.

For v1 simplicity, add a simple flow:
1. On "Repertoire" tap, load `getAllRepertoires()`.
2. If none exist, create a default repertoire ("My Repertoire") and navigate to it.
3. If one exists, navigate directly.
4. If multiple exist, show a simple selection dialog (or just navigate to the first).

```dart
onPressed: () async {
  final repo = LocalRepertoireRepository(widget.db);
  var repertoires = await repo.getAllRepertoires();
  if (repertoires.isEmpty) {
    await repo.saveRepertoire(RepertoiresCompanion.insert(name: 'My Repertoire'));
    repertoires = await repo.getAllRepertoires();
  }
  if (mounted) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RepertoireBrowserScreen(db: widget.db, repertoireId: repertoires.first.id),
    ));
  }
}
```

**Depends on:** Step 4.

### 6. Write unit tests for `getAggregateDisplayName` and `getMoveNotation`

**File:** `src/test/models/repertoire_tree_cache_test.dart`

Test the new `RepertoireTreeCache` methods using hand-constructed `RepertoireMove` objects (following the pattern in `drill_engine_test.dart`).

**Test cases:**
- `getAggregateDisplayName` for a node with no labels along its path returns empty string.
- `getAggregateDisplayName` for a node with one label returns that label.
- `getAggregateDisplayName` for a node with multiple labels along path returns them joined with " -- ".
- `getAggregateDisplayName` only includes labels on the root-to-node path, not labels on sibling branches.
- `getMoveNotation` for first move (ply 1) returns "1. e4" format.
- `getMoveNotation` for second move (ply 2) returns "1...c5" format.
- `getMoveNotation` for later moves computes correct move number.

**Depends on:** Step 1.

### 7. Write unit tests for `MoveTreeWidget` visible node construction

**File:** `src/test/widgets/move_tree_widget_test.dart`

Test the flat-list construction logic. If `_buildVisibleNodes` is extracted as a top-level or static function for testability:

**Test cases:**
- Empty tree produces empty visible node list.
- Single root move produces one visible node at depth 0.
- Root with children, all collapsed: only root visible.
- Root with children, root expanded: root and children visible at correct depths.
- Deeply nested tree with selective expansion: only expanded subtrees visible.
- Multiple root moves are all visible at depth 0.

Also write widget tests (using `flutter_test`):
- Tree renders correct number of tiles for a given tree + expand state.
- Tapping a node calls `onNodeSelected` with the correct move ID.
- Tapping the expand chevron calls `onNodeToggleExpand` with the correct move ID.
- Selected node has distinct visual styling.
- Labeled nodes have distinct visual styling (bold text or icon present).

**Depends on:** Step 3.

### 8. Write widget tests for `RepertoireBrowserScreen`

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

These tests require mocking the database or repositories. Following the existing pattern, either use an in-memory Drift database or mock repositories.

**Test cases:**
- Screen shows loading indicator while data loads, then shows tree and board.
- Selecting a node updates the board position (verify board FEN changes).
- Aggregate display name header updates when selecting a labeled node.
- Aggregate display name is empty when selecting an unlabeled node with no labeled ancestors.
- Expand/collapse toggles child visibility in the tree.
- Board flip button changes board orientation.
- Forward/back navigation: back selects parent node, forward selects only child.
- Forward at a branch point expands the node instead of selecting a child.
- Action buttons enabled/disabled state: "Focus" enabled only for labeled nodes, "Delete" enabled only for leaf nodes.
- Empty repertoire (no moves) shows an appropriate empty state.

**Depends on:** Steps 4, 5.

## Risks / Open Questions

1. **Riverpod adoption timing.** The state-management spec mandates Riverpod, but the existing codebase (`HomeScreen`, `main.dart`) does not use it yet. This plan follows the existing `StatefulWidget` pattern for consistency. If Riverpod is adopted before or during CT-2.1 implementation, the browser screen should use an `AsyncNotifier` instead of `StatefulWidget` + `setState`. The plan's logical structure (state class, load-on-entry, handler methods) maps directly to either approach.

2. **Tree widget vs. move-list layout.** The spec notes this is the "biggest UI decision in the app" (Key Decision #1). This plan implements a tree widget (file-explorer style with indentation and expand/collapse). An alternative move-list layout (lichess analysis-board style) could be explored later. The tree approach is more explicit about branching, which is important for repertoire management. The `MoveTreeWidget` is a self-contained widget that could be swapped out without changing the screen.

3. **Mobile layout.** The plan uses a stacked portrait layout (board on top, tree below). This gives limited vertical space to the tree. The spec lists several alternatives (side-by-side, swipeable panels, collapsible board). For v1, the stacked layout is simplest. The board can be given a constrained max height (e.g., 40% of screen height or a fixed max of 300px) to leave room for the tree. This can be refined based on user feedback.

4. **Due-card count performance.** Computing due counts per labeled node requires one `getCardsForSubtree` call per labeled node. For a tree with many labeled nodes, this could mean many recursive CTE queries. An optimization would be to load all cards for the repertoire once (`getAllCardsForRepertoire`) and compute counts in memory using the tree cache's `getSubtree`. This optimization should be implemented if performance is noticeable, but the simpler per-node approach is correct and acceptable for v1.

5. **Initial expand state.** The spec says "collapsed to the first level of labeled nodes." This means: start from roots, expand each node until a labeled descendant is reached, then stop. If no nodes are labeled, show only root-level nodes (fully collapsed). The implementation of this breadth-first walk needs care to avoid expanding the entire tree when labels are sparse. If a branch has no labeled nodes at all, it should remain collapsed at the root.

6. **Action button stubs.** CT-2.1 creates the UI hooks (buttons) for edit mode, labeling, deletion, and focus mode, but does not implement the actions themselves. The buttons should be present but either disabled or show a "coming soon" toast. The actual action handlers will be wired in CT-2.2, CT-2.3, CT-2.4, and CT-4 respectively. This means those tasks will modify `repertoire_browser_screen.dart` to add real `onPressed` handlers.

7. **Line list view.** The spec describes a flat line-list view as an alternative to the tree view, toggled via a tab or segmented control. This plan defers the line list view -- it is described as a convenience for small repertoires and "could be deferred to a later phase if the tree view alone is sufficient." If it is needed, it can be added as a separate widget within the same screen, toggled by a tab bar.

8. **Board animation on node selection.** The spec says "the board animates the transition between positions when stepping forward/back through a line." Chessground provides built-in animation when the FEN changes, so this should work automatically via `controller.setPosition(newFen)`. However, the animation quality depends on chessground recognizing that only one piece moved. When jumping between non-adjacent positions (e.g., selecting a node far from the currently selected one), the animation may look chaotic. This is acceptable for v1 -- animation is a polish concern.

9. **Keyboard/gesture navigation.** The spec describes swipe gestures on mobile and dedicated forward/back buttons. For v1, implement only the forward/back buttons. Swipe gesture support can be added later with a `GestureDetector` wrapping the board widget.
