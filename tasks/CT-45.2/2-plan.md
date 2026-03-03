# CT-45.2: Plan

## Goal

Collapse single-child unlabeled sequences in the move tree into single `VisibleNode` rows, displaying compact multi-move notation and routing interactions to the appropriate head/tail move.

## Steps

### 1. Change `VisibleNode` data model from single move to move list

File: `src/lib/widgets/move_tree_widget.dart` (lines 11-26)

Replace the `move` field with a `moves` list and add convenience getters:

```dart
class VisibleNode {
  final List<RepertoireMove> moves;
  final int depth;
  final bool hasChildren;
  final int plyCount;

  const VisibleNode({
    required this.moves,
    required this.depth,
    required this.hasChildren,
    required this.plyCount,
  });

  RepertoireMove get firstMove => moves.first;
  RepertoireMove get lastMove => moves.last;
}
```

- `moves` always has at least one element (single-move "chain" for branch points, leaves, or labeled nodes).
- `hasChildren` refers to the **last** move's children.
- `plyCount` is the ply of the **first** move (depth + 1).

No dependencies on other steps.

### 2. Update `buildVisibleNodes()` to collapse chains

File: `src/lib/widgets/move_tree_widget.dart` (lines 37-63)

Modify the inner `walk()` function. For each node, greedily absorb subsequent single-child unlabeled nodes into a chain:

```
walk(nodes, depth):
  for each node in nodes:
    chain = [node]
    current = node
    while true:
      children = cache.getChildren(current.id)
      if children.length != 1: break
      child = children[0]
      if child.label != null: break   // labeled nodes always get own row
      chain.add(child)
      current = child

    tailChildren = cache.getChildren(current.id)
    emit VisibleNode(
      moves: chain,
      depth: depth,
      hasChildren: tailChildren.isNotEmpty,
      plyCount: depth + 1,
    )

    if tailChildren.isNotEmpty && expanded.contains(current.id):
      walk(tailChildren, depth + 1)
```

Key behaviors:
- The first node in the chain may have a label (it is the entry point for that row). Only **children** with labels cause the chain to stop.
- `expanded.contains()` checks use `current.id` (the tail), which aligns with the controller's `_computeInitialExpandState()` that already expands unlabeled interior nodes.
- Children of the tail are walked at `depth + 1`, same as before.
- Note: The initial `getChildren` call for branching detection moves inside the while-loop. The call at the top of the for-loop (current line 46) is no longer needed as a separate step -- the loop handles it. However, we still need a final `getChildren(current.id)` after the loop exits to determine `hasChildren` and get the tail's children for recursion. Since the while-loop's last iteration already called `getChildren(current.id)` and broke because `children.length != 1`, we can reuse that value. Implementation detail: store the last `children` result from the loop.

Depends on: Step 1 (VisibleNode constructor change).

### 3. Add `buildChainNotation()` function

File: `src/lib/widgets/move_tree_widget.dart` (add near `buildVisibleNodes`, around line 64)

Create a top-level function for testability:

```dart
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
      // Black move: needs number prefix if it's the first in the chain
      // or if the previous move was also black (shouldn't happen in chess,
      // but defensive). If previous was white, just append SAN.
      final prevPly = node.plyCount + i - 1;
      final prevIsBlack = prevPly.isEven;
      if (i == 0 || prevIsBlack) {
        buffer.write('$moveNumber...$san');
      } else {
        buffer.write(san);
      }
    } else {
      // White move: always has number prefix
      buffer.write('$moveNumber. $san');
    }
  }
  return buffer.toString();
}
```

Notation rules (matching `getMoveNotation` logic):
- `ply` is 1-based. Odd ply = white, even ply = black.
- `moveNumber = (ply + 1) ~/ 2`.
- White moves: `"N. san"` (always with number).
- Black moves after a white move in the same chain: just `"san"` (compact).
- Black moves at the start of a chain or after another black move: `"N...san"` (with number for clarity).

No dependencies on other steps, but uses `VisibleNode` from Step 1.

### 4. Update `MoveTreeWidget.build()` tile construction

File: `src/lib/widgets/move_tree_widget.dart` (lines 106-138)

Update the `itemBuilder` closure to use the new `VisibleNode` API:

