# CT-54: Implementation Plan

## Goal

After confirming a line on the Add Line screen, keep the pills and board position in place (with all moves now marked as saved) so the user can navigate back to a previous position and branch into a new variation without replaying the shared prefix.

## Steps

### Step 1: Update the feature spec (`features/add-line.md`)

**File:** `features/add-line.md`

Update the **Entry Flow** section (currently steps 1-8) to specify post-confirm persistence:

- After step 5 ("User presses Confirm to save buffered moves..."), add: "After confirm, the pills and board position remain unchanged. All previously-buffered moves are now displayed as saved. The Confirm button becomes disabled and the 'Existing line' indicator appears, since there are no new moves."
- Add a new sub-section or bullets specifying:
  - The user can tap any previous pill to navigate to that position, then play a different move to start a new variation (branching).
  - When the user plays a move that diverges from the saved line, the new move appears as unsaved and Confirm re-enables.
  - The board resets to the starting position in two cases: (a) the user explicitly navigates away from the screen, or (b) the user taps Undo on the post-confirm snackbar, which deletes the just-saved line and reloads the screen to the original starting position.
- Update step 7 ("If the user follows an existing line exactly...") to clarify that this now naturally applies after confirm (since all moves became saved).
- Remove any implication that the builder resets after confirm.

Update the **Undo Feedback Lifetime** section:

- Clarify that the undo snackbar coexists with the persistent pills. The snackbar is dismissed when the user plays the first move of a **new variation** (i.e., a move that diverges from the currently-displayed saved line), not merely because pills are visible.
- The existing rule ("first move of a fresh sequence following the builder reset") needs rewording since there is no longer a builder reset. Replace with: "the first board move that creates a new buffered (unsaved) move after a confirm."
- Explicitly document that tapping Undo on the snackbar deletes the saved line and reloads the screen to the original starting position (root if `startingMoveId` was null, or the `startingMoveId` position if the screen was opened mid-tree).

No changes needed to the Move Pills, Branching, Board Orientation, or Confirmation Behavior sections -- they already support the new flow.

### Step 2: Refactor `loadData()` and modify `_persistMoves()` to preserve position after confirm

**File:** `src/lib/controllers/add_line_controller.dart`

The current flow in `_persistMoves()` is:
1. Persist moves to DB.
2. Call `await loadData()` (rebuilds engine from scratch -- this is the reset).
3. Return `ConfirmSuccess`.

**Approach -- parameterise `loadData()` instead of duplicating it:**

Refactor the existing `loadData()` into a private `_loadData({int? leafMoveId})` method that accepts an optional `leafMoveId` parameter. When `leafMoveId` is provided, the engine is created with that move as the `startingMoveId` (so `_existingPath` contains the full root-to-leaf path and all pills appear saved). When `leafMoveId` is null, the engine is created with the controller's original `_startingMoveId`, preserving the current reset-to-starting-position behaviour.

```dart
Future<void> _loadData({int? leafMoveId}) async {
  _pendingLabels.clear();

  final repertoire = await _repertoireRepo.getRepertoire(_repertoireId);
  final allMoves = await _repertoireRepo.getMovesForRepertoire(_repertoireId);
  final cache = RepertoireTreeCache.build(allMoves);

  // Use leafMoveId when restoring post-confirm position,
  // otherwise fall back to the controller's original _startingMoveId.
  final effectiveStartId = leafMoveId ?? _startingMoveId;

  final engine = LineEntryEngine(
    treeCache: cache,
    repertoireId: _repertoireId,
    startingMoveId: effectiveStartId,
  );

  final String startingFen;
  if (effectiveStartId != null) {
    final move = cache.movesById[effectiveStartId];
    startingFen = move?.fen ?? kInitialFEN;
  } else {
    startingFen = kInitialFEN;
  }

  final displayName = _computeDisplayNameWithPending(engine);
  final pills = _buildPillsList(engine);

  _state = AddLineState(
    treeCache: cache,
    engine: engine,
    boardOrientation: _state.boardOrientation,
    focusedPillIndex: pills.isNotEmpty ? pills.length - 1 : null,
    currentFen: startingFen,
    preMoveFen: startingFen,
    aggregateDisplayName: displayName,
    isLoading: false,
    repertoireName: repertoire.name,
    pills: pills,
  );
  notifyListeners();
}
```

