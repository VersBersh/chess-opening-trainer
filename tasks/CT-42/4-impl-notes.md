# CT-42 Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/theme/pill_theme.dart` | Removed `unsavedColor` field; renamed `savedColor` to `pillColor` and `textOnSavedColor` to `textOnPillColor`. Updated constructor, `light()`, `dark()`, `copyWith()`, and `lerp()`. |
| `src/lib/widgets/move_pills_widget.dart` | Collapsed the four-way `isSaved x isFocused` color matrix into two cases (focused / unfocused) in both the `pillTheme` and fallback branches. `data.isSaved` is no longer read for any styling decision. |
| `src/test/widgets/move_pills_widget_test.dart` | Updated `_testPillTheme` to use `pillColor` instead of `savedColor`/`unsavedColor`. Renamed focused-pill tests. Rewrote "saved vs unsaved" test to assert **identical** background, border, and text colors. Updated stale comment in fallback test. |

## Files Verified (No Changes Needed)

| File | Reason |
|------|--------|
| `src/lib/main.dart` | Uses `PillTheme.light()` and `PillTheme.dark()` named constructors which were updated in-place; call sites remain unchanged. |
| `src/lib/controllers/add_line_controller.dart` | Uses `isSaved` for branching-safety logic only, not for styling. No references to `PillTheme` fields. |
| `src/lib/screens/add_line_screen.dart` | Uses `isSaved` for label-editor gating only, not for styling. No references to `PillTheme` fields. |

## Deviations from Plan

- **Fallback test comment updated:** The plan said to keep the fallback test as-is, but the comment "primaryContainer for focused saved pill" was slightly misleading after collapsing the branches. Updated to "primaryContainer for focused pill" for accuracy.
- No other deviations.

## Plan Review Fix Incorporated

Per the plan review (3-plan-review.md), the "saved and unsaved pills have identical styling" test now also asserts equal text color between saved and unsaved pills, not just background and border.

## Follow-up Work

- **Semantic label still distinguishes saved vs new:** The `_semanticLabel` getter in `_MovePill` still produces "saved" or "new" suffixes. The plan explicitly deferred this as out of scope (accessibility concern, not styling). A future task could unify or remove this distinction if desired.
- The `dart:ui` import in the test file (line 1) appears unused (likely a leftover from earlier work). Could be cleaned up in a separate task.
