# CT-2.2 Plan Review

## Verdict

**Approved with Notes**

The plan is well-structured, follows existing codebase patterns closely, and correctly identifies the right files, APIs, and types to use. The step ordering is sound (pure logic first, tests second, then UI wiring). The risks section is thorough and honest. There are a few issues that need attention during implementation, but none require a fundamental rethinking of the approach.

## Issues

### 1. (Major) `makeSan` returns a record, not a String

**Affected step:** Step 4c

The plan's code snippet shows:

```dart
final san = preMovePosition.makeSan(move);
```

In dartchess 0.12.1, `Position.makeSan(Move)` returns `(Position, String)` -- a Dart record -- not a plain `String`. The correct usage is:

```dart
final (_, san) = preMovePosition.makeSan(move);
```

Or equivalently `preMovePosition.makeSan(move).$2`. This applies everywhere `makeSan` is called. The deprecated `toSan` method does return a plain `String` but should not be used.

**Fix:** Use destructuring or `.$2` to extract the SAN string from the record.

---

### 2. (Major) Null parentMoveId when entering a line from root

**Affected steps:** Steps 1, 6b

The plan's `getConfirmData()` method returns `parentMoveId` as `lastExistingMoveId`, which is `null` when entering a brand-new line from the initial position (no existing moves followed, no starting node selected). Two problems follow:

(a) `isExtension` is computed via `treeCache.isLeaf(parentMoveId)`, but `isLeaf` takes a non-nullable `int`. Calling it with `null` would be a compile error.

(b) Step 6b's persistence code for the non-extension path uses `int parentId = confirmData.parentMoveId!;` with a force-unwrap, which would crash at runtime for root-level entries. The comment acknowledges "or handle null for root" but the code does not implement the null case.

**Fix:** In `getConfirmData`, when `parentMoveId` is null, `isExtension` should be `false`. In the persistence code, handle the null case: the first buffered move should be inserted with `parentMoveId: Value.absent()` (a root move), and subsequent moves chain from the returned ID.

---

### 3. (Minor) Sort order for new sibling moves is hardcoded to 0

**Affected step:** Step 6b

The plan sets `sortOrder: 0` for all new moves. When branching from an existing non-leaf parent that already has children with `sortOrder: 0`, this creates ordering ambiguity. It will not cause a crash (the sibling uniqueness constraint is on `(parent_move_id, san)`, not on sort_order), but the tree display order may not reflect insertion order.

Risk #8 in the plan acknowledges this and suggests querying `max(sort_order) + 1`, but the implementation code does not do so.

**Fix:** For the first buffered move (the one becoming a new sibling), query the existing children's max sort_order from the tree cache (`treeCache.getChildren(parentMoveId).length` works as a simple heuristic since children are already sorted). Subsequent chained moves can use sort_order 0 since they have no siblings.

---

### 4. (Minor) `RepertoireBrowserState.copyWith` uses nullable function wrapper for `selectedMoveId`

**Affected step:** Step 3

The existing `copyWith` uses `int? Function()? selectedMoveId` to distinguish "not provided" from "set to null." The plan says to add new fields to `copyWith`, but the implementing agent should be aware of this pattern: setting `selectedMoveId` to null requires passing `selectedMoveId: () => null`, not `selectedMoveId: null` (which means "don't change"). Any new nullable fields (like `lineEntryEngine` and `currentFen`) should follow the same pattern if the code needs to clear them back to null when exiting edit mode.

**Fix:** Use the nullable function wrapper pattern for `lineEntryEngine` and `currentFen` in `copyWith`, consistent with `selectedMoveId`, or use a different mechanism (e.g., a dedicated `exitEditMode` method that returns a new state with those fields cleared).

---

### 5. (Minor) `_preMoveFen` initialization gap

**Affected step:** Step 4c

The plan says `_preMoveFen` is initialized when entering edit mode. However, if no node is selected (entering from root), the initial FEN should be `kInitialFEN` (the standard starting position). The plan mentions `controller.resetToInitial()` for this case but does not explicitly state what `_preMoveFen` should be set to. If it is left null or uninitialized, the first `_onEditModeMove` call would fail.

**Fix:** Explicitly set `_preMoveFen = kInitialFEN` (or `Chess.initial.fen`) when entering edit mode from root. When entering from a selected node, set `_preMoveFen = selectedMove.fen`.

---

### 6. (Minor) Missing undo snackbar after confirm

**Affected step:** Step 6

The spec (`line-management.md`, "Undo Line Extension" section) calls for a transient undo snackbar (~8 seconds) after confirming a line extension. The plan does not mention this. It is reasonable to defer this to a follow-up task, but it should be noted as a known gap.

**Fix:** Either add a step for the undo snackbar, or explicitly note it as deferred.

---

### 7. (Minor) No handling of the `comment` field on RepertoireMove

**Affected step:** Step 6b

The `RepertoireMoves` table has a `comment` column (nullable). The `RepertoireMovesCompanion.insert` will default it to `Value.absent()`, which is correct for new moves that have no comments. This is not a bug, but the implementing agent should be aware that the database schema includes a `comment` field not mentioned in the plan or context document.

**Fix:** No code change needed. Just awareness.
