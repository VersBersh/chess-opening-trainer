# CT-45.1: Plan

## Goal

Reduce the move tree's row height, icon sizes, padding, and indentation in `_MoveTreeNodeTile` to achieve file-explorer density (~28dp per row), and update tests that depend on the old 48dp dimensions.

## Steps

1. **Replace `kMinInteractiveDimension` with `28` for row min-height**
   File: `src/lib/widgets/move_tree_widget.dart` (line 185)

   - Change `minHeight: kMinInteractiveDimension,` to `minHeight: 28,` in the `ConstrainedBox` constraints.

2. **Replace `kMinInteractiveDimension` with `28` for chevron hit area**
   File: `src/lib/widgets/move_tree_widget.dart` (lines 195-196)

   - Change `width: kMinInteractiveDimension,` to `width: 28,` and `height: kMinInteractiveDimension,` to `height: 28,` in the `SizedBox` wrapping the chevron `GestureDetector`.

3. **Reduce chevron icon size from 20 to 16**
   File: `src/lib/widgets/move_tree_widget.dart` (line 202)

   - Change `size: 20,` to `size: 16,` on the chevron `Icon`.

4. **Reduce left base padding from 16 to 8 and indent-per-depth from 24 to 20**
   File: `src/lib/widgets/move_tree_widget.dart` (line 180)

   - Change `left: 16.0 + node.depth * 24.0,` to `left: 8.0 + node.depth * 20.0,` in `EdgeInsets.only`.

5. **Replace `kMinInteractiveDimension` with `28` for non-chevron spacer**
   File: `src/lib/widgets/move_tree_widget.dart` (line 209)

   - Change `const SizedBox(width: kMinInteractiveDimension)` to `const SizedBox(width: 28)`.

6. **Replace `kMinInteractiveDimension` with `28` for label-icon hit area**
   File: `src/lib/widgets/move_tree_widget.dart` (lines 251-252)

   - Change `width: kMinInteractiveDimension,` to `width: 28,` and `height: kMinInteractiveDimension,` to `height: 28,` in the `SizedBox` wrapping the label icon `GestureDetector`.

7. **Reduce label icon size from 18 to 14**
   File: `src/lib/widgets/move_tree_widget.dart` (line 258)

   - Change `size: 18,` to `size: 14,` on the label `Icon`.

8. **Update "enlarged label icon area" test tap offset**
   File: `src/test/widgets/move_tree_widget_test.dart` (lines 519-523)

   - Update the comment from "18px but sits inside a 48x48 SizedBox" to "14px but sits inside a 28x28 SizedBox".
   - Change the tap offset from `Offset(0, -20)` to `Offset(0, -10)`. Rationale: the 28dp box has a 14dp half-height, so a 10px offset is comfortably inside the box but outside the 14px visual icon (7px half-height). Using -10 instead of -12 provides more margin from the box edge and reduces flake risk.
   - Depends on: Steps 6-7.

9. **Update "enlarged chevron area" test tap offset**
   File: `src/test/widgets/move_tree_widget_test.dart` (lines 544-548)

   - Update the comment from "20px but sits inside a 48x48 SizedBox" to "16px but sits inside a 28x28 SizedBox".
   - Change the tap offset from `Offset(0, -20)` to `Offset(0, -10)`. Rationale: same as Step 8 -- 10px is comfortably inside the 28dp box (14dp half) but outside the 16px icon (8px half).
   - Depends on: Steps 2-3.

10. **Run the full test suite and verify**

    - Run `flutter test` to confirm all widget and unit tests pass, including screen-level tests in `src/test/screens/repertoire_browser_screen_test.dart` that exercise `MoveTreeWidget` indirectly.
    - All `buildVisibleNodes` unit tests should pass unchanged (no logic changes).
    - All other widget tests (tile count, tap callbacks, styling, badges) should pass unchanged since they do not assert on pixel dimensions.

## Risks / Open Questions

1. **Tap offset arithmetic for tests:** The chosen offset of 10px is well within the 28dp box (14dp from center to edge) and outside the visual icon (7-8dp from center to edge), providing 4dp margin from the box edge. This should be robust against rounding differences.

2. **Touch usability on mobile:** 28dp is below Material's recommended 48dp minimum touch target. The feature spec explicitly calls for this density ("~28-32dp height similar to a file explorer"), so this is an intentional design decision. If usability issues arise on small screens, the values can be tuned upward without structural changes.

3. **No `kMinInteractiveDimension` references remain:** After these changes, `move_tree_widget.dart` will have zero references to `kMinInteractiveDimension`. If the `flutter/material.dart` import was only needed for that constant plus other Material widgets, the import remains needed (for `Material`, `InkWell`, `Icon`, etc.). No import changes are required.
