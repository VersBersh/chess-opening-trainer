# CT-11.6: Equal-width pills -- Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/widgets/move_pills_widget.dart` | Added `_kPillWidth = 66` constant; added `width: _kPillWidth` and `alignment: Alignment.center` to the `Container` in `_MovePill.build()`. |
| `src/test/widgets/move_pills_widget_test.dart` | Added test `'all pills have equal fixed width regardless of SAN length or label'` verifying all pills (short, long, unlabeled, labeled) have width 66. |

## Deviations from Plan

None. All three implementation steps (constant, Container changes, test) were applied exactly as specified in the plan.

## Follow-up Work

- **Step 4 (visual verification):** The plan calls for on-device visual verification of short SANs centering, long SANs fitting, wrap behavior, and label rendering. This was not performed by this agent per instructions.
- **Pixel value tuning:** The plan notes that `_kPillWidth = 66` may need minor adjustment after visual testing if platform text rendering differs from the derivation assumptions. Worth confirming during visual verification.