| Property | Current code | New code |
|----------|-------------|----------|
| `isSelected` | `vn.move.id == selectedMoveId` | `vn.moves.any((m) => m.id == selectedMoveId)` |
| `dueCount` | `dueCountByMoveId[vn.move.id] ?? 0` | `vn.moves.map((m) => dueCountByMoveId[m.id] ?? 0).firstWhere((c) => c > 0, orElse: () => 0)` — use "first non-zero in chain order" as specified in the task acceptance criteria |
| `isExpanded` | `expandedNodeIds.contains(vn.move.id)` | `expandedNodeIds.contains(vn.lastMove.id)` |
| `moveNotation` | `treeCache.getMoveNotation(vn.move.id, plyCount: vn.plyCount)` | `buildChainNotation(vn, treeCache)` |
| `onTap` | `onNodeSelected(vn.move.id)` | `onNodeSelected(vn.lastMove.id)` |
| `onToggleExpand` | `onNodeToggleExpand(vn.move.id)` | `onNodeToggleExpand(vn.lastMove.id)` |
| `onEditLabel` | `onEditLabel!(vn.move.id)` | `onEditLabel!(vn.firstMove.id)` |

Depends on: Steps 1, 2, 3.

### 5. Update `_MoveTreeNodeTile` label reference

File: `src/lib/widgets/move_tree_widget.dart` (line 170)

Change:
```dart
final hasLabel = node.move.label != null;
```
To:
```dart
final hasLabel = node.firstMove.label != null;
```

And update the label text span (lines 228-239) to reference `node.firstMove.label` instead of `node.move.label`:
```dart
if (hasLabel) ...[
  const TextSpan(text: '  '),
  TextSpan(
    text: node.firstMove.label!,
    // ... style unchanged
  ),
],
```

Depends on: Step 1.

### 6. Update existing unit tests for `buildVisibleNodes`

File: `src/test/widgets/move_tree_widget_test.dart`

Update all references from `result[n].move.san` to `result[n].firstMove.san` (or verify `.moves` list). Affected tests:

- **"single root move produces one visible node at depth 0"** (line 117): `result[0].move.san` -> `result[0].firstMove.san`
- **"root with children, all collapsed: only root visible"** (line 130): `result[0].move.san` -> `result[0].firstMove.san`
- **"root with children, root expanded: root and child visible"** (lines 143-148): update `.move.san` references. **Important:** this test creates a 3-move linear chain (`e4, e5, Nf3`) and expands only `{1}` (e4). With chain collapsing, `e4` has one unlabeled child `e5`, and `e5` has one unlabeled child `Nf3`. The entire sequence collapses into a single `VisibleNode` with `moves: [e4, e5, Nf3]`. The test currently expects 2 visible nodes; it will now expect 1 with 3 moves. Update assertions accordingly.
- **"deeply nested tree with selective expansion"** (lines 151-167): 5-move linear chain with selective expansion. Since all nodes are unlabeled single-child, the chain will collapse entirely when the tail is expanded. Update expected node count and move references.
- **"multiple root moves"** (lines 169-195): Two root moves, each a leaf -- no chain collapsing expected. Just update `.move.san` -> `.firstMove.san`.
- **"only expanded subtrees are visible"** (lines 197-221): `e4` has two children (`e5` and `c5`), so `e4` is a branch point and stays its own row. `e5` has child `Nf3` but is not expanded; `c5` is a leaf. Chain collapsing does not apply at the `e4` level (2 children). Update `.move.san` references.
- **"plyCount tracks line position"** (lines 223-236): Linear chain of 4 moves, all expanded. With chain collapsing, this becomes a single `VisibleNode` with 4 moves. The test must be rewritten to check the single node's plyCount (1) and moves list (4 entries).

Depends on: Steps 1, 2.

### 7. Update existing widget tests

File: `src/test/widgets/move_tree_widget_test.dart`

Several widget tests create linear sequences and may now render fewer rows:

