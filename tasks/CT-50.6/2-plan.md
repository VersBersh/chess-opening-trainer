# CT-50.6: Plan

## Goal

Replace overlap-prone label placement under move pills with a robust, row-aware layout that prevents both vertical (inter-row) and horizontal (intra-row) label collisions.

## Steps

1. **Audit current geometry.**
   Confirm the exact pixel budget: pill tap target height is `_kPillMinTapTarget = 36 dp`, pill width is `_kPillWidth = 66 dp`, label font size is 10 sp, label bottom offset is `_kLabelBottomOffset = -8 dp` (paints outside the Stack). The `Wrap` uses `runSpacing: 10` with `clipBehavior: Clip.none`, so labels from one run bleed into the run below. Both problems (vertical inter-row collision and horizontal intra-row overflow) stem from the same root: the Wrap children have non-uniform painted height and the label text is unconstrained.

2. **Commit to a single layout strategy: fixed-height vertical item with always-reserved label slot.**
   Replace the current branching logic (bare `pillBody` vs `Stack` with `Positioned` label) with a single `Column`-based item structure used for every pill, regardless of whether it has a label:

   - The item is a `Column` with `mainAxisSize: MainAxisSize.min` containing two children:
     1. The pill body (`SizedBox` of `width: _kPillWidth, height: _kPillMinTapTarget`), unchanged.
     2. A label slot: a `SizedBox` of `width: _kPillWidth` and a fixed height sufficient for one line of 10 sp text (approximately 14 dp). When `data.label` is non-null, this slot renders the label text; when null, it renders an empty `SizedBox` of the same dimensions.
   - This eliminates the `Stack`/`Positioned`/`Clip.none` approach entirely. Every Wrap child has an identical total height (`_kPillMinTapTarget + label slot height`), so the Wrap lays out all runs with uniform item height and no paint bleed.
   - Adjust `Wrap.runSpacing` to a smaller value (e.g. 4 dp) since the label slot is now inside the item's own height budget and no longer needs extra run gap to avoid collision.

3. **Constrain label text to pill width with ellipsis overflow.**
   Inside the label slot, the `Text` widget must be explicitly constrained to `_kPillWidth` (matching the pill body) and must never overflow horizontally:

   - Wrap the label `Text` in a `SizedBox(width: _kPillWidth)` (or use the slot's own `SizedBox` width constraint).
   - Set `overflow: TextOverflow.ellipsis` (not `TextOverflow.visible`) so long labels are clipped to the pill width.
   - Set `maxLines: 1` (already present; keep it).
   - Use `textAlign: TextAlign.center` (or `TextAlign.left`, matching the pill body's `Alignment.center`) to keep label alignment consistent across all pills.
   - Remove the old `_kLabelBottomOffset` constant and the `clipBehavior: Clip.none` on the `Wrap` — neither is needed once labels are in-flow.

4. **Verify behavior in the `AddLineScreen` parent layout.**
   Open `add_line_screen.dart` and trace the layout path: `SingleChildScrollView > Column > MovePillsWidget > ... > _buildActionBar`. Check that:

   - The increased minimum item height (pill + label slot) does not cause the pills section to crowd out the action bar on small screens (e.g. 360 dp wide, many pills). The `SingleChildScrollView` wrapper means overflow is handled by scrolling, not clipping, so this should be safe, but confirm visually.
   - The `Wrap`'s `spacing: 4` and revised `runSpacing` values leave adequate breathing room between pills and between the pill section and the inline label editor / parity warning that appear directly below `MovePillsWidget` in the `Column`.
   - The `Padding(horizontal: 8, vertical: 4)` wrapper on `MovePillsWidget.build` still provides appropriate insets.

5. **Confirm no regressions in tap targets and focus highlight.**
   The `GestureDetector` and `Semantics` are attached to `pillBody` and its parent `Semantics` wrapper respectively. Moving the label out of the `Stack` and into a sibling `Column` child must not change which widget receives taps. Verify that only the pill body (the `SizedBox` of `height: _kPillMinTapTarget`) is inside the `GestureDetector`, not the label slot.

## Non-Goals

- No changes to label editing business logic.
- No changes to add-line confirmation flow.
- No compile/test execution as part of this planning task set.

## Risks

- **Increased row height reduces visible move density.** Adding a ~14 dp label slot to every pill increases each row's height from 36 dp to ~50 dp. On dense sequences this means fewer rows are visible without scrolling. This is an acceptable trade-off given the existing `SingleChildScrollView` wrapper; the alternative (colliding labels) is a correctness problem not a density preference.
- **Mixed rows alignment with `runSpacing` reduction.** Reducing `runSpacing` from 10 to 4 is safe only because the label slot is now fully in-flow. If the slot height is later changed dynamically (e.g. two-line labels), the uniform-height guarantee breaks. The plan explicitly reserves a fixed single-line slot height to prevent this.
- **(Review issue 3 addressed above in Step 4)** The review flagged that `add_line_screen.dart` was listed as relevant but the original plan had no verification step against it. Step 4 now explicitly covers the `SingleChildScrollView` column, action-bar spacing, and narrow-screen behavior.
