# CT-34: Implementation Plan

## Goal

After saving a label in Add Line mode, preserve the user's navigation state (pills, focused index, board position, FEN) and keep the board controller in sync with the controller's FEN, eliminating disabled pills and ghost pieces.

## Steps

### 1. Add defensive guard and targeted refresh in `updateLabel()` to preserve navigation state

**File:** `src/lib/controllers/add_line_controller.dart`

First, add a defensive guard at the top of `updateLabel()`: if `hasNewMoves` is true, return early (or assert in debug mode). The UI already gates label editing behind `canEditLabel` which requires `!hasNewMoves`, but `updateLabel()` is a public API and test or direct callers could bypass the UI gate. The guard prevents accidental loss of buffered moves.

```dart
Future<void> updateLabel(int pillIndex, String? newLabel) async {
  // Guard: label editing requires no unsaved moves (the UI enforces this
  // via canEditLabel, but protect against direct callers).
  if (hasNewMoves) return;

  final moveId = getMoveIdAtPillIndex(pillIndex);
  if (moveId == null) return;
  ...
```

Then replace the `loadData()` call with a targeted refresh that preserves navigation state:

a. Save the current `focusedPillIndex`, `currentFen`, `preMoveFen`, and `boardOrientation` from `_state` before the refresh.

b. Reload the repertoire name, all moves from DB, and rebuild `RepertoireTreeCache` (same first 2 steps as `loadData()`).

c. Create a new `LineEntryEngine` with `startingMoveId` set to `_state.engine!.lastExistingMoveId` (NOT `_startingMoveId`). This causes the new engine's `_existingPath` to include the full path the user navigated to. Since the guard above ensures `hasNewMoves` is false, `_bufferedMoves` is guaranteed empty, so no data is lost.

d. Rebuild the pills list from the new engine.

e. Construct the new `AddLineState` preserving: `focusedPillIndex` (clamped to new pills length - 1), `currentFen`, `preMoveFen`, `boardOrientation`. The `aggregateDisplayName` is recomputed from the new engine/cache (which now reflects the updated label).

f. Call `notifyListeners()`.

**Depends on:** Nothing. This is the core fix.

### 2. Add board sync after label save in `AddLineScreen`

**File:** `src/lib/screens/add_line_screen.dart`

In the `onSave` callback of `_buildInlineLabelEditor`, after `_controller.updateLabel()` completes, sync the board controller with the controller's current FEN. This mirrors the pattern used by `_handleConfirmSuccess()` and the undo handlers.

After `await _controller.updateLabel(focusedIndex, label)`, add:
```dart
if (mounted) {
  final fen = _controller.state.currentFen;
  if (fen == kInitialFEN) {
    _boardController.resetToInitial();
  } else {
    _boardController.setPosition(fen);
  }
}
```

With Step 1's fix, `currentFen` will be the preserved FEN (the position the user was viewing), so this sync is a safety net and clears the board's internal move history.

**Depends on:** Step 1 (so that `currentFen` is correct after `updateLabel`).

### 3. Add controller-level unit tests for label update state preservation

**File:** `src/test/controllers/add_line_controller_test.dart`

Add tests to the existing `Label update` group:

a. **"updateLabel preserves focusedPillIndex and currentFen"**: Seed tree with `['e4', 'e5', 'Nf3']`. Follow all 3 moves. Tap pill at index 1 (e5). Call `updateLabel(1, 'Sicilian')`. Assert: `focusedPillIndex` = 1, `currentFen` = FEN after e5, `preMoveFen` = FEN after e5, `pills.length` = 3, all pills are saved, `pills[1].label` = 'Sicilian'.

b. **"updateLabel does not break subsequent branching"**: Same setup as (a): seed `['e4', 'e5', 'Nf3']`, follow all 3, tap pill index 1 (e5), call `updateLabel(1, 'Sicilian')`. After `updateLabel`, assert: `hasNewMoves` = false, `canTakeBack` = false. Then play a new move (`d4`) on the board from the e5 position. Because `focusedPillIndex` (1) is not at the end of the pills list (length 3), `onBoardMove` triggers branch mode: it creates a new engine starting from e5's move ID, drops the tail (`Nf3`), and adds `d4` as a buffered move. Assert: `pills.length` = 3 (e4 saved, e5 saved, d4 unsaved), `hasNewMoves` = true, `canTakeBack` = true, `pills[0].san` = 'e4', `pills[1].san` = 'e5', `pills[2].san` = 'd4', `pills[2].isSaved` = false.

c. **"updateLabel preserves pills when starting from root"**: Seed tree with `['e4', 'e5']`. Create controller with `startingMoveId: null`. Follow e4 and e5. Tap pill 0 (e4). Call `updateLabel(0, 'King Pawn')`. Assert: pills.length = 2, pills[0].label = 'King Pawn', focusedPillIndex = 0, currentFen = FEN after e4.