- **"renders correct number of tiles"** (lines 271-287): Creates `[e4, e5, Nf3]` with `expandedNodeIds: {1}`. With chain collapsing, `e4` -> `e5` -> `Nf3` (all unlabeled single-child except Nf3 which is a leaf) collapses into one row. The test expects `1. e4` and `1...e5` as separate rows but they will now be combined. Update to expect the combined notation text and correct tile count.
- **"tapping a node calls onNodeSelected"** (lines 289-303): Creates `[e4, e5]` with `{1}` expanded. `e4` has one child `e5` which is a leaf -- chain collapses to `[e4, e5]` in one row. Tap on the combined text should call `onNodeSelected` with the **tail** ID (2). Update expected text and assertions.
- **"tapping the expand chevron"** (lines 306-321): Creates `[e4, e5, Nf3]` with no expansion. `e4` has one unlabeled child `e5`, which has one unlabeled child `Nf3`. All three collapse into one VisibleNode. The chain's tail is `Nf3` (id=3). The chevron should not appear because `Nf3` (the tail) has no children (`hasChildren: false`). This test needs restructuring -- create a tree with a branch point at the end of a chain so the chevron is visible.
- **"each row shows a label icon"** (lines 392-405): Creates `[e4, e5]` expanded. Will collapse to 1 row. Update expected icon count from 2 to 1.
- **"tapping the label icon calls onEditLabel"** (lines 420-440): Creates `[e4, e5]` expanded. Collapses to 1 row. Label icon tap should call `onEditLabel` with the **first** move's ID (1). Update assertions.
- **"tapping the row itself does not trigger onEditLabel"** (lines 442-462): Similar chain collapse, update text finder.
- Other tests (selected styling, labeled nodes, empty tree, due count, label icon colors, enlarged area taps) need review for chain effects.

Depends on: Steps 1-5.

### 8. Add new chain-specific unit tests for `buildVisibleNodes`

File: `src/test/widgets/move_tree_widget_test.dart`

Add to the `buildVisibleNodes` group:

- **"single-child chain collapses into one VisibleNode with multiple moves"**: Build `[e4, e5, Nf3]` (linear, no labels). Expand all. Expect 1 `VisibleNode` with `moves.length == 3`, `firstMove.san == 'e4'`, `lastMove.san == 'Nf3'`, `hasChildren == false`, `depth == 0`, `plyCount == 1`.
- **"chain stops at branch point"**: Build `[e4, e5]` main + `[e4, d5]` branch. Expand `e4`. Expect: `e4` alone (branch point, 2 children), then `e5` and `d5` as separate nodes. `e4.moves.length == 1`.
- **"chain stops before labeled child"**: Build `[e4, e5, Nf3]` with `labels: {1: 'Open Game'}` (e5 is labeled). Expand all. Expect: `e4` alone (its child `e5` is labeled, so chain stops), then `e5` with label (its child `Nf3` is unlabeled single-child, so `e5-Nf3` chain), as a chain of 2.
- **"entire linear tree produces one VisibleNode"**: Build `[e4, e5, Nf3, Nc6, Bb5]`. Expand all. Expect exactly 1 `VisibleNode` with `moves.length == 5`.
- **"mixed tree with branches and chains"**: Build a tree where `e4` has children `e5` and `c5`. `e5` continues linearly to `Nf3, Nc6`. `c5` continues linearly to `Nf3, d6`. Expand all. Expect: `e4` (branch, 1 move), `e5 Nf3 Nc6` chain (3 moves), `c5 Nf3 d6` chain (3 moves).

Depends on: Steps 1, 2.

### 9. Add new chain-specific widget tests

File: `src/test/widgets/move_tree_widget_test.dart`

Add to the `MoveTreeWidget` group:

- **"collapsed chain shows combined notation"**: Build a linear `[e4, e5, Nf3, Nc6]` tree, expand all. Expect a single row with text `"1. e4 e5 2. Nf3 Nc6"`.
- **"tapping chain row selects last move"**: Same tree. Tap the combined text. Expect `onNodeSelected` called with the tail move's ID.
- **"chain row highlights when any move in chain is selected"**: Build `[e4, e5, Nf3]`, expand all. Set `selectedMoveId` to the middle move (`e5`, id=2). Verify the chain row has the `primaryContainer` highlight.
- **"chevron on chain toggles last move's expansion"**: Build a tree where a chain ends at a branch point (e.g., `e4 -> e5 -> Nf3`, where `Nf3` has 2 children `Nc6` and `d4`). The chain is `[e4, e5, Nf3]` (Nf3 has 2+ children, chain stops). Chevron should toggle `Nf3`'s expansion (id=3). Tap the chevron, verify `onNodeToggleExpand` called with 3.
- **"label icon on chain edits first move's label"**: Build `[e4, e5]` chain with `onEditLabel`. Tap label icon. Verify `onEditLabel` called with first move's ID (1).
- **"dueCount shows first non-zero in chain order"**: Build a chain `[e4, e5, Nf3]` with `dueCountByMoveId` having a non-zero count on the middle move only. Verify the row displays the due count from the middle move.

