# CT-38: Implementation Plan

## Goal

Show a dismissible warning dialog when the user confirms a new line that has no label/name anywhere along its path, informing them that naming lines is recommended for training mode.

## Steps

### 1. Add a method to `AddLineController` to check whether the current line has a name

**File:** `src/lib/controllers/add_line_controller.dart`

Add a public getter `hasLineLabel` (or similar) that returns `true` if the aggregate display name is non-empty (meaning at least one move along the existing + followed saved path has a label).

The logic: check `_state.aggregateDisplayName.isNotEmpty`. This field is populated from `LineEntryEngine.getCurrentDisplayName()`, which calls `RepertoireTreeCache.getAggregateDisplayName(_lastExistingMoveId)`. That method walks the root-to-node path for `_lastExistingMoveId` and concatenates all labels found. Since `_lastExistingMoveId` is updated as the user follows existing tree moves, this covers both the initial existing path (from root to starting node) and any followed existing moves. If the result is empty, no saved move along the entire navigated path has a label, meaning the line is unnamed.

This keeps the "has a name?" logic in the controller where it belongs, and the screen simply reads it.

### 2. Add a "no name" warning dialog function to `repertoire_dialogs.dart`

**File:** `src/lib/widgets/repertoire_dialogs.dart`

Add a new function following the existing dialog patterns:

```dart
Future<bool?> showNoNameWarningDialog(BuildContext context)
```

This shows an `AlertDialog` with:
- **Title:** `'Line has no name'` (or similar)
- **Content:** Text explaining that naming lines is recommended for training mode so the player knows which line they are supposed to play.
- **Actions:**
  - "Add name" button that returns `false` (cancel the save, user wants to go add a label)
  - "Save without name" button that returns `true` (proceed with the save anyway)

This follows the same `showDialog<bool>` pattern as `showDeleteConfirmationDialog`, `showBranchDeleteConfirmationDialog`, etc.

### 3. Integrate the warning into `_onConfirmLine()` in `AddLineScreen`

**File:** `src/lib/screens/add_line_screen.dart`

Modify `_onConfirmLine()` to check for a missing name **before** calling `_controller.confirmAndPersist()`. The check should happen early, before any persistence.

The updated flow:

```
1. Dismiss label editor (existing behavior)
2. Check if the controller has new moves (guard, existing via hasNewMoves)
3. If the line has no label (!_controller.hasLineLabel):
   a. Show the warning dialog
   b. If user chose "Add name" (result != true): return early (do not persist)
4. Call _controller.confirmAndPersist() (existing behavior)
5. Handle results (existing behavior)
```

This placement ensures the warning appears before parity validation, which is the right UX order: name check -> parity check -> persist.

**Depends on:** Steps 1 and 2.

### 4. Integrate the warning into `_onFlipAndConfirm()` in `AddLineScreen`

**File:** `src/lib/screens/add_line_screen.dart`

The `_onFlipAndConfirm()` method is called when the user accepts a parity flip. This is an alternative confirm path. However, this method is only reachable after `_onConfirmLine()` has already run (the parity warning is shown as a result of `confirmAndPersist()`). Since the no-name check runs before `confirmAndPersist()` in step 3, the user will have already seen and dismissed the no-name warning before reaching `_onFlipAndConfirm()`. Therefore, **no change is needed here** -- the warning is not duplicated on the flip-and-confirm path.

### 5. Add unit tests for `hasLineLabel` in the controller

**File:** `src/test/controllers/add_line_controller_test.dart`

Add tests:
- A line with no labels in the path: `hasLineLabel` returns `false`
- A line extending a path that has a label: `hasLineLabel` returns `true`
- An empty/fresh repertoire (no moves yet): `hasLineLabel` returns `false`

Use the existing `seedRepertoire()` helper with and without `labelsOnSan`.

**Depends on:** Step 1.

### 6. Add widget tests for the no-name warning dialog in the screen

**File:** `src/test/screens/add_line_screen_test.dart`

Add tests:
- Confirming a line with no labels shows the warning dialog
- Dismissing the warning with "Save without name" proceeds to persist the line
- Dismissing the warning with "Add name" does not persist (stays on screen)
- Confirming a line that has a label along the path does NOT show the warning dialog
- **Choosing "Add name" short-circuits before parity validation:** Seed a scenario where the line would produce `ConfirmParityMismatch` if `confirmAndPersist()` were called (e.g., wrong ply parity for the board orientation). Confirm the line, see the no-name dialog, tap "Add name". Assert that the parity warning UI is NOT shown and persistence did NOT occur. This proves the no-name check truly exits early before parity handling runs.

Use the existing test infrastructure (in-memory DB, `seedRepertoire()`, `controllerOverride`).

**Depends on:** Steps 1, 2, 3.

## Risks / Open Questions

1. **Extension vs. new line:** When extending an already-labeled line, the `aggregateDisplayName` will be non-empty (the ancestor label carries forward). The warning should correctly NOT fire in this case. The proposed `aggregateDisplayName.isNotEmpty` check handles this correctly since `getCurrentDisplayName()` includes all ancestor labels.

2. **Branching from a labeled node:** When the user branches from a focused pill that has a label, the new engine is created with that pill's moveId as `startingMoveId`, so `getCurrentDisplayName()` will include that label. The warning should correctly NOT fire. This needs a test to confirm.

3. **Dialog ordering:** The no-name warning fires before parity validation. If the user dismisses the no-name warning with "Save without name" and then hits a parity mismatch, they will see the parity warning next. This is acceptable UX -- two sequential warnings are better than losing the no-name check. However, if this feels heavy, we could consider combining them, though that would be significantly more complex.

4. **"Add name" action:** When the user taps "Add name," the dialog dismisses and they return to the screen. They would need to tap a saved pill to open the inline label editor. It may be worth considering whether the "Add name" action should automatically open the label editor, but this is a nice-to-have and not required by the acceptance criteria.
