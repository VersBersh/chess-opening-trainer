# CT-55: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `features/free-practice.md` | Added "### Mobile Keyboard Handling" subsection inside the "## Inline Filter" section, documenting the collapse behavior for both active-card and pass-complete screens. |
| `src/lib/screens/drill_screen.dart` | (1) Detect keyboard via `MediaQuery.viewInsets.bottom` in `_buildDrillScaffold` and `_buildPassComplete`. (2) Wrap board + line label in `AnimatedSize` with conditional `height: 0` in narrow free-practice layout. (3) Wrap pass-complete header (icon, title, subtitle, spacer) in `AnimatedSize` with collapse logic; when keyboard is open, switch from centered `Column` to `SingleChildScrollView` to prevent overflow on short screens. (4) Conditionally wrap `filterWidget` in `Expanded` only when keyboard is open in narrow free-practice layout. (5) Add `_focusNode.unfocus()` in `onSelected` to dismiss keyboard after label selection. |
| `src/test/screens/drill_filter_test.dart` | Added 5 keyboard-layout tests. "Board reappears" and "pass-complete header" tests use a `ValueNotifier<EdgeInsets>` pattern to change viewInsets without recreating the ProviderScope. Tests use `.hitTestable()` for visibility assertions. |
| `src/test/screens/drill_screen_test.dart` | Fixed pre-existing overflow in "filter box renders in narrow layout" test by adding `setSurfaceSize` to match viewportSize. |

## Files Not Modified (reviewed, no changes needed)

| File | Reason |
|------|--------|
| `src/lib/theme/spacing.dart` | Constants unchanged; `kMaxBoardSize` and `kLineLabelHeight` still used as-is. |
| `src/lib/widgets/chessboard_widget.dart` | No changes needed; board widget is consumed unchanged. |

## Deviations from Plan

| Step | Deviation | Reason |
|------|-----------|--------|
| Step 3 (board sizing) | Used `boardSizeForNarrow()` with `kBoardHorizontalInsets` instead of `const BoxConstraints(maxHeight: kMaxBoardSize)`. | Master branch (CT-52) updated the board sizing API. Resolved merge conflict to use the new API inside our `AnimatedSize` wrapper. |
| Step 4 (pass-complete) | Used `SingleChildScrollView` when keyboard is open instead of only switching `mainAxisAlignment`. | Buttons + filter box can overflow the reduced height on shorter phones. Scrollable layout prevents overflow while keeping all controls accessible. |
| Step 5 (`resizeToAvoidBottomInset`) | Did not set the flag. | The plan's Outcome A applies: with the board collapsed to 0, the freed ~332px (board + label) compensates for the ~300px keyboard. The default `resizeToAvoidBottomInset: true` keeps the body above the keyboard without double-compensation issues. Leaving the default also keeps snackbars and other bottom-anchored widgets positioned correctly. |
| Step 6 (`_computeDropdownLayout`) | No code changes. | The existing logic already uses `MediaQuery.viewInsets.bottom` to compute usable height. When the board collapses and the filter moves up, `spaceBelow` naturally increases, so the dropdown opens downward with adequate room. |

## New Tasks / Follow-up Work

- **Manual device testing:** The `resizeToAvoidBottomInset` decision (Step 5, Outcome A) should be validated on real devices with varying keyboard heights. If any device shows double-compensation artifacts, revisit and conditionally set the flag.
- **Animation golden tests:** The `AnimatedSize` transition (200ms ease-in-out) cannot be verified by widget tests. Consider adding golden image tests or manual QA to confirm smooth transitions.
- **Filter focus during card transitions:** If the user has the filter focused and a new card starts via `_startNextCard`, the board should remain collapsed because `viewInsets.bottom` is still positive. This scenario should be tested manually.