The public `loadData()` method becomes a thin wrapper:

```dart
Future<void> loadData() => _loadData();
```

This avoids duplicating the state-assembly logic that currently lives in `loadData()` (lines 154-198 of the controller).

Then in `_persistMoves()`, on the success path, replace `await loadData()` with:

```dart
// Find the move ID of the new leaf (last inserted move).
final leafMoveId = result.insertedMoveIds.isNotEmpty
    ? result.insertedMoveIds.last
    : confirmData.parentMoveId;

if (leafMoveId != null) {
  await _loadData(leafMoveId: leafMoveId);
} else {
  await _loadData(); // Fallback (shouldn't happen in practice).
}
```

The error/catch path continues to call `await _loadData()` (no `leafMoveId`), which resets to the original starting position since persistence failed.

This uses the existing `LineEntryEngine` constructor with `startingMoveId`, which populates `_existingPath` with the full root-to-leaf path. All pills will show as saved, `hasNewMoves` will be false, and `isExistingLine` will be true.

### Step 3: Update `_handleConfirmSuccess()` in the screen

**File:** `src/lib/screens/add_line_screen.dart`

The current `_handleConfirmSuccess()` syncs the board to `_controller.state.currentFen`. After Step 2, `currentFen` will be the leaf position (not `kInitialFEN`), so the board sync already works correctly. However, review and verify:

- The `_boardController.setPosition(fen)` call should use the preserved FEN from the controller state (which is now the leaf position).
- The `resetToInitial()` branch should only fire if `fen == kInitialFEN`, which won't happen after the Step 2 change (unless the line was somehow empty).
- No functional change needed here, but add a comment clarifying the intent.

### Step 4: Verify undo snackbar coexistence with persistent pills

**File:** `src/lib/screens/add_line_screen.dart`

The `_dismissSnackBarOnNextMove` mechanism works on the `hasNewMoves` false-to-true transition. After confirm with persistent pills:
- `hasNewMoves` is `false` (all moves are saved) -- correct.
- When the user navigates back and plays a divergent move, `hasNewMoves` becomes `true` -- this triggers snackbar dismissal -- correct.
- The snackbar should NOT be dismissed merely because pills exist -- and it won't be, since `_dismissSnackBarOnNextMove` only fires on the false-to-true transition of `hasNewMoves`.

**Conclusion:** The existing mechanism already handles this correctly. No code change needed, but add a test to verify.

### Step 5: Handle the error path in `_persistMoves()`

**File:** `src/lib/controllers/add_line_controller.dart`

In the `catch` block of `_persistMoves()`, the current code calls `await loadData()` to restore consistent state. This should continue to call `_loadData()` (no `leafMoveId`), resetting to the original starting position since persistence failed and the buffer state is unknown. No change needed here beyond using the renamed internal method.

### Step 6: Handle undo after confirm with persistent pills

**Files:** `src/lib/controllers/add_line_controller.dart`, `src/lib/screens/add_line_screen.dart`

After undo (extension or new-line), the controller calls `loadData()` which resets to the **original starting position** -- that is, root (empty board) when `_startingMoveId` is null, or the `_startingMoveId` position when the screen was opened mid-tree. This is correct: if the user undoes the confirm, the line is deleted and the builder should show the state before the undone line existed, which is the same position the screen started from.

The existing board-sync code in the screen's undo `onPressed` callbacks already handles this correctly:

```dart
final fen = _controller.state.currentFen;
if (fen == kInitialFEN) {
  _boardController.resetToInitial();
} else {
  _boardController.setPosition(fen);
}
```

