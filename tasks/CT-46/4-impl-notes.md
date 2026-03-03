# CT-46: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/theme/spacing.dart` | Added `kLineLabelHeight` (32dp) and `kLineLabelLeftInset` (16dp) constants |
| `src/lib/widgets/browser_board_panel.dart` | Restyled `BrowserDisplayNameHeader`: always renders fixed-height SizedBox, removed colored background, changed text from `titleSmall` to `titleMedium` with `FontWeight.normal`, updated padding to left-only inset. Added `spacing.dart` import. |
| `src/lib/widgets/browser_content.dart` | Narrow layout: moved `BrowserDisplayNameHeader` from above the board to below it. Wide layout: moved label from right-panel Column into left column (wrapped board + label in a `Column` with `Flexible` + `AspectRatio`). |
| `src/lib/screens/drill_screen.dart` | Changed `lineLabelWidget` from nullable to always-present `SizedBox` with fixed height. Updated padding to `EdgeInsets.only(left: kLineLabelLeftInset, ...)`. Removed `?` prefix from both narrow and wide layout children lists. Added `spacing.dart` import. |
| `src/test/screens/drill_screen_test.dart` | Updated two test names and descriptions for empty-label tests to reflect the new "reserves space" behavior. Existing assertions still valid since the `ValueKey` is conditionally set only when label is non-empty. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Added `browser_board_panel.dart` import. Updated unlabeled-node test to assert `BrowserDisplayNameHeader` widget is always present. Added two new tests verifying label appears below the board in narrow and wide layouts. |

## Deviations from Plan

1. **Drill screen `ValueKey` strategy**: The plan said to "keep the `ValueKey('drill-line-label')` only when label is non-empty," which is exactly what was implemented. The plan also said to update tests to "verify label text is not present instead of key absent." Since the key is conditionally set (only present when non-empty), the existing `find.byKey(...findsNothing)` assertions remain correct and were kept. The test names and comments were updated to clarify the new semantics (space is reserved, text is absent).

2. **No `spacing.dart` import needed in `browser_content.dart`**: The plan mentioned "Import `spacing.dart` if not already imported" for Step 4. It was already imported (line 8), so no additional import was needed.

## Post-Review Fixes

After code review, the following fixes were applied:
- Added always-present `ValueKey('drill-line-label-area')` to the drill screen's label SizedBox for testability
- Moved `ValueKey('drill-line-label')` from the SizedBox to the inner Padding (only when label is non-empty)
- Added `kLineLabelHeight` assertions in drill tests to verify reserved space when unlabeled
- Added `Text` descendant absence assertion in browser test for unlabeled case
- Added `spacing.dart` import to drill test file

## Follow-up Work

- **Extract shared `LineLabelBanner` widget**: The line-label rendering logic is duplicated between `drill_screen.dart` and `browser_board_panel.dart` (same style, padding, text behavior). Extract a shared widget to avoid divergence.
- **Visual testing**: The plan's risk section notes that the 32dp label height reduces the board size slightly in both layouts. This should be visually verified on small screens and wide layouts to ensure the board remains appropriately sized.
- **Accessibility/text scaling**: `kLineLabelHeight = 32` is fixed and may clip text at extreme accessibility text scale factors. A future task could make this responsive to `MediaQuery.textScaleFactor`.
- **Pre-existing test failure**: "back navigation from root move returns to initial position" in `repertoire_browser_screen_test.dart` was already failing before this task. Needs investigation (unrelated to CT-46).
