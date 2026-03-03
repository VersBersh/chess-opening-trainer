# CT-50.6: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/widgets/move_pills_widget.dart` | Replaced Stack/Positioned/Clip.none label approach with a Column-based fixed-height item structure; added `_kLabelSlotHeight` constant; removed `_kLabelBottomOffset` constant; changed `Wrap.runSpacing` from 10 to 4; removed `clipBehavior: Clip.none` from Wrap. |

## Changes Made

1. **Removed `_kLabelBottomOffset`** constant and its doc comment. No longer needed once labels are in-flow.

2. **Added `_kLabelSlotHeight = 14`** constant with a doc comment explaining it is reserved for one line of 10 sp text and must remain fixed-height so all Wrap rows have uniform item height.

3. **Removed `clipBehavior: Clip.none`** from the `Wrap` in `MovePillsWidget.build`. The default `Clip.hardEdge` is now correct since labels no longer paint outside item bounds.

4. **Reduced `Wrap.runSpacing` from 10 to 4** since the label slot is fully in-flow and no longer needs extra run-gap to prevent bleed from one row into the next.

5. **Replaced branching `content` logic in `_MovePill.build`** with a single `Column(mainAxisSize: MainAxisSize.min)` containing:
   - `pillBody` (`GestureDetector` wrapping a `SizedBox` of `width: _kPillWidth, height: _kPillMinTapTarget`) — unchanged; still the only widget inside the `GestureDetector`.
   - `labelSlot`: a `SizedBox(width: _kPillWidth, height: _kLabelSlotHeight)` — contains an `ExcludeSemantics`-wrapped `Text` when `data.label` is non-null, or is empty when null. Label text uses `overflow: TextOverflow.ellipsis`, `maxLines: 1`, and `textAlign: TextAlign.center`.

6. **`Semantics` wrapper** remains on the outermost widget (now the `Column`), consistent with prior behavior. Tap handling is still on `pillBody` only; the label slot is outside the `GestureDetector`.

## Deviations from Plan

None. All steps in `2-plan.md` were implemented as specified.

## Follow-up Work / New Tasks Discovered

- **Visual regression check on `add_line_screen.dart`** (plan step 4): The `SingleChildScrollView > Column` layout was reviewed and no code changes were needed. The increased per-row height (36 + 14 = 50 dp vs. 36 dp previously) is absorbed by the existing scroll wrapper. No layout code in `add_line_screen.dart` was modified.
- If two-line labels are ever needed in future, `_kLabelSlotHeight` will need to be increased and the uniform-height guarantee re-evaluated; this should be tracked as a separate task.