After undo + `loadData()`, `currentFen` will be the starting position FEN (which is `kInitialFEN` only when `_startingMoveId` is null; otherwise it is the FEN of the `_startingMoveId` move). The `if/else` already covers both cases. No code change needed.

### Step 7: Update existing tests that assert old post-confirm reset behaviour

**Files:** `src/test/controllers/add_line_controller_test.dart`, `src/test/screens/add_line_screen_test.dart`

Before adding new tests, audit and update existing tests that assume the old post-confirm reset. Key tests to update:

1. **Controller: "is a no-op when generation does not match"** (controller test, undo-generation group, ~line 1302). This test confirms a first line (e4/e5), then plays a second line (d4/d5) starting from `kInitialFEN`. After the change, post-confirm position will be the e5 leaf (not root), so the second line must be played by first navigating back to a root-equivalent position or by branching from the persisted line. Update this test to navigate back to pill index 0 (e4 position) and branch with d4 from there, or navigate to "before first pill" to return to root.

2. **Controller: "confirmAndPersist persists pending labels alongside moves atomically"** (~line 2210) and **"pendingLabels cleared after confirm"** (~line 2270). These tests play moves after confirm and may assume position is at root. Update them to account for post-confirm position being at the new leaf.

3. **Screen: "Line extended snackbar is dismissed when user plays first move of new line"** (~line 1607). This test currently reads `postConfirmFen` from the controller, which under the old behaviour is the `_startingMoveId` FEN (e4 position). With persistence, the post-confirm FEN will be the e5 leaf FEN. The test already reads `controller.state.currentFen` dynamically, so it may just work, but verify that the move played (d5) is valid from the new post-confirm position and that the snackbar dismissal still triggers correctly. If the post-confirm position is e5 (white to move), the diverging move should be something other than d5. Update accordingly.

4. **Screen: "Line saved snackbar is dismissed when user plays first move of new line"** (~line 1581). Similar to above -- currently plays d4 from `kInitialFEN`. With persistence, position is at e4 leaf (black to move). Update the diverging move to be valid from the new post-confirm FEN (e.g., play d5 from the e4 position).

5. **Any test that calls `confirmAndPersist()` and then plays new moves** should be checked to ensure the assumed board position matches the new post-confirm leaf FEN rather than the old reset-to-root FEN.

### Step 8: Add new controller tests

**File:** `src/test/controllers/add_line_controller_test.dart`

Add tests for:

1. **Pills persist after confirm (root start):** Seed empty repertoire, play e4/e5, flip to black, confirm. Verify pills list has 2 pills, both with `isSaved: true`. Verify `hasNewMoves` is `false`. Verify `isExistingLine` is `true`. Verify `currentFen` is the FEN after e5 (not `kInitialFEN`).

2. **Pills persist after confirm (mid-tree start):** Seed repertoire with e4/e5/Nf3, create controller with `startingMoveId` = Nf3 move ID, play Nc6 (extends from Nf3), flip, confirm. Verify pills show the full path (e4, e5, Nf3, Nc6) all saved, and `currentFen` is the Nc6 FEN.

3. **Board position preserved after confirm:** Same setup as test 1. Verify `currentFen` and `preMoveFen` match the FEN after the last confirmed move.

4. **Branching after confirm:** After confirming e4/e5, tap pill at index 0 (e4), play d5 (diverging from e5). Verify pills now show the branched line (e4, d5), with e4 saved and d5 unsaved. Verify `hasNewMoves` is `true`.

5. **Confirm button disabled after confirm:** Verify `hasNewMoves` is `false` after confirm (Confirm button disabled by screen).

6. **Second confirm after branching:** After confirming e4/e5, branch to e4/d5, confirm again. Verify pills persist showing e4/d5, both saved.

7. **Undo after confirm resets to original starting position (root start):** Seed empty repertoire, play e4/e5, confirm, then undo. Verify state resets to initial (empty pills, `kInitialFEN`).