Depends on: Steps 1-5.

### 10. Add unit tests for `buildChainNotation`

File: `src/test/widgets/move_tree_widget_test.dart`

Add a new `group('buildChainNotation', ...)`:

- **"single white move matches getMoveNotation output for single-move chains"**: Build a `VisibleNode` with one move at ply 1. Expect `"1. e4"`.
- **"single black move matches getMoveNotation output for single-move chains"**: Build a `VisibleNode` with one move at ply 2. Expect `"1...e5"`.
- **"multi-move chain starting with white"**: Moves `[e4, e5, Nf3, Nc6]` at ply 1. Expect `"1. e4 e5 2. Nf3 Nc6"`.
- **"multi-move chain starting with black"**: Moves `[c5, Nf3, d6]` at ply 2. Expect `"1...c5 2. Nf3 d6"`.
- **"chain with only one pair"**: Moves `[e4, e5]` at ply 1. Expect `"1. e4 e5"`.

Depends on: Steps 1, 3.

### 11. Update screen-level tests for collapsed chain rows

File: `src/test/screens/repertoire_browser_screen_test.dart`

Chain collapsing changes how many rows appear and what text is shown in screen-level tests. Since `_computeInitialExpandState()` auto-expands all unlabeled interior nodes, linear unlabeled sequences will render as combined rows (e.g., `"1. e4 e5"` instead of separate `"1. e4"` and `"1...e5"` rows). These tests must be explicitly updated:

**Tests affected by chain collapsing (linear unlabeled trees):**

- **"shows loading indicator then tree and board after load"** (line 164): Seeds `[e4, e5, Nf3]` with no labels. All three collapse into one row. The assertion `find.text('1. e4')` must change to `find.textContaining('1. e4')` or match the full combined notation `"1. e4 e5 2. Nf3"`.
- **"selecting a node updates the board position"** (line 191): Seeds `[e4, e5]`. Will collapse to one row `"1. e4 e5"`. The tap target `find.text('1...e5')` must change to tap the combined row and verify the board updates (tap selects the tail, which is e5).
- **"aggregate display name is empty for unlabeled node"** (line 237): Seeds `[e4, e5]`. Collapses to one row. The tap `find.text('1...e5')` must change.
- **"expand/collapse toggles child visibility"** (line 258): Seeds `[e4, e5, Nf3]`. Collapses to one row with no children (leaf tail), so no chevron. This test needs restructuring: use a tree that ends at a branch point, or use a labeled tree where individual rows are preserved and expand/collapse is still testable.
- **"back navigation selects parent node"** (line 315): Seeds `[e4, e5]`. Collapses to one row. Tap `find.text('1...e5')` must change.
- **"action buttons enabled/disabled state"** (line 370): Seeds `[e4, e5, Nf3]` with label on e4. e4 is labeled so it starts collapsed. When expanded, e5 has one unlabeled child Nf3, so `[e5, Nf3]` collapse into a chain. The taps on `find.text('2. Nf3')` must change to use the combined chain text or `find.textContaining(...)`.
- **"aggregate display name preview in inline editor"** (line 685): Seeds `[e4, c5, Nf3]` with label on e4. When e4 is expanded then c5 expanded, `[c5, Nf3]` collapse into a chain `"1...c5 2. Nf3"`. The tap `find.text('2. Nf3')` must change.
- **"label works on root, interior, and leaf nodes"** (line 755): Seeds `[e4, e5, Nf3]` no labels. All three collapse. After labeling e4 (making it its own row), e5+Nf3 collapse into a chain. Individual taps on `find.text('1...e5')` and `find.text('2. Nf3')` must be updated for the chained rendering.
- **"node selection updates board in wide layout"** (line 1970): Seeds `[e4, e5]`. Collapses to one row. The tap `find.text('1...e5')` must change.

