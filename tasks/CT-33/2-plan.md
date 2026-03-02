# CT-33: Implementation Plan

## Goal

Enlarge the label icon and chevron tap targets to meet the Material Design 48dp minimum while preserving compact visual density, and prevent accidental row selection when tapping near these targets.

## Steps

1. **Enlarge the chevron's tap target** in `src/lib/widgets/move_tree_widget.dart` (lines 188-204).
   - Replace the current `GestureDetector` > `Padding(right: 4)` > `Icon(size: 20)` structure with `GestureDetector` > `SizedBox(width: kMinInteractiveDimension, height: kMinInteractiveDimension)` > `Center` > `Icon(size: 20)`.
   - The `SizedBox` replaces the existing `Padding(right: 4)` — do **not** keep both. The 48dp box fully subsumes the old 4px padding.
   - Update the `else` branch placeholder from `SizedBox(width: 24)` to `SizedBox(width: kMinInteractiveDimension)` so that the text column aligns identically whether or not the chevron is present.
   - `kMinInteractiveDimension` (48.0) is already available from `package:flutter/material.dart`, which is already imported. No new constant or import needed.

2. **Enlarge the label icon's tap target** in `src/lib/widgets/move_tree_widget.dart` (lines 241-258).
   - Replace the current `GestureDetector` > `Padding(horizontal: 4)` > `Tooltip` > `Icon(size: 18)` structure with `GestureDetector` > `SizedBox(width: kMinInteractiveDimension, height: kMinInteractiveDimension)` > `Center` > `Tooltip` > `Icon(size: 18)`.
   - The `SizedBox` replaces the existing `Padding(horizontal: 4)` — do **not** keep both. The 48dp box fully subsumes the old 4px padding.
   - Keep `HitTestBehavior.opaque` on the `GestureDetector` so the entire 48dp area absorbs taps, preventing tap-through to the `InkWell`.
   - Keep the visual icon at 18px; only the touch bounds are enlarged.

3. **Adjust row padding** in `src/lib/widgets/move_tree_widget.dart` (line 179).
   - The 48dp `SizedBox` children now enforce adequate row height. Remove explicit vertical padding (`top: 4.0, bottom: 4.0`) from the outer `Padding` to keep rows from becoming too tall. The 48dp min-height provides sufficient touch target.
   - Depends on: Steps 1-2.

4. **Update existing widget tests** in `src/test/widgets/move_tree_widget_test.dart`.
   - Verify existing label icon and chevron tests still pass with the enlarged tap targets.
   - Add a test that tapping inside the enlarged tap area of the label icon (but outside the visual 18px icon) triggers `onEditLabel` and does **not** trigger `onNodeSelected`.
   - Add a test that tapping inside the enlarged tap area of the chevron (but outside the visual 20px icon) triggers `onNodeToggleExpand` and does **not** trigger `onNodeSelected`.
   - Both tests should use `tester.tapAt` with a coordinate offset from the icon center to target the enlarged area outside the icon's visual bounds.
   - Depends on: Steps 1-2.

## Risks / Open Questions

1. **Row height increase may affect test viewports.** Existing tests use `SizedBox(height: 600)`. With taller rows (48dp min vs. previous ~28dp), fewer fit on screen. Test viewport heights may need adjusting if tests reference rows that no longer fit.

2. **Horizontal space budget.** On a 360dp screen: 360 - 16 (left base) - 8 (right) - 48 (chevron) - 48 (label icon) = 240dp for text before indentation. Each depth level removes 24dp. At depth 4, only 144dp remains — sufficient for most move notations but tight with long labels.

3. **Consistency.** Both chevron and label icon must be updated uniformly to avoid visual/behavioral inconsistency. The `else` branch placeholder width must match the chevron `SizedBox` width exactly.

4. **Indentation capping was removed from this plan.** The original plan included capping `node.depth * 24.0` indentation at depth 5. This is a separate UX/behavioral concern unrelated to the stated goal of tap target enlargement. It also had a type issue: `int.clamp(int, int)` returns `num` in Dart, not `int` or `double`, which would cause a type error in `EdgeInsets.only(left: ...)`. If indentation capping is desired, it should be a separate ticket with dedicated UX validation.

5. **`kMinInteractiveDimension` vs. custom constant.** The plan uses Flutter's built-in `kMinInteractiveDimension` (48.0) from `material.dart` rather than introducing a custom `kMinTapTarget` constant in `spacing.dart`. This avoids a new file import and follows Flutter conventions. If the tap target size ever needs to diverge from the Material standard, a custom constant can be introduced at that time.