8. **Undo after confirm resets to original starting position (mid-tree start):** Seed repertoire with e4/e5/Nf3, create controller with `startingMoveId` = Nf3 move ID, play Nc6, confirm, then undo. Verify state resets to the Nf3 position (existing path e4/e5/Nf3, `currentFen` = FEN after Nf3), not to `kInitialFEN`.

### Step 9: Add new screen/widget tests

**File:** `src/test/screens/add_line_screen_test.dart`

Add tests for:

1. **Pills visible after confirm:** Play moves, confirm, verify pill widgets are still rendered.

2. **"Existing line" label visible after confirm:** Verify the info label appears.

3. **Confirm button disabled after confirm:** Verify the button is disabled.

4. **Undo snackbar coexists with pills:** Confirm, verify snackbar appears while pills are still visible.

5. **Undo snackbar dismissed on new variation:** Confirm, navigate back to a previous pill, play a divergent move, verify snackbar is dismissed.

### Step 10: Update spec for "already saved" indicator

**File:** `features/add-line.md`

The "already saved" indicator after confirm is the existing `isExistingLine` info label ("Existing line") that already appears when all pills are saved. After Step 2, this label will naturally appear post-confirm because `hasNewMoves` is false and pills are non-empty.

No new visual indicator is needed beyond what already exists. The spec update from Step 1 should document this: "After confirm, the 'Existing line' label appears below the pills, indicating that the displayed line is saved in the repertoire."

If a more prominent indicator is desired (e.g., a checkmark near the confirm button, or different pill styling for "just confirmed" moves), that can be added as a follow-up. The current "Existing line" label is sufficient for v0.

## Risks / Open Questions

1. **`_loadData(leafMoveId:)` correctness:** The parameterised `_loadData` approach creates the engine with `startingMoveId` set to the new leaf. This populates `_existingPath` with the full root-to-leaf path. Need to verify that `LineEntryEngine` correctly handles subsequent moves from this position (following existing children or buffering new ones). The engine already supports this -- it's the same pattern used when `startingMoveId` is passed at controller construction time. **Risk: Low.**

2. **Pending labels after confirm:** `_loadData` clears `_pendingLabels`. This is correct because all labels were persisted during confirm. But verify that the pills list after reload correctly shows the DB labels (which now include the previously-pending ones). **Risk: Low** -- `_buildPillsList` reads from `engine.existingPath` which comes from the rebuilt tree cache.

3. **Multiple rapid confirms:** If the user confirms, navigates back, branches, and confirms again quickly, the `_undoGeneration` counter should correctly invalidate earlier snackbars. The existing generation-based invalidation handles this. **Risk: Low.**

4. **`focusedPillIndex` after confirm:** After `_loadData(leafMoveId:)`, the focused pill is set to the last pill (the leaf). This is correct -- the board shows the leaf position, which matches. **Risk: Low.**

5. **No "New Line" / reset button:** The spec says "the board resets to the starting position if the user explicitly navigates away or taps Undo." There is currently no "New Line" / reset button on the Add Line screen. If the user wants to start a completely fresh line (not branching from the current one), they must navigate away and come back. This seems acceptable for now but could be a UX improvement in a follow-up task.

6. **Undo snackbar interaction edge case:** If the user confirms line A (snackbar appears), then navigates back and confirms line B (new snackbar), the generation counter invalidates snackbar A. But what if the user taps undo on snackbar B -- should the pills reset to show line A's position, or to the original starting position? Currently `undoNewLine` / `undoExtension` calls `loadData()` (which resets to the original starting position). With persistent pills, after undoing line B, we might want to show line A again. This is complex and probably acceptable to defer -- having undo reset to the original starting position is a reasonable simplification. **Risk: Medium (UX gap, not a bug).**

7. **Review issue 1 was correct:** The original plan incorrectly stated that undo resets to `kInitialFEN`. In reality, `loadData()` rebuilds with the controller's `_startingMoveId`, so undo returns to the original starting position of the screen -- which is root only when `_startingMoveId` is null. Step 6 and the test plans (Steps 7-9) have been corrected to account for both root-start and mid-tree-start flows.
