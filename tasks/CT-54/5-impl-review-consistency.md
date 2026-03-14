**Verdict** — `Needs Fixes`

**Progress**
- `[x]` Step 1: Updated `features/add-line.md` for post-confirm persistence and snackbar lifetime.
- `[~]` Step 2: Refactored `loadData()` into `_loadData({leafMoveId})` and preserved the confirmed leaf position, but the new post-confirm state leaves saved-pill label edits without a valid save path.
- `[x]` Step 3: Updated `_handleConfirmSuccess()` commentary in the screen.
- `[x]` Step 4: Verified snackbar coexistence/dismissal behaviour with tests.
- `[x]` Step 5: Error path now reloads through `_loadData()`.
- `[x]` Step 6: Undo-after-confirm behaviour remains aligned with the plan.
- `[x]` Step 7: Existing tests that assumed reset-after-confirm were updated.
- `[x]` Step 8: Added controller tests for persistent pills / preserved position / branching / undo.
- `[x]` Step 9: Added screen tests for persistent pills / existing-line label / disabled confirm / snackbar behaviour.
- `[x]` Step 10: Documented the existing-line indicator in the spec.

**Issues**
1. **Major** — Post-confirm label edits on saved pills are now a dead end and can be lost silently. [add_line_controller.dart#L337](/C:/code/draftable/chess-3/src/lib/controllers/add_line_controller.dart#L337), [add_line_controller.dart#L543](/C:/code/draftable/chess-3/src/lib/controllers/add_line_controller.dart#L543), [add_line_controller.dart#L706](/C:/code/draftable/chess-3/src/lib/controllers/add_line_controller.dart#L706), [add_line_screen.dart#L177](/C:/code/draftable/chess-3/src/lib/screens/add_line_screen.dart#L177), [add_line_screen.dart#L376](/C:/code/draftable/chess-3/src/lib/screens/add_line_screen.dart#L376), [add_line_screen.dart#L648](/C:/code/draftable/chess-3/src/lib/screens/add_line_screen.dart#L648). After `_loadData(leafMoveId:)`, CT-54 correctly leaves the confirmed line visible with `hasNewMoves == false`. But saved pills are still editable through `updateLabel()`, which stores `_pendingLabels` in memory. Because confirm enablement, `confirmAndPersist()`, and the pop guard all still key off `hasNewMoves` only, a user can edit a label after confirm, see the UI update, and then have no way to save it; navigating away also skips the discard warning. This is a new regression introduced by the persistent-pills flow. Fix by introducing a broader dirty-state such as `engine.hasNewMoves || _pendingLabels.isNotEmpty`, using that for Confirm enablement / confirm guards / pop protection, and reserving `isExistingLine` for the truly clean state. Add controller and widget tests for “edit saved pill label after confirm, then save/discard”.