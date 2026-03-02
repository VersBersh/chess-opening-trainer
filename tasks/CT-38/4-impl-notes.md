# CT-38: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/controllers/add_line_controller.dart` | Added `hasLineLabel` getter that returns `true` when `aggregateDisplayName` is non-empty. |
| `src/lib/widgets/repertoire_dialogs.dart` | Added `showNoNameWarningDialog()` function following existing dialog patterns. Returns `true` for "Save without name", `false` for "Add name". |
| `src/lib/screens/add_line_screen.dart` | Modified `_onConfirmLine()` to check `hasLineLabel` before calling `confirmAndPersist()`. Shows warning dialog if no label; returns early on "Add name" or dismiss. Added early `hasNewMoves` guard before the dialog check. |
| `src/test/controllers/add_line_controller_test.dart` | Added `hasLineLabel` test group with 4 tests: fresh repertoire (false), path with no labels (false), extending a labeled path (true), branching from a labeled starting node (true). |
| `src/test/screens/add_line_screen_test.dart` | Added `No-name warning dialog` test group with 5 tests: dialog shown on unnamed line, "Save without name" persists, "Add name" cancels, labeled line skips dialog, "Add name" short-circuits before parity validation. |

## Deviations from Plan

1. **Added early `hasNewMoves` guard in `_onConfirmLine()`**: The plan specified checking `hasNewMoves` as an existing guard, but the original code relied on `confirmAndPersist()` returning `ConfirmNoNewMoves`. I added an explicit `if (!_controller.hasNewMoves) return;` check before the no-name dialog to avoid showing the warning when there are no new moves to save. This prevents a confusing UX where the user sees a "no name" warning but has nothing to confirm.

2. **Step 4 (no change needed)**: Confirmed as stated in the plan -- `_onFlipAndConfirm()` is only reachable after the no-name check has already run, so no changes were needed there.

## Follow-up Work

- **"Add name" could auto-open the label editor**: When the user taps "Add name", they return to the screen but must manually tap a saved pill to open the inline label editor. A follow-up task could automatically open the label editor after dismissing the dialog. This was noted as a nice-to-have in the plan's open questions.
