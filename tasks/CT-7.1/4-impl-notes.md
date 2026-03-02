# CT-7.1 Implementation Notes

## Files Created

- **`src/lib/widgets/move_pills_widget.dart`** -- New file containing `MovePillData` data class, `MovePillsWidget` stateless widget, and `_MovePill` private widget. Implements horizontal scrollable pill row with 4 visual states (saved/unsaved x focused/unfocused), label display via `Transform.rotate`, and delete-last-pill affordance.

- **`src/test/widgets/move_pills_widget_test.dart`** -- New file containing 11 widget tests covering: pill count rendering, empty state placeholder, tap callbacks with correct index, focused saved/unsaved pill styling verification, saved vs unsaved border color distinction, label presence/absence, delete icon visibility rules, delete callback firing, and delete-not-triggering-pill-tap isolation.

## Deviations from Plan

1. **Separated tap targets instead of nested GestureDetectors.** The plan's Step 3 pseudocode showed a single outer `GestureDetector` wrapping the entire pill container with a nested inner `GestureDetector` for the delete icon. This would cause both `onTap` and `onDelete` to fire when tapping the delete icon (Flutter's gesture arena does not prevent parent gesture recognizers from firing when a child recognizer also accepts the same gesture type). Instead, the implementation places the SAN text and delete icon as **sibling** `GestureDetector`s inside a `Row` within a non-interactive `Container`. This ensures tapping the delete icon fires only `onDelete` and not `onTap`, matching the test requirement ("tapping delete icon does not fire onPillTapped").

2. **No `Semantics` wrapper.** The plan's Risk #5 mentioned considering accessibility labels. This was not implemented -- it is noted as a follow-up below.

3. **Focused unsaved pill test added as separate test.** The plan listed "focused pill has distinct visual styling" as a single test case covering both saved and unsaved variants. The implementation splits this into two tests: one for focused saved pill (`primaryContainer`) and one for focused unsaved pill (`tertiaryContainer`), resulting in 11 test methods total as specified.

## Follow-up Work

- **Accessibility:** Add `Semantics` widget wrapping each pill with descriptive labels (e.g., "Move 3: Nf3, saved") for screen reader support.
- **Auto-scroll:** Deferred per plan. If needed, can be added in CT-7.2 where the parent screen owns the scroll controller.
- **Touch target sizing:** The delete icon tap area (14px icon + 4-6px padding) may be smaller than the Material 24x24dp minimum touch target. Consider increasing padding or wrapping in a `SizedBox` with minimum constraints if usability testing reveals issues.
