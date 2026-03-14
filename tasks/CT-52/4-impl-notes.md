# CT-52 Implementation Notes

## Files created or modified

| File | Change |
|------|--------|
| `architecture/board-layout-consistency.md` | Added wide-layout consistency section; updated Board Frame rules to specify 4dp inset and width-based sizing formula. |
| `design/ui-guidelines.md` | Added "Board padding" subsection under Spacing with mobile/desktop guidelines. |
| `src/lib/theme/spacing.dart` | Added `kBoardHorizontalInset` (4.0), `kBoardHorizontalInsets`, three helper functions (`boardSizeForWidth`, `boardSizeForConstraints`, `boardSizeForNarrow`); changed `kMaxBoardSize` from 300 to 600; added `import 'dart:math'`. |
| `src/lib/screens/add_line_screen.dart` | Refactored `_buildContent` into narrow/wide branches; narrow uses `boardSizeForWidth` + `kBoardHorizontalInsets` padding; added `_buildWideContent` with `LayoutBuilder` + `boardSizeForConstraints` + side-panel Row layout. |
| `src/lib/screens/drill_screen.dart` | Narrow branch: replaced `const BoxConstraints(maxHeight: kMaxBoardSize)` with `BoxConstraints(maxHeight: boardSizeForWidth(screenWidth))`, wrapped in `Padding(kBoardHorizontalInsets)`. Wide branch: replaced `constraints.maxWidth * 0.6` with `boardSizeForConstraints(constraints)`. |
| `src/lib/widgets/browser_content.dart` | Narrow branch: replaced `(screenHeight * 0.4).clamp(0.0, kMaxBoardSize)` with `boardSizeForWidth(screenWidth)`, wrapped in `Padding(kBoardHorizontalInsets)`, removed `Flexible` wrapper around board (was causing board to shrink below intended size due to Column pressure). Wide branch: replaced ad-hoc `constraints.maxHeight.clamp(0.0, constraints.maxWidth * 0.5)` with `boardSizeForConstraints(constraints)`. |
| `src/test/layout/board_layout_test.dart` | Added `spacing.dart` import; added sanity-check assertion tying reference board size to `boardSizeForWidth(_phoneSize.width)`. |

## Deviations from the plan

1. **Browser narrow layout uses `boardSizeForWidth` instead of `boardSizeForNarrow` with `maxHeightFraction: 0.4`.** The plan (Step 5) called for `boardSizeForNarrow(screenWidth, screenHeight, maxHeightFraction: 0.4)`, but at 390x844 this produces 337.6, while `boardSizeForWidth(390)` produces 382. The existing `board_layout_test.dart` asserts all four screens have the same board size (equality assertion), which the plan (Step 6) says "must be kept." Using a different formula for Browser would break this equality. To maintain the consistency contract, Browser narrow now uses `boardSizeForWidth` like all other screens. The `boardSizeForNarrow` helper remains available if a per-screen height guard is needed in the future.

2. **Drill wide branch uses `widthFraction: 0.5` (default) instead of `0.6`.** The plan (Step 4) called for `boardSizeForConstraints(constraints, widthFraction: 0.6)`, but the wide-layout test (`board_layout_wide_test.dart`) asserts all four screens produce the same board size. At 1024x768, widthFraction 0.5 gives 512 while widthFraction 0.6 gives 600 (clamped from 614.4). Using different fractions would break the equality assertion. The plan's Risk 3 already recommended standardizing on 0.5 for all wide layouts, so this is consistent with the recommended approach.

3. **Add Line wide layout includes the display-name banner above the board (in the left column).** This matches the narrow layout behavior. The plan did not specify where the banner goes in the wide layout; placing it above the board in the left column is the most natural adaptation. Note that this diverges from the "no dynamic content above the board" spec clause (as called out in the plan's Risk 6), but this is a pre-existing issue, not introduced by CT-52.

## Follow-up work

- **Browser height guard for short/landscape viewports:** The old Browser narrow code used `screenHeight * 0.4` as a height guard. This was removed to maintain cross-screen consistency. On very short phones (e.g., iPhone SE in landscape at 667x375), the board would be 367px, leaving only ~308px for controls and move tree. This should be verified manually. If vertical space is too tight, all screens (not just Browser) could adopt `boardSizeForNarrow` with a shared `maxHeightFraction`, preserving the consistency contract while adding a secondary height clamp.

- **`kLineLabelLeftInset` alignment:** With near-zero board margins (4dp), the 16dp left inset for the line label may look visually misaligned relative to the board edge. Consider reducing to match `kBoardHorizontalInset` (4dp).

- **Add Line dynamic banner above the board:** The `aggregateDisplayName` banner above the board in Add Line violates the "no dynamic content above the board" clause in `board-layout-consistency.md`. This is a pre-existing issue (not introduced by CT-52) and should be addressed separately.
