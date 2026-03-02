# CT-36: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/widgets/move_pills_widget.dart` | Added `_kPillMinTapTarget = 44` constant. Wrapped the pill `Container` in a `SizedBox(height: 44)` + `Center` inside the `GestureDetector` to decouple the visual decoration from the interactive tap target. Reduced vertical padding from 6 to 4. Updated `_kLabelBottomOffset` from -14 to -4 to account for the taller Stack. |
| `src/test/widgets/move_pills_widget_test.dart` | Added new test `'each pill tap target is at least 44 dp tall'` that verifies all pill variants (saved, unsaved, labeled) have a GestureDetector height >= 44dp. |

## Deviations from Plan

1. **Label offset value (`_kLabelBottomOffset`):** The plan said to determine the value empirically by running the app or widget inspector. Since the instructions prohibit running the app or tests, the value was calculated arithmetically instead:
   - Old pill height: ~30dp (14dp text + 12dp vertical padding + ~2dp border).
   - New visible pill height: ~24dp (14dp text + 8dp vertical padding + ~2dp border).
   - Centered in 44dp SizedBox: ~10dp transparent space below visible decoration.
   - Old offset: -14 (label 14dp below Stack bottom = 14dp below visible bottom, since Stack = visible).
   - New offset: -4 (label 4dp below Stack bottom = 4dp below Stack bottom, but Stack bottom is ~10dp below visible bottom, so label is ~14dp below visible bottom -- same visual distance).
   - **This value should be verified visually** when the app is next run. If the label appears mispositioned, adjust `_kLabelBottomOffset` accordingly.

2. **No existing test changes needed.** The plan flagged potential issues with existing test finders after adding `SizedBox` between `GestureDetector` and `Container`. Analysis confirmed all existing finders use `find.ancestor(of: find.text(...), matching: find.byType(Container)).first`, which still resolves to the innermost decoration `Container` (not the `SizedBox`). No test modifications were required.

## Follow-up Work

- **Visual verification of label offset:** The `_kLabelBottomOffset = -4` value was arithmetically estimated. It should be visually verified in the running app or widget inspector to confirm the label appears at the intended position beneath the pill decoration. If the label is mispositioned, create a follow-up task to calibrate the offset.
- **Row height impact:** Each pill row in the Wrap is now 44dp + 4dp runSpacing = 48dp, up from ~30dp + 4dp = ~34dp. The visible decoration is more compact, but the layout height is taller due to the tap target. If product feedback indicates too much vertical space, consider a follow-up task to evaluate reducing `_kPillMinTapTarget` (with accessibility trade-off sign-off) or reducing `runSpacing`.
