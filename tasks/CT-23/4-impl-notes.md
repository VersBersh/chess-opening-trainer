# CT-23 Implementation Notes

## Files Modified

- **`src/test/screens/repertoire_browser_screen_test.dart`** -- Added new `testWidgets` test `'orphan prompt -- dismiss preserves the orphaned move'` inside the existing `Deletion` group (after the root-node deletion test, before the group's closing brace). The test seeds a `['e4', 'e5']` line with cards, deletes e5, verifies the orphan prompt appears, dismisses it by tapping outside the dialog at `Offset(10, 10)`, and asserts that e4 is preserved in both the UI tree and database while no review card exists for e4.

## Deviations from Plan

- **Dialog dismiss method:** The plan's primary approach (`tester.tap(find.byType(ModalBarrier).last)`) sends the tap at the barrier's center, which coincides with the dialog content — the dialog intercepts the tap and isn't dismissed. Changed to `tester.tapAt(const Offset(10, 10))` which taps the barrier at a corner outside the dialog content. This exercises the real barrier-dismiss path (returns null to the controller) and avoids coupling to `Navigator.pop()` internals.
- Verified UI state (e4 visible, e5 gone) and DB state (one move with san `'e4'`, no review cards).

## Follow-up Work

- **Controller-level unit test for null dismiss:** As noted in the plan's risks section, `src/test/controllers/repertoire_browser_controller_test.dart` has `handleOrphans` tests for `keepShorterLine` and `removeMove` choices but no test for the `null` (dismiss) result. A companion unit test would be low-cost and improve coverage of the CT-2.4 bug fix at the controller layer.
