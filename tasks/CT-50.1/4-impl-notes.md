# CT-50.1: Implementation Notes

## Files Modified

| File | Change |
|------|--------|
| `src/lib/theme/spacing.dart` | Added `kBoardFrameTopGap` (double, equals `kBannerGap`) and `kBoardFrameTopInsets` (EdgeInsets) constants with doc comments clarifying they are currently equal to `kBannerGap` but semantically independent. |
| `src/lib/screens/drill_screen.dart` | Wrapped the `body` in `_buildDrillScaffold` with `Padding(padding: kBoardFrameTopInsets, ...)`, applying an 8dp top gap uniformly to both the narrow `Column` branch and the wide `LayoutBuilder` branch. |
| `src/lib/widgets/browser_content.dart` | Changed `kBannerGapInsets` to `kBoardFrameTopInsets` in the root `Padding` of `build()` -- numeric value unchanged, semantic name updated. |
| `src/lib/screens/add_line_screen.dart` | Replaced the conditional `SizedBox(height: kBannerGap)` inside the `if (displayName.isNotEmpty) ...[...]` spread with an unconditional `SizedBox(height: kBoardFrameTopGap)` placed immediately before the `ConstrainedBox`. The display-name banner `Container` is now a bare `if` statement (not a spread list) since it no longer needs to be grouped with a sibling `SizedBox`. |

## Deviations from Plan

None. All four steps were implemented exactly as specified.

## New Tasks / Follow-up Work

- The `kBannerGapInsets` constant in `spacing.dart` is now unreferenced within the codebase (its sole usage in `browser_content.dart` was migrated to `kBoardFrameTopInsets`). A follow-up task could audit remaining usages of `kBannerGapInsets` across the codebase and either remove the constant or confirm it is still used elsewhere.
- The wide-layout `SizedBox(height: constraints.maxHeight, ...)` in `drill_screen.dart` now receives 8dp less height due to the outer `Padding`. Visual verification (plan Step 4) should confirm the `AspectRatio` / `Flexible` combination still renders the board correctly at representative screen sizes.