d. **"updateLabel is a no-op when hasNewMoves is true"**: Seed tree with `['e4']`. Follow e4 (saved), then play e5 (buffered). Assert `hasNewMoves` = true. Call `updateLabel(0, 'Test')`. Assert: `pills[0].label` remains null (unchanged), `hasNewMoves` still true, `pills.length` unchanged at 2. Verify the label was NOT persisted to DB.

**Depends on:** Step 1.

### 4. Add screen-level integration test for board sync after label save

**File:** `src/test/screens/add_line_screen_test.dart`

Add a test **"board FEN and pills preserved after label save"** following the existing screen test patterns:

a. Seed tree with `['e4', 'e5', 'Nf3']`. Compute expected FENs: `expectedFens = computeFens(['e4', 'e5', 'Nf3'])`.

b. Build the screen with `startingMoveId` = Nf3's move ID (so existing path has all 3 pills) using `buildTestApp(db, repId, startingMoveId: nf3Id, controller: controller)`, injecting a controller via `controllerOverride`.

c. After `pumpAndSettle()`, tap the e4 pill text to navigate there. Then tap e4 again to open the inline editor (re-tap focused saved pill opens editor, per existing pattern).

d. Enter a new label text in the `TextField` and submit via `testTextInput.receiveAction(TextInputAction.done)`. Call `pumpAndSettle()`.

e. Assert state-level correctness:
   - Pills still show 3 items: `find.text('e4')`, `find.text('e5')`, `find.text('Nf3')` each `findsOneWidget`.
   - The board FEN matches the expected FEN at e4: `tester.widget<Chessboard>(find.byType(Chessboard)).fen` equals `expectedFens[0]`.
   - Confirm button is disabled (no new moves): `tester.widget<TextButton>(find.widgetWithText(TextButton, 'Confirm')).onPressed` is null.
   - Take Back button is disabled (no buffered moves): `tester.widget<TextButton>(find.widgetWithText(TextButton, 'Take Back')).onPressed` is null.
   - The label was persisted in DB: query moves and assert `e4Move.label` equals the entered text.

f. Verify board remains functional after label save: invoke the `Chessboard` widget's `onMove` callback with a legal move (e.g., `d5` from the e4 position where black is to move). After `pumpAndSettle()`, assert a new pill appears (`find.text('d5')`, `findsOneWidget`), confirming no desync or ghost state.

**Depends on:** Steps 1-2.

## Risks / Open Questions

1. **Engine's `_lastExistingMoveId` after label update**: The fix relies on creating a new engine with `startingMoveId` = `oldEngine.lastExistingMoveId`. This means the new engine's `_existingPath` = full path from root to the tip of the followed trail. The old engine's `_existingPath` + `_followedMoves` become the new engine's `_existingPath` alone, with `_followedMoves` empty. This is semantically correct (all those moves are saved in DB), but it changes the internal partitioning. Inspection confirms `_buildPillsList` treats them identically (both produce `isSaved: true` pills), so this is safe.

2. **Clamping `focusedPillIndex`**: If a label update somehow changed the tree structure (it should not, since labels are metadata-only), the clamping ensures no out-of-bounds access. But in normal operation, the pill count should remain unchanged after a label-only update.

3. **Board sync redundancy**: The board sync in Step 2 is technically redundant when Step 1 correctly preserves `currentFen`, because the board already shows that position. However, it serves as a defense-in-depth measure and clears the board's internal move history, preventing stale undo state. This matches the defensive pattern used in `_handleConfirmSuccess`.

4. **`_isLabelEditorVisible` lifecycle**: After `updateLabel()` completes, `onClose()` is called by the `InlineLabelEditor`, setting `_isLabelEditorVisible = false`. Meanwhile, `notifyListeners()` from the controller triggers a widget rebuild. The ordering is: `updateLabel` completes -> board sync -> `onSave` returns -> `InlineLabelEditor._confirmEdit` calls `onClose` -> `setState`. This should be fine because all these happen in the same microtask chain, and Flutter batches `setState` calls.

5. **No changes to `LineEntryEngine`**: The engine class remains unchanged. The fix works entirely at the controller and screen levels. This keeps the pure-logic engine simple and avoids adding state-restoration complexity to it.

6. **Defensive guard scope**: The `hasNewMoves` guard added in Step 1 is a silent early return (not a thrown exception) to match the existing pattern where `getMoveIdAtPillIndex` returning null also causes a silent return. In debug builds, a `debugPrint` or `assert` could also be added, but the early return alone is sufficient to prevent data loss.
