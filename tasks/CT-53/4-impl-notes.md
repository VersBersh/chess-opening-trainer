# CT-53: Implementation Notes

## Files modified

| File | Change |
|------|--------|
| `design/ui-guidelines.md` | Added "Uniform vertical spacing" bullet under Pills & Chips section. |
| `features/add-line.md` | Added "Compact height" and "Uniform gap" bullets under Move Pills > Display subsection. |
| `src/lib/widgets/move_pills_widget.dart` | Reduced `_kPillMinTapTarget` from 36 to 32; reduced inner Container vertical padding from 4 to 2; extracted `_kPillRunSpacing` constant (4); added derived `_kPillAreaTopPadding` constant (18 = _kLabelSlotHeight + _kPillRunSpacing); changed outer Padding from `symmetric(horizontal: 8, vertical: 4)` to `only(left: 8, right: 8, top: _kPillAreaTopPadding, bottom: 4)`; changed Wrap.runSpacing from hard-coded 4 to `_kPillRunSpacing`. |

## Files not modified (pre-written tests)

| File | Notes |
|------|-------|
| `src/test/widgets/move_pills_widget_test.dart` | Tests were already updated per 3.5-test-notes.md. Height assertion is 46, tap target assertion is 32, and the new "board-to-first-row gap equals inter-row pill-body gap" test is present. |

## Deviations from plan

None. All steps were implemented exactly as specified.

## Verification (Step 8)

Confirmed that `MovePillsWidget` is only used in two files:
- `src/lib/widgets/move_pills_widget.dart` (definition)
- `src/lib/screens/add_line_screen.dart` (only consumer)

No other screens are affected by these changes.

## Follow-up work

- **Visual verification (plan Step 9):** The app should be run to verify that the 18 dp top padding looks balanced visually. As noted in the plan's risk #4, when most pills have no labels the perceived inter-row gap may feel smaller than the top padding because the eye groups the empty label slot with its pill. If the top padding looks too generous, reducing `_kLabelSlotHeight` or `_kPillRunSpacing` could help, but those changes have broader implications.
- **Test execution:** Tests were not run as part of this implementation. They should be run to confirm all assertions pass with the new constants.