**Tests NOT affected (branching trees or labeled nodes that prevent collapsing):**

- Tests that seed branching trees (e.g., `['e4', 'e5']` + `['e4', 'c5']`) where `e4` is a branch point: `e4` stays its own row, children are separate rows. These tests are unaffected.
- Tests that use `labelsOnSan` on root moves (e.g., `{'e4': 'King Pawn'}`): labeled e4 gets its own row. If its child is also labeled or a branch, no chaining occurs. These need case-by-case review but many are unaffected.

**Deletion group tests** (line 1233+): Many deletion tests build branching trees (e.g., `['e4', 'e5', 'Nf3']` + `['e4', 'e5', 'Bc4']`) where `e5` has 2 children. In these cases, `e4` has one child `e5` which has 2 children, so the chain is `[e4, e5]` (stops because e5 has 2 children). The row shows `"1. e4 e5"` instead of separate rows. Assertions like `find.text('1. e4')` and `find.text('1...e5')` must change to `find.textContaining('1. e4')` or match the combined text. Post-deletion, if a sibling is removed and the tree becomes linear, further collapsing may occur. Each deletion test must be carefully reviewed.

**Approach:** For each affected test, update `find.text(...)` matchers to match the new combined notation. Where tests tap on specific moves that are now part of a chain, tap the chain row instead (which selects the tail). Where tests need to select an interior chain move (not the tail), consider whether the test scenario still makes sense or if the tree structure needs adjustment (e.g., add a label or branch to prevent collapsing so the individual move is still its own row).

Depends on: Steps 1-5.

### 12. Run full test suite and verify

Run `flutter test` from `src/` to confirm all tests pass. Check:
- All existing tests (updated) pass.
- All new chain tests pass.
- No regressions in any test file.

Depends on: All previous steps.

## Risks / Open Questions

1. **`dueCount` aggregation for chains:** The task spec says "first move in chain with a due count." The plan uses "first non-zero in chain order" (`vn.moves.map((m) => dueCountByMoveId[m.id] ?? 0).firstWhere((c) => c > 0, orElse: () => 0)`). In practice, due counts are only assigned to labeled nodes or subtree roots by the controller, and chain members are unlabeled interior nodes that are unlikely to have individual due counts. The "first non-zero" approach matches the spec and is correct. A new widget test in Step 9 locks this behavior.

2. **Screen-level test breakage:** Tests in `repertoire_browser_screen_test.dart` are explicitly addressed in Step 11. This is a mandatory step, not an optional check-during-run item. The step catalogs specific tests affected by chain collapsing and the required updates for each.

3. **Expand state edge case -- chain tail is a leaf:** If a chain reaches a leaf node (0 children), `hasChildren` is false, no chevron is shown, and `expanded.contains(tail.id)` is irrelevant. This is correct behavior.

4. **Chain of length 1 at a branch point:** A node with 2+ children cannot be absorbed into a predecessor's chain. It forms its own single-move `VisibleNode` with `moves.length == 1`. The `buildChainNotation` function correctly delegates to `getMoveNotation` for single-move nodes, producing identical output to the current behavior. No visual change for non-chain rows.

5. **Performance:** The chain-building loop calls `cache.getChildren()` once per node in the chain (O(1) hash lookup). Total work is O(n) where n is the number of visible nodes, same as before. No performance concern.

6. **`_computeInitialExpandState` compatibility:** The controller expands all unlabeled interior nodes. A chain tail node is the last node before a branch/leaf/label. If the tail has children (branch point below), it is an unlabeled interior node and will be in the expanded set. If the tail is a leaf, it has no children and does not need to be expanded. If the tail's child is labeled, the tail is still unlabeled and interior, so it is expanded. All cases are correct without controller changes.

7. **Chain starting at a labeled node:** A labeled node at the start of a chain is fine -- the chain's first move can have a label. The label displays on the chain row via `node.firstMove.label`. The chain only stops absorbing when it encounters a labeled **child** (the next node to absorb). The labeled first node itself is already committed to this chain/row.

8. **Step 10 test wording:** The review flagged that test descriptions saying "delegates to getMoveNotation" imply call-level verification (mocking/spying), which these tests do not perform. The tests verify output equivalence only. The descriptions have been reworded to "matches getMoveNotation output for single-move chains" to accurately reflect what is being tested.
