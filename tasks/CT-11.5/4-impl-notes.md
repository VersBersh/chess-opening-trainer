# CT-11.5: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/widgets/move_pills_widget.dart` | Added `_kLabelBottomOffset` constant; replaced `Column` + `Transform.rotate` layout with `Stack` + `Positioned` for labeled pills and direct `pillBody` return for unlabeled pills; added explicit `clipBehavior: Clip.none` to `Wrap`; changed label `TextOverflow` from `ellipsis` to `visible`. |
| `src/test/widgets/move_pills_widget_test.dart` | Updated "no label when null" test to check for absence of `fontSize: 10` Text widget instead of `Transform.rotate`; added "labeled pill renders flat text without rotation" test; added "label does not affect pill layout height" test. |

## Deviations from Plan

- **`Wrap.clipBehavior` addition (Step 2):** The plan marked this as optional ("purely a clarity choice"). I included the explicit `clipBehavior: Clip.none` on the `Wrap` widget with a comment, since the plan recommended it for readability and it documents the intent that labels may paint outside pill bounds.
- No other deviations. All steps were implemented as specified.

## New Tasks / Follow-up Work

- **Accessibility text scaling:** As noted in the plan's risk section, `_kLabelBottomOffset = -14` is calibrated for default text scale (font size 10 + ~4px clearance). Under accessibility text scaling, both the pill body and label text grow, so the offset may not remain visually correct. A future pass could use `LayoutBuilder` or `CustomSingleChildLayout` for dynamic positioning.
- **Very long label strings:** Labels with `TextOverflow.visible` are unconstrained in width and could extend far beyond the pill horizontally. This is acceptable per spec for typical chess opening names but could be revisited if longer labels are introduced.
